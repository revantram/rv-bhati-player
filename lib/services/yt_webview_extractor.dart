import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'yt_audio_resolver.dart';

/// Headless Chromium WebView YouTube stream extractor (inspired by YMusicV4's
/// embedded web player architecture). Runs YouTube's live BotGuard/PO-token JS
/// inside Android's system WebView and captures the signed `googlevideo.com`
/// audio playback URL for native ExoPlayer / LocalStreamProxy playback.
class YtWebViewExtractor {
  YtWebViewExtractor._();

  static const String _mobileUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36';

  static Future<List<ResolvedAudioStream>> extractAudioStreams(
    String videoId, {
    Duration timeout = const Duration(seconds: 7),
  }) async {
    final cleanId = videoId.replaceFirst('yt_', '').trim();
    if (cleanId.isEmpty) return const [];

    final completer = Completer<List<ResolvedAudioStream>>();
    final collected = <ResolvedAudioStream>[];
    final seenUrls = <String>{};
    HeadlessInAppWebView? headless;
    bool finished = false;
    Timer? hardTimer;

    void finishNow() {
      if (finished) return;
      finished = true;
      hardTimer?.cancel();
      try {
        headless?.dispose();
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.complete(List.unmodifiable(collected));
      }
    }

    void considerUrl(String rawUrl, {Map<String, String>? reqHeaders}) {
      if (finished || rawUrl.isEmpty) return;
      if (!rawUrl.contains('googlevideo.com/videoplayback')) return;

      final uri = Uri.tryParse(rawUrl);
      if (uri == null) return;
      final qp = Map<String, String>.from(uri.queryParameters);
      final mime = (qp['mime'] ?? '').toLowerCase();
      final itag = qp['itag'] ?? '';
      final isAudio = mime.startsWith('audio/') ||
          itag == '140' ||
          itag == '139' ||
          itag == '251' ||
          itag == '250' ||
          itag == '249';
      if (!isAudio) return;

      // Strip chunk range parameters so ExoPlayer/LocalStreamProxy can fetch from byte 0
      qp.remove('range');
      qp.remove('rn');
      qp.remove('rbuf');
      final cleanUrl = uri.replace(queryParameters: qp).toString();
      if (!seenUrls.add(cleanUrl)) return;

      final headers = <String, String>{
        'User-Agent': reqHeaders?['User-Agent'] ?? _mobileUa,
        'Referer': 'https://m.youtube.com/',
        'Origin': 'https://m.youtube.com',
      };

      collected.add(ResolvedAudioStream(
        url: cleanUrl,
        headers: headers,
        source: 'webview_yt',
      ));

      // Prefer audio/mp4 (itag 140/139); finish immediately once found
      if (mime.contains('mp4') || itag == '140' || itag == '139') {
        finishNow();
      } else {
        Future.delayed(const Duration(milliseconds: 500), finishNow);
      }
    }

    hardTimer = Timer(timeout, finishNow);

    try {
      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://m.youtube.com/watch?v=$cleanId'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          cacheEnabled: true,
          userAgent: _mobileUa,
        ),
        shouldInterceptRequest: (controller, request) async {
          considerUrl(
            request.url.toString(),
            reqHeaders: request.headers,
          );
          return null;
        },
        onLoadResource: (controller, resource) {
          final u = resource.url?.toString() ?? '';
          considerUrl(u);
        },
        onLoadStop: (controller, url) async {
          if (finished) return;
          try {
            // Mute any HTML5 player element and nudge playback + check adaptiveFormats
            final jsResult = await controller.evaluateJavascript(source: '''
              (function() {
                try {
                  var vids = document.querySelectorAll('video, audio');
                  for (var i = 0; i < vids.length; i++) {
                    vids[i].muted = true;
                    vids[i].volume = 0;
                    if (vids[i].paused && typeof vids[i].play === 'function') {
                      vids[i].play().catch(function(){});
                    }
                  }
                  var pr = window.ytInitialPlayerResponse;
                  if (pr && pr.streamingData && pr.streamingData.adaptiveFormats) {
                    var out = [];
                    var af = pr.streamingData.adaptiveFormats;
                    for (var j = 0; j < af.length; j++) {
                      if (af[j].url && af[j].mimeType && af[j].mimeType.indexOf('audio/') === 0) {
                        out.push(af[j].url);
                      }
                    }
                    return JSON.stringify(out);
                  }
                } catch (e) {}
                return '[]';
              })();
            ''');
            if (!finished && jsResult is String && jsResult.startsWith('[')) {
              final list = jsonDecode(jsResult);
              if (list is List) {
                for (final item in list) {
                  if (item is String && item.isNotEmpty) {
                    considerUrl(item);
                  }
                }
              }
            }
          } catch (_) {}
        },
      );

      await headless.run();
    } catch (e) {
      debugPrint('[YtWebViewExtractor] error: $e');
      finishNow();
    }

    return completer.future;
  }
}
