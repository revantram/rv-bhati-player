import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/media_scanner.dart';
import '../utils/format.dart';
import '../utils/id3_parser.dart';
import '../widgets/art_box.dart';
import '../widgets/glass_bars.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';

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

  // Video Sub-view: 0 = all, 1 = folders
  int _videoSubTab = 0;
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
    final ac = AudioController.instance;
    Navigator.of(context).push(glassRoute(AudioPlayerScreen(
      queue: ac.queue,
      startIndex: ac.player.currentIndex ?? 0,
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(app.tr('sort_by'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
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
          color: active ? AppState.instance.accentColor.withValues(alpha: 0.2) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: active ? AppState.instance.accentColor : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppState.instance.accentColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Accent Palette Sheet ---
  void _openPaletteSheet() {
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(AppState.instance.tr('theme_color'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: AppState.accentOptions.map((c) {
                  final active = AppState.instance.accentColor == c;
                  return GestureDetector(
                    onTap: () {
                      AppState.instance.setAccentColor(c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? Colors.white : Colors.transparent,
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
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14192B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(AppState.instance.tr('create_playlist'), style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: AppState.instance.tr('playlist_name'),
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppState.instance.tr('cancel'), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppState.instance.accentColor),
              onPressed: () {
                AppState.instance.createPlaylist(textCtrl.text);
                Navigator.pop(context);
              },
              child: Text(AppState.instance.tr('create'), style: const TextStyle(color: Colors.white)),
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
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: LiquidBackground(accent: accent)),
              Positioned.fill(child: _buildContent(pad)),
              // Top Bar
              Positioned(
                top: pad.top + 10,
                left: 16,
                right: 16,
                child: _isSearching
                    ? _buildSearchBar()
                    : GlassTopBar(
                        title: app.tr('app_name'),
                        subtitle: _loading
                            ? 'Scanning storage...'
                            : '${_videos.length} ${app.tr('videos').toLowerCase()}  -  ${_audios.length} ${app.tr('music').toLowerCase()}',
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accent, const Color(0xFF00D2FF)],
                            ),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                        actions: [
                          // Search
                          LiquidGlassButton(
                            icon: Icons.search_rounded,
                            size: 44,
                            iconSize: 22,
                            onTap: () => setState(() => _isSearching = true),
                          ),
                          const SizedBox(width: 4),
                          // Sort
                          LiquidGlassButton(
                            icon: Icons.swap_vert_rounded,
                            size: 44,
                            iconSize: 22,
                            onTap: _openSortSheet,
                          ),
                          const SizedBox(width: 4),
                          // Language toggle
                          LiquidGlassButton(
                            label: app.language == AppLanguage.hi ? 'हिं' : 'EN',
                            size: 44,
                            onTap: () {
                              app.setLanguage(app.language == AppLanguage.en ? AppLanguage.hi : AppLanguage.en);
                            },
                          ),
                          const SizedBox(width: 4),
                          // Accent Color
                          LiquidGlassButton(
                            icon: Icons.palette_outlined,
                            size: 44,
                            iconSize: 20,
                            tint: accent,
                            onTap: _openPaletteSheet,
                          ),
                        ],
                      ),
              ),
              // Bottom Nav & Mini Player
              Positioned(
                left: 16,
                right: 16,
                bottom: pad.bottom + 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniPlayer(onOpen: _openNowPlaying),
                    GlassBottomNav(
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
                        GlassNavItem(Icons.library_music_rounded, app.tr('music')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: AppState.instance.tr('search_hint'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => _searchCtrl.clear(),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
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

    final topOffset = pad.top + 86;
    final bottomOffset = pad.bottom + 170;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _tab == 0
          ? _buildVideosSection(topOffset, bottomOffset)
          : _buildMusicSection(topOffset, bottomOffset),
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
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
                child: _MediaCard(item: items[i], onTap: () => _open(items, i)),
              ),
            ),
          ),
        ],
      );
    }

    // Sub-tab: All Videos vs Folders
    return Column(
      children: [
        SizedBox(height: topOffset),
        // Sub-tabs pill selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _subTabPill(app.tr('all_videos'), _videoSubTab == 0, () {
                setState(() => _videoSubTab = 0);
              }),
              const SizedBox(width: 10),
              _subTabPill(app.tr('folders'), _videoSubTab == 1, () {
                setState(() => _videoSubTab = 1);
              }),
            ],
          ),
        ),
        Expanded(
          child: _videoSubTab == 0
              ? _buildAllVideosList(bottomOffset)
              : _buildVideoFoldersGrid(bottomOffset),
        ),
      ],
    );
  }

  Widget _buildAllVideosList(double bottomOffset) {
    final items = _filterAndSort(_videos);
    if (items.isEmpty) {
      return Center(
        child: _GlassMessage(
          icon: Icons.movie_outlined,
          title: AppState.instance.tr('no_videos'),
          body: 'No .mp4 or .mkv files found on this device.',
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
            child: _MediaCard(item: item, onTap: () => _open(items, idx)),
          );
        }),
      ],
    );
  }

  Widget _buildVideoFoldersGrid(double bottomOffset) {
    final folders = <String, List<MediaFile>>{};
    for (final v in _videos) {
      folders.putIfAbsent(v.folderName, () => []).add(v);
    }

    final folderKeys = folders.keys.toList()..sort();
    if (folderKeys.isEmpty) {
      return Center(
        child: _GlassMessage(
          icon: Icons.folder_open_rounded,
          title: 'No Folders',
          body: 'No video folders found.',
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomOffset),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: folderKeys.length,
      itemBuilder: (context, i) {
        final folderName = folderKeys[i];
        final videosInFolder = folders[folderName]!;
        final firstVideo = videosInFolder.first;

        return PressableScale(
          onTap: () => setState(() => _selectedFolder = folderName),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(12),
            blur: 0,
            glow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox.expand(
                      child: _VideoThumb(entity: firstVideo.entity),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  folderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
                ),
                Text(
                  '${videosInFolder.length} videos',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Music Tab View ---
  Widget _buildMusicSection(double topOffset, double bottomOffset) {
    final app = AppState.instance;

    // If viewing inside a custom playlist
    if (_selectedPlaylist != null) {
      final songIds = app.playlists[_selectedPlaylist] ?? [];
      final playlistSongs = _audios.where((s) => songIds.contains(s.id)).toList();
      final items = _filterAndSort(playlistSongs);

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
                  child: Text(
                    _selectedPlaylist!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
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
            child: items.isEmpty
                ? const Center(child: Text('Playlist is empty', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomOffset),
                    itemCount: items.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MediaCard(item: items[i], onTap: () => _open(items, i)),
                    ),
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
    final playlists = AppState.instance.playlists;
    final keys = playlists.keys.toList();
    if (keys.isEmpty) {
      return Center(
        child: _GlassMessage(
          icon: Icons.playlist_add_rounded,
          title: AppState.instance.tr('no_playlists'),
          body: 'Tap the + button above to create a playlist.',
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomOffset),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final name = keys[i];
        final count = playlists[name]?.length ?? 0;
        return PressableScale(
          onTap: () => setState(() => _selectedPlaylist = name),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(16),
            blur: 0,
            glow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_music_rounded, color: AppState.instance.accentColor, size: 36),
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count songs',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistSheet(MediaFile item) {
    final playlists = AppState.instance.playlists.keys.toList();
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(AppState.instance.tr('add_to_playlist'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No playlists available. Create one first.', style: TextStyle(color: Colors.white54)),
                )
              else
                ...playlists.map((pl) => ListTile(
                      leading: Icon(Icons.playlist_add_rounded, color: AppState.instance.accentColor),
                      title: Text(pl, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      onTap: () {
                        AppState.instance.addToPlaylist(pl, item.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to $pl')),
                        );
                      },
                    )),
            ],
          ),
        );
      },
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, size: 18, color: AppState.instance.accentColor),
            const SizedBox(width: 6),
            Text(
              AppState.instance.tr('recently_played'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70),
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
                    glow: false,
                    child: SizedBox(
                      width: 140,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 50,
                              height: 80,
                              child: item.kind == MediaKind.video
                                  ? _VideoThumb(entity: item.entity)
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
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatDuration(item.duration),
                                  style: const TextStyle(fontSize: 11, color: Colors.white54),
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
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderColor: active ? AppState.instance.accentColor : Colors.white12,
        tint: active ? AppState.instance.accentColor.withValues(alpha: 0.25) : null,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppState.instance.accentColor : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item, required this.onTap, this.onLongPress});

  final MediaFile item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.kind == MediaKind.video;
    final isFav = AppState.instance.isFavorite(item.id);

    return PressableScale(
      hapticOnDown: false,
      onTap: onTap,
      onLongPress: onLongPress,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(26),
        padding: const EdgeInsets.all(10),
        blur: 0,
        glow: false,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 76,
                height: 76,
                child: isVideo
                    ? _VideoThumb(entity: item.entity)
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
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.artist != null
                        ? '${item.artist!}  -  ${formatDuration(item.duration)}'
                        : '${formatDuration(item.duration)}  -  ${item.extension}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (!isVideo)
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? const Color(0xFFFF2A85) : Colors.white38,
                  size: 22,
                ),
                onPressed: () => AppState.instance.toggleFavorite(item.id),
              ),
            Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: 34,
            ),
            const SizedBox(width: 4),
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
      return ColoredBox(
        color: Colors.white.withValues(alpha: 0.08),
        child: const Icon(Icons.movie_rounded, color: Colors.white54),
      );
    }
    return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final player = AudioController.instance.player;
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snap) {
        final tag = snap.data?.currentSource?.tag;
        if (tag is! MediaItem) return const SizedBox.shrink();
        final queue = AudioController.instance.queue;
        final currentIdx = player.currentIndex ?? 0;
        final currentSong = currentIdx < queue.length ? queue[currentIdx] : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PressableScale(
            hapticOnDown: false,
            onTap: onOpen,
            child: LiquidGlassContainer(
              borderRadius: LiquidGlassContainer.capsuleRadius,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: currentSong?.embeddedArt != null
                          ? Image.memory(currentSong!.embeddedArt!, fit: BoxFit.cover)
                          : ArtBox(seed: tag.title, radius: 0, iconSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tag.artist ?? (tag.album ?? 'RV Bhati Player'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, s) {
                      final playing = s.data?.playing ?? false;
                      return LiquidGlassButton(
                        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 40,
                        iconSize: 24,
                        tint: AppState.instance.accentColor,
                        onTap: () => playing ? player.pause() : player.play(),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(32),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              )
            else
              Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.65), height: 1.4),
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
