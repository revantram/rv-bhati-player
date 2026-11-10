import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_file.dart';
import '../models/playlist_item.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/media_action_service.dart';
import '../services/media_scanner.dart';
import '../utils/format.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/art_box.dart';
import '../widgets/ios_bounce_button.dart';
import '../widgets/liquid_glass_container.dart';
import 'audio_player_screen.dart';
import 'audio_trimmer_screen.dart';

enum MusicSort { nameAsc, nameDesc, dateDesc, durationDesc }

class LocalStorageMusicScreen extends StatefulWidget {
  const LocalStorageMusicScreen({super.key});

  @override
  State<LocalStorageMusicScreen> createState() => _LocalStorageMusicScreenState();
}

class _LocalStorageMusicScreenState extends State<LocalStorageMusicScreen> {
  int _subTab = 0; // 0 = all, 1 = favorites, 2 = playlists
  String? _selectedPlaylist;

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  MusicSort _sort = MusicSort.dateDesc;

  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MediaFile> get _audios => MediaScanner.lastScannedAudios;

  List<MediaFile> _filterAndSort(List<MediaFile> list) {
    var out = list;
    if (_searchQuery.isNotEmpty) {
      out = out.where((m) {
        final title = m.title.toLowerCase();
        final artist = (m.artist ?? '').toLowerCase();
        final album = (m.album ?? '').toLowerCase();
        return title.contains(_searchQuery) ||
            artist.contains(_searchQuery) ||
            album.contains(_searchQuery);
      }).toList();
    }
    out = List.of(out);
    switch (_sort) {
      case MusicSort.nameAsc:
        out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case MusicSort.nameDesc:
        out.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case MusicSort.dateDesc:
        out.sort((a, b) => (b.modifiedDate ?? DateTime(2000)).compareTo(a.modifiedDate ?? DateTime(2000)));
        break;
      case MusicSort.durationDesc:
        out.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
    return out;
  }

  void _playSong(List<MediaFile> list, int index, {bool shuffle = false}) {
    if (list.isEmpty) return;
    AudioController.instance.playQueue(list, index, shuffle: shuffle);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
    );
  }

