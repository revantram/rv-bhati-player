import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_file.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import '../services/app_state.dart';
import 'liquid_glass_container.dart';

class AddToPlaylistDialog extends StatefulWidget {
  const AddToPlaylistDialog({
    super.key,
    required this.item,
  });

  final PlaylistItem item;

  static Future<void> showForMedia(BuildContext context, MediaFile file) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => AddToPlaylistDialog(
        item: PlaylistItem.fromMediaFile(file),
      ),
    );
  }

  static Future<void> showForOnline(BuildContext context, OnlineSong song) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => AddToPlaylistDialog(
        item: PlaylistItem.fromOnlineSong(song),
      ),
    );
  }

  static Future<void> showForItem(BuildContext context, PlaylistItem item) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => AddToPlaylistDialog(item: item),
    );
  }

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final _appState = AppState.instance;
  final _newController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  void _createNew() {
    final name = _newController.text.trim();
    if (name.isEmpty) return;
    HapticFeedback.lightImpact();
    _appState.createPlaylist(name);
    _appState.addToCustomPlaylist(name, widget.item);
    _newController.clear();
    setState(() => _creating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to "$name"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _appState.accentColor;
    final playlists = _appState.customPlaylists;
    final playlistNames = playlists.keys.toList();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.playlist_add_rounded, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to Playlist',
                            style: TextStyle(
                              color: _appState.textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _appState.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PressableScale(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _appState.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: _appState.secondaryTextColor, size: 18),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Create new playlist row
                if (!_creating) ...[
                  PressableScale(
                    onTap: () => setState(() => _creating = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'New Playlist',
                            style: TextStyle(
                              color: accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newController,
                          autofocus: true,
                          style: TextStyle(color: _appState.textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Playlist name...',
                            hintStyle: TextStyle(color: _appState.secondaryTextColor.withValues(alpha: 0.6)),
                            filled: true,
                            fillColor: _appState.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: accent),
                            ),
                          ),
                          onSubmitted: (_) => _createNew(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PressableScale(
                        onTap: _createNew,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Create',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Existing playlists list
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: playlistNames.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No playlists yet.\nCreate one above!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _appState.secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: playlistNames.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final name = playlistNames[idx];
                            final list = playlists[name] ?? [];
                            final contains = list.any((t) => t.id == widget.item.id);

                            return PressableScale(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (contains) {
                                  _appState.removeFromCustomPlaylist(name, widget.item.id);
                                } else {
                                  _appState.addToCustomPlaylist(name, widget.item);
                                }
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: contains
                                      ? accent.withValues(alpha: 0.2)
                                      : (_appState.isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.06)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: contains
                                        ? accent.withValues(alpha: 0.5)
                                        : (_appState.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.queue_music_rounded,
                                      color: contains ? accent : _appState.secondaryTextColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: contains ? (_appState.isLight ? accent : Colors.white) : _appState.textColor,
                                              fontSize: 14,
                                              fontWeight: contains ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${list.length} tracks',
                                            style: TextStyle(
                                              color: _appState.secondaryTextColor,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      contains
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: contains ? accent : (_appState.isLight ? Colors.black26 : Colors.white30),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 14),

                PressableScale(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _appState.isLight ? accent : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: _appState.isLight ? Border.all(color: accent) : Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Center(
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
