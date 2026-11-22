import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import '../screens/audio_player_screen.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/saavn_api_service.dart';
import '../services/yt_music_service.dart';
import '../utils/format.dart';
import 'add_to_playlist_dialog.dart';
import 'liquid_glass_container.dart';
import 'youtube_music_sheet.dart';

class ArtistSongsSheet extends StatefulWidget {
  final String artistName;
  final String? avatarUrl;
  final String? subtitle;
  final BitArtist? artist;

  const ArtistSongsSheet({
    super.key,
    required this.artistName,
    this.avatarUrl,
    this.subtitle,
    this.artist,
  });

  static Future<void> show(
    BuildContext context, {
    required String artistName,
    String? avatarUrl,
    String? subtitle,
    BitArtist? artist,
  }) {
    final cleanArtistName = artistName.contains(',')
        ? artistName.split(',').first.trim()
        : (artistName.contains('&') ? artistName.split('&').first.trim() : artistName.trim());

    final matched = artist ?? YtMusicService.findCuratedArtist(cleanArtistName);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArtistSongsSheet(
        artistName: cleanArtistName.isNotEmpty ? cleanArtistName : artistName,
        avatarUrl: avatarUrl ?? matched?.avatarUrl,
        subtitle: subtitle ?? matched?.subtitle,
        artist: matched,
      ),
    );
  }

  @override
  State<ArtistSongsSheet> createState() => _ArtistSongsSheetState();
}

class _ArtistSongsSheetState extends State<ArtistSongsSheet> {
  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  final List<OnlineSong> _allSongs = [];
  List<OnlineSong> _displaySongs = [];