  void _playHybrid(List<PlaylistItem> list, int index, {bool shuffle = false}) {
    if (list.isEmpty) return;
    AudioController.instance.playHybridQueue(list, index, shuffle: shuffle);
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

    final allFiltered = _filterAndSort(_audios);
    final favList = _filterAndSort(_audios.where((a) => app.isFavorite(a.id)).toList());

    return PopScope(
      canPop: !_isSearching && _selectedPlaylist == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchCtrl.clear();
          });
          return;
        }
        if (_selectedPlaylist != null) {
          setState(() => _selectedPlaylist = null);
          return;
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
                color: (isLight ? Colors.white : const Color(0xFF0F172A)).withValues(alpha: 0.95),
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
                              _selectedPlaylist ?? 'Local Storage Music',
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
                              _selectedPlaylist != null
                                  ? 'Playlist'
                                  : '${_audios.length} tracks on device',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: textColor),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) _searchCtrl.clear();
                          });
                        },
                      ),
                      PopupMenuButton<MusicSort>(
                        icon: Icon(Icons.sort_rounded, color: accent),
                        onSelected: (s) => setState(() => _sort = s),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: MusicSort.dateDesc, child: Text('Date (Newest first)')),
                          const PopupMenuItem(value: MusicSort.nameAsc, child: Text('Name (A-Z)')),
                          const PopupMenuItem(value: MusicSort.nameDesc, child: Text('Name (Z-A)')),
                          const PopupMenuItem(value: MusicSort.durationDesc, child: Text('Duration (Longest)')),
                        ],
                      ),
                    ],
                  ),
                  if (_isSearching) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search title, artist, album...',
                          hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, color: secondaryTextColor, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                  if (_selectedPlaylist == null) ...[
                    const SizedBox(height: 12),
                    // Sub-tab chips
                    Row(
                      children: [
                        _buildSubTabChip(0, 'All Songs (${_audios.length})', accent, isLight, secondaryTextColor),
                        const SizedBox(width: 8),
                        _buildSubTabChip(1, 'Favorites (${app.favorites.length})', accent, isLight, secondaryTextColor),
                        const SizedBox(width: 8),
                        _buildSubTabChip(2, 'Playlists (${app.playlists.length + app.customPlaylists.length})', accent, isLight, secondaryTextColor),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: _selectedPlaylist != null
                  ? _buildPlaylistView(accent, textColor, secondaryTextColor, isLight)
                  : _subTab == 0
                      ? _buildSongListView(allFiltered, accent, textColor, secondaryTextColor, isLight)
                      : _subTab == 1
                          ? _buildSongListView(favList, accent, textColor, secondaryTextColor, isLight, isFavTab: true)
                          : _buildPlaylistsListView(accent, textColor, secondaryTextColor, isLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabChip(int index, String label, Color accent, bool isLight, Color secondaryTextColor) {
    final isSel = _subTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _subTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? accent : (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSel ? Colors.white : secondaryTextColor,
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongListView(
    List<MediaFile> list,
    Color accent,
    Color textColor,
    Color secondaryTextColor,
    bool isLight, {
    bool isFavTab = false,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isFavTab ? 'No favorite songs yet' : 'No local audio files found',
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
      );
    }

    return Column(
      children: [
        // Shuffle & Play row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${list.length} tracks',
                style: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _playSong(list, 0, shuffle: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.15),
                      foregroundColor: accent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.shuffle_rounded, size: 16),
                    label: const Text('Shuffle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _playSong(list, 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final song = list[idx];
              final isFav = app.isFavorite(song.id);

              return iOSBounceButton(
                onTap: () => _playSong(list, idx),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ArtBox(
                          item: song,
                          size: 48,
                          shape: BoxShape.rectangle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${song.artist ?? "Unknown"} • ${formatDuration(song.duration)}',
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
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : secondaryTextColor,
                          size: 20,
                        ),
                        onPressed: () => app.toggleFavorite(song.id),
                      ),
                      IconButton(
                        icon: Icon(Icons.more_vert_rounded, color: secondaryTextColor, size: 20),
                        onPressed: () => _showSongOptions(song),
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
  }

  void _showSongOptions(MediaFile song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: app.isLight ? Colors.white : const Color(0xFF1E293B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.playlist_add_rounded, color: app.accentColor),
              title: Text('Add to Playlist', style: TextStyle(color: app.textColor)),
              onTap: () {
                Navigator.pop(ctx);
                AddToPlaylistDialog.show(context, song.id);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_cut_rounded, color: app.accentColor),
              title: Text('Ringtone Cutter & Trimmer', style: TextStyle(color: app.textColor)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AudioTrimmerScreen(availableTracks: _audios, initialTrack: song)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.share_rounded, color: app.accentColor),
              title: Text('Share Audio File', style: TextStyle(color: app.textColor)),
              onTap: () {
                Navigator.pop(ctx);
                MediaActionService.shareFile(song.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete from Device', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await MediaActionService.deleteMedia(context, song);
                if (ok && mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsListView(Color accent, Color textColor, Color secondaryTextColor, bool isLight) {
    final list = [
      '🔥 Most Played',
      '⏱️ Recently Added',
      '🕒 Recently Played',
      ...app.customPlaylists.keys,
      ...app.playlists.keys.where((k) => !app.customPlaylists.containsKey(k)),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final pl = list[idx];
        return iOSBounceButton(
          onTap: () => setState(() => _selectedPlaylist = pl),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.queue_music_rounded, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    pl,
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: secondaryTextColor, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistView(Color accent, Color textColor, Color secondaryTextColor, bool isLight) {
    List<PlaylistItem> displayItems = [];

    if (_selectedPlaylist == '🔥 Most Played') {
      final sorted = List<MediaFile>.from(_audios)
        ..sort((a, b) => (app.playCounts[b.id] ?? 0).compareTo(app.playCounts[a.id] ?? 0));
      displayItems = sorted.take(50).map(PlaylistItem.fromMediaFile).toList();
    } else if (_selectedPlaylist == '⏱️ Recently Added') {
      final sorted = List<MediaFile>.from(_audios)
        ..sort((a, b) => (b.modifiedDate ?? DateTime(2000)).compareTo(a.modifiedDate ?? DateTime(2000)));
      displayItems = sorted.take(50).map(PlaylistItem.fromMediaFile).toList();
    } else if (_selectedPlaylist == '🕒 Recently Played') {
      final map = {for (final m in _audios) m.id: m};
      for (final id in app.recentlyPlayed) {
        if (map.containsKey(id)) {
          displayItems.add(PlaylistItem.fromMediaFile(map[id]!));
        }
      }
    } else {
      final customList = app.customPlaylists[_selectedPlaylist] ?? [];
      final legacyIds = app.playlists[_selectedPlaylist] ?? [];
      displayItems = List.from(customList);
      for (final id in legacyIds) {
        if (!displayItems.any((t) => t.id == id)) {
          final local = _audios.where((s) => s.id == id).firstOrNull;
          if (local != null) displayItems.add(PlaylistItem.fromMediaFile(local));
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${displayItems.length} songs',
                style: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (displayItems.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _playHybrid(displayItems, 0, shuffle: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: const Text('Shuffle Play', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        Expanded(
          child: displayItems.isEmpty
              ? Center(child: Text('Playlist is empty', style: TextStyle(color: secondaryTextColor)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: displayItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final item = displayItems[idx];
                    return iOSBounceButton(
                      onTap: () => _playHybrid(displayItems, idx),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withValues(alpha: 0.12),
                              ),
                              child: Center(
                                child: Text('${idx + 1}', style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w800)),
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
                                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
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
