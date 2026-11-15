import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/app_state.dart';
import '../services/yt_auth_service.dart';
import 'liquid_glass_container.dart';

class YouTubeLoginSheet extends StatefulWidget {
  const YouTubeLoginSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const YouTubeLoginSheet(),
    );
  }

  @override
  State<YouTubeLoginSheet> createState() => _YouTubeLoginSheetState();
}

class _YouTubeLoginSheetState extends State<YouTubeLoginSheet> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  bool _loginDetected = false;

  final String _initialUrl =
      'https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F';

  Future<void> _checkCookies() async {
    if (_loginDetected) return;
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: WebUri('https://music.youtube.com'));
      final cookieString = cookies.map((c) => c.name + "=" + c.value).join("; ");

      final bool hasAuth = cookies.any((c) => c.name == 'SAPISID' || c.name == 'LOGIN_INFO' || c.name == '__Secure-1PSID');

      if (hasAuth && !_loginDetected) {
        _loginDetected = true;
        HapticFeedback.heavyImpact();

        await YouTubeAuthService.instance.saveLoginSession(
          cookies: cookieString,
          userName: 'YouTube Music User',
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('YouTube Music Account connected successfully! 🎉'),
              backgroundColor: AppState.instance.accentColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[YouTubeLoginSheet] Cookie check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF0D1117),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isLight ? Colors.black12 : Colors.white12,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA2D48).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFA2D48), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YouTube Music Sign In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: app.textColor,
                        ),
                      ),
                      Text(
                        'Sign in to sync your Liked Songs & Playlists',
                        style: TextStyle(
                          fontSize: 11,
                          color: app.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: app.secondaryTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          if (_isLoading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFA2D48)),
              minHeight: 2.5,
            ),

          // WebView
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
              initialSettings: InAppWebViewSettings(
                userAgent:
                    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36',
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                thirdPartyCookiesEnabled: true,
                supportMultipleWindows: false,
              ),
              onWebViewCreated: (controller) => _webViewController = controller,
              onProgressChanged: (_, progress) {
                setState(() {
                  _progress = progress / 100;
                  _isLoading = progress < 100;
                });
                if (progress > 60) _checkCookies();
              },
              onLoadStop: (controller, url) async {
                setState(() => _isLoading = false);
                await _checkCookies();
              },
            ),
          ),
        ],
      ),
    );
  }
}