  String? _fallbackAvatarUrl;
  String? _resolvingSongId;

  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearchOpen = false;
  int _filterSource = 0; // 0 = All, 1 = Studio 320k (JioSaavn), 2 = YouTube

  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _normalizeTitle(String title) {
    var t = title.toLowerCase();
    t = t.replaceAll(RegExp(r'\(from\s+.*?\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\b(full|video|song|lyrical|official|audio|remix|hd|4k)\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'[^\w\s]'), '');
    return t.trim();
  }

  void _onFilterChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = List<OnlineSong>.from(_allSongs);

    if (_filterSource == 1) {
      list = list.where((s) => !s.id.startsWith('yt_')).toList();
    } else if (_filterSource == 2) {
      list = list.where((s) => s.id.startsWith('yt_')).toList();
    }

    if (query.isNotEmpty) {
      list = list.where((s) {
        return s.title.toLowerCase().contains(query) ||
            s.artist.toLowerCase().contains(query) ||
            s.album.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _displaySongs = list;
    });
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final cleanName = widget.artistName.trim();

    try {
      // 1. Fetch comprehensive catalog from JioSaavn (Studio 320k) and YouTube Music in parallel
      final futures = await Future.wait([
        SaavnApiService.instance.getArtistSongs(cleanName, page: 1, limit: 250),
        YtMusicService.instance.getArtistSongs(cleanName, limit: 120),
      ]);

      final saavnSongs = futures[0];
      final ytSongs = futures[1];

      final seenIds = <String>{};
      final seenTitles = <String>{};
      final merged = <OnlineSong>[];

      // JioSaavn studio tracks first
      for (final s in saavnSongs) {
        if (!seenIds.add(s.id)) continue;
        final norm = _normalizeTitle(s.title);
        if (norm.isNotEmpty && !seenTitles.add(norm)) continue;
        merged.add(s);
      }

      // YouTube Music tracks (live, rare, unplugged, jukebox)
      for (final s in ytSongs) {
        if (!seenIds.add(s.id)) continue;
        final norm = _normalizeTitle(s.title);
        if (norm.isNotEmpty && !seenTitles.add(norm)) continue;
        merged.add(s);
      }

      if (mounted) {
        setState(() {
          _allSongs.clear();
          _allSongs.addAll(merged);
          _loading = false;
          _currentPage = 1;
          _hasMore = saavnSongs.length >= 35;
          if (widget.avatarUrl == null && merged.isNotEmpty) {
            _fallbackAvatarUrl = merged.first.imageUrl;
          }
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final cleanName = widget.artistName.trim();
      final nextPage = _currentPage + 1;

      final moreSongs = await SaavnApiService.instance.getArtistSongs(
        cleanName,
        page: nextPage,
        limit: 80,
      );

      if (moreSongs.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        }
        return;
      }

      final seenIds = _allSongs.map((s) => s.id).toSet();
      final seenTitles = _allSongs.map((s) => _normalizeTitle(s.title)).toSet();
      final additional = <OnlineSong>[];

      for (final s in moreSongs) {
        if (!seenIds.add(s.id)) continue;
        final norm = _normalizeTitle(s.title);
        if (norm.isNotEmpty && !seenTitles.add(norm)) continue;
        additional.add(s);
      }

      if (mounted) {
        setState(() {
          _allSongs.addAll(additional);
          _currentPage = nextPage;
          _isLoadingMore = false;
          if (additional.isEmpty || moreSongs.length < 20) {
            _hasMore = false;
          }
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _playSong(int index) async {
    if (_displaySongs.isEmpty || index < 0 || index >= _displaySongs.length) return;
    final selected = _displaySongs[index];
    if (_resolvingSongId == selected.id) return;
    setState(() => _resolvingSongId = selected.id);
    HapticFeedback.lightImpact();

    final err = await AudioController.instance.playOnlineQueue(_displaySongs, index);
    if (!mounted) return;
    if (_resolvingSongId == selected.id) {
      setState(() => _resolvingSongId = null);
    }
    if (err == AudioController.playbackCancelledToken || (err != null && err.toLowerCase().contains('cancel'))) return;

    if (err != null) {
      final isYt = selected.id.startsWith('yt_');
      final cleanMsg = err.contains('__exhausted__') || err.length > 60
          ? 'Could not stream audio. Tap to retry.'
          : err;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanMsg),
          behavior: SnackBarBehavior.floating,
          action: isYt
              ? SnackBarAction(
                  label: 'Play Web',
                  onPressed: () {
                    if (!mounted) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => YouTubeMusicSheet(song: selected),
                    );
                  },
                )
              : SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _playSong(index),
                ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
    );
  }

  Future<void> _playAll({bool shuffle = false}) async {
    if (_displaySongs.isEmpty) return;
    final list = List<OnlineSong>.from(_displaySongs);
    if (shuffle) list.shuffle();
    final first = list.first;
    if (_resolvingSongId == first.id) return;
    setState(() => _resolvingSongId = first.id);
    HapticFeedback.lightImpact();

    final err = await AudioController.instance.playOnlineQueue(list, 0, shuffle: shuffle);
    if (!mounted) return;
    if (_resolvingSongId == first.id) {
      setState(() => _resolvingSongId = null);
    }
    if (err == AudioController.playbackCancelledToken || (err != null && err.toLowerCase().contains('cancel'))) return;

    if (err != null) {
      final isYt = first.id.startsWith('yt_');
      final cleanMsg = err.contains('__exhausted__') || err.length > 60
          ? 'Could not stream playlist. Tap to retry.'
          : err;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanMsg),
          behavior: SnackBarBehavior.floating,
          action: isYt
              ? SnackBarAction(
                  label: 'Play Web',
                  onPressed: () {
                    if (!mounted) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => YouTubeMusicSheet(song: first),
                    );
                  },
                )
              : SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _playAll(shuffle: shuffle),
                ),
        ),
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

    final avatar = widget.avatarUrl ?? _fallbackAvatarUrl;
    final saavnCount = _allSongs.where((s) => !s.id.startsWith('yt_')).length;
    final ytCount = _allSongs.where((s) => s.id.startsWith('yt_')).length;

    return LiquidGlassContainer(
      height: MediaQuery.of(context).size.height * 0.90,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      blur: 28,
      tint: isLight ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF14192B),
      borderColor: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white24,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isLight ? Colors.black26 : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header Bar with Back/Close, Title & Search toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_downward_rounded, color: textColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Artist Hub / सम्पूर्ण कलाकार संग्रह',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                // Search toggle button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isSearchOpen = !_isSearchOpen;
                      if (!_isSearchOpen) {
                        _searchCtrl.clear();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _isSearchOpen
                          ? accent.withValues(alpha: 0.18)
                          : (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isSearchOpen ? accent : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                      color: _isSearchOpen ? accent : textColor,
                      size: 19,
                    ),
                  ),
                ),
                // Track Count Badge
                if (_allSongs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${_allSongs.length}+ Tracks',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // In-Sheet Live Search Bar (if opened)
          if (_isSearchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white24,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 13.5),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: accent, size: 18),
                    hintText: 'Search songs by ${widget.artistName}...',
                    hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),

          // Artist Profile Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatar != null && avatar.isNotEmpty
                        ? Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackAvatar(accent),
                          )
                        : _buildFallbackAvatar(accent),
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: Color(0xFF00D2FF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Full Discography • Complete Songs Catalog',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Source Filter Pills (All, Studio 320k, YouTube)
          if (!_loading && _allSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  _buildFilterChip('All (${_allSongs.length})', 0, isLight, textColor, secondaryTextColor, accent),
                  const SizedBox(width: 6),
                  if (saavnCount > 0)
                    _buildFilterChip('Studio ($saavnCount)', 1, isLight, textColor, secondaryTextColor, accent),
                  const SizedBox(width: 6),
                  if (ytCount > 0)
                    _buildFilterChip('YouTube ($ytCount)', 2, isLight, textColor, secondaryTextColor, accent),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Play All & Shuffle Buttons
          if (!_loading && _displaySongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: PressableScale(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _playAll(shuffle: false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'Play All (${_displaySongs.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PressableScale(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _playAll(shuffle: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shuffle_rounded, color: textColor, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Shuffle',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
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

          const SizedBox(height: 10),
          Divider(color: isLight ? Colors.black12 : Colors.white12, height: 1),

          // Songs List with Load More Button
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: accent),
                        const SizedBox(height: 14),
                        Text(
                          'Loading full discography for ${widget.artistName}...',
                          style: TextStyle(color: secondaryTextColor, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : _displaySongs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_off_rounded, size: 48, color: secondaryTextColor.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                _searchCtrl.text.isNotEmpty
                                    ? 'No tracks matching "${_searchCtrl.text}"'
                                    : 'No songs found for this artist',
                                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchCtrl.text.isNotEmpty
                                    ? 'Try checking for typos or searching a different keyword.'
                                    : 'Check your network connection or try searching another singer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: secondaryTextColor, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                        itemCount: _displaySongs.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _displaySongs.length) {
                            // Load More Button
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: _isLoadingMore
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2.2, color: accent),
                                      )
                                    : TextButton.icon(
                                        onPressed: _loadMore,
                                        icon: Icon(Icons.expand_more_rounded, color: accent, size: 20),
                                        label: Text(
                                          'Load More Songs / और गाने लोड करें (${_allSongs.length} Loaded)',
                                          style: TextStyle(
                                            color: accent,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          backgroundColor: accent.withValues(alpha: 0.12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: accent.withValues(alpha: 0.3)),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          }

                          final song = _displaySongs[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ArtistSongTile(
                              song: song,
                              isResolving: _resolvingSongId == song.id,
                              onTap: () => _playSong(i),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    int index,
    bool isLight,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
  ) {
    final active = _filterSource == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterSource = index);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.20)
              : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? accent : secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          widget.artistName.isNotEmpty ? widget.artistName[0].toUpperCase() : 'A',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent),
        ),
      ),
    );
  }
}

class _ArtistSongTile extends StatelessWidget {
  final OnlineSong song;
  final VoidCallback onTap;
  final bool isResolving;

  const _ArtistSongTile({
    required this.song,
    required this.onTap,
    this.isResolving = false,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isFav = app.isFavorite(song.id);
    final accent = app.accentColor;

    return PressableScale(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        blur: 0,
        child: Row(
          children: [
            // Thumbnail with loading indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(
                            song.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: accent.withValues(alpha: 0.2),
                              child: Icon(Icons.music_note_rounded, color: accent),
                            ),
                          )
                        : Container(
                            color: accent.withValues(alpha: 0.2),
                            child: Icon(Icons.music_note_rounded, color: accent),
                          ),
                  ),
                  if (isResolving)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Song Title & Artist Info
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
                      color: app.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: song.id.startsWith('yt_')
                              ? const Color(0xFFFF0000).withValues(alpha: 0.18)
                              : const Color(0xFF10B981).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          song.id.startsWith('yt_') ? 'YT' : '320k',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: song.id.startsWith('yt_') ? const Color(0xFFFF4D4D) : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          song.album.isNotEmpty ? song.album : (song.artist.isNotEmpty ? song.artist : 'RV Bhati Player'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: app.secondaryTextColor,
                          ),
                        ),
                      ),
                      if (song.duration.inSeconds > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatDuration(song.duration),
                          style: TextStyle(
                            fontSize: 11,
                            color: app.secondaryTextColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Download Offline button
            ListenableBuilder(
              listenable: DownloadService.instance,
              builder: (context, _) {
                final isDl = DownloadService.instance.isDownloaded(song.id);
                final isDownloading = DownloadService.instance.isDownloading(song.id);

                return IconButton(
                  icon: isDownloading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                      : Icon(
                          isDl ? Icons.download_done_rounded : Icons.download_rounded,
                          color: isDl ? const Color(0xFF10B981) : app.secondaryTextColor,
                          size: 20,
                        ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (!isDl && !isDownloading) {
                      DownloadService.instance.downloadSong(song);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloading "${song.title}"...'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else if (isDl) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${song.title}" is saved offline.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),

            // Favourite button
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFFF2A85) : app.secondaryTextColor.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () => app.toggleFavorite(song.id, item: PlaylistItem.fromOnlineSong(song)),
            ),

            // Three-dot menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: app.secondaryTextColor, size: 18),
              color: app.isLight ? Colors.white : const Color(0xFF14192B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'play_now') {
                  onTap();
                } else if (val == 'download') {
                  DownloadService.instance.downloadSong(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading "${song.title}"...')),
                  );
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
                } else if (val == 'add_playlist') {
                  AddToPlaylistDialog.showForOnline(context, song);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'play_now',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Play Now', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Download Offline', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_play_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Play Next', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Add to Queue', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Add to Playlist', style: TextStyle(color: app.textColor)),
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
