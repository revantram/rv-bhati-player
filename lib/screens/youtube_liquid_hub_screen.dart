import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import '../widgets/liquid_glass_container.dart';
import 'video_player_screen.dart';

class NativeYoutubeVideo {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;
  final int? viewCount;
  final DateTime? uploadDate;

  const NativeYoutubeVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
    this.viewCount,
    this.uploadDate,
  });

  String get viewsFormatted {
    if (viewCount == null || viewCount == 0) return '';
    if (viewCount! >= 1000000) {
      return '${(viewCount! / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount! >= 1000) {
      return '${(viewCount! / 1000).toStringAsFixed(1)}K views';
    }
    return '$viewCount views';
  }

  String get uploadTimeAgo {
    if (uploadDate == null) return '';
    final diff = DateTime.now().difference(uploadDate!);
    if (diff.inDays >= 365) {
      final y = (diff.inDays / 365).floor();
      return '$y ${y == 1 ? "year" : "years"} ago';
    } else if (diff.inDays >= 30) {
      final m = (diff.inDays / 30).floor();
      return '$m ${m == 1 ? "month" : "months"} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? "day" : "days"} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} ago';
    }
    return 'Just now';
  }
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

class _YoutubeLiquidHubScreenState extends State<YoutubeLiquidHubScreen>
    with SingleTickerProviderStateMixin {
  final YoutubeExplode _yt = YoutubeExplode();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late final AnimationController _shimmerCtrl;

  // In-memory feed cache for instantaneous 0ms tab switching
  static final Map<String, List<NativeYoutubeVideo>> _feedCache = {};

  List<NativeYoutubeVideo> _videos = [];
  bool _isLoading = true;
  bool _isResolvingStream = false;
  String? _resolvingVideoTitle;
  String? _errorMessage;

  static const List<Map<String, String>> _categories = [
    {'name': '🔥 Trending', 'query': 'trending india music'},
    {'name': '🎵 Music Hits', 'query': 'latest top hits hindi'},
    {'name': '🐪 Rajasthani', 'query': 'rajasthani song new marwadi'},
    {'name': '🎬 New Releases', 'query': 'latest official music video'},
    {'name': '✨ Bollywood', 'query': 'bollywood superhit songs'},
    {'name': '⚡ Punjabi', 'query': 'latest punjabi hits'},
    {'name': '🎙️ Podcasts', 'query': 'hindi podcast episodes'},
  ];

  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _loadFeed(_categories[_selectedCategoryIndex]['query']!);
    _prefetchNextCategories();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _yt.close();
    super.dispose();
  }

  // Background prefetching for smooth, zero-wait category exploration
  void _prefetchNextCategories() async {
    for (int i = 1; i < math.min(4, _categories.length); i++) {
      final q = _categories[i]['query']!;
      if (!_feedCache.containsKey(q)) {
        try {
          final res = await _yt.search.search(q).timeout(const Duration(seconds: 5));
          final list = <NativeYoutubeVideo>[];
          for (final v in res) {
            list.add(
              NativeYoutubeVideo(
                id: v.id.value,
                title: v.title,
                author: v.author,
                thumbnailUrl: v.thumbnails.highResUrl,
                duration: v.duration,
                viewCount: v.engagement.viewCount,
                uploadDate: v.uploadDate,
              ),
            );
            if (list.length >= 25) break;
          }
          if (list.isNotEmpty) {
            _feedCache[q] = list;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _loadFeed(String query) async {
    // 1. Instant Cache Check (0ms latency!)
    if (_feedCache.containsKey(query) && _feedCache[query]!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _videos = _feedCache[query]!;
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final searchResults = await _yt.search.search(query).timeout(const Duration(seconds: 6));
      final list = <NativeYoutubeVideo>[];

      for (final v in searchResults) {
        list.add(
          NativeYoutubeVideo(
            id: v.id.value,
            title: v.title,
            author: v.author,
            thumbnailUrl: v.thumbnails.highResUrl,
            duration: v.duration,
            viewCount: v.engagement.viewCount,
            uploadDate: v.uploadDate,
          ),
        );
        if (list.length >= 25) break;
      }

      if (list.isNotEmpty) {
        _feedCache[query] = list;
        if (mounted) {
          setState(() {
            _videos = list;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback: Query via Piped CDN API mirrors
    final pipedMirrors = [
      'https://pipedapi.lunar.icu',
      'https://api.piped.private.coffee',
      'https://pipedapi.kavin.rocks',
    ];

    for (final mirror in pipedMirrors) {
      try {
        final uri = Uri.parse('$mirror/search?q=${Uri.encodeComponent(query)}&filter=all');
        final resp = await http.get(uri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final items = data['items'] as List? ?? [];
          final list = <NativeYoutubeVideo>[];

          for (final item in items) {
            final url = item['url']?.toString() ?? '';
            final id = url.contains('/watch?v=') ? url.split('/watch?v=').last : '';
            if (id.isNotEmpty) {
              list.add(
                NativeYoutubeVideo(
                  id: id,
                  title: item['title']?.toString() ?? 'Video',
                  author: item['uploaderName']?.toString() ?? 'YouTube',
                  thumbnailUrl: item['thumbnail']?.toString() ?? 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                  duration: Duration(seconds: (item['duration'] as num?)?.toInt() ?? 180),
                  viewCount: (item['views'] as num?)?.toInt(),
                ),
              );
            }
          }

          if (list.isNotEmpty) {
            _feedCache[query] = list;
            if (mounted) {
              setState(() {
                _videos = list;
                _isLoading = false;
              });
            }
            return;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network connection issue. Tap retry to reload.';
      });
    }
  }

  void _onCategorySelected(int index) {
    if (_selectedCategoryIndex == index && !_isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategoryIndex = index);
    _loadFeed(_categories[index]['query']!);
  }

  void _onSearch(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _loadFeed(clean);
  }

  Future<void> _playVideo(NativeYoutubeVideo video) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isResolvingStream = true;
      _resolvingVideoTitle = video.title;
    });

    String? directStreamUrl;
    final Map<String, String> qualityMap = {};

    // 1. Try YoutubeExplode direct streams & extract all resolutions for Quality selector
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 5));
      final muxed = manifest.muxed.toList();
      if (muxed.isNotEmpty) {
        for (final s in muxed) {
          final q = s.qualityLabel;
          if (!qualityMap.containsKey(q)) {
            qualityMap[q] = s.url.toString();
          }
        }
        final highest = muxed.withHighestBitrate();
        directStreamUrl = highest.url.toString();
      }
    } catch (_) {}

    // 2. High-speed Piped CDN stream fallback with quality resolution collection
    if (directStreamUrl == null || directStreamUrl.isEmpty) {
      final pipedApis = [
        'https://pipedapi.lunar.icu/streams/${video.id}',
        'https://api.piped.private.coffee/streams/${video.id}',
        'https://pipedapi.kavin.rocks/streams/${video.id}',
      ];

      for (final api in pipedApis) {
        try {
          final resp = await http.get(Uri.parse(api)).timeout(const Duration(seconds: 4));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            final hls = data['hls']?.toString();
            final videoStreams = data['videoStreams'] as List?;
            if (videoStreams != null && videoStreams.isNotEmpty) {
              for (final vs in videoStreams) {
                final u = vs['url']?.toString();
                final q = vs['quality']?.toString() ?? 'Auto';
                if (u != null && u.isNotEmpty && !qualityMap.containsKey(q)) {
                  qualityMap[q] = u;
                }
              }
            }
            if (hls != null && hls.isNotEmpty) {
              directStreamUrl = hls;
              qualityMap['Auto (HLS)'] = hls;
              break;
            } else if (qualityMap.isNotEmpty) {
              directStreamUrl = qualityMap.values.first;
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 3. Invidious stream fallback
    if (directStreamUrl == null || directStreamUrl.isEmpty) {
      try {
        final invUrl = 'https://yewtu.be/api/v1/videos/${video.id}';
        final resp = await http.get(Uri.parse(invUrl)).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final hls = data['hlsUrl']?.toString();
          if (hls != null && hls.isNotEmpty) {
            directStreamUrl = hls;
            qualityMap['Auto (HLS)'] = hls;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isResolvingStream = false);

    if (directStreamUrl != null && directStreamUrl.isNotEmpty) {
      // Launch native RV Bhati Video Player with full gesture controls, quality switch & multi-audio
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            playlist: [
              MediaFile(
                id: 'yt_${video.id}',
                title: '${video.title}.mp4',
                path: directStreamUrl!,
                kind: MediaKind.video,
                duration: video.duration ?? const Duration(minutes: 5),
                qualityUrls: qualityMap.isNotEmpty ? qualityMap : null,
              ),
            ],
            startIndex: 0,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resolve stream. Please try another video.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final pad = MediaQuery.paddingOf(context);
    final topPad = widget.topOffset ?? (pad.top + 8);
    // 160 bottom clearance to prevent overlap with floating Mini Player & Bottom Bar
    final bottomPad = widget.bottomOffset ?? (pad.bottom + 160);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Main Scrollable Native Feed
          Positioned.fill(
            child: RefreshIndicator(
              color: app.accentColor,
              backgroundColor: app.isDark ? const Color(0xFF1E2438) : Colors.white,
              onRefresh: () async {
                _feedCache.remove(_categories[_selectedCategoryIndex]['query']!);
                await _loadFeed(_categories[_selectedCategoryIndex]['query']!);
              },
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // Top Spacer for Header and Search
                  SliverToBoxAdapter(
                    child: SizedBox(height: topPad + 118),
                  ),

                  // Category Filter Pills
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (context, i) {
                          final cat = _categories[i];
                          final isSel = _selectedCategoryIndex == i;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _onCategorySelected(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? app.accentColor.withValues(alpha: app.isDark ? 0.28 : 0.18)
                                      : (app.isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.white.withValues(alpha: 0.88)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSel ? app.accentColor : (app.isDark ? Colors.white12 : Colors.black12),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: app.accentColor.withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  cat['name']!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                    color: isSel
                                        ? (app.isDark ? app.accentColor : const Color(0xFF0F172A))
                                        : (app.isDark ? Colors.white70 : const Color(0xFF1E293B)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Content: Shimmer Skeletons, Error or Video Cards
                  if (_isLoading)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildShimmerSkeleton(),
                          childCount: 6,
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
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
                                  'Connection Issue',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: app.isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: app.isDark ? Colors.white60 : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LiquidGlassButton(
                                  icon: Icons.refresh_rounded,
                                  label: 'Retry',
                                  tint: app.accentColor,
                                  size: 40,
                                  onTap: () => _loadFeed(_categories[_selectedCategoryIndex]['query']!),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final video = _videos[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildVideoCard(video, app),
                            );
                          },
                          childCount: _videos.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Frosted Floating Top Header Bar
          Positioned(
            top: topPad,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top branding row
                LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  blur: 20,
                  glow: true,
                  child: Row(
                    children: [
                      // Back Button
                      LiquidGlassButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 38,
                        iconSize: 18,
                        onTap: () {
                          if (widget.onBack != null) {
                            widget.onBack!.call();
                          } else {
                            Navigator.maybePop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Red YouTube Badge
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF0000),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),

                      // Screen Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'RV Bhati YouTube',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: app.isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '100% Native  •  Zero Ads',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: app.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Refresh Button
                      LiquidGlassButton(
                        icon: Icons.refresh_rounded,
                        size: 38,
                        iconSize: 20,
                        onTap: () {
                          _feedCache.remove(_categories[_selectedCategoryIndex]['query']!);
                          _loadFeed(_categories[_selectedCategoryIndex]['query']!);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Search Bar Input
                LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  blur: 18,
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: app.accentColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(
                            color: app.isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: _onSearch,
                          decoration: InputDecoration(
                            hintText: 'Search songs, videos or artists...',
                            hintStyle: TextStyle(
                              color: app.isDark ? Colors.white54 : const Color(0xFF64748B),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() {});
                            _loadFeed(_categories[_selectedCategoryIndex]['query']!);
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: app.isDark ? Colors.white60 : const Color(0xFF64748B),
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Resolving Stream Overlay
          if (_isResolvingStream)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(24),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            valueColor: AlwaysStoppedAnimation<Color>(app.accentColor),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Opening Ad-Free Stream...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: app.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (_resolvingVideoTitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _resolvingVideoTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: app.isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 100% Native Frosted Video Card Widget (Zero Scroll-Lag, 120 FPS, Crisp Contrast)
  Widget _buildVideoCard(NativeYoutubeVideo video, AppState app) {
    final metaText = [
      if (video.viewsFormatted.isNotEmpty) video.viewsFormatted,
      if (video.uploadTimeAgo.isNotEmpty) video.uploadTimeAgo,
    ].join(' • ');

    return GestureDetector(
      onTap: () => _playVideo(video),
      child: Container(
        decoration: BoxDecoration(
          color: app.isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: app.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: app.isDark ? 0.25 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 High-Res Thumbnail with Duration Badge Overlay (Optimized cacheWidth for 120 FPS scrolling)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 640,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(Icons.video_library_rounded, color: Colors.white38, size: 40),
                      ),
                    ),
                    // Duration Badge Overlay (Bottom Right)
                    if (video.duration != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Text(
                            formatDuration(video.duration!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    // Centered Play Button
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Video Details: Crisp High-Contrast Title, Channel, Views
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: app.isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 14, color: app.accentColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              video.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: app.isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (metaText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          metaText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: app.isDark ? Colors.white60 : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Shimmer Skeleton Loading Widget (Zero Lag, No Black Screen)
  Widget _buildShimmerSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 Skeleton Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        stops: const [0.1, 0.5, 0.9],
                        begin: Alignment(-1.0 + 2.0 * _shimmerCtrl.value, -0.3),
                        end: Alignment(1.0 + 2.0 * _shimmerCtrl.value, 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Title Skeleton Line 1
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 6),
                // Title Skeleton Line 2
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle Skeleton
                Container(
                  width: 120,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
