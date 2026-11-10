import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../utils/format.dart';
import '../widgets/liquid_glass_container.dart';

class PlaylistsManagerScreen extends StatefulWidget {
  const PlaylistsManagerScreen({super.key});

  @override
  State<PlaylistsManagerScreen> createState() => _PlaylistsManagerScreenState();
}

class _PlaylistsManagerScreenState extends State<PlaylistsManagerScreen> {
  AppState get app => AppState.instance;

  String? _selectedPlaylist;

  void _showCreateDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: app.isLight ? Colors.white : const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'New Playlist',
            style: TextStyle(
              color: app.textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            style: TextStyle(color: app.textColor),
            decoration: InputDecoration(
              hintText: 'Enter playlist name...',
              hintStyle: TextStyle(color: app.secondaryTextColor),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: app.secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: app.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final name = textCtrl.text.trim();
                if (name.isNotEmpty) {
                  app.createPlaylist(name);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
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
      canPop: _selectedPlaylist == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectedPlaylist != null) {
          setState(() => _selectedPlaylist = null);
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
                      if (_selectedPlaylist != null) {
                        setState(() => _selectedPlaylist = null);
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
                          _selectedPlaylist ?? 'Playlists Hub',
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
                          _selectedPlaylist != null
                              ? 'Playlist Tracks'
                              : 'Custom audio queues',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedPlaylist == null)
                    iOSBounceButton(
                      onTap: _showCreateDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                size: 18, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'New',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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
                  if (_selectedPlaylist != null) {
                    return _buildPlaylistDetail(
                        textColor, secondaryTextColor, accent, isLight);
                  }
                  return _buildPlaylistsList(
                      textColor, secondaryTextColor, accent, isLight);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsList(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final allNames = <String>{
      ...app.playlists.keys,
      ...app.customPlaylists.keys,
    }.toList();

    if (allNames.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded,
                size: 64, color: accent.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No Playlists Found',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + New above to create your first playlist.',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: allNames.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final name = allNames[index];
        final songIds = app.playlists[name] ?? app.customPlaylists[name] ?? [];

        return iOSBounceButton(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedPlaylist = name);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.queue_music_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${songIds.length} Tracks',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: secondaryTextColor, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistDetail(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final name = _selectedPlaylist!;
    final songIds = app.playlists[name] ?? app.customPlaylists[name] ?? [];
    final songs = app.audios.where((a) => songIds.contains(a.id)).toList();

    return Column(
      children: [
        if (songs.isNotEmpty)
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
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    'No songs added to this playlist yet.',
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                )
              : ListView.separated(
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
                            Icon(Icons.play_arrow_rounded,
                                color: accent, size: 24),
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
