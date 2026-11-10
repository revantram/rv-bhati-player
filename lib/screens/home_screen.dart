import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';
import '../models/playlist_item.dart';
import '../models/radio_station.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/radio_controller.dart';
import '../services/media_scanner.dart';
import '../services/update_service.dart';
import '../utils/format.dart';
import '../utils/id3_parser.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/art_box.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/dynamic_island_player.dart';
import '../widgets/glass_bars.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import '../models/video_folder.dart';
import '../services/thumbnail_service.dart';
import '../widgets/video_thumbnail_widget.dart';
import '../widgets/video_options_sheet.dart';
import 'audio_player_screen.dart';
import 'folder_videos_list_screen.dart';
import 'online_music_screen.dart';
import 'radio_screen.dart';
import 'video_folder_screen.dart';
import 'video_player_screen.dart';
import 'settings_screen.dart';
import '../widgets/wave_visualizer.dart';

enum SortOption {
  nameAsc,
  nameDesc,
  dateDesc,
  dateAsc,
  durationDesc,
  durationAsc,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0; // 0 = videos, 1 = music
  bool _loading = true;
  bool _denied = false;
  String? _error;

  List<MediaFile> _videos = const [];
  List<MediaFile> _audios = const [];

  String? _selectedFolder;

  // Music Sub-view: 0 = all, 1 = favorites, 2 = playlists
  int _musicSubTab = 0;
  String? _selectedPlaylist;

