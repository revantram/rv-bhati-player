import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/online_song.dart';
import '../models/playlist_item.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/saavn_api_service.dart';
import '../services/settings_service.dart';
import '../services/spotify_service.dart';
import '../services/yt_music_service.dart';
import '../utils/format.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/ios_bounce_button.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/youtube_music_sheet.dart';
import '../widgets/jiosaavn_login_sheet.dart';
import '../services/jiosaavn_auth_service.dart';
import 'artists_hub_screen.dart';
import 'audio_player_screen.dart';
import 'downloads_screen.dart';
import 'liked_songs_screen.dart';
import 'local_storage_music_screen.dart';
import 'playlists_manager_screen.dart';
import 'settings_screen.dart';
import 'shows_hub_screen.dart';

/// BitMusic Tab:
/// Powered by YouTube Music InnerTube + Piped/Invidious fallback + LRCLIB Synced Lyrics,
/// styled with BitChord's Apple Music aesthetic.
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
  bool _isLoadingResults = false;
  List<OnlineSong> _searchResults = [];
  List<String> _suggestions = [];

  bool _isLoadingTrending = true;
  List<OnlineSong> _trendingSongs = [];

  String? _customDisplayTitle;
  bool _isLoadingCustomSongs = false;
  List<OnlineSong>? _customSongs;
  String? _resolvingSongId;

  AppState get app => AppState.instance;

  static const List<Map<String, String>> _bitMoods = [
    {'title': '🔥 Trending', 'query': 'Trending YouTube India'},
    {'title': '📼 90s Gold', 'query': '90s Bollywood Evergreen Hits'},
    {'title': '❤️ Romantic', 'query': 'Romantic Hindi Songs 2025'},
    {'title': '🏜️ Rajasthani DJ', 'query': 'Rajasthani & Marwadi DJ'},
    {'title': '🙏 Desi Bhajan', 'query': 'Desi Bhajan & Aarti'},
    {'title': '⚡ Punjabi 101', 'query': 'Punjabi Top Hits 2025'},
    {'title': '🎧 Lo-Fi Chill', 'query': 'Lo-Fi Hindi Chill Beats'},
    {'title': '🌍 Global Hits', 'query': 'Top Global Pop Hits 2025'},
    {'title': '💪 Workout', 'query': 'Hindi Gym Workout Pump Songs'},
    {'title': '💔 Sad Vibes', 'query': 'Sad Hindi Songs Heartbreak'},
  ];

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

  MusicEngine get _engine => SettingsService.instance.musicEngine;

  Future<void> _loadTrending({bool force = false}) async {
    setState(() => _isLoadingTrending = true);
    List<OnlineSong> songs;
    if (_engine == MusicEngine.spotify) {
      songs = await SpotifyService.instance.getTrendingSongs();
    } else {
      songs = await SaavnApiService.instance.getTrendingSongs(forceRefresh: force);
    }
    if (mounted) {
      setState(() {
        _trendingSongs = songs;
        _isLoadingTrending = false;
      });
    }
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _isSearching = false;
        _isLoadingResults = false;
        _searchResults = [];
        _suggestions = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _isLoadingResults = true;
    });
    _debounce = Timer(const Duration(milliseconds: 380), () async {
      List<OnlineSong> songs;
      if (_engine == MusicEngine.spotify) {
        songs = await SpotifyService.instance.search(clean);
      } else {
        songs = await SaavnApiService.instance.searchSongs(clean);
      }
      if (mounted && _searchCtrl.text.trim() == clean) {
        setState(() {
          _searchResults = songs;
          _suggestions = [];
          _isLoadingResults = false;
        });
      }
    });
  }

  Future<void> _loadSongsByQuery(String query, String displayTitle) async {
    setState(() {
      _customDisplayTitle = displayTitle;
      _isLoadingCustomSongs = true;
      _customSongs = [];
    });
    List<OnlineSong> songs;
    if (_engine == MusicEngine.spotify) {
      songs = await SpotifyService.instance.search(query);
    } else {
      songs = await SaavnApiService.instance.searchSongs(query, limit: 100);
    }
    if (mounted) {
      setState(() {
        _customSongs = songs;
        _isLoadingCustomSongs = false;
      });
    }
  }

  void _resetToPopular() {
    setState(() {
      _customDisplayTitle = null;
      _customSongs = null;
      _isLoadingCustomSongs = false;
    });
  }

  Future<void> _playSong(List<OnlineSong> list, int index) async {
    if (index < 0 || index >= list.length) return;
    final selected = list[index];
    if (_resolvingSongId == selected.id) return;
    setState(() => _resolvingSongId = selected.id);
    HapticFeedback.lightImpact();

    final error = await AudioController.instance.playOnlineQueue(list, index);
    if (!mounted) return;
    if (_resolvingSongId == selected.id) {
      setState(() => _resolvingSongId = null);
    }
    if (error == AudioController.playbackCancelledToken) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
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
    final accent = _engine == MusicEngine.spotify
        ? const Color(0xFF1DB954)
        : const Color(0xFF10B981);

    return Column(
      children: [
        SizedBox(height: widget.topOffset),
        _buildBitMusicHeader(accent),
        _buildExtensionSelector(accent),
        _buildJioSaavnAccountBar(accent),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildSearchBar(accent),
        ),
        if (_isSearching && _suggestions.isNotEmpty) _buildSuggestionChips(accent),
        Expanded(
          child: _isSearching
              ? _buildSongList(
                  _searchResults,
                  _isLoadingResults,
                  _engine == MusicEngine.spotify
                      ? 'No songs found on Spotify'
                      : 'No songs found on JioSaavn HD',
                  accent,
                )
              : _buildHomeView(accent),
        ),
      ],
    );
  }

  Widget _buildBitMusicHeader(Color accent) {
    final isSpotify = _engine == MusicEngine.spotify;
    final title = isSpotify ? 'Spotify Music' : 'JioSaavn HD';
    final subtitle = isSpotify ? 'Top Charts, Playlists & Viral Hits' : '320kbps Studio Audio • Lossless FLAC';
    final icon = isSpotify ? Icons.graphic_eq_rounded : Icons.music_note_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  accent.withValues(alpha: 0.72),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: app.textColor,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: app.secondaryTextColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: app.secondaryTextColor, size: 21),
            tooltip: 'Refresh Feed',
            onPressed: () => _loadTrending(force: true),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: app.secondaryTextColor, size: 21),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJioSaavnAccountBar(Color accent) {
    final auth = JioSaavnAuthService.instance;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isLoggedIn) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => JioSaavnLoginSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2EA043).withValues(alpha: 0.18),
                      const Color(0xFF238636).withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2EA043).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2EA043).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_android_rounded, color: Color(0xFF2EA043), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'JioSaavn Mobile Login (OTP)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Sync Liked Songs & Playlists • 100% Ad-Free',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2EA043), Color(0xFF238636)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2EA043).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2EA043).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2EA043),
                  backgroundImage: (auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty)
                      ? NetworkImage(auth.avatarUrl!)
                      : null,
                  child: (auth.avatarUrl == null || auth.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person_rounded, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              auth.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF2EA043), size: 13),
                        ],
                      ),
                      Text(
                        auth.isSyncing
                            ? 'Syncing library...'
                            : (auth.lastSyncMessage ?? 'JioSaavn Synced (Ad-Free)'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: auth.isSyncing
                              ? const Color(0xFF2EA043)
                              : Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                if (auth.isSyncing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2EA043)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF2EA043)),
                    tooltip: 'Sync Playlists & Liked Songs',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => auth.syncUserLibrary(),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.logout_rounded, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                  tooltip: 'Logout JioSaavn',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => auth.logout(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtensionSelector(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: app.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: app.cardBorderColor,
          ),
        ),
        child: Row(
          children: MusicEngine.values.map((eng) {
            final isSel = _engine == eng;
            Color col;
            IconData ic;
            if (eng == MusicEngine.spotify) {
              col = const Color(0xFF1DB954);
              ic = Icons.graphic_eq_rounded;
            } else {
              col = const Color(0xFF10B981);
              ic = Icons.music_note_rounded;
            }

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_engine != eng) {
                    HapticFeedback.selectionClick();
                    SettingsService.instance.setMusicEngine(eng);
                    setState(() {
                      _searchCtrl.clear();
                      _isSearching = false;
                      _searchResults = [];
                      _suggestions = [];
                      _customDisplayTitle = null;
                      _customSongs = null;
                    });
                    _loadTrending(force: true);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel ? col : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: col.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(ic, size: 14, color: isSel ? Colors.white : app.secondaryTextColor),
                      const SizedBox(width: 5),
                      Text(
                        eng.shortName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? Colors.white : app.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color accent) {
    String hint = _engine == MusicEngine.spotify
        ? 'Spotify Top Hits, Playlist ya gaana khojein...'
        : 'JioSaavn 320kbps HD gane ya gayak khojein...';

    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(18),
      blur: 0,
      glow: false,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        onSubmitted: _onSearch,
        style: TextStyle(color: app.textColor, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: app.secondaryTextColor, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded, color: accent, size: 21),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: app.secondaryTextColor, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(Color accent) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = _suggestions[i];
          return GestureDetector(
            onTap: () {
              _searchCtrl.text = s;
              _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: s.length));
              _onSearch(s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: app.surfaceColorSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: app.cardBorderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.north_west_rounded, size: 13, color: accent),
                  const SizedBox(width: 5),
                  Text(
                    s,
                    style: TextStyle(
                      color: app.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeView(Color accent) {
    return RefreshIndicator(
      color: accent,
      onRefresh: () => _loadTrending(force: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, math.max(165.0, widget.bottomOffset)),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. BitChord Library Quick Hub (6 Tiles in 2 rows of horizontal cards or 3-column chips)
          _buildQuickHubGrid(accent),
          const SizedBox(height: 16),

          // 2. Mood & Genre Explorer Strip
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _bitMoods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = _bitMoods[i];
                final active = _customDisplayTitle == m['title'];
                return iOSBounceButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (active) {
                      _resetToPopular();
                    } else {
                      _loadSongsByQuery(m['query']!, m['title']!);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? accent : app.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? accent : app.cardBorderColor,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        m['title']!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                          color: active ? Colors.white : app.textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // 3. Curated Indian & Rajasthani Artists Row
          _buildArtistsSection(accent),
          const SizedBox(height: 18),

          if (_engine == MusicEngine.spotify) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'SPOTIFY FEATURED PLAYLISTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: app.secondaryTextColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.whatshot_rounded,
                    title: "Today's Top Hits",
                    subtitle: 'Spotify Global',
                    accent: const Color(0xFF1DB954),
                    onTap: () async {
                      setState(() {
                        _customDisplayTitle = "🔥 Today's Top Hits (Spotify)";
                        _isLoadingCustomSongs = true;
                        _customSongs = [];
                      });
                      final songs = await SpotifyService.instance.getSpotifyPlaylist('top_hits');
                      if (mounted) setState(() { _customSongs = songs; _isLoadingCustomSongs = false; });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.music_note_rounded,
                    title: 'Hot Hits Hindi',
                    subtitle: 'Spotify India',
                    accent: const Color(0xFFFF416C),
                    onTap: () async {
                      setState(() {
                        _customDisplayTitle = '🇮🇳 Hot Hits Hindi (Spotify)';
                        _isLoadingCustomSongs = true;
                        _customSongs = [];
                      });
                      final songs = await SpotifyService.instance.getSpotifyPlaylist('india_50');
                      if (mounted) setState(() { _customSongs = songs; _isLoadingCustomSongs = false; });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.rocket_launch_rounded,
                    title: 'Viral Hits India',
                    subtitle: 'Trending Reels',
                    accent: const Color(0xFF8E2DE2),
                    onTap: () async {
                      setState(() {
                        _customDisplayTitle = '🚀 Viral Hits India (Spotify)';
                        _isLoadingCustomSongs = true;
                        _customSongs = [];
                      });
                      final songs = await SpotifyService.instance.getSpotifyPlaylist('viral_50');
                      if (mounted) setState(() { _customSongs = songs; _isLoadingCustomSongs = false; });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.bolt_rounded,
                    title: 'Punjabi 101',
                    subtitle: 'Sidhu & Karan Aujla',
                    accent: const Color(0xFFF7971E),
                    onTap: () async {
                      setState(() {
                        _customDisplayTitle = '⚡ Punjabi 101 (Spotify)';
                        _isLoadingCustomSongs = true;
                        _customSongs = [];
                      });
                      final songs = await SpotifyService.instance.getSpotifyPlaylist('punjabi_100');
                      if (mounted) setState(() { _customSongs = songs; _isLoadingCustomSongs = false; });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // 4. Discover / Selected Mix Header
          Row(
            children: [
              Icon(
                _customSongs != null ? Icons.album_rounded : Icons.whatshot_rounded,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _customDisplayTitle ??
                      (_engine == MusicEngine.spotify
                          ? '🔥 Spotify Top Charts & Viral Hits'
                          : '🔥 Popular Right Now (JioSaavn HD)'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: app.textColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (_customSongs != null)
                TextButton.icon(
                  onPressed: _resetToPopular,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Trending', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 5. Songs List
          if (_isLoadingCustomSongs || (_customSongs == null && _isLoadingTrending))
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: accent)),
            )
          else if (_customSongs != null)
            _customSongs!.isEmpty
                ? _buildEmptyState('No tracks found for $_customDisplayTitle', accent)
                : Column(
                    children: [
                      for (int i = 0; i < _customSongs!.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BitMusicSongTile(
                            song: _customSongs![i],
                            accent: accent,
                            isResolving: _resolvingSongId == _customSongs![i].id,
                            onTap: () => _playSong(_customSongs!, i),
                          ),
                        ),
                    ],
                  )
          else if (_trendingSongs.isEmpty)
            _buildEmptyState('Check internet connection or pull to refresh', accent)
          else
            Column(
              children: [
                for (int i = 0; i < _trendingSongs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BitMusicSongTile(
                      song: _trendingSongs[i],
                      accent: accent,
                      isResolving: _resolvingSongId == _trendingSongs[i].id,
                      onTap: () => _playSong(_trendingSongs, i),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickHubGrid(Color accent) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.library_music_rounded,
                title: 'Local Audio',
                subtitle: 'Device MP3 & FLAC',
                accent: accent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LocalStorageMusicScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ListenableBuilder(
                listenable: app,
                builder: (_, __) => _buildActionCard(
                  icon: Icons.favorite_rounded,
                  title: 'Liked Songs',
                  subtitle: '${app.favorites.length} Favorites',
                  accent: const Color(0xFFFA2D48),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.podcasts_rounded,
                title: 'Shows & Osho',
                subtitle: 'Desi FM & Aawaz',
                accent: const Color(0xFFFF9F0A),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShowsHubScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.queue_music_rounded,
                title: 'Playlists & Offline',
                subtitle: '${DownloadService.instance.downloadedSongs.length} Saved',
                accent: const Color(0xFF00D2FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.playlist_play_rounded, color: accent, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'My Playlists',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlaylistsManagerScreen()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return iOSBounceButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        blur: 0,
        glow: false,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: app.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildArtistsSection(Color accent) {
    final artists = YtMusicService.curatedArtists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Singers & Artists',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: app.textColor,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArtistsHubScreen()),
              ),
              child: Text(
                'See All →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artists.length,
            itemBuilder: (context, i) {
              final a = artists[i];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => ArtistSongsSheet.show(
                    context,
                    artist: a,
                    artistName: a.name,
                    avatarUrl: a.avatarUrl,
                    subtitle: a.subtitle,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.55),
                            width: 1.8,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            a.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: accent.withValues(alpha: 0.14),
                              child: Icon(Icons.person_rounded, size: 30, color: accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 72,
                        child: Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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

  Widget _buildSongList(
    List<OnlineSong> songs,
    bool loading,
    String emptyMsg,
    Color accent,
  ) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }
    if (songs.isEmpty) {
      return _buildEmptyState(emptyMsg, accent);
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 6, 16, math.max(165.0, widget.bottomOffset)),
      itemCount: songs.length,
      itemBuilder: (context, idx) {
        final song = songs[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BitMusicSongTile(
            song: song,
            accent: accent,
            isResolving: _resolvingSongId == song.id,
            onTap: () => _playSong(songs, idx),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String msg, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_rounded, size: 44, color: accent.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: app.secondaryTextColor, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BitMusicSongTile extends StatelessWidget {
  const _BitMusicSongTile({
    required this.song,
    required this.accent,
    required this.onTap,
    this.isResolving = false,
  });

  final OnlineSong song;
  final Color accent;
  final VoidCallback onTap;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isFav = app.isFavorite(song.id);

    return iOSBounceButton(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        blur: 0,
        glow: false,
        child: Row(
          children: [
            // Rounded Apple Music Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    song.imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 54,
                      height: 54,
                      color: accent.withValues(alpha: 0.16),
                      child: Icon(Icons.music_note_rounded, color: accent, size: 24),
                    ),
                  ),
                  if (isResolving)
                    Container(
                      width: 54,
                      height: 54,
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Title & Artist Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: app.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          SettingsService.instance.musicEngine == MusicEngine.spotify
                              ? 'Spotify'
                              : '320 kbps HD',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDuration(song.duration),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: app.secondaryTextColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            ExcludeFocus(
              excluding: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Download action
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                              )
                            : Icon(
                                isDl ? Icons.download_done_rounded : Icons.download_rounded,
                                color: isDl
                                    ? const Color(0xFF00D084)
                                    : app.secondaryTextColor.withValues(alpha: 0.6),
                                size: 20,
                              ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (!isDl && !isDownloading) {
                            DownloadService.instance.downloadSong(song);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Downloading "${song.title}"...')),
                            );
                          }
                        },
                      );
                    },
                  ),

                  // Favorite toggle
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav
                          ? const Color(0xFFFA2D48)
                          : app.secondaryTextColor.withValues(alpha: 0.5),
                      size: 21,
                    ),
                    onPressed: () =>
                        app.toggleFavorite(song.id, item: PlaylistItem.fromOnlineSong(song)),
                  ),

                  // More Menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: app.secondaryTextColor, size: 20),
                    color: app.surfaceColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (val) {
                      if (val == 'play_now') {
                        onTap();
                      } else if (val == 'download') {
                        DownloadService.instance.downloadSong(song);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading Audio "${song.title}"...')),
                        );
                      } else if (val == 'download_video') {
                        DownloadService.instance.downloadVideo(song);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading Video "${song.title}"...')),
                        );
                      } else if (val == 'play_next') {
                        AudioController.instance.playOnlineNext(song);
                      } else if (val == 'add_queue') {
                        AudioController.instance.addOnlineToQueue(song);
                      } else if (val == 'add_playlist') {
                        AddToPlaylistDialog.showForOnline(context, song);
                      } else if (val == 'view_artist') {
                        ArtistSongsSheet.show(context, artistName: song.artist);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'play_now',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow_rounded, color: accent, size: 20),
                            const SizedBox(width: 10),
                            Text('Play Now', style: TextStyle(color: app.textColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.music_note_rounded, color: const Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            Text('Download Audio (MP3)', style: TextStyle(color: app.textColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download_video',
                        child: Row(
                          children: [
                            Icon(Icons.video_collection_rounded, color: const Color(0xFFFF1744), size: 20),
                            const SizedBox(width: 10),
                            Text('Download Video (MP4)', style: TextStyle(color: app.textColor)),
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
                        value: 'add_playlist',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add_rounded, color: app.secondaryTextColor, size: 20),
                            const SizedBox(width: 10),
                            Text('Add to Playlist', style: TextStyle(color: app.textColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'view_artist',
                        child: Row(
                          children: [
                            Icon(Icons.person_rounded, color: app.secondaryTextColor, size: 20),
                            const SizedBox(width: 10),
                            Text('Songs by Artist', style: TextStyle(color: app.textColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
