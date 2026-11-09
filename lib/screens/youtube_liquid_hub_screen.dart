import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../widgets/liquid_glass_container.dart';
import 'video_player_screen.dart';

class YouTubeServerInstance {
  final String name;
  final String webUrl;
  final String apiBase;
  final bool isInvidious;

  const YouTubeServerInstance({
    required this.name,
    required this.webUrl,
    required this.apiBase,
    this.isInvidious = false,
  });
}

class YoutubeLiquidHubScreen extends StatefulWidget {
  final double? topOffset;
  final double? bottomOffset;
  final VoidCallback? onBack;
  final bool isEmbedded;

  const YoutubeLiquidHubScreen({
    super.key,
    this.topOffset,
    this.bottomOffset,
    this.onBack,
    this.isEmbedded = false,
  });

  @override
  State<YoutubeLiquidHubScreen> createState() => _YoutubeLiquidHubScreenState();
}

class _YoutubeLiquidHubScreenState extends State<YoutubeLiquidHubScreen> {
  InAppWebViewController? _webViewController;

  static const List<YouTubeServerInstance> _instances = [
    YouTubeServerInstance(
      name: 'Piped (Ultra-Fast)',
      webUrl: 'https://piped.video',
      apiBase: 'https://pipedapi.kavin.rocks',
    ),
    YouTubeServerInstance(
      name: 'Piped Lunar (CDN)',
      webUrl: 'https://piped.lunar.icu',
      apiBase: 'https://pipedapi.lunar.icu',
    ),
    YouTubeServerInstance(
      name: 'Yewtu.be (Invidious)',
      webUrl: 'https://yewtu.be',
      apiBase: 'https://yewtu.be/api/v1',
      isInvidious: true,
    ),
    YouTubeServerInstance(
      name: 'Puffyan (Backup)',
      webUrl: 'https://vid.puffyan.us',
      apiBase: 'https://vid.puffyan.us/api/v1',
      isInvidious: true,
    ),
  ];

  int _currentInstanceIndex = 0;
  YouTubeServerInstance get _currentInstance => _instances[_currentInstanceIndex];

  bool _isLoading = true;
  double _loadProgress = 0.0;
  bool _hasError = false;
  String? _errorMessage;
  bool _isSearching = false;
  bool _isResolvingStream = false;
  final TextEditingController _searchCtrl = TextEditingController();

  static const String _glassmorphismCss = """
    /* 1. Hide Website Headers, Navbars, Footers & Branding */
    header, nav, .navbar, .site-header, footer, .footer, .drawer, #sidebar, .header-container {
        display: none !important;
    }

    /* 2. Force App-Matched Dark/Frosted Background */
    body, html, #app, main, .main-content {
        background: transparent !important;
        background-color: transparent !important;
        color: #FFFFFF !important;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
        overflow-x: hidden !important;
    }

    /* 3. Style Video Cards into Liquid Glass Containers */
    .card, .thumbnail, .video-card, .video-item, .feed-item, .grid-item {
        background: rgba(255, 255, 255, 0.08) !important;
        backdrop-filter: blur(20px) !important;
        -webkit-backdrop-filter: blur(20px) !important;
        border: 1px solid rgba(255, 255, 255, 0.15) !important;
        border-radius: 18px !important;
        box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3) !important;
        margin-bottom: 14px !important;
        overflow: hidden !important;
    }

    /* 4. Text & Typography Refinement */
    h1, h2, h3, h4, p, span, a {
        color: #F5F5F7 !important;
    }
    .channel-name, .metadata, .views {
        color: rgba(255, 255, 255, 0.6) !important;
    }

    /* 5. Extra Ads & Promo Cleaning */
    .ad-container, .promoted-item, .banner, .announcement {
        display: none !important;
    }
  """;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _injectGlassmorphism() {
    final js = """
      (function() {
        var existing = document.getElementById('rv-liquid-style');
        if (!existing) {
          var style = document.createElement('style');
          style.id = 'rv-liquid-style';
          style.type = 'text/css';
          style.innerHTML = `$_glassmorphismCss`;
          document.head.appendChild(style);
        }
      })();
    """;
    _webViewController?.evaluateJavascript(source: js);
  }

