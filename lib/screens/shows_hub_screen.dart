import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/online_song.dart';
import '../models/radio_station.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/osho_service.dart';
import '../services/radio_controller.dart';
import '../widgets/ios_bounce_button.dart';
import 'audio_player_screen.dart';

class ShowsHubScreen extends StatefulWidget {
  const ShowsHubScreen({super.key});

  @override
  State<ShowsHubScreen> createState() => _ShowsHubScreenState();
}

class _ShowsHubScreenState extends State<ShowsHubScreen> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _oshoSearchCtrl = TextEditingController();
  AppState get app => AppState.instance;

  List<OshoSeries> _oshoSeries = [];
  bool _isLoadingOsho = false;
  OshoSeries? _selectedSeries;
  List<OshoTrack> _seriesTracks = [];
  bool _isLoadingTracks = false;

  static const List<String> _categories = [
    '🧘 Osho World (ओशो अमृतवाणी)',
    '🎙️ Top Podcasts',
    '🔥 Pocket Stories',
    '📻 Live FM Radio',
  ];

  @override
  void initState() {
    super.initState();
    _loadOshoSeries();
  }

  @override
  void dispose() {
    _oshoSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOshoSeries({bool force = false}) async {
    setState(() => _isLoadingOsho = true);
    final list = await OshoService.instance.fetchHindiSeries(forceRefresh: force);
    if (mounted) {
      setState(() {
        _oshoSeries = list;
        _isLoadingOsho = false;
      });
    }
  }

  Future<void> _selectSeries(OshoSeries series) async {
    setState(() {
      _selectedSeries = series;
      _isLoadingTracks = true;
      _seriesTracks = [];
    });

    final tracks = await OshoService.instance.fetchSeriesTracks(series);
    if (mounted) {
      setState(() {
        _seriesTracks = tracks;
        _isLoadingTracks = false;
      });
    }
  }

  void _playTrack(int index) {
    if (_selectedSeries == null || _seriesTracks.isEmpty) return;
    final onlineSongs = _seriesTracks.map((t) => t.toOnlineSong(_selectedSeries!)).toList();
    AudioController.instance.playOnlineQueue(onlineSongs, index);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AudioPlayerScreen(startPlayback: false),
      ),
    );
  }

  void _playAllTracks() {
    if (_seriesTracks.isNotEmpty) {
      _playTrack(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;
    final pad = MediaQuery.paddingOf(context);

    return PopScope(
      canPop: _selectedSeries == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedSeries != null) {
          setState(() {
            _selectedSeries = null;
            _seriesTracks = [];
          });
        }
      },
      child: Scaffold(
        backgroundColor: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF090D16),
        body: Column(
          children: [
            // Top Bar
            Container(
              padding: EdgeInsets.only(
                top: pad.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                color: (isLight ? Colors.white : const Color(0xFF0F172A))
                    .withValues(alpha: 0.92),
                border: Border(
                  bottom: BorderSide(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      iOSBounceButton(
                        onTap: () {
                          if (_selectedSeries != null) {
                            setState(() {
                              _selectedSeries = null;
                              _seriesTracks = [];
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 19,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedSeries != null
                                  ? _selectedSeries!.title
                                  : 'Shows & Discourses Hub',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _selectedSeries != null
                                  ? 'Osho World Hindi Discourses'
                                  : 'Osho World, Podcasts & Stories',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedCategoryIndex == 0 && _selectedSeries == null)
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: accent),
                          onPressed: () => _loadOshoSeries(force: true),
                        ),
                    ],
                  ),
                  if (_selectedSeries == null) ...[
                    const SizedBox(height: 12),
                    // Category Selector
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final isSel = _selectedCategoryIndex == i;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategoryIndex = i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? accent
                                    : (isLight
                                        ? Colors.black.withValues(alpha: 0.05)
                                        : Colors.white.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: isSel
                                      ? accent
                                      : (isLight
                                          ? Colors.black.withValues(alpha: 0.08)
                                          : Colors.white.withValues(alpha: 0.1)),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _categories[i],
                                  style: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : secondaryTextColor,
                                    fontSize: 12.5,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: _selectedSeries != null
                  ? _buildSeriesDetail(textColor, secondaryTextColor, accent, isLight)
                  : _buildMainContent(textColor, secondaryTextColor, accent, isLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    switch (_selectedCategoryIndex) {
      case 0:
        return _buildOshoSection(textColor, secondaryTextColor, accent, isLight);
      case 1:
      case 2:
        return _buildStoriesAndPodcasts(textColor, secondaryTextColor, accent, isLight);
      case 3:
      default:
        return _buildRadioSection(textColor, secondaryTextColor, accent, isLight);
    }
  }

  Widget _buildOshoSection(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    if (_isLoadingOsho) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accent, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text(
              'Loading Osho World Catalog...',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final query = _oshoSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _oshoSeries
        : _oshoSeries.where((s) {
            return s.title.toLowerCase().contains(query) ||
                s.slug.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: TextField(
              controller: _oshoSearchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search 170+ Discourses (Geeta, Kabir, Dhyan...)',
                hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: secondaryTextColor, size: 20),
                suffixIcon: _oshoSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: secondaryTextColor, size: 18),
                        onPressed: () {
                          _oshoSearchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Total count badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Series (${filtered.length})',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'https://oshoworld.com',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Series List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No discourses found for "${_oshoSearchCtrl.text}"',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return iOSBounceButton(
                      onTap: () => _selectSeries(s),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                s.imageUrl,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 62,
                                  height: 62,
                                  color: accent.withValues(alpha: 0.15),
                                  child: Icon(Icons.self_improvement_rounded, color: accent, size: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${s.count} Discourses',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Osho World',
                                        style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: secondaryTextColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSeriesDetail(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final s = _selectedSeries!;

    return Column(
      children: [
        // Series Banner
        Container(
          padding: const EdgeInsets.all(16),
          color: (isLight ? Colors.white : const Color(0xFF131A2A)).withValues(alpha: 0.6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  s.imageUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: accent.withValues(alpha: 0.2),
                    child: Icon(Icons.self_improvement_rounded, color: accent, size: 36),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Discourse Series • ${s.count} Episodes',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (_seriesTracks.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _playAllTracks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play All Discourses', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tracks List
        Expanded(
          child: _isLoadingTracks
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: accent, strokeWidth: 2.5),
                      const SizedBox(height: 12),
                      Text('Loading discourses from Osho World...', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                    ],
                  ),
                )
              : _seriesTracks.isEmpty
                  ? Center(
                      child: Text('No tracks found for this series', style: TextStyle(color: secondaryTextColor)),
                    )
                  : ListenableBuilder(
                      listenable: DownloadService.instance,
                      builder: (context, _) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _seriesTracks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final track = _seriesTracks[idx];
                            final onlineSong = track.toOnlineSong(s);
                            final isDl = DownloadService.instance.isDownloaded(onlineSong.id);
                            final isDownloading = DownloadService.instance.isDownloading(onlineSong.id);

                            return iOSBounceButton(
                              onTap: () => _playTrack(idx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.white : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isLight
                                        ? Colors.black.withValues(alpha: 0.05)
                                        : Colors.white.withValues(alpha: 0.07),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent.withValues(alpha: 0.12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${track.duration.inMinutes} mins • High Quality Audio',
                                            style: TextStyle(
                                              color: secondaryTextColor,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Direct Local Download Button
                                    IconButton(
                                      icon: isDownloading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: accent,
                                              ),
                                            )
                                          : Icon(
                                              isDl
                                                  ? Icons.check_circle_rounded
                                                  : Icons.download_rounded,
                                              color: isDl ? Colors.green : secondaryTextColor,
                                              size: 22,
                                            ),
                                      onPressed: () {
                                        if (!isDl && !isDownloading) {
                                          DownloadService.instance.downloadSong(onlineSong);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Downloading to local storage: ${track.title}'),
                                              backgroundColor: accent,
                                            ),
                                          );
                                        }
                                      },
                                    ),

                                    // Play icon
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStoriesAndPodcasts(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final catName = _categories[_selectedCategoryIndex]
        .replaceAll('🎙️', '')
        .replaceAll('🔥', '')
        .trim();

    final stories = [
      ShowItem(
        id: 'story_1',
        title: 'Kafan - Munshi Premchand',
        creator: 'Classic Kahaniyaan',
        category: 'Pocket Stories',
        description: 'Masterpiece classic story narrating human nature with profound realism.',
        coverUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&q=80',
        streamUrl: 'https://archive.org/download/kafan_premchand/kafan.mp3',
        duration: const Duration(minutes: 24, seconds: 15),
      ),
      ShowItem(
        id: 'story_2',
        title: 'Bhoot Ka Bangla - Midnight Mystery',
        creator: 'Fear Files Audio',
        category: 'Pocket Stories',
        description: 'Chilling midnight audio thriller of an abandoned mansion on NH8.',
        coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&q=80',
        streamUrl: 'https://archive.org/download/horror_hindi_story/ghost_story.mp3',
        duration: const Duration(minutes: 32, seconds: 40),
      ),
      ShowItem(
        id: 'podcast_1',
        title: 'The Power of Mindset & Focus',
        creator: 'The Ranveer Hindi Show',
        category: 'Top Podcasts',
        description: 'Actionable discussion on meditation, brain clarity, and supreme daily focus.',
        coverUrl: 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&q=80',
        streamUrl: 'https://archive.org/download/ranveer_mindset_pod/ranveer_focus.mp3',
        duration: const Duration(minutes: 42, seconds: 10),
      ),
      ShowItem(
        id: 'podcast_2',
        title: 'Gita Saar: Karma Yoga Simplified',
        creator: 'Spiritual Audio',
        category: 'Top Podcasts',
        description: 'Daily life principles of Bhagavad Gita translated into contemporary mindset.',
        coverUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=500&q=80',
        streamUrl: 'https://archive.org/download/gita_hindi_audio/karma_yoga.mp3',
        duration: const Duration(minutes: 28, seconds: 50),
      ),
    ];

    final items = stories
        .where((s) => s.category.toLowerCase().contains(catName.toLowerCase()))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final onlineSong = item.toOnlineSong();

        return ListenableBuilder(
          listenable: DownloadService.instance,
          builder: (context, _) {
            final isDl = DownloadService.instance.isDownloaded(onlineSong.id);
            final isDownloading = DownloadService.instance.isDownloading(onlineSong.id);

            return iOSBounceButton(
              onTap: () {
                AudioController.instance.playOnlineQueue([onlineSong], 0);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AudioPlayerScreen(startPlayback: false),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.coverUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: accent.withValues(alpha: 0.2),
                          child: Icon(Icons.podcasts_rounded, color: accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.creator,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.duration.inMinutes} mins • ${item.category}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: isDownloading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: accent),
                            )
                          : Icon(
                              isDl ? Icons.check_circle_rounded : Icons.download_rounded,
                              color: isDl ? Colors.green : secondaryTextColor,
                              size: 22,
                            ),
                      onPressed: () {
                        if (!isDl && !isDownloading) {
                          DownloadService.instance.downloadSong(onlineSong);
                        }
                      },
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadioSection(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final stations = RadioStation.stations;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: stations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final station = stations[index];
        return iOSBounceButton(
          onTap: () => RadioController.instance.playStation(station),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.radio_rounded, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${station.category} • 24x7 Broadcast',
                        style: TextStyle(color: secondaryTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.15),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: accent, size: 22),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ShowItem {
  final String id;
  final String title;
  final String creator;
  final String category;
  final String description;
  final String coverUrl;
  final String streamUrl;
  final Duration duration;

  const ShowItem({
    required this.id,
    required this.title,
    required this.creator,
    required this.category,
    required this.description,
    required this.coverUrl,
    required this.streamUrl,
    required this.duration,
  });

  OnlineSong toOnlineSong() {
    return OnlineSong(
      id: 'show_$id',
      title: title,
      artist: creator,
      album: category,
      duration: duration,
      imageUrl: coverUrl,
      streamUrl: streamUrl,
    );
  }
}
