import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/playlist_item.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../utils/format.dart';
import '../widgets/ios_bounce_button.dart';
import 'audio_player_screen.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    // Resolve online metadata for liked songs if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      app.ensureFavoriteItemsResolved();
    });
  }

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
              child: Row(
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
                    child: ListenableBuilder(
                      listenable: app,
                      builder: (context, _) {
                        final count = app.favorites.length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Liked Songs (पसंदीदा गाने)',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '$count Favorite Tracks',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListenableBuilder(
                listenable: app,
                builder: (context, _) {
                  final list = app.favoritePlaylistItems;

                  if (list.isEmpty) {
                    if (app.favorites.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: accent),
                            const SizedBox(height: 14),
                            Text(
                              'Loading liked songs...',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 64,
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No Liked Songs Yet',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Text(
                              'Tap the heart (❤️) icon on any song while listening to add it to your favorite collection.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: const Text('Play All',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () {
                                  AudioController.instance.playHybridQueue(list, 0, shuffle: false);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textColor,
                                  side: BorderSide(
                                    color: isLight
                                        ? Colors.black.withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.15),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.shuffle_rounded, size: 20),
                                label: const Text('Shuffle',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () {
                                  AudioController.instance.playHybridQueue(list, 0, shuffle: true);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final f = list[index];

                            return iOSBounceButton(
                              onTap: () {
                                AudioController.instance.playHybridQueue(list, index);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.white : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isLight
                                        ? Colors.black.withValues(alpha: 0.05)
                                        : Colors.white.withValues(alpha: 0.07),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: (f.imageUrl != null && f.imageUrl!.isNotEmpty)
                                            ? Image.network(
                                                f.imageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _buildFallbackArt(),
                                              )
                                            : _buildFallbackArt(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            f.duration.inSeconds > 0
                                                ? '${f.artist} • ${FormatUtils.duration(f.duration)}'
                                                : '${f.artist} • ${f.isOnline ? "BitMusic" : "Local Music"}',
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
                                    IconButton(
                                      icon: const Icon(
                                        Icons.favorite_rounded,
                                        size: 22,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        app.toggleFavorite(f.id);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent, Colors.pinkAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}