  // Search
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Sort
  SortOption _sortOption = SortOption.dateDesc;

  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _denied) _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _denied = false;
      _error = null;
    });
    try {
      final granted = await MediaScanner.requestPermissions();
      if (!granted) {
        if (mounted) {
          setState(() {
            _denied = true;
            _loading = false;
          });
        }
        return;
      }
      final results = await Future.wait([
        MediaScanner.scan(MediaKind.video),
        MediaScanner.scan(MediaKind.audio),
      ]);
      if (!mounted) return;
      setState(() {
        _videos = results[0];
        _audios = results[1];
        _loading = false;
      });
      Permission.notification.request();
      // Auto-check for updates in background on app open
      UpdateService.instance.checkAndPromptUpdate(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _open(List<MediaFile> items, int i) {
    final page = _tab == 0
        ? VideoPlayerScreen(playlist: items, startIndex: i)
        : AudioPlayerScreen(queue: items, startIndex: i);
    Navigator.of(context).push(glassRoute(page));
  }

  void _openNowPlaying() {
    Navigator.of(context).push(glassRoute(const AudioPlayerScreen(
      startPlayback: false,
    )));
  }

  void _openHybrid(List<PlaylistItem> items, int i, {bool shuffle = false}) {
    AudioController.instance.playHybridQueue(items, i, shuffle: shuffle);
    Navigator.of(context).push(glassRoute(const AudioPlayerScreen(
      startPlayback: false,
    )));
  }

  // --- Filtering & Sorting ---
  List<MediaFile> _filterAndSort(List<MediaFile> list) {
    var filtered = list;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((m) {
        final title = m.displayTitle.toLowerCase();
        final artist = (m.artist ?? '').toLowerCase();
        return title.contains(_searchQuery) || artist.contains(_searchQuery);
      }).toList();
    }

    final sorted = List<MediaFile>.from(filtered);
    switch (_sortOption) {
      case SortOption.nameAsc:
        sorted.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
        break;
      case SortOption.nameDesc:
        sorted.sort((a, b) => b.displayTitle.toLowerCase().compareTo(a.displayTitle.toLowerCase()));
        break;
      case SortOption.dateDesc:
        sorted.sort((a, b) => (b.modifiedDate ?? DateTime(0)).compareTo(a.modifiedDate ?? DateTime(0)));
        break;
      case SortOption.dateAsc:
        sorted.sort((a, b) => (a.modifiedDate ?? DateTime(0)).compareTo(b.modifiedDate ?? DateTime(0)));
        break;
      case SortOption.durationDesc:
        sorted.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case SortOption.durationAsc:
        sorted.sort((a, b) => a.duration.compareTo(b.duration));
        break;
    }
    return sorted;
  }

  // --- Sort Sheet ---
  void _openSortSheet() {
    final app = AppState.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: app.isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                app.tr('sort_by'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
              const SizedBox(height: 16),
              _sortItem(SortOption.dateDesc, app.tr('sort_date_desc')),
              _sortItem(SortOption.dateAsc, app.tr('sort_date_asc')),
              _sortItem(SortOption.nameAsc, app.tr('sort_name_asc')),
              _sortItem(SortOption.nameDesc, app.tr('sort_name_desc')),
              _sortItem(SortOption.durationDesc, app.tr('sort_duration_desc')),
              _sortItem(SortOption.durationAsc, app.tr('sort_duration_asc')),
            ],
          ),
        );
      },
    );
  }

  Widget _sortItem(SortOption opt, String label) {
    final app = AppState.instance;
    final active = _sortOption == opt;
    return GestureDetector(
      onTap: () {
        setState(() => _sortOption = opt);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: active ? app.accentColor.withValues(alpha: 0.2) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: active ? app.accentColor : app.secondaryTextColor,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? app.accentColor : app.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Accent Palette Sheet ---
  void _openPaletteSheet() {
    final app = AppState.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: app.isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                app.tr('theme_color'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: AppState.accentOptions.map((c) {
                  final active = app.accentColor == c;
                  return GestureDetector(
                    onTap: () {
                      app.setAccentColor(c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? (app.isLight ? Colors.black87 : Colors.white) : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: active ? const Icon(Icons.check_rounded, color: Colors.white, size: 26) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Create Playlist Dialog ---
  void _showCreatePlaylistDialog() {
    final app = AppState.instance;
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: app.isLight ? Colors.white : const Color(0xFF14192B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            app.tr('create_playlist'),
            style: TextStyle(color: app.textColor, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            style: TextStyle(color: app.textColor),
            decoration: InputDecoration(
              hintText: app.tr('playlist_name'),
              hintStyle: TextStyle(color: app.secondaryTextColor.withValues(alpha: 0.6)),
              filled: true,
              fillColor: app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(app.tr('cancel'), style: TextStyle(color: app.secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: app.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                app.createPlaylist(textCtrl.text);
                Navigator.pop(context);
              },
              child: Text(app.tr('create'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final app = AppState.instance;

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final accent = app.accentColor;
        return PopScope(
          canPop: !_isSearching && _tab == 0 && _musicSubTab == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchCtrl.clear();
                _searchQuery = '';
              });
              return;
            }
            if (_tab != 0) {
              setState(() => _tab = 0);
              return;
            }
            if (_musicSubTab != 0) {
              setState(() => _musicSubTab = 0);
              return;
            }
          },
          child: Scaffold(
            body: Stack(
            children: [
              Positioned.fill(child: LiquidBackground(accent: accent)),
              Positioned.fill(child: _buildContent(pad)),
              // Top Bar: only show floating search bar when user searches
              if (_isSearching)
                Positioned(
                  top: pad.top + 8,
                  left: 16,
                  right: 16,
                  child: _buildSearchBar(),
                ),
              // Dynamic Island: Floats above bottom nav when audio/radio is playing
              Positioned(
                left: 16,
                right: 16,
                bottom: pad.bottom + 84,
                child: DynamicIslandPlayer(
                  onOpen: _openNowPlaying,
                  onOpenRadio: () => setState(() => _tab = 1),
                  onOpenOnline: _openNowPlaying,
                ),
              ),
              // Bottom Nav: 4 items (Videos, FM Radio, JioSaavn, Settings)
              Positioned(
                left: 16,
                right: 16,
                bottom: pad.bottom + 12,
                child: GlassBottomNav(
                  index: _tab,
                  onChanged: (i) {
                    setState(() {
                      _tab = i;
                      _selectedFolder = null;
                      _selectedPlaylist = null;
                    });
                  },
                  items: [
                    GlassNavItem(Icons.movie_filter_rounded, app.tr('videos')),
                    GlassNavItem(Icons.radio_rounded, 'FM Radio'),
                    GlassNavItem(Icons.music_note_rounded, 'JioSaavn'),
                    GlassNavItem(Icons.settings_rounded, 'Settings'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  Widget _buildSearchBar() {
    final app = AppState.instance;
    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: app.secondaryTextColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(color: app.textColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: app.tr('search_hint'),
                hintStyle: TextStyle(
                  color: app.secondaryTextColor.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => _searchCtrl.clear(),
              child: Icon(Icons.close_rounded, color: app.secondaryTextColor, size: 20),
            ),
          const SizedBox(width: 8),
          LiquidGlassButton(
            icon: Icons.arrow_back_rounded,
            size: 36,
            iconSize: 18,
            onTap: () {
              setState(() {
                _isSearching = false;
                _searchCtrl.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(EdgeInsets pad) {
    if (_loading) {
      return const Center(
        child: _GlassMessage(
          icon: Icons.hourglass_top_rounded,
          title: 'Scanning storage',
          body: 'Finding your .mp4, .mkv and .mp3 files...',
          showSpinner: true,
        ),
      );
    }
    if (_denied) {
      return Center(
        child: _GlassMessage(
          icon: Icons.lock_outline_rounded,
          title: 'Allow media access',
          body: 'RV Bhati Player needs permission to read videos and audio on this device.',
          actions: [
            LiquidGlassButton(
              icon: Icons.check_rounded,
              label: 'Allow',
              size: 48,
              tint: AppState.instance.accentColor,
              onTap: _init,
            ),
            const SizedBox(height: 10),
            LiquidGlassButton(
              icon: Icons.settings_rounded,
              label: 'Open Settings',
              size: 48,
              onTap: openAppSettings,
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: _GlassMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not scan media',
          body: _error!,
          actions: [
            LiquidGlassButton(
              icon: Icons.refresh_rounded,
              label: 'Retry',
              size: 48,
              onTap: _init,
            ),
          ],
        ),
      );
    }

    final topOffset = pad.top + 8;
    final bottomOffset = pad.bottom + 155;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _tab == 0
          ? _buildVideosSection(topOffset, bottomOffset)
          : _tab == 1
              ? RadioScreen(topOffset: topOffset, bottomOffset: bottomOffset)
              : _tab == 2
                  ? OnlineMusicScreen(topOffset: topOffset, bottomOffset: bottomOffset)
                  : SettingsScreen(isTab: true, bottomOffset: bottomOffset),
    );
  }

  // --- Videos Tab View ---
  Widget _buildVideosSection(double topOffset, double bottomOffset) {
    final app = AppState.instance;

    // If viewing inside a folder
    if (_selectedFolder != null) {
      final folderVideos = _videos.where((v) => v.folderName == _selectedFolder).toList();
      final items = _filterAndSort(folderVideos);

      return Column(
        children: [
          SizedBox(height: topOffset),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                LiquidGlassButton(
                  icon: Icons.arrow_back_rounded,
                  size: 38,
                  iconSize: 20,
                  onTap: () => setState(() => _selectedFolder = null),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFolder!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomOffset),
              itemCount: items.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MediaCard(
                  item: items[i],
                  onTap: () => _open(items, i),
                  onVideoOptions: items[i].kind == MediaKind.video
                      ? () => _showVideoOptions(items[i], items, i)
                      : null,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isLight = app.isLight;
    final accent = app.accentColor;

    // Video section: Direct Clean Folders list (YouTube tab removed)
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: topOffset),
            child: VideoFolderScreen(
              videos: _videos,
              bottomOffset: bottomOffset + 68,
              onVideoDeleted: (deleted) {
                setState(() {
                  _videos.removeWhere((v) => v.id == deleted.id || v.path == deleted.path);
                });
              },
            ),
          ),
        ),
        // Quick Resume Button for user's most recent video
                    Builder(builder: (context) {
                      final recentVideos = _getRecentlyPlayed(MediaKind.video);
                      final recentVideo = recentVideos.isNotEmpty ? recentVideos.first : null;
                      if (recentVideo == null) return const SizedBox.shrink();

                      return Positioned(
                        left: 20,
                        right: 20,
                        bottom: bottomOffset - 78,
                        child: Center(
                          child: PressableScale(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _open([recentVideo], 0);
                            },
                            child: Container(
                              height: 52,
                              constraints: const BoxConstraints(maxWidth: 380),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isLight ? Colors.white : const Color(0xFF1E2438),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: accent, width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [accent, const Color(0xFF00D2FF)],
                                      ),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Resume Recent Video / पिछला वीडियो',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: accent,
                                          ),
                                        ),
                                        Text(
                                          VideoFolderScreen.cleanFolderName(recentVideo.displayTitle),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: app.textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: accent),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
      ],
    );
  }

  void _showVideoOptions(MediaFile video, List<MediaFile> playlist, int index) {
    VideoOptionsSheet.show(
      context,
      video: video,
      onPlay: () => _open(playlist, index),
      onDeleted: (deleted) {
        setState(() {
          _videos.removeWhere((v) => v.id == deleted.id || v.path == deleted.path);
        });
      },
    );
  }

  Widget _buildAllVideosList(double bottomOffset) {
    final items = _filterAndSort(_videos);
    if (items.isEmpty) {
      return Center(
        child: _GlassMessage(
          icon: Icons.movie_outlined,
          title: AppState.instance.tr('no_videos'),
          body: 'No .mp4, .mkv or .webm files found on this device.',
        ),
      );
    }

    final recentItems = _getRecentlyPlayed(MediaKind.video);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomOffset),
      children: [
        if (recentItems.isNotEmpty && _searchQuery.isEmpty) ...[
          _buildRecentlyPlayedSection(recentItems),
          const SizedBox(height: 16),
        ],
        ...items.map((item) {
          final idx = items.indexOf(item);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MediaCard(
              item: item,
              onTap: () => _open(items, idx),
              onVideoOptions: () => _showVideoOptions(item, items, idx),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVideoFoldersGrid(double bottomOffset) {
    return VideoFolderScreen(
      videos: _videos,
      bottomOffset: bottomOffset,
      onVideoDeleted: (deleted) {
        setState(() {
          _videos.removeWhere((v) => v.id == deleted.id || v.path == deleted.path);
        });
      },
    );
  }

  // --- Music Tab View ---
  Widget _buildMusicSection(double topOffset, double bottomOffset) {
    final app = AppState.instance;

    // If viewing inside a custom or smart playlist
    if (_selectedPlaylist != null) {
      final isSmart = _selectedPlaylist == '🔥 Most Played' ||
          _selectedPlaylist == '⏱️ Recently Added' ||
          _selectedPlaylist == '🕒 Recently Played';

      List<PlaylistItem> displayItems = [];

      if (_selectedPlaylist == '🔥 Most Played') {
        final sorted = List<MediaFile>.from(_audios)
          ..sort((a, b) => (app.playCounts[b.id] ?? 0).compareTo(app.playCounts[a.id] ?? 0));
        final top = sorted.where((s) => (app.playCounts[s.id] ?? 0) > 0).take(50).toList();
        displayItems = (top.isNotEmpty ? top : _audios.take(30)).map(PlaylistItem.fromMediaFile).toList();
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
            if (local != null) {
              displayItems.add(PlaylistItem.fromMediaFile(local));
            }
          }
        }
      }

      return Column(
        children: [
          SizedBox(height: topOffset),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                LiquidGlassButton(
                  icon: Icons.arrow_back_rounded,
                  size: 38,
                  iconSize: 20,
                  onTap: () => setState(() => _selectedPlaylist = null),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPlaylist!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: app.textColor,
                        ),
                      ),
                      Text(
                        '${displayItems.length} songs',
                        style: TextStyle(
                          fontSize: 12,
                          color: app.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (displayItems.isNotEmpty) ...[
                  LiquidGlassButton(
                    icon: Icons.shuffle_rounded,
                    size: 38,
                    iconSize: 20,
                    onTap: () => _openHybrid(displayItems, 0, shuffle: true),
                  ),
                  const SizedBox(width: 8),
                  LiquidGlassButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play All',
                    size: 38,
                    tint: app.accentColor,
                    onTap: () => _openHybrid(displayItems, 0),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isSmart)
                  LiquidGlassButton(
                    icon: Icons.delete_outline_rounded,
                    size: 38,
                    iconSize: 20,
                    tint: Colors.redAccent,
                    onTap: () {
                      app.deletePlaylist(_selectedPlaylist!);
                      setState(() => _selectedPlaylist = null);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: displayItems.isEmpty
                ? Center(
                    child: Text(
                      'Playlist is empty',
                      style: TextStyle(color: app.secondaryTextColor),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomOffset),
                    itemCount: displayItems.length,
                    itemBuilder: (_, i) {
                      final track = displayItems[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PlaylistItemTile(
                          item: track,
                          onTap: () => _openHybrid(displayItems, i),
                          onDelete: isSmart
                              ? null
                              : () {
                                  app.removeFromCustomPlaylist(_selectedPlaylist!, track.id);
                                  setState(() {});
                                },
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: topOffset),
        // Sub-tabs pill selector: All Songs, Favorites, Playlists
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _subTabPill(app.tr('all_songs'), _musicSubTab == 0, () {
                setState(() => _musicSubTab = 0);
              }),
              const SizedBox(width: 8),
              _subTabPill(app.tr('favorites'), _musicSubTab == 1, () {
                setState(() => _musicSubTab = 1);
              }),
              const SizedBox(width: 8),
              _subTabPill(app.tr('playlists'), _musicSubTab == 2, () {
                setState(() => _musicSubTab = 2);
              }),
              if (_musicSubTab == 2) ...[
                const Spacer(),
                LiquidGlassButton(
                  icon: Icons.add_rounded,
                  size: 36,
                  iconSize: 20,
                  tint: app.accentColor,
                  onTap: _showCreatePlaylistDialog,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _musicSubTab == 0
              ? _buildAllMusicList(bottomOffset)
              : (_musicSubTab == 1
                  ? _buildFavoritesList(bottomOffset)
                  : _buildPlaylistsGrid(bottomOffset)),
        ),
      ],
    );
  }

  Widget _buildAllMusicList(double bottomOffset) {
    final items = _filterAndSort(_audios);
    if (items.isEmpty) {
      return Center(
        child: _GlassMessage(
          icon: Icons.music_off_rounded,
          title: AppState.instance.tr('no_songs'),
          body: 'No .mp3 files found on this device.',
        ),
      );
    }

    final recentItems = _getRecentlyPlayed(MediaKind.audio);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomOffset),
      children: [
        if (recentItems.isNotEmpty && _searchQuery.isEmpty) ...[
          _buildRecentlyPlayedSection(recentItems),
          const SizedBox(height: 16),
        ],
        ...items.map((item) {
          final idx = items.indexOf(item);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MediaCard(
              item: item,
              onTap: () => _open(items, idx),
              onLongPress: () => _showAddToPlaylistSheet(item),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFavoritesList(double bottomOffset) {
    final favList = _audios.where((s) => AppState.instance.isFavorite(s.id)).toList();
    final items = _filterAndSort(favList);
    if (items.isEmpty) {
      return Center(
        child: _GlassMessage(
          icon: Icons.favorite_border_rounded,
          title: AppState.instance.tr('no_favorites'),
          body: 'Tap the heart icon on any song to add it here.',
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomOffset),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MediaCard(item: items[i], onTap: () => _open(items, i)),
      ),
    );
  }

  Widget _buildPlaylistsGrid(double bottomOffset) {
    final customPlaylists = AppState.instance.customPlaylists;
    final legacyPlaylists = AppState.instance.playlists;
    final customKeys = <String>{...customPlaylists.keys, ...legacyPlaylists.keys}.toList();

    // Auto-calculate Smart Playlist counts
    final mostPlayedCount = _audios.where((s) => (app.playCounts[s.id] ?? 0) > 0).length;
    final recentlyAddedCount = math.min(_audios.length, 50);
    final recentlyPlayedCount = app.recentlyPlayed.where((id) => _audios.any((a) => a.id == id)).length;

    final smartPlaylists = [
      {
        'name': '🔥 Most Played',
        'subtitle': '$mostPlayedCount songs',
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFFF6B00),
      },
      {
        'name': '⏱️ Recently Added',
        'subtitle': '$recentlyAddedCount songs',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF00D2FF),
      },
      {
        'name': '🕒 Recently Played',
        'subtitle': '$recentlyPlayedCount songs',
        'icon': Icons.history_rounded,
        'color': const Color(0xFFA855F7),
      },
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomOffset),
      children: [
        // Smart Playlists Section
        Row(
          children: [
            Icon(Icons.smart_toy_rounded, size: 16, color: app.accentColor),
            const SizedBox(width: 6),
            Text(
              'SMART PLAYLISTS (AUTO-GENERATED)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: app.secondaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: smartPlaylists.length,
          itemBuilder: (context, i) {
            final sp = smartPlaylists[i];
            final color = sp['color'] as Color;
            return PressableScale(
              onTap: () => setState(() => _selectedPlaylist = sp['name'] as String),
              child: LiquidGlassContainer(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                tint: color.withValues(alpha: 0.12),
                borderColor: color.withValues(alpha: 0.35),
                blur: 0,
                glow: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(sp['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sp['name'] as String,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: app.textColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sp['subtitle'] as String,
                      style: TextStyle(fontSize: 10, color: app.secondaryTextColor),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 22),

        // Custom Playlists Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.queue_music_rounded, size: 16, color: app.accentColor),
                const SizedBox(width: 6),
                Text(
                  'MY PLAYLISTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: app.secondaryTextColor,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _showCreatePlaylistDialog,
              child: Text(
                '+ New Playlist',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: app.accentColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (customKeys.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 40, color: app.secondaryTextColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'No custom playlists yet.\nTap "+ New Playlist" to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: app.secondaryTextColor),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: customKeys.length,
            itemBuilder: (context, i) {
              final name = customKeys[i];
              final count = customPlaylists[name]?.length ?? legacyPlaylists[name]?.length ?? 0;
              return PressableScale(
                onTap: () => setState(() => _selectedPlaylist = name),
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.all(14),
                  blur: 0,
                  glow: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue_music_rounded, color: AppState.instance.accentColor, size: 32),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: app.textColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$count songs',
                        style: TextStyle(fontSize: 12, color: app.secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddToPlaylistSheet(MediaFile item) {
    AddToPlaylistDialog.showForMedia(context, item);
  }

  List<MediaFile> _getRecentlyPlayed(MediaKind kind) {
    final recents = AppState.instance.recentlyPlayed;
    final all = kind == MediaKind.video ? _videos : _audios;
    final map = {for (final m in all) m.id: m};
    final list = <MediaFile>[];
    for (final id in recents) {
      if (map.containsKey(id)) {
        list.add(map[id]!);
      }
      if (list.length >= 6) break;
    }
    return list;
  }

  Widget _buildRecentlyPlayedSection(List<MediaFile> items) {
    final app = AppState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, size: 18, color: app.accentColor),
            const SizedBox(width: 6),
            Text(
              app.tr('recently_played'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: app.textColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: PressableScale(
                  onTap: () => _open(items, i),
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(8),
                    blur: 0,
                    glow: true,
                    child: SizedBox(
                      width: 150,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 50,
                              height: 80,
                              child: item.kind == MediaKind.video
                                  ? VideoThumbnailWidget(
                                      video: item,
                                      width: 50,
                                      height: 80,
                                      borderRadius: BorderRadius.circular(14),
                                      fit: BoxFit.cover,
                                    )
                                  : (item.embeddedArt != null
                                      ? Image.memory(item.embeddedArt!, fit: BoxFit.cover)
                                      : ArtBox(seed: item.displayTitle, radius: 0, iconSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: app.textColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatDuration(item.duration),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: app.secondaryTextColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _subTabPill(String title, bool active, VoidCallback onTap) {
    final app = AppState.instance;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? app.accentColor
              : (app.isLight ? Colors.white : const Color(0xFF1E2438)),
          border: Border.all(
            color: active
                ? app.accentColor
                : (app.isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.18)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? app.accentColor.withValues(alpha: 0.35)
                  : (app.isLight ? const Color(0xFF0F172A).withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.2)),
              blurRadius: active ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : app.textColor,
          ),
        ),
      ),
    );
  }

  // --- Live Radio Section ---
  Widget _buildRadioSection(double topOffset, double bottomOffset) {
    return RadioScreen(topOffset: topOffset, bottomOffset: bottomOffset);
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.onVideoOptions,
  });

  final MediaFile item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onVideoOptions;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isVideo = item.kind == MediaKind.video;
    final isFav = app.isFavorite(item.id);

    return PressableScale(
      hapticOnDown: false,
      onTap: onTap,
      onLongPress: onLongPress ?? (isVideo ? onVideoOptions : null),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(26),
        padding: const EdgeInsets.all(10),
        blur: 0,
        glow: true,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 76,
                height: 76,
                child: isVideo
                    ? VideoThumbnailWidget(
                        video: item,
                        width: 76,
                        height: 76,
                        borderRadius: BorderRadius.circular(18),
                        fit: BoxFit.cover,
                      )
                    : (item.embeddedArt != null
                        ? Image.memory(item.embeddedArt!, fit: BoxFit.cover)
                        : _AsyncArtThumb(item: item)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  item.artist != null && item.artist!.isNotEmpty && item.artist != 'Unknown'
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            ArtistSongsSheet.show(context, artistName: item.artist!);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  item.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: app.accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 9,
                                color: app.accentColor,
                              ),
                              Text(
                                '  •  ${formatDuration(item.duration)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: app.secondaryTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          item.artist != null
                              ? '${item.artist!}  -  ${formatDuration(item.duration)}'
                              : '${formatDuration(item.duration)}  -  ${item.extension}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: app.secondaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),
            ),
            if (!isVideo) ...[
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? const Color(0xFFFF2A85) : app.secondaryTextColor.withValues(alpha: 0.5),
                  size: 22,
                ),
                onPressed: () => app.toggleFavorite(item.id, item: PlaylistItem.fromMediaFile(item)),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: app.secondaryTextColor, size: 20),
                color: app.isLight ? Colors.white : const Color(0xFF14192B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'playlist') {
                    AddToPlaylistDialog.showForMedia(context, item);
                  } else if (val == 'view_artist' && item.artist != null) {
                    ArtistSongsSheet.show(context, artistName: item.artist!);
                  }
                },
                itemBuilder: (context) => [
                  if (item.artist != null && item.artist!.isNotEmpty && item.artist != 'Unknown')
                    PopupMenuItem(
                      value: 'view_artist',
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, color: app.secondaryTextColor, size: 20),
                          const SizedBox(width: 10),
                          Text('View Artist', style: TextStyle(color: app.textColor)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'playlist',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add_rounded, color: app.secondaryTextColor, size: 20),
                        const SizedBox(width: 10),
                        Text('Add to Playlist', style: TextStyle(color: app.textColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (isVideo && onVideoOptions != null) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onVideoOptions,
                child: Container(
                  width: 32,
                  height: 34,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(5.5),
                    decoration: BoxDecoration(
                      color: app.isLight
                          ? Colors.black.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: app.secondaryTextColor,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.play_circle_fill_rounded,
              color: app.isLight ? app.accentColor : Colors.white.withValues(alpha: 0.85),
              size: 34,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _PlaylistItemTile extends StatelessWidget {
  const _PlaylistItemTile({
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  final PlaylistItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return PressableScale(
      hapticOnDown: false,
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(10),
        blur: 0,
        glow: false,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 60,
                height: 60,
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ArtBox(seed: item.title, radius: 0, iconSize: 24),
                      )
                    : ArtBox(seed: item.title, radius: 0, iconSize: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: app.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.isOnline)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ONLINE',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF00D2FF), fontWeight: FontWeight.w700),
                          ),
                        ),
                      Expanded(
                        child: item.artist.isNotEmpty && item.artist != 'Unknown'
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  ArtistSongsSheet.show(context, artistName: item.artist);
                                },
                                child: Text(
                                  item.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: app.accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : Text(
                                item.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: app.secondaryTextColor,
                                ),
                              ),
                      ),
                      Text(
                        formatDuration(item.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: app.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.close_rounded, color: app.secondaryTextColor, size: 18),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _AsyncArtThumb extends StatefulWidget {
  const _AsyncArtThumb({required this.item});
  final MediaFile item;

  @override
  State<_AsyncArtThumb> createState() => _AsyncArtThumbState();
}

class _AsyncArtThumbState extends State<_AsyncArtThumb> {
  @override
  void initState() {
    super.initState();
    if (widget.item.embeddedArt == null) {
      Id3Parser.parse(widget.item.path).then((meta) {
        if (mounted && meta?.albumArt != null) {
          widget.item.embeddedArt = meta!.albumArt;
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.embeddedArt != null) {
      return Image.memory(widget.item.embeddedArt!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return ArtBox(seed: widget.item.displayTitle, radius: 0, iconSize: 32);
  }
}

class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.entity});
  final AssetEntity entity;

  static final Map<String, Uint8List?> _cache = {};

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  Uint8List? _cachedData;

  @override
  void initState() {
    super.initState();
    _cachedData = _VideoThumb._cache[widget.entity.id];
    if (_cachedData == null && !_VideoThumb._cache.containsKey(widget.entity.id)) {
      widget.entity.thumbnailDataWithSize(const ThumbnailSize(160, 160)).then((data) {
        if (mounted) {
          _VideoThumb._cache[widget.entity.id] = data;
          setState(() => _cachedData = data);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _cachedData ?? _VideoThumb._cache[widget.entity.id];
    if (data == null) {
      final app = AppState.instance;
      return Container(
        color: app.isLight ? const Color(0xFFE2E6EE) : const Color(0xFF161C2E),
        child: Center(
          child: Icon(
            Icons.movie_creation_rounded,
            color: app.accentColor.withValues(alpha: 0.5),
            size: 28,
          ),
        ),
      );
    }
    return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

class _GlassMessage extends StatelessWidget {
  const _GlassMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showSpinner = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(32),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: app.accentColor),
              )
            else
              Icon(icon, size: 48, color: app.textColor.withValues(alpha: 0.85)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: app.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: app.secondaryTextColor, height: 1.4),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }
}
