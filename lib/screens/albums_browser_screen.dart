import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/media_scanner.dart';
import '../utils/format.dart';
import '../widgets/ios_bounce_button.dart';
import '../widgets/liquid_glass_container.dart';

class AlbumsBrowserScreen extends StatefulWidget {
  const AlbumsBrowserScreen({super.key});

  @override
  State<AlbumsBrowserScreen> createState() => _AlbumsBrowserScreenState();
}

class _AlbumsBrowserScreenState extends State<AlbumsBrowserScreen> {
  AppState get app => AppState.instance;

  String? _selectedAlbum;

  Map<String, List<MediaFile>> get _albumsMap {
    final map = <String, List<MediaFile>>{};
    for (final a in MediaScanner.lastScannedAudios) {
      final name = (a.album != null && a.album!.trim().isNotEmpty)
          ? a.album!.trim()
          : 'Unknown Album';
      map.putIfAbsent(name, () => []).add(a);
    }
    return map;
  }


  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;
    final pad = MediaQuery.paddingOf(context);

    return PopScope(
      canPop: _selectedAlbum == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectedAlbum != null) {
          setState(() => _selectedAlbum = null);
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
                    onTap: () {
                      if (_selectedAlbum != null) {
                        setState(() => _selectedAlbum = null);
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
                          _selectedAlbum ?? 'Albums Collection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          _selectedAlbum != null
                              ? 'Tap any track to play'
                              : '${_albumsMap.length} Total Albums',
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
            ),

            // Content
            Expanded(
              child: _selectedAlbum != null
                  ? _buildAlbumSongs(textColor, secondaryTextColor, accent, isLight)
                  : _buildAlbumsGrid(textColor, secondaryTextColor, accent, isLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsGrid(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final albums = _albumsMap;

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album_outlined,
                size: 64, color: accent.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No Albums Discovered',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.88,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final albumName = albums.keys.elementAt(index);
        final songs = albums[albumName] ?? [];

        return iOSBounceButton(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedAlbum = albumName);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.07),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.8),
                          accent.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.album_rounded,
                          size: 48, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  albumName,
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
                  '${songs.length} Tracks',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumSongs(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final songs = _albumsMap[_selectedAlbum] ?? [];

    return Column(
      children: [
        // Play all & Shuffle Bar
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
                    AudioController.instance.playQueue(songs, 0, shuffle: false);
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
                    AudioController.instance.playQueue(songs, 0, shuffle: true);
                  },
                ),
              ),
            ],
          ),
        ),

        // Songs list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final s = songs[index];
              return iOSBounceButton(
                onTap: () {
                  AudioController.instance.playQueue(songs, index);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
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
                              '${s.artist ?? "Unknown"} • ${FormatUtils.duration(s.duration)}',
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
                      Icon(Icons.play_arrow_rounded, color: accent, size: 24),
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
}
