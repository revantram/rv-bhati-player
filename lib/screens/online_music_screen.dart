import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/online_song.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/saavn_api_service.dart';
import '../services/settings_service.dart';
import '../services/yt_music_service.dart';
import '../utils/format.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/glass_bars.dart';
import '../widgets/liquid_glass_container.dart';

class OnlineMusicScreen extends StatefulWidget {
  const OnlineMusicScreen({
    super.key,
    this.topOffset = 90,
    this.bottomOffset = 150,
  });

  final double topOffset;
  final double bottomOffset;

  @override
  State<OnlineMusicScreen> createState() => _OnlineMusicScreenState();
}

class _OnlineMusicScreenState extends State<OnlineMusicScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  bool _loadingSearch = false;
  List<OnlineSong> _searchResults = [];

  bool _loadingTrending = true;
  List<OnlineSong> _trendingSongs = [];

  String? _selectedCategory;
  bool _loadingCategory = false;
  List<OnlineSong> _categorySongs = [];

  String _artistCategoryFilter = 'All'; // 'All', 'Modern Hits', '90s Icons', 'Legends', 'Rajasthani & Folk'

  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    SettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTrending() async {
    setState(() => _loadingTrending = true);
    final songs = await SaavnApiService.instance.getTrendingSongs();
    if (mounted) {
      setState(() {
        _trendingSongs = songs;
        _loadingTrending = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _isSearching = false;
        _loadingSearch = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _loadingSearch = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final engine = SettingsService.instance.musicEngine;
      List<OnlineSong> results;
      if (engine == MusicEngine.youtube) {
        results = await YtMusicService.instance.search(clean);
      } else {
        results = await SaavnApiService.instance.searchSongs(clean);
      }
      if (mounted) {
        setState(() {
          _searchResults = results;
          _loadingSearch = false;
        });
      }
    });
  }

  Future<void> _openCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _loadingCategory = true;
      _categorySongs = [];
    });

    final songs = await SaavnApiService.instance.getCategorizedPlaylist(category);
    if (mounted) {
      setState(() {
        _categorySongs = songs;
        _loadingCategory = false;
      });
    }
  }

  Future<void> _openMoodCategory(String moodId, String title) async {
    setState(() {
      _selectedCategory = title;
      _loadingCategory = true;
      _categorySongs = [];
    });

    final songs = await SaavnApiService.instance.getMoodPlaylist(moodId);
    if (mounted) {
      setState(() {
        _categorySongs = songs;
        _loadingCategory = false;
      });
    }
  }

  void _openArtistSheet(SaavnArtist artist) {
    ArtistSongsSheet.show(
      context,
      artist: artist,
      artistName: artist.name,
      avatarUrl: artist.avatarUrl,
      subtitle: artist.subtitle,
    );
  }

  void _playSong(List<OnlineSong> list, int index) {
    AudioController.instance.playOnlineQueue(list, index);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return Column(
      children: [
        SizedBox(height: widget.topOffset),
        // Live Floating Search Bar (Apple Spotlight Style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _buildSpotlightSearchBar(),
        ),

        // Search Engine Selector Pills (YouTube Music vs JioSaavn HD)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: _buildEngineSelectorPills(),
        ),

        // Main Body Content
        Expanded(
          child: _isSearching
              ? _buildSearchResultsView()
              : _selectedCategory != null
                  ? _buildCategoryView()
                  : _buildBrowseView(),
        ),
      ],
    );
  }

  // --- Search Engine Selector Pills ---
  Widget _buildEngineSelectorPills() {
    final app = AppState.instance;
    final currentEngine = SettingsService.instance.musicEngine;
    final accent = app.accentColor;

    return Row(
      children: [
        Expanded(
          child: _buildEnginePill(
            engine: MusicEngine.youtube,
            label: 'YouTube Music',
            icon: Icons.play_circle_fill_rounded,
            activeColor: const Color(0xFFFF0000),
            isSelected: currentEngine == MusicEngine.youtube,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildEnginePill(
            engine: MusicEngine.jiosaavn,
            label: 'JioSaavn HD',
            icon: Icons.graphic_eq_rounded,
            activeColor: accent,
            isSelected: currentEngine == MusicEngine.jiosaavn,
          ),
        ),
      ],
    );
  }

  Widget _buildEnginePill({
    required MusicEngine engine,
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isSelected,
  }) {
    final isLight = AppState.instance.isLight;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        SettingsService.instance.setMusicEngine(engine);
        if (_searchCtrl.text.trim().isNotEmpty) {
          _onSearchChanged(_searchCtrl.text);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.16)
              : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.6)
                : (isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.09)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : AppState.instance.secondaryTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isLight ? Colors.black : Colors.white)
                    : AppState.instance.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Live Floating Spotlight Search Bar ---
  Widget _buildSpotlightSearchBar() {
    final app = AppState.instance;
    final accent = app.accentColor;
    final engine = SettingsService.instance.musicEngine;

    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      borderColor: _isSearching ? accent.withValues(alpha: 0.6) : null,
      tint: _isSearching ? accent.withValues(alpha: 0.12) : null,
      blur: 0,
      glow: false,
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: _isSearching ? accent : app.secondaryTextColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: TextStyle(color: app.textColor, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: engine == MusicEngine.youtube
                    ? 'Search YouTube Music (Songs, Covers, Artists)...'
                    : app.tr('search_online'),
                hintStyle: TextStyle(
                  color: app.secondaryTextColor.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_loadingSearch) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
            const SizedBox(width: 8),
          ],
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: app.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, color: app.secondaryTextColor, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  // --- Search Results List View ---
  Widget _buildSearchResultsView() {
    final app = AppState.instance;
    if (_loadingSearch && _searchResults.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: app.accentColor,
        ),
      );
    }

    if (!_loadingSearch && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: app.secondaryTextColor.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              'No online songs found',
              style: TextStyle(color: app.textColor, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching for another song, movie or singer.',
              style: TextStyle(color: app.secondaryTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 10, 16, widget.bottomOffset),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OnlineSongTile(
            song: _searchResults[i],
            onTap: () => _playSong(_searchResults, i),
          ),
        );
      },
    );
  }

  // --- Category Specific View (New Hits / Old Is Gold) ---
  Widget _buildCategoryView() {
    final app = AppState.instance;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              LiquidGlassButton(
                icon: Icons.arrow_back_rounded,
                size: 38,
                iconSize: 20,
                onTap: () => setState(() => _selectedCategory = null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedCategory!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: app.textColor,
                  ),
                ),
              ),
              if (_categorySongs.isNotEmpty)
                LiquidGlassButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play All',
                  size: 38,
                  tint: AppState.instance.accentColor,
                  onTap: () => _playSong(_categorySongs, 0),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loadingCategory
              ? Center(
                  child: CircularProgressIndicator(color: AppState.instance.accentColor),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, widget.bottomOffset),
                  itemCount: _categorySongs.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OnlineSongTile(
                        song: _categorySongs[i],
                        onTap: () => _playSong(_categorySongs, i),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Browse Home View ---
  Widget _buildBrowseView() {
    final app = AppState.instance;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 10, 16, widget.bottomOffset),
      children: [
        // 1. Dedicated Singer Folders (Curated Artist Hub - directly below search bar)
        _buildArtistHub(),
        const SizedBox(height: 20),

        // 2. Curated Era Folders (Quick Filters)
        _buildCuratedEraFolders(),
        const SizedBox(height: 18),

        // 3. Dynamic Mood & Regional Playlists (Rajasthani, Bhakti, etc.)
        _buildMoodAndRegionalPlaylists(),
        const SizedBox(height: 22),

        // 4. Top Recommended / Trending Carousel
        _buildTrendingCarousel(),
        const SizedBox(height: 22),

        // 5. Featured Trending Songs List
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.whatshot_rounded, size: 20, color: app.accentColor),
              const SizedBox(width: 8),
              Text(
                'Popular Right Now',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingTrending)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(color: app.accentColor),
            ),
          )
        else
          ..._trendingSongs.take(15).map((song) {
            final idx = _trendingSongs.indexOf(song);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OnlineSongTile(
                song: song,
                onTap: () => _playSong(_trendingSongs, idx),
              ),
            );
          }),
      ],
    );
  }

  // --- 2. Curated Era Folders ---
  Widget _buildCuratedEraFolders() {
    final app = AppState.instance;

    return Row(
      children: [
        Expanded(
          child: PressableScale(
            hapticOnDown: false,
            onTap: () => _openCategory('New Bollywood Hits'),
            child: LiquidGlassContainer(
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              borderColor: const Color(0xFFFF2A85).withValues(alpha: 0.4),
              tint: const Color(0xFFFF2A85).withValues(alpha: 0.12),
              blur: 0,
              glow: false,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF2A85), Color(0xFFFF7043)],
                      ),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Hits',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: app.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Latest Bollywood',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: app.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PressableScale(
            hapticOnDown: false,
            onTap: () => _openCategory('Evergreen Classics'),
            child: LiquidGlassContainer(
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              borderColor: const Color(0xFFFFB300).withValues(alpha: 0.4),
              tint: const Color(0xFFFFB300).withValues(alpha: 0.12),
              blur: 0,
              glow: false,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                      ),
                    ),
                    child: const Icon(Icons.radio_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Old Is Gold',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: app.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '70s-90s Classics',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: app.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Dynamic Mood & Regional Playlists ---
  Widget _buildMoodAndRegionalPlaylists() {
    final app = AppState.instance;
    final categories = SaavnApiService.moodCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Mood & Regional Classics',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final cat = categories[i];
              final c1 = Color(int.parse(cat['color1']!));
              final c2 = Color(int.parse(cat['color2']!));

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: PressableScale(
                  hapticOnDown: false,
                  onTap: () => _openMoodCategory(cat['id']!, cat['title']!),
                  child: Container(
                    width: 170,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          c1.withValues(alpha: 0.35),
                          c2.withValues(alpha: 0.15),
                        ],
                      ),
                      border: Border.all(
                        color: c1.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cat['icon'] ?? '🎵',
                              style: const TextStyle(fontSize: 26),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: app.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: app.isLight ? app.textColor : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat['title']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: app.textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cat['subtitle']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: app.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // --- 3. Top Recommended / Trending Carousel ---
  Widget _buildTrendingCarousel() {
    final app = AppState.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 19, color: app.accentColor),
              const SizedBox(width: 8),
              Text(
                'Top Trending Chartbusters',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: _loadingTrending
              ? Center(child: CircularProgressIndicator(color: app.accentColor))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _trendingSongs.length.clamp(0, 10),
                  itemBuilder: (context, i) {
                    final song = _trendingSongs[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: PressableScale(
                        hapticOnDown: false,
                        onTap: () => _playSong(_trendingSongs, i),
                        child: LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(22),
                          padding: const EdgeInsets.all(10),
                          blur: 0,
                          glow: false,
                          child: SizedBox(
                            width: 130,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: 130,
                                        height: 100,
                                        child: Image.network(
                                          song.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => ColoredBox(
                                            color: app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white10,
                                            child: Icon(Icons.music_note_rounded,
                                                color: app.secondaryTextColor, size: 32),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: app.accentColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: app.accentColor.withValues(alpha: 0.6),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: app.textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => ArtistSongsSheet.show(
                                    context,
                                    artistName: song.artist,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: app.accentColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 8,
                                        color: app.accentColor,
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

  // --- 4. Curated Artist Hub (Singer Folders) ---
  Widget _buildArtistHub() {
    final app = AppState.instance;

    final categories = ['All', 'Modern Hits', '90s Icons', 'Legends', 'Rajasthani & Folk'];
    final currentArtists = _artistCategoryFilter == 'All'
        ? SaavnApiService.curatedArtists
        : SaavnApiService.curatedArtists
            .where((a) => a.category == _artistCategoryFilter)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.stars_rounded, size: 21, color: app.accentColor),
              const SizedBox(width: 8),
              Text(
                'Popular Artists',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: app.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${currentArtists.length} Artists',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: app.accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Category Pills for Artists
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((cat) {
              final active = _artistCategoryFilter == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _artistCategoryFilter = cat),
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    borderColor: active ? app.accentColor : (app.isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white12),
                    tint: active ? app.accentColor.withValues(alpha: 0.22) : null,
                    blur: 0,
                    glow: false,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? app.accentColor : (app.isLight ? app.textColor : Colors.white70),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Long Horizontal scrolling avatars list
        SizedBox(
          height: 114,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: currentArtists.length,
            itemBuilder: (context, i) {
              final artist = currentArtists[i];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: PressableScale(
                  hapticOnDown: false,
                  onTap: () => _openArtistSheet(artist),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: app.accentColor.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: app.accentColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            artist.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: app.accentColor.withValues(alpha: 0.2),
                              child: Icon(Icons.person_rounded,
                                  color: app.secondaryTextColor, size: 38),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 76,
                        child: Text(
                          artist.name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: app.textColor,
                          ),
                        ),
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
}

// --- 5. Online Song Tile Component ---
class _OnlineSongTile extends StatelessWidget {
  const _OnlineSongTile({
    required this.song,
    required this.onTap,
  });

  final OnlineSong song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isFav = app.isFavorite(song.id);

    final currentOnline = AudioController.instance.currentOnlineSong;
    final isCurrent = currentOnline?.id == song.id;

    return PressableScale(
      hapticOnDown: false,
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(8),
        borderColor: isCurrent ? app.accentColor.withValues(alpha: 0.6) : null,
        tint: isCurrent ? app.accentColor.withValues(alpha: 0.12) : null,
        blur: 0,
        glow: true,
        child: Row(
          children: [
            // High-res Album Art
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      song.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: Colors.white12,
                        child: const Icon(Icons.music_note_rounded,
                            color: Colors.white54, size: 28),
                      ),
                    ),
                    if (isCurrent)
                      StreamBuilder<PlayerState>(
                        stream: AudioController.instance.player.playerStateStream,
                        builder: (context, snap) {
                          final playing = snap.data?.playing ?? false;
                          if (!playing) return const SizedBox.shrink();
                          return Container(
                            color: Colors.black45,
                            child: const Center(
                              child: Icon(Icons.equalizer_rounded,
                                  color: Colors.white, size: 26),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Song Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isCurrent ? app.accentColor : app.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ArtistSongsSheet.show(
                      context,
                      artistName: song.artist,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: app.accentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: app.accentColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '320 kbps',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFF00D2FF), fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDuration(song.duration),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: app.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Heart / Favourite button
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFFF2A85) : app.secondaryTextColor.withValues(alpha: 0.5),
                size: 22,
              ),
              onPressed: () => app.toggleFavorite(song.id),
            ),

            // Three-dot Action Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: app.secondaryTextColor, size: 20),
              color: app.isLight ? Colors.white : const Color(0xFF14192B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'play_now') {
                  AudioController.instance.playOnlineQueue([song], 0);
                } else if (val == 'play_next') {
                  AudioController.instance.playOnlineNext(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Playing next: ${song.title}')),
                  );
                } else if (val == 'add_queue') {
                  AudioController.instance.addOnlineToQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to queue: ${song.title}')),
                  );
                } else if (val == 'view_artist') {
                  ArtistSongsSheet.show(context, artistName: song.artist);
                } else if (val == 'add_playlist') {
                  AddToPlaylistDialog.showForOnline(context, song);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'play_now',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, color: app.secondaryTextColor, size: 20),
                      const SizedBox(width: 10),
                      Text('Play Now', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_play_rounded, color: app.secondaryTextColor, size: 20),
                      const SizedBox(width: 10),
                      Text('Play Next', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, color: app.secondaryTextColor, size: 20),
                      const SizedBox(width: 10),
                      Text('Add to Queue', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
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
                  value: 'add_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: app.secondaryTextColor, size: 20),
                      const SizedBox(width: 10),
                      Text('Add to Custom Playlist', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
