import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/online_song.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/radio_controller.dart';
import '../widgets/liquid_glass_container.dart';

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

class ShowsHubScreen extends StatefulWidget {
  const ShowsHubScreen({super.key});

  @override
  State<ShowsHubScreen> createState() => _ShowsHubScreenState();
}

class _ShowsHubScreenState extends State<ShowsHubScreen> {
  int _selectedCategoryIndex = 0;
  AppState get app => AppState.instance;

  static const List<String> _categories = [
    '🔥 Pocket Stories',
    '🎙️ Top Podcasts',
    '📻 Live FM Radio',
    '👻 Horror & Mystery',
  ];

  static const List<ShowItem> _stories = [
    ShowItem(
      id: 'story_1',
      title: 'Kafan - Munshi Premchand',
      creator: 'Classic Kahaniyaan',
      category: 'Pocket Stories',
      description: 'Masterpiece classic story narrating human nature with profound realism.',
      coverUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&q=80',
      streamUrl: 'https://archive.org/download/kafan_premchand/kafan.mp3',
      duration: Duration(minutes: 24, seconds: 15),
    ),
    ShowItem(
      id: 'story_2',
      title: 'Bhoot Ka Bangla - Midnight Mystery',
      creator: 'Fear Files Audio',
      category: 'Horror & Mystery',
      description: 'Chilling midnight audio thriller of an abandoned mansion on NH8.',
      coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&q=80',
      streamUrl: 'https://archive.org/download/horror_hindi_story/ghost_story.mp3',
      duration: Duration(minutes: 32, seconds: 40),
    ),
    ShowItem(
      id: 'story_3',
      title: 'Panchatantra: The Smart Fox & Lion',
      creator: 'Ancient Tales',
      category: 'Pocket Stories',
      description: 'Timeless wisdom stories of moral intelligence and friendship.',
      coverUrl: 'https://images.unsplash.com/photo-1532012164546-f432f2e3777f?w=500&q=80',
      streamUrl: 'https://archive.org/download/panchatantra_audio/smart_fox.mp3',
      duration: Duration(minutes: 18, seconds: 30),
    ),
    ShowItem(
      id: 'podcast_1',
      title: 'The Power of Mindset & Focus',
      creator: 'The Ranveer Hindi Show',
      category: 'Top Podcasts',
      description: 'Actionable discussion on meditation, brain clarity, and supreme daily focus.',
      coverUrl: 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&q=80',
      streamUrl: 'https://archive.org/download/ranveer_mindset_pod/ranveer_focus.mp3',
      duration: Duration(minutes: 42, seconds: 10),
    ),
    ShowItem(
      id: 'podcast_2',
      title: 'Gita Saar: Karma Yoga Simplified',
      creator: 'Spiritual Audio',
      category: 'Top Podcasts',
      description: 'Daily life principles of Bhagavad Gita translated into contemporary mindset.',
      coverUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=500&q=80',
      streamUrl: 'https://archive.org/download/gita_hindi_audio/karma_yoga.mp3',
      duration: Duration(minutes: 28, seconds: 50),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;
    final pad = MediaQuery.paddingOf(context);

    return PopScope(
      canPop: true,
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
                    .withValues(alpha: 0.85),
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
                        onTap: () => Navigator.pop(context),
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
                              'Shows & Podcasts Hub',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Pocket FM Stories, Podcasts & Live FM',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category Selector
                  SizedBox(
                    height: 36,
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
                              borderRadius: BorderRadius.circular(18),
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
              ),
            ),

            // Content Area
            Expanded(
              child: _selectedCategoryIndex == 2
                  ? _buildRadioSection(textColor, secondaryTextColor, accent, isLight)
                  : _buildShowsList(textColor, secondaryTextColor, accent, isLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowsList(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final catName = _categories[_selectedCategoryIndex]
        .replaceAll('🔥', '')
        .replaceAll('🎙️', '')
        .replaceAll('👻', '')
        .trim();

    final items = _stories
        .where((s) =>
            catName == 'Pocket Stories' ||
            s.category.toLowerCase().contains(catName.toLowerCase()))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final onlineSong = item.toOnlineSong();

        return ListenableBuilder(
          listenable: DownloadService.instance,
          builder: (context, _) {
            final isDl = DownloadService.instance.isDownloaded(onlineSong.id);
            final isDownloading =
                DownloadService.instance.isDownloading(onlineSong.id);

            return iOSBounceButton(
              onTap: () {
                AudioController.instance.playOnlineQueue([onlineSong], 0);
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
                    const SizedBox(width: 8),

                    // Download Button
                    IconButton(
                      icon: isDownloading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
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
                        }
                      },
                    ),

                    // Play Button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
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
      padding: const EdgeInsets.all(16),
      itemCount: stations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final station = stations[index];
        return iOSBounceButton(
          onTap: () {
            RadioController.instance.playStation(station);
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
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
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
