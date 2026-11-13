import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _ProxiedTarget {
  final String url;
  final Map<String, String> headers;
  final String ext;
  final StreamInfo? ytStreamInfo;
  final YoutubeExplode? ytClient;
  final bool preferExplodeStream;

  const _ProxiedTarget({
    required this.url,
    required this.headers,
    required this.ext,
    this.ytStreamInfo,
    this.ytClient,
    this.preferExplodeStream = false,
  });
}

/// Lightweight local loopback HTTP proxy on 127.0.0.1 for ExoPlayer / just_audio.
/// Eliminates IPv4/IPv6 mismatches, header stripping across redirects, and HTTP 403
/// "(0) Source error" when ExoPlayer fetches googlevideo.com streams directly.
class LocalStreamProxy {
  LocalStreamProxy._();
  static final LocalStreamProxy instance = LocalStreamProxy._();

  HttpServer? _server;
  int _port = 0;
  int _counter = 0;
  final Map<String, _ProxiedTarget> _targets = {};
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..autoUncompress = false;

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handleRequest, onError: (e) {
      debugPrint('[LocalStreamProxy] server error: $e');
    });
    debugPrint('[LocalStreamProxy] listening on 127.0.0.1:$_port');
  }

  String _guessExtension(String url, {String? mimeHint}) {
    final lower = '${mimeHint ?? ''} $url'.toLowerCase();
    if (lower.contains('webm') ||
        lower.contains('opus') ||
        lower.contains('itag=251') ||
        lower.contains('itag=250') ||
        lower.contains('itag=249')) {
      return 'webm';
    }
    if (lower.contains('.mp3') || lower.contains('audio/mpeg')) {
      return 'mp3';
    }
    if (lower.contains('.aac') || lower.contains('audio/aac')) {
      return 'aac';
    }
    return 'm4a';
  }

  /// Registers a remote audio stream and returns a local `http://127.0.0.1:<port>/stream/<id>.<ext>` URL.
  Future<String> register(
    String url, {
    Map<String, String>? headers,
    String? mimeHint,
    StreamInfo? ytStreamInfo,
    YoutubeExplode? ytClient,
    bool preferExplodeStream = false,
  }) async {
    await _ensureStarted();
    if (_targets.length > 40) {
      final oldestKeys = _targets.keys.take(_targets.length - 30).toList();
      for (final k in oldestKeys) {
        _targets.remove(k);
      }
    }
    final ext = ytStreamInfo != null
        ? (ytStreamInfo.container.name.toLowerCase() == 'webm' ? 'webm' : 'm4a')
        : _guessExtension(url, mimeHint: mimeHint);
    final id = '${++_counter}_${DateTime.now().millisecondsSinceEpoch}';
    _targets[id] = _ProxiedTarget(
      url: url,
      headers: headers ?? const {},
      ext: ext,
      ytStreamInfo: ytStreamInfo,
      ytClient: ytClient,
      preferExplodeStream: preferExplodeStream,
    );
    return 'http://127.0.0.1:$_port/stream/$id.$ext';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final segments = req.uri.pathSegments;
    if (segments.length < 2 || segments.first != 'stream') {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    final rawId = segments[1].replaceFirst(RegExp(r'\.(m4a|mp4|mp3|webm|aac)$'), '');
    final target = _targets[rawId];
    if (target == null) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    try {
      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      final isHead = req.method.toUpperCase() == 'HEAD';

      if (target.preferExplodeStream &&
          target.ytStreamInfo != null &&
          target.ytClient != null) {
        final served = await _serveViaYoutubeExplode(req, target, isHead: isHead);
        if (served) return;
      }

      HttpClientResponse? upstreamResp;
      try {
        upstreamResp = await _openFollowingRedirects(
          method: req.method,
          url: target.url,
          baseHeaders: target.headers,
          rangeHeader: rangeHeader,
        );
        // Many googlevideo.com endpoints reject HEAD with 403/405; probe via GET bytes=0-0 instead.
        if (isHead && upstreamResp.statusCode >= 400) {
          await upstreamResp.drain<void>();
          upstreamResp = await _openFollowingRedirects(
            method: 'GET',
            url: target.url,
            baseHeaders: target.headers,
            rangeHeader: 'bytes=0-0',
          );
        }
      } catch (e) {
        debugPrint('[LocalStreamProxy] upstream open failed: $e');
        upstreamResp = null;
      }

      if (upstreamResp != null && upstreamResp.statusCode < 400) {
        req.response.bufferOutput = false;
        req.response.statusCode = isHead ? HttpStatus.ok : upstreamResp.statusCode;

        final defaultMime = target.ext == 'webm' ? 'audio/webm' : 'audio/mp4';
        final contentType = upstreamResp.headers.value(HttpHeaders.contentTypeHeader);
        req.response.headers.set(
          HttpHeaders.contentTypeHeader,
          (contentType != null && contentType.isNotEmpty) ? contentType : defaultMime,
        );

        final contentRange = upstreamResp.headers.value(HttpHeaders.contentRangeHeader);
        if (isHead) {
          final totalFromRange = _parseTotalFromContentRange(contentRange);
          final len = totalFromRange ?? upstreamResp.contentLength;
          if (len >= 0) {
            req.response.contentLength = len;
          }
          req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
          await upstreamResp.drain<void>();
          await req.response.close();
          return;
        }

        final contentLength = upstreamResp.contentLength;
        if (contentLength >= 0) {
          req.response.contentLength = contentLength;
        }
        if (contentRange != null) {
          req.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
        }
        req.response.headers.set(
          HttpHeaders.acceptRangesHeader,
          upstreamResp.headers.value(HttpHeaders.acceptRangesHeader) ?? 'bytes',
        );

        try {
          await req.response.addStream(upstreamResp);
        } catch (_) {}
        try {
          await req.response.close();
        } catch (_) {}
        return;
      }

      if (upstreamResp != null) {
        await upstreamResp.drain<void>();
      }

      // Fallback to YoutubeExplode streamsClient.get() if StreamInfo is attached
      if (target.ytStreamInfo != null && target.ytClient != null) {
        final served = await _serveViaYoutubeExplode(req, target, isHead: isHead);
        if (served) return;
      }

      req.response.statusCode = upstreamResp?.statusCode ?? HttpStatus.badGateway;
      await req.response.close();
    } catch (e) {
      debugPrint('[LocalStreamProxy] upstream error: $e');
      try {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<bool> _serveViaYoutubeExplode(
    HttpRequest req,
    _ProxiedTarget target, {
    required bool isHead,
  }) async {
    final info = target.ytStreamInfo!;
    final yt = target.ytClient!;
    final total = info.size.totalBytes;
    final defaultMime = target.ext == 'webm' ? 'audio/webm' : 'audio/mp4';

    try {
      if (isHead) {
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.set(HttpHeaders.contentTypeHeader, defaultMime);
        req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        if (total > 0) req.response.contentLength = total;
        await req.response.close();
        return true;
      }

      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      int startByte = 0;
      int? endByte;
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        startByte = int.tryParse(parts[0].trim()) ?? 0;
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          endByte = int.tryParse(parts[1].trim());
        }
      }

      final hasRange = rangeHeader != null && total > 0;
      final clampedEnd =
          (endByte != null && endByte < total) ? endByte : (total > 0 ? total - 1 : null);

      req.response.bufferOutput = false;
      req.response.statusCode = hasRange ? HttpStatus.partialContent : HttpStatus.ok;
      req.response.headers.set(HttpHeaders.contentTypeHeader, defaultMime);
      req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (hasRange && clampedEnd != null && clampedEnd >= startByte) {
        req.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $startByte-$clampedEnd/$total',
        );
        req.response.contentLength = clampedEnd - startByte + 1;
      } else if (total > 0) {
        req.response.contentLength = total;
      }

      final byteStream = yt.videos.streamsClient.get(info);
      int skipped = 0;
      int sent = 0;
      final maxToSend = (hasRange && clampedEnd != null) ? (clampedEnd - startByte + 1) : null;

      await for (final chunk in byteStream) {
        if (chunk.isEmpty) continue;
        List<int> slice = chunk;
        if (skipped < startByte) {
          final remainingSkip = startByte - skipped;
          if (remainingSkip >= slice.length) {
            skipped += slice.length;
            continue;
          }
          slice = slice.sublist(remainingSkip);
          skipped = startByte;
        }
        if (maxToSend != null) {
          final remaining = maxToSend - sent;
          if (remaining <= 0) break;
          if (slice.length > remaining) {
            slice = slice.sublist(0, remaining);
          }
        }
        req.response.add(slice);
        sent += slice.length;
        if (maxToSend != null && sent >= maxToSend) break;
      }

      try {
        await req.response.close();
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('[LocalStreamProxy] YoutubeExplode stream serve error: $e');
      return false;
    }
  }

  int? _parseTotalFromContentRange(String? contentRange) {
    if (contentRange == null || !contentRange.contains('/')) return null;
    final totalPart = contentRange.split('/').last.trim();
    if (totalPart == '*') return null;
    return int.tryParse(totalPart);
  }

  Future<HttpClientResponse> _openFollowingRedirects({
    required String method,
    required String url,
    required Map<String, String> baseHeaders,
    String? rangeHeader,
    int maxRedirects = 5,
  }) async {
    var currentUri = Uri.parse(url);
    for (int hop = 0; hop <= maxRedirects; hop++) {
      final outReq = await _client.openUrl(
        method.toUpperCase() == 'HEAD' ? 'HEAD' : 'GET',
        currentUri,
      );
      outReq.followRedirects = false;
      baseHeaders.forEach((k, v) => outReq.headers.set(k, v));
      outReq.headers.set(HttpHeaders.acceptHeader, '*/*');
      if (rangeHeader != null && rangeHeader.isNotEmpty) {
        outReq.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      }

      final resp = await outReq.close().timeout(const Duration(seconds: 12));
      if (resp.isRedirect ||
          resp.statusCode == 301 ||
          resp.statusCode == 302 ||
          resp.statusCode == 303 ||
          resp.statusCode == 307 ||
          resp.statusCode == 308) {
        final loc = resp.headers.value(HttpHeaders.locationHeader);
        await resp.drain<void>();
        if (loc == null || loc.isEmpty) return resp;
        currentUri = currentUri.resolve(loc);
        continue;
      }
      return resp;
    }
    throw Exception('Too many redirects');
  }
}
