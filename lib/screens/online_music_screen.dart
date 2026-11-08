import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/online_song.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/saavn_api_service.dart';
import '../utils/format.dart';
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

  String _artistCategoryFilter = 'Modern Hits'; // 'Modern Hits', '90s Icons', 'Legends'

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
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
      final results = await SaavnApiService.instance.searchSongs(clean);
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

  void _openArtistSheet(SaavnArtist artist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ArtistSongsSheet(artist: artist);
      },
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

  // --- 1. Live Floating Spotlight Search Bar ---
  Widget _buildSpotlightSearchBar() {
    final accent = AppState.instance.accentColor;

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
            color: _isSearching ? accent : Colors.white60,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: AppState.instance.tr('search_online'),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
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
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  // --- Search Results List View ---
  Widget _buildSearchResultsView() {
    if (_loadingSearch && _searchResults.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: AppState.instance.accentColor,
        ),
      );
    }

    if (!_loadingSearch && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'No online songs found',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching for another song, movie or singer.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
        // 2. Curated Era Folders (Quick Filters)
        _buildCuratedEraFolders(),
        const SizedBox(height: 20),

        // 3. Top Recommended / Trending Carousel
        _buildTrendingCarousel(),
        const SizedBox(height: 22),

        // 4. Dedicated Singer Folders (Curated Artist Hub)
        _buildArtistHub(),
        const SizedBox(height: 22),

        // 5. Featured Trending Songs List
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.whatshot_rounded, size: 20, color: app.accentColor),
              const SizedBox(width: 8),
              const Text(
                'Popular Right Now',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
    final accent = AppState.instance.accentColor;

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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
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
                        const Text(
                          'New Hits',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Latest Bollywood',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
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
                        const Text(
                          'Old Is Gold',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '70s-90s Classics',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
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
              const Text(
                'Top Trending Chartbusters',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                                            color: Colors.white10,
                                            child: const Icon(Icons.music_note_rounded,
                                                color: Colors.white54, size: 32),
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.6),
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

    final categories = ['Modern Hits', '90s Icons', 'Legends'];
    final currentArtists = SaavnApiService.curatedArtists
        .where((a) => a.category == _artistCategoryFilter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.mic_external_on_rounded, size: 20, color: app.accentColor),
              const SizedBox(width: 8),
              const Text(
                'Curated Singer Hub',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Category Pills for Artists
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
                    borderColor: active ? app.accentColor : Colors.white12,
                    tint: active ? app.accentColor.withValues(alpha: 0.22) : null,
                    blur: 0,
                    glow: false,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? app.accentColor : Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal avatars
        SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
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
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: app.accentColor.withValues(alpha: 0.5),
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
                              child: const Icon(Icons.person_rounded,
                                  color: Colors.white70, size: 36),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 74,
                        child: Text(
                          artist.name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
        glow: false,
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
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? app.accentColor : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '320 kbps',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFF00D2FF), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDuration(song.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
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
                color: isFav ? const Color(0xFFFF2A85) : Colors.white38,
                size: 22,
              ),
              onPressed: () => app.toggleFavorite(song.id),
            ),

            // Three-dot Action Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
              color: const Color(0xFF14192B),
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
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'play_now',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Text('Play Now', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_play_rounded, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Text('Play Next', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Text('Add to Queue', style: TextStyle(color: Colors.white)),
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

// --- Dynamic Modal Sheet for Singer Catalog ---
class _ArtistSongsSheet extends StatefulWidget {
  const _ArtistSongsSheet({required this.artist});
  final SaavnArtist artist;

  @override
  State<_ArtistSongsSheet> createState() => _ArtistSongsSheetState();
}

class _ArtistSongsSheetState extends State<_ArtistSongsSheet> {
  bool _loading = true;
  List<OnlineSong> _songs = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final songs = await SaavnApiService.instance.getArtistSongs(widget.artist.name);
    if (mounted) {
      setState(() {
        _songs = songs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppState.instance.accentColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1224),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Artist Header Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      widget.artist.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.artist.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.artist.subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_songs.isNotEmpty)
                  LiquidGlassButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play All',
                    size: 40,
                    tint: accent,
                    onTap: () {
                      Navigator.pop(context);
                      AudioController.instance.playOnlineQueue(_songs, 0);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),

          // Songs List
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: accent))
                : _songs.isEmpty
                    ? const Center(
                        child: Text('No songs found for this artist',
                            style: TextStyle(color: Colors.white60)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                        itemCount: _songs.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _OnlineSongTile(
                              song: _songs[i],
                              onTap: () {
                                Navigator.pop(context);
                                AudioController.instance.playOnlineQueue(_songs, i);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
