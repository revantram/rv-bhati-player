import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/app_state.dart';
import '../services/jiosaavn_auth_service.dart';
import 'ios_bounce_button.dart';

class JioSaavnLoginSheet extends StatefulWidget {
  const JioSaavnLoginSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const JioSaavnLoginSheet(),
    );
  }

  @override
  State<JioSaavnLoginSheet> createState() => _JioSaavnLoginSheetState();
}

class _JioSaavnLoginSheetState extends State<JioSaavnLoginSheet> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _loginHandled = false;

  static const String _kCustomCss = '''
    html, body {
      background-color: #0d1117 !important;
      color: #f0f6fc !important;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
    }
    header, footer, nav, [class*="header" i], [class*="footer" i], [class*="banner" i], .c-banner, #sr-toast-announcer-global {
      display: none !important;
    }
    [class*="email" i], button[name*="email" i], a[href*="email" i], div:has(> input[type="email"]), input[type="email"] {
      display: none !important;
    }
    [class*="google" i], [class*="facebook" i], [class*="apple" i], [class*="social" i], .c-login__social, .c-login__divider {
      display: none !important;
    }
    .PhoneInputInput, input[type="tel"] {
      background: #161b22 !important;
      color: #ffffff !important;
      border: 1.5px solid #30363d !important;
      border-radius: 12px !important;
      padding: 14px 16px !important;
      font-size: 17px !important;
      outline: none !important;
    }
    .PhoneInputInput:focus, input[type="tel"]:focus {
      border-color: #2ea043 !important;
      box-shadow: 0 0 10px rgba(46, 160, 67, 0.3) !important;
    }
    input[type="number"], input[maxlength="1"], input[maxlength="6"] {
      background: #161b22 !important;
      color: #ffffff !important;
      border: 1.5px solid #2ea043 !important;
      border-radius: 10px !important;
      font-size: 20px !important;
      text-align: center !important;
    }
    button[type="submit"], button.c-btn, button[class*="primary" i] {
      background: linear-gradient(135deg, #2ea043, #238636) !important;
      color: #ffffff !important;
      border: none !important;
      border-radius: 25px !important;
      padding: 14px 28px !important;
      font-size: 16px !important;
      font-weight: 600 !important;
      box-shadow: 0 4px 15px rgba(46, 160, 67, 0.4) !important;
    }
  ''';

  static const String _kInjectionJs = '''
    (function() {
      function removeNonOtpOptions() {
        document.querySelectorAll('button, a, p, span, div').forEach(function(el) {
          var t = (el.innerText || '').toLowerCase();
          if (t.includes('continue with email') || t.includes('or continue with') || t.includes('facebook') || t.includes('google') || t.includes('log in with email')) {
            if (el.tagName === 'BUTTON' || el.tagName === 'A' || el.classList.contains('c-login__social')) {
              el.style.display = 'none';
            }
          }
        });
      }
      removeNonOtpOptions();
      setInterval(removeNonOtpOptions, 500);

      var reported = false;
      async function checkLogin() {
        if (reported) return;
        var cookies = document.cookie || '';
        var isAuth = cookies.includes('CT=') || cookies.includes('user_id=') || (!window.location.pathname.includes('/login') && !window.location.pathname.includes('/signup'));

        if (isAuth) {
          reported = true;
          try {
            let res = await fetch('/api.php?__call=webapi.getUserDetails&api_version=4&ctx=web6dot0&_format=json&_marker=0', {credentials: 'include'});
            let data = await res.json();
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('onLoginSuccess', {
                cookies: cookies,
                data: data
              });
            }
          } catch (err) {
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('onLoginSuccess', {
                cookies: cookies,
                data: null
              });
            }
          }
        }
      }

      setInterval(checkLogin, 1000);
    })();
  ''';

  void _handleSuccessfulLogin(dynamic args) async {
    if (!mounted || _loginHandled) return;
    _loginHandled = true;

    String cookies = '';
    String? userId;
    String? userName;
    String? avatarUrl;
    String? phoneNumber;

    try {
      if (args is List && args.isNotEmpty && args[0] is Map) {
        final map = args[0] as Map;
        cookies = map['cookies']?.toString() ?? '';
        final data = map['data'];
        if (data is Map) {
          userId = data['id']?.toString() ?? data['uid']?.toString();
          userName = data['name']?.toString() ?? data['user_name']?.toString();
          avatarUrl = data['image']?.toString();
          phoneNumber = data['phone']?.toString();
        }
      }

      // Also extract cookies directly from CookieManager if available
      try {
        final cookieList = await CookieManager.instance().getCookies(
          url: WebUri('https://www.jiosaavn.com'),
        );
        if (cookieList.isNotEmpty) {
          final cookieHeader = cookieList.map((c) => '${c.name}=${c.value}').join('; ');
          if (cookieHeader.isNotEmpty) cookies = cookieHeader;
          for (final c in cookieList) {
            if (c.name == 'user_id' && (userId == null || userId.isEmpty)) {
              userId = c.value.toString();
            }
          }
        }
      } catch (_) {}

      await JioSaavnAuthService.instance.saveLoginSession(
        cookies: cookies,
        userId: userId,
        userName: userName,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2EA043),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'JioSaavn Login Successful! Syncing ${JioSaavnAuthService.instance.displayName}...',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[JioSaavnLoginSheet] error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final size = MediaQuery.sizeOf(context);

    return Container(
      height: size.height * 0.88,
      decoration: BoxDecoration(
        color: app.isDark ? const Color(0xFF0D1117) : const Color(0xFF161B22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EA043).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Color(0xFF2EA043),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'JioSaavn Mobile Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Mobile OTP Only • 100% Ad-Free • Studio 320kbps',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IosBounceButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 2.5,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2EA043)),
              )
            else
              const Divider(height: 1, color: Colors.white12),

            // OTP Hint Info Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2EA043).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2EA043).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF2EA043), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter your mobile number below to receive an OTP. Liked songs & playlists will sync automatically.',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

            // WebView
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://www.jiosaavn.com/login'),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  cacheEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  transparentBackground: true,
                  userAgent: 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'onLoginSuccess',
                    callback: (args) => _handleSuccessfulLogin(args),
                  );
                },
                onLoadStart: (controller, url) {
                  setState(() => _isLoading = true);
                },
                onProgressChanged: (controller, progress) {
                  setState(() => _progress = progress / 100);
                  if (progress > 50) {
                    controller.injectCSSCode(source: _kCustomCss);
                    controller.evaluateJavascript(source: _kInjectionJs);
                  }
                },
                onLoadStop: (controller, url) async {
                  setState(() => _isLoading = false);
                  await controller.injectCSSCode(source: _kCustomCss);
                  await controller.evaluateJavascript(source: _kInjectionJs);

                  // If navigated away from login page, check if login occurred
                  final urlStr = url?.toString() ?? '';
                  if (!urlStr.contains('/login') && !urlStr.contains('/signup')) {
                    _handleSuccessfulLogin([
                      {'cookies': '', 'data': null}
                    ]);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