  void _switchToNextInstance({bool silent = false}) {
    final nextIndex = (_currentInstanceIndex + 1) % _instances.length;
    setState(() {
      _currentInstanceIndex = nextIndex;
      _hasError = false;
      _isLoading = true;
    });

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Switched to ${_currentInstance.name}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_currentInstance.webUrl)),
    );
  }

  void _onSearchSubmit(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    setState(() => _isSearching = false);
    HapticFeedback.lightImpact();

    String searchUrl;
    if (_currentInstance.isInvidious) {
      searchUrl = '${_currentInstance.webUrl}/search?q=${Uri.encodeComponent(clean)}';
    } else {
      searchUrl = '${_currentInstance.webUrl}/results?search_query=${Uri.encodeComponent(clean)}';
    }

    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(searchUrl)));
  }

  String? _extractVideoId(Uri uri) {
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    final path = uri.path;
    if (path.contains('/watch/')) {
      final parts = path.split('/watch/');
      if (parts.length > 1 && parts[1].isNotEmpty) {
        return parts[1].split('?').first;
      }
    } else if (path.startsWith('/watch')) {
      final segments = uri.pathSegments;
      if (segments.length > 1) {
        return segments[1];
      }
    } else if (path.startsWith('/embed/')) {
      return path.split('/embed/').last.split('?').first;
    }
    return null;
  }

  Future<void> _handleWatchIntercept(String videoId, Uri originalUri) async {
    setState(() => _isResolvingStream = true);
    HapticFeedback.mediumImpact();

    String? directStreamUrl;
    String videoTitle = 'YouTube Video';
    int durationSec = 300;

    // 1. Try Piped stream endpoints
    final pipedApis = [
      'https://pipedapi.kavin.rocks/streams/$videoId',
      'https://pipedapi.lunar.icu/streams/$videoId',
      'https://api.piped.private.coffee/streams/$videoId',
    ];

    for (final api in pipedApis) {
      try {
        final resp = await http.get(Uri.parse(api)).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          videoTitle = data['title']?.toString() ?? videoTitle;
          durationSec = (data['duration'] as num?)?.toInt() ?? 300;

          // Prefer HLS stream
          final hls = data['hls']?.toString();
          if (hls != null && hls.isNotEmpty) {
            directStreamUrl = hls;
            break;
          }

          // Otherwise best progressive video stream
          final videoStreams = data['videoStreams'] as List?;
          if (videoStreams != null && videoStreams.isNotEmpty) {
            for (final vs in videoStreams) {
              final url = vs['url']?.toString();
              if (url != null && url.isNotEmpty) {
                directStreamUrl = url;
                break;
              }
            }
          }
          if (directStreamUrl != null) break;
        }
      } catch (_) {}
    }

    // 2. Try Invidious API fallback
    if (directStreamUrl == null) {
      try {
        final invUrl = 'https://yewtu.be/api/v1/videos/$videoId';
        final resp = await http.get(Uri.parse(invUrl)).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          videoTitle = data['title']?.toString() ?? videoTitle;
          final hls = data['hlsUrl']?.toString();
          if (hls != null && hls.isNotEmpty) {
            directStreamUrl = hls;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isResolvingStream = false);

    if (directStreamUrl != null && directStreamUrl.isNotEmpty) {
      // Launch native RV Bhati Video Player with all gesture controls, speed, audio boost!
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            playlist: [
              MediaFile(
                id: 'yt_$videoId',
                title: '$videoTitle.mp4',
                path: directStreamUrl!,
                kind: MediaKind.video,
                duration: Duration(seconds: durationSec),
              ),
            ],
            startIndex: 0,
          ),
        ),
      );
    } else {
      // Fallback: load directly inside webview for seamless ad-free inline playback
      _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(originalUri.toString())));
    }
  }

  void _showServerSwitcher() {
    HapticFeedback.lightImpact();
    final app = AppState.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.cloud_sync_rounded, color: Color(0xFFFF2A85), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'YouTube Server Instance',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(_instances.length, (i) {
                final inst = _instances[i];
                final isSelected = i == _currentInstanceIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentInstanceIndex = i;
                        _hasError = false;
                        _isLoading = true;
                      });
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(inst.webUrl)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? app.accentColor.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? app.accentColor : Colors.white12,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            inst.isInvidious ? Icons.shield_rounded : Icons.bolt_rounded,
                            color: isSelected ? app.accentColor : Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inst.name,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? app.accentColor : app.textColor,
                                  ),
                                ),
                                Text(
                                  inst.webUrl,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: app.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: app.accentColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final pad = MediaQuery.paddingOf(context);
    final topPad = widget.topOffset ?? (pad.top + 8);
    final bottomPad = widget.bottomOffset ?? (pad.bottom + 160);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. InAppWebView
          Padding(
            padding: EdgeInsets.only(top: topPad + 58, bottom: bottomPad),
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_currentInstance.webUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                isInspectable: false,
                transparentBackground: true,
                userAgent:
                    'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              ),
              onWebViewCreated: (ctrl) {
                _webViewController = ctrl;
              },
              onProgressChanged: (ctrl, progress) {
                setState(() {
                  _loadProgress = progress / 100.0;
                  if (progress >= 100) _isLoading = false;
                });
                if (progress > 70) {
                  _injectGlassmorphism();
                }
              },
              onLoadStop: (ctrl, url) {
                setState(() => _isLoading = false);
                _injectGlassmorphism();
              },
              onReceivedError: (ctrl, request, error) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                  _isLoading = false;
                });
                // Silent fallback switch
                _switchToNextInstance(silent: true);
              },
              shouldOverrideUrlLoading: (ctrl, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;

                final scheme = uri.scheme.toLowerCase();
                final urlStr = uri.toString();

                // Strictly block external YouTube / Market app intents
                if (scheme == 'vnd.youtube' ||
                    urlStr.startsWith('intent://') ||
                    scheme == 'market' ||
                    urlStr.contains('play.google.com')) {
                  return NavigationActionPolicy.CANCEL;
                }

                // Intercept video playback
                final videoId = _extractVideoId(uri.uriValue);
                if (videoId != null && videoId.isNotEmpty) {
                  _handleWatchIntercept(videoId, uri.uriValue);
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),

          // 2. Loading Indicator Line
          if (_isLoading)
            Positioned(
              top: topPad + 56,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadProgress > 0 ? _loadProgress : null,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(app.accentColor),
                minHeight: 2.5,
              ),
            ),

          // 3. Resolving Stream Overlay
          if (_isResolvingStream)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(22),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(app.accentColor),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Opening Ad-Free Player...',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Frosted Error & Retry Dialog
          if (_hasError)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(26),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF2A85), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Connection Problem',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: app.textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage ?? 'Unable to reach video server.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: app.secondaryTextColor),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LiquidGlassButton(
                              icon: Icons.refresh_rounded,
                              label: 'Retry',
                              size: 40,
                              onTap: () {
                                setState(() {
                                  _hasError = false;
                                  _isLoading = true;
                                });
                                _webViewController?.reload();
                              },
                            ),
                            const SizedBox(width: 12),
                            LiquidGlassButton(
                              icon: Icons.switch_access_shortcut_rounded,
                              label: 'Change Server',
                              tint: app.accentColor,
                              size: 40,
                              onTap: () => _switchToNextInstance(silent: false),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 5. Top Frosted Header Bar
          Positioned(
            top: topPad,
            left: 16,
            right: 16,
            child: _isSearching ? _buildSearchBar(app) : _buildHeaderBar(app),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(AppState app) {
    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      blur: 20,
      glow: true,
      child: Row(
        children: [
          // Back button
          LiquidGlassButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 38,
            iconSize: 18,
            onTap: () async {
              if (await _webViewController?.canGoBack() ?? false) {
                _webViewController?.goBack();
              } else {
                widget.onBack?.call() ?? Navigator.maybePop(context);
              }
            },
          ),
          const SizedBox(width: 8),

          // YouTube Icon Badge
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF0000),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),

          // Screen Title with Subtle Glow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'RV Bhati YouTube',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '100% Ad-Free Hub  •  ${_currentInstance.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: app.accentColor,
                  ),
                ),
              ],
            ),
          ),

          // Search button
          LiquidGlassButton(
            icon: Icons.search_rounded,
            size: 38,
            iconSize: 20,
            onTap: () => setState(() => _isSearching = true),
          ),
          const SizedBox(width: 6),

          // Server switcher / Refresh button
          LiquidGlassButton(
            icon: Icons.dns_rounded,
            size: 38,
            iconSize: 20,
            onTap: _showServerSwitcher,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppState app) {
    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      blur: 20,
      glow: true,
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: app.accentColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(color: app.textColor, fontSize: 14.5),
              onSubmitted: _onSearchSubmit,
              decoration: const InputDecoration(
                hintText: 'Search YouTube (Songs, Videos, Channels)...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 13.5),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            onPressed: () => setState(() => _isSearching = false),
          ),
        ],
      ),
    );
  }
}
