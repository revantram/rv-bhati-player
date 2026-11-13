import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/online_song.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../utils/format.dart';
import '../widgets/ios_bounce_button.dart';
import '../widgets/liquid_glass_container.dart';
import 'audio_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  AppState get app => AppState.instance;

  Future<void> _playOfflineQueue(
    BuildContext context,
    List<OnlineSong> onlineSongs,
    int index, {
    bool shuffle = false,
  }) async {
    final err = await AudioController.instance.playOnlineQueue(
      onlineSongs,
      index,
      shuffle: shuffle,
    );
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
    );
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
                      listenable: DownloadService.instance,
                      builder: (context, _) {
                        final list = DownloadService.instance.downloadedSongs;
                        final totalBytes = list.fold<int>(
                            0, (sum, item) => sum + item.fileSizeBytes);
                        final sizeText =
                            DownloadService.instance.formatBytes(totalBytes);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Downloads',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${list.length} Songs • $sizeText',
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
                listenable: DownloadService.instance,
                builder: (context, _) {
                  final list = DownloadService.instance.downloadedSongs;

                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_for_offline_rounded,
                            size: 64,
                            color: accent.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No Offline Downloads',
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
                              'Tap the download (⬇️) icon on any online song or show to save it for offline listening without internet.',
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

                  final onlineSongs =
                      list.map((d) => d.toOnlineSong()).toList();

                  return Column(
                    children: [
                      // Action buttons: Play All & Shuffle
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 22),
                                label: const Text('Play All',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () => _playOfflineQueue(
                                  context,
                                  onlineSongs,
                                  0,
                                  shuffle: false,
                                ),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.shuffle_rounded,
                                    size: 20),
                                label: const Text('Shuffle',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () => _playOfflineQueue(
                                  context,
                                  onlineSongs,
                                  0,
                                  shuffle: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Songs List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final d = list[index];
                            final sizeStr =
                                DownloadService.instance.formatBytes(d.fileSizeBytes);

                            return iOSBounceButton(
                              onTap: () => _playOfflineQueue(
                                context,
                                onlineSongs,
                                index,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
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
                                      child: Image.network(
                                        d.imageUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 52,
                                          height: 52,
                                          color: accent.withValues(alpha: 0.2),
                                          child: Icon(Icons.music_note_rounded,
                                              color: accent),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.title,
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
                                            '${d.artist} • $sizeStr • ${FormatUtils.duration(d.duration)}',
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
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: Colors.redAccent.withValues(alpha: 0.8),
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        DownloadService.instance.deleteSong(d.id);
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
}
