import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/online_song.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import 'ios_bounce_button.dart';

class YouTubeMusicSheet extends StatefulWidget {
  final OnlineSong song;

  const YouTubeMusicSheet({super.key, required this.song});

  @override
  State<YouTubeMusicSheet> createState() => _YouTubeMusicSheetState();
}

class _YouTubeMusicSheetState extends State<YouTubeMusicSheet> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _useMobileWatch = false;

  String get _videoId {
    final id = widget.song.id;
    return id.startsWith('yt_') ? id.replaceFirst('yt_', '') : id;
  }

  @override
  void initState() {
    super.initState();
    try {
      AudioController.instance.player.pause();
    } catch (_) {}
  }

  void _switchToMobileWatch() {
    if (!mounted || _useMobileWatch) return;
    setState(() {
      _useMobileWatch = true;
      _isLoading = true;
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri('https://m.youtube.com/watch?v=$_videoId'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;
    final pad = MediaQuery.paddingOf(context);

    final embedHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background-color: #0B0F19; display: flex; justify-content: center; align-items: center; height: 100vh; overflow: hidden; }
    #player { width: 100%; height: 100%; border: none; border-radius: 16px; }
  </style>
</head>
<body>
  <div id="player"></div>
  <script src="https://www.youtube.com/iframe_api"></script>
  <script>
    function onYouTubeIframeAPIReady() {
      new YT.Player('player', {
        videoId: '$_videoId',
        playerVars: { autoplay: 1, playsinline: 1, rel: 0, origin: 'https://revantram.github.io' },
        events: {
          onReady: function(e) { try { e.target.playVideo(); } catch (_) {} },
          onError: function(e) {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('embedError', e.data);
            }
          }
        }
      });
    }
  </script>
</body>
</html>
''';

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: pad.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Song info & close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.song.artist} • ${_useMobileWatch ? "YouTube Mobile" : "YouTube Web Engine"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_useMobileWatch)
                TextButton(
                  onPressed: _switchToMobileWatch,
                  child: Text(
                    'Full Web',
                    style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Embedded Video / Audio Player View
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: _useMobileWatch ? 320 : 220,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  InAppWebView(
                    initialData: InAppWebViewInitialData(
                      data: embedHtml,
                      baseUrl: WebUri('https://revantram.github.io/rv-bhati-player/'),
                      mimeType: 'text/html',
                      encoding: 'utf-8',
                    ),
                    initialSettings: InAppWebViewSettings(
                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: false,
                      cacheEnabled: true,
                      javaScriptEnabled: true,
                      transparentBackground: true,
                      userAgent:
                          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36',
                    ),
                    onWebViewCreated: (ctrl) {
                      _webViewController = ctrl;
                      ctrl.addJavaScriptHandler(
                        handlerName: 'embedError',
                        callback: (_) {
                          _switchToMobileWatch();
                          return null;
                        },
                      );
                    },
                    onLoadStop: (ctrl, url) {
                      if (mounted) setState(() => _isLoading = false);
                      if (_useMobileWatch) {
                        ctrl.evaluateJavascript(source: '''
                          (function() {
                            var v = document.querySelector('video');
                            if (v) { v.muted = false; v.play().catch(function(){}); }
                          })();
                        ''');
                      }
                    },
                  ),
                  if (_isLoading)
                    Container(
                      color: const Color(0xFF0B0F19),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: accent,
                              strokeWidth: 2.5,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Starting YouTube Player...',
                              style: TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action row
          Row(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: DownloadService.instance,
                  builder: (context, _) {
                    final isDl = DownloadService.instance.isDownloaded(widget.song.id);
                    final isDownloading = DownloadService.instance.isDownloading(widget.song.id);

                    return iOSBounceButton(
                      onTap: () {
                        if (!isDl && !isDownloading) {
                          DownloadService.instance.downloadSong(widget.song);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloading to local storage: "${widget.song.title}"'),
                              backgroundColor: accent,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isDownloading)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                              )
                            else
                              Icon(
                                isDl ? Icons.check_circle_rounded : Icons.download_rounded,
                                size: 18,
                                color: isDl ? Colors.green : textColor,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              isDl ? 'Downloaded' : 'Download to Storage',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
