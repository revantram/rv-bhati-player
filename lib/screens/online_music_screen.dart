import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/online_song.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/saavn_api_service.dart';
import '../services/settings_service.dart';
import '../services/spotify_service.dart';
import '../services/yt_audio_resolver.dart';
import '../services/yt_music_service.dart';
import '../utils/format.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/glass_bars.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/youtube_music_sheet.dart';
import 'audio_player_screen.dart';
import 'artists_hub_screen.dart';
import 'radio_screen.dart';

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
  // Current active sub-platform: null = Gateway Selector, 'jiosaavn', 'youtube', 'spotify', 'radio'
  String? _selectedPlatform;

  // Search controllers for each platform (100% separate!)
  final TextEditingController _saavnSearchCtrl = TextEditingController();
  final TextEditingController _ytSearchCtrl = TextEditingController();
  final TextEditingController _spotifySearchCtrl = TextEditingController();
  Timer? _debounce;

  // JioSaavn state
  bool _saavnSearching = false;
  bool _saavnLoading = false;
  List<OnlineSong> _saavnResults = [];
  bool _saavnLoadingTrending = true;
  List<OnlineSong> _saavnTrending = [];
  String? _saavnSelectedCategory;
  bool _saavnLoadingCategory = false;
  List<OnlineSong> _saavnCategorySongs = [];

  // YouTube Music state
  bool _ytSearching = false;
  bool _ytLoading = false;
  List<OnlineSong> _ytResults = [];
  String _ytActiveCategory = 'Rajasthani & Marwadi DJ';

  // Spotify state
  bool _spotifySearching = false;
  bool _spotifyLoading = false;
  List<OnlineSong> _spotifyResults = [];
  String _spotifyActivePlaylistId = 'top_hits';
  String _spotifyActivePlaylistTitle = "Today's Top Hits";
  List<OnlineSong> _spotifyPlaylistSongs = [];
  bool _spotifyLoadingPlaylist = false;

  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    _loadSaavnTrending();
    _loadYtCategory(_ytActiveCategory);
    _loadSpotifyPlaylist(_spotifyActivePlaylistId, _spotifyActivePlaylistTitle);
    SettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    _debounce?.cancel();
    _saavnSearchCtrl.dispose();
    _ytSearchCtrl.dispose();
    _spotifySearchCtrl.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  // --- JioSaavn Methods ---
  Future<void> _loadSaavnTrending() async {
    setState(() => _saavnLoadingTrending = true);
    final songs = await SaavnApiService.instance.getTrendingSongs();
    if (mounted) {
      setState(() {
        _saavnTrending = songs;
        _saavnLoadingTrending = false;
      });
    }
  }

  void _onSaavnSearch(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _saavnSearching = false;
        _saavnLoading = false;
        _saavnResults = [];
      });
      return;
    }
    setState(() {
      _saavnSearching = true;
      _saavnLoading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final res = await SaavnApiService.instance.searchSongs(clean);
      if (mounted) {
        setState(() {
          _saavnResults = res;
          _saavnLoading = false;
        });
      }
    });
  }

  Future<void> _openSaavnCategory(String category) async {
    setState(() {
      _saavnSelectedCategory = category;
      _saavnLoadingCategory = true;
      _saavnCategorySongs = [];
    });
    final songs = await SaavnApiService.instance.getCategorizedPlaylist(category);
    if (mounted) {
      setState(() {
        _saavnCategorySongs = songs;
        _saavnLoadingCategory = false;
      });
    }
  }

  Future<void> _openSaavnMood(String moodId, String title) async {
    setState(() {
      _saavnSelectedCategory = title;
      _saavnLoadingCategory = true;
      _saavnCategorySongs = [];
    });
    final songs = await SaavnApiService.instance.getMoodPlaylist(moodId);
    if (mounted) {
      setState(() {
        _saavnCategorySongs = songs;
        _saavnLoadingCategory = false;
      });
    }
  }

  // --- YouTube Music Methods ---
  Future<void> _loadYtCategory(String query) async {
    setState(() {
      _ytActiveCategory = query;
      _ytLoading = true;
    });
    final songs = await YtMusicService.instance.search(query);
    if (mounted) {
      setState(() {
        _ytResults = songs;
        _ytLoading = false;
      });
    }
  }

  void _onYtSearch(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _ytSearching = false;
        _ytLoading = false;
      });
      _loadYtCategory(_ytActiveCategory);
      return;
    }
    setState(() {
      _ytSearching = true;
      _ytLoading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final songs = await YtMusicService.instance.search(clean);
      if (mounted) {
        setState(() {
          _ytResults = songs;
          _ytLoading = false;
        });
      }
    });
  }

  // --- Spotify Methods ---
  Future<void> _loadSpotifyPlaylist(String id, String title) async {
    setState(() {
      _spotifyActivePlaylistId = id;
      _spotifyActivePlaylistTitle = title;
      _spotifyLoadingPlaylist = true;
      _spotifySearching = false;
      _spotifySearchCtrl.clear();
    });
    final songs = await SpotifyService.instance.getSpotifyPlaylist(id);
    if (mounted) {
      setState(() {
        _spotifyPlaylistSongs = songs;
        _spotifyLoadingPlaylist = false;
      });
    }
  }

  void _onSpotifySearch(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _spotifySearching = false;
        _spotifyLoading = false;
        _spotifyResults = [];
      });
      return;
    }
    setState(() {
      _spotifySearching = true;
      _spotifyLoading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final songs = await SpotifyService.instance.search(clean);
      if (mounted) {
        setState(() {
          _spotifyResults = songs;
          _spotifyLoading = false;
        });
      }
    });
  }

  Future<void> _playSong(List<OnlineSong> list, int index) async {
    final song = list[index];

    // If it is a YouTube song, resolve with instant feedback
    if (song.id.startsWith('yt_')) {
      final ytId = song.id.replaceFirst('yt_', '');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Starting "${song.title}"...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final directUrl = await YtAudioResolver.resolveAudioStream(
        ytId,
        fallbackTitle: song.title,
        fallbackArtist: song.artist,
      );

      if (!mounted) return;

      if (directUrl != null && directUrl.isNotEmpty) {
        final updatedList = List<OnlineSong>.from(list);
        updatedList[index] = OnlineSong(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: song.duration,
          imageUrl: song.imageUrl,
          streamUrl: directUrl,
        );
        AudioController.instance.playOnlineQueue(updatedList, index);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
        );
      } else {
        // Direct audio extraction blocked -> launch dedicated in-app YouTube player sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => YouTubeMusicSheet(song: song),
        );
      }
    } else {
      // JioSaavn / Osho / Spotify standard playback
      AudioController.instance.playOnlineQueue(list, index);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
      );
    }
  }

  void _openQualitySheet() {
    final app = AppState.instance;
    final isLight = app.isLight;
    final currentQ = SettingsService.instance.audioQuality;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF14192B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.black12 : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ऑडियो स्ट्रीमिंग क्वालिटी (Audio Quality)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
              const SizedBox(height: 14),
              for (final q in AudioQuality.values) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: currentQ == q
                      ? app.accentColor.withValues(alpha: 0.12)
                      : (isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.05)),
                  leading: Icon(
                    q == AudioQuality.hd320
                        ? Icons.high_quality_rounded
                        : (q == AudioQuality.standard160 ? Icons.headphones_rounded : Icons.network_cell_rounded),
                    color: currentQ == q ? app.accentColor : app.secondaryTextColor,
                  ),
                  title: Text(
                    q.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: currentQ == q ? app.accentColor : app.textColor,
                    ),
                  ),
                  subtitle: Text(
                    q.description,
                    style: TextStyle(fontSize: 12, color: app.secondaryTextColor),
                  ),
                  trailing: currentQ == q
                      ? Icon(Icons.check_circle_rounded, color: app.accentColor)
                      : null,
                  onTap: () {
                    SettingsService.instance.setAudioQuality(q);
                    Navigator.pop(ctx);
                    if (mounted) setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Audio streaming quality: ${q.label}')),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _selectedPlatform == null
          ? _buildPlatformGateway()
          : _selectedPlatform == 'jiosaavn'
              ? _buildJioSaavnScreen()
              : _selectedPlatform == 'youtube'
                  ? _buildYouTubeMusicScreen()
                  : _selectedPlatform == 'spotify'
                      ? _buildSpotifyScreen()
                      : _buildRadioScreenWrapper(),
    );
  }

  // =========================================================================
  // 1. GATEWAY: Platform Selector (3 Cards + Radio = 4 Sections)
  // =========================================================================
  Widget _buildPlatformGateway() {
    final app = AppState.instance;
    final isLight = app.isLight;
    final curQuality = SettingsService.instance.audioQuality;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, widget.topOffset + 8, 16, math.max(160.0, widget.bottomOffset)),
      children: [
        // Quality Badge Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ऑनलाइन म्यूजिक हब',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: app.textColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'अपना पसंदीदा प्लेटफॉर्म चुनें',
                  style: TextStyle(
                    fontSize: 13,
                    color: app.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _openQualitySheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : const Color(0xFF1C2230),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLight ? const Color(0xFFE2E8F0) : Colors.white12,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      curQuality.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: app.textColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: app.secondaryTextColor),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Platform 1: JioSaavn HD
        _buildPlatformCard(
          title: 'JioSaavn HD',
          badgeText: '320 kbps Lossless',
          description: 'Bollywood, 90s Classics, Curated Singers & Hindi Chartbusters',
          featureChips: ['320kbps Audio', 'Original Artists', 'Mood Playlists'],
          icon: Icons.album_rounded,
          gradientColors: [const Color(0xFF10B981), const Color(0xFF047857)],
          onTap: () => setState(() => _selectedPlatform = 'jiosaavn'),
        ),
        const SizedBox(height: 14),

        // Platform 2: YouTube Music
        _buildPlatformCard(
          title: 'YouTube Music',
          badgeText: 'Marwadi & DJ Hits',
          description: 'Marwadi DJ Remixes, Desi Bhajans, Rajasthani Folk & Indie Music',
          featureChips: ['Rajasthani & Marwadi', 'DJ Remixes', 'Live Bhajans'],
          icon: Icons.smart_display_rounded,
          gradientColors: [const Color(0xFFFF0033), const Color(0xFF990000)],
          onTap: () => setState(() => _selectedPlatform = 'youtube'),
        ),
        const SizedBox(height: 14),

        // Platform 3: Spotify Hub
        _buildPlatformCard(
          title: 'Spotify Hub',
          badgeText: 'Top Charts',
          description: 'Global Top 50, Viral Hits India, Lo-Fi Chill Beats & Sleep Vibes',
          featureChips: ["Today's Top Hits", 'Viral 50', 'Lo-Fi Chill'],
          icon: Icons.stream_rounded,
          gradientColors: [const Color(0xFF1DB954), const Color(0xFF0B6623)],
          onTap: () => setState(() => _selectedPlatform = 'spotify'),
        ),
        const SizedBox(height: 14),

        // Platform 4: Live Radio 24x7
        _buildPlatformCard(
          title: 'Live FM & Radio',
          badgeText: '24x7 Live Streaming',
          description: 'Vividh Bharati, AIR News, Superhits 93.5 Red FM & Marwadi Radio',
          featureChips: ['All India Radio', 'FM Channels', 'Devotional'],
          icon: Icons.radio_rounded,
          gradientColors: [const Color(0xFFFF8C00), const Color(0xFFE65100)],
          onTap: () => setState(() => _selectedPlatform = 'radio'),
        ),
      ],
    );
  }

  Widget _buildPlatformCard({
    required String title,
    required String badgeText,
    required String description,
    required List<String> featureChips,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final app = AppState.instance;
    final isLight = app.isLight;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF181E2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: isLight ? 0.12 : 0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Platform Icon with gradient
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: app.textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradientColors[0].withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: gradientColors[0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFF1F5F9) : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: gradientColors[0],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 12.5,
                color: app.secondaryTextColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: featureChips.map((chip) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E2638),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: app.textColor.withValues(alpha: 0.85),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Top Return-to-Gateway Bar
  Widget _buildTopPlatformHeader(String platformTitle, Color accentColor) {
    final app = AppState.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedPlatform = null);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: app.isLight ? Colors.white : const Color(0xFF1C2230),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: app.isLight ? const Color(0xFFE2E8F0) : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'प्लेटफॉर्म बदलें',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              platformTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: app.textColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: _openQualitySheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: app.isLight ? Colors.white : const Color(0xFF1C2230),
                shape: BoxShape.circle,
                border: Border.all(color: app.isLight ? const Color(0xFFE2E8F0) : Colors.white12),
              ),
              child: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. DEDICATED JIOSAAVN HD SCREEN
  // =========================================================================
  Widget _buildJioSaavnScreen() {
    final app = AppState.instance;
    const saavnColor = Color(0xFF10B981);

    return Column(
      children: [
        SizedBox(height: widget.topOffset),
        _buildTopPlatformHeader('JioSaavn HD', saavnColor),
        // Dedicated JioSaavn Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildDedicatedSearchBar(
            controller: _saavnSearchCtrl,
            hint: 'JioSaavn 320kbps HD गाने या गायक खोजें...',
            accentColor: saavnColor,
            onChanged: _onSaavnSearch,
            onClear: () {
              _saavnSearchCtrl.clear();
              _onSaavnSearch('');
            },
          ),
        ),
        // Body
        Expanded(
          child: _saavnSearching
              ? _buildSongList(_saavnResults, _saavnLoading, 'No JioSaavn tracks found')
              : _saavnSelectedCategory != null
                  ? _buildSaavnCategoryView()
                  : _buildSaavnHomeView(),
        ),
      ],
    );
  }

  Widget _buildSaavnHomeView() {
    final app = AppState.instance;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 10, 16, math.max(160.0, widget.bottomOffset)),
      children: [
        // Curated Singers
        _buildSaavnSingersRow(),
        const SizedBox(height: 20),
        // Curated Era Folders (New Bollywood Hits / Old Is Gold)
        Row(
          children: [
            Expanded(
              child: _buildEraCard('New Bollywood Hits', 'Latest 2024 Hits', Icons.whatshot_rounded, const Color(0xFF00D2FF), () => _openSaavnCategory('New Bollywood Hits')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEraCard('Old Is Gold', '70s-90s Classics', Icons.radio_rounded, const Color(0xFFFFB300), () => _openSaavnCategory('Old Is Gold')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Mood Playlists (Rajasthani, Bhakti, etc.)
        _buildSaavnMoodRow(),
        const SizedBox(height: 22),
        // Trending Chartbusters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.whatshot_rounded, size: 20, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                'Popular Right Now (JioSaavn HD)',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: app.textColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_saavnLoadingTrending)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF10B981))))
        else
          ..._saavnTrending.take(20).map((song) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OnlineSongTile(song: song, onTap: () => _playSong(_saavnTrending, _saavnTrending.indexOf(song))),
              )),
      ],
    );
  }

  Widget _buildSaavnSingersRow() {
    final app = AppState.instance;
    final artists = SaavnApiService.curatedArtists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('लोकप्रिय कलाकार (Popular Artists)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.textColor)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArtistsHubScreen())),
              child: const Text('सभी देखें →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 98,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artists.length,
            itemBuilder: (context, i) {
              final a = artists[i];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => ArtistSongsSheet.show(context, artist: a, artistName: a.name, avatarUrl: a.avatarUrl, subtitle: a.subtitle),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.network(a.avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 30)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: app.textColor),
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

  Widget _buildEraCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    final app = AppState.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: app.isLight ? Colors.white : const Color(0xFF181E2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: app.isLight ? const Color(0xFFE2E8F0) : Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: app.textColor), maxLines: 1),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: app.secondaryTextColor), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaavnMoodRow() {
    final app = AppState.instance;
    final categories = SaavnApiService.moodCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('मूड एवं क्षेत्रीय संगीत (Mood & Regional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.textColor)),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final c = categories[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _openSaavnMood(c['id']!, c['title']!),
                  child: Container(
                    width: 170,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: app.isLight ? Colors.white : const Color(0xFF181E2E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: app.isLight ? const Color(0xFFE2E8F0) : Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Text(c['icon'] ?? '🎵', style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(c['title']!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: app.textColor), maxLines: 1),
                              Text(c['subtitle']!, style: TextStyle(fontSize: 10.5, color: app.secondaryTextColor), maxLines: 1),
                            ],
                          ),
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

  Widget _buildSaavnCategoryView() {
    final app = AppState.instance;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _saavnSelectedCategory = null)),
              Expanded(child: Text(_saavnSelectedCategory!, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: app.textColor))),
              if (_saavnCategorySongs.isNotEmpty)
                IconButton(icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF10B981), size: 30), onPressed: () => _playSong(_saavnCategorySongs, 0)),
            ],
          ),
        ),
        Expanded(child: _buildSongList(_saavnCategorySongs, _saavnLoadingCategory, 'No songs found in this category')),
      ],
    );
  }

  // =========================================================================
  // 3. DEDICATED YOUTUBE MUSIC SCREEN (Rajasthani, Marwadi, DJ, Bhajans)
  // =========================================================================
  Widget _buildYouTubeMusicScreen() {
    const ytColor = Color(0xFFFF0033);
    final ytChips = [
      'Rajasthani & Marwadi DJ',
      'Desi Bhajan & Aarti',
      'Trending YouTube India',
      'Marwadi Vivah Geet',
      'Prakash Mali Bhajan',
      'Indie Pop & Mashup',
      'Veena Rajasthani Hits',
    ];

    return Column(
      children: [
        SizedBox(height: widget.topOffset),
        _buildTopPlatformHeader('YouTube Music', ytColor),
        // Dedicated YouTube Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildDedicatedSearchBar(
            controller: _ytSearchCtrl,
            hint: 'YouTube पर मारवाड़ी DJ, भजन या वीडियो गाने खोजें...',
            accentColor: ytColor,
            onChanged: _onYtSearch,
            onClear: () {
              _ytSearchCtrl.clear();
              _onYtSearch('');
            },
          ),
        ),
        // Category Pills for YouTube
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: ytChips.length,
            itemBuilder: (context, i) {
              final chip = ytChips[i];
              final isActive = _ytActiveCategory == chip && !_ytSearching;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    _ytSearchCtrl.clear();
                    _ytSearching = false;
                    _loadYtCategory(chip);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? ytColor : (app.isLight ? Colors.white : const Color(0xFF1C2230)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isActive ? ytColor : (app.isLight ? const Color(0xFFE2E8F0) : Colors.white12)),
                    ),
                    child: Center(
                      child: Text(
                        chip,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? Colors.white : app.textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Results List
        Expanded(
          child: _buildSongList(_ytResults, _ytLoading, 'YouTube results loading or none found'),
        ),
      ],
    );
  }

  // =========================================================================
  // 4. DEDICATED SPOTIFY HUB SCREEN
  // =========================================================================
  Widget _buildSpotifyScreen() {
    const spotifyColor = Color(0xFF1DB954);
    final playlists = SpotifyService.spotifyPlaylists;

    return Column(
      children: [
        SizedBox(height: widget.topOffset),
        _buildTopPlatformHeader('Spotify Hub', spotifyColor),
        // Dedicated Spotify Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildDedicatedSearchBar(
            controller: _spotifySearchCtrl,
            hint: 'Spotify ग्लोबल हिट्स, वायरल रील्स गाने खोजें...',
            accentColor: spotifyColor,
            onChanged: _onSpotifySearch,
            onClear: () {
              _spotifySearchCtrl.clear();
              _onSpotifySearch('');
            },
          ),
        ),
        // Spotify Playlist Selector Pills
        if (!_spotifySearching)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: playlists.length,
              itemBuilder: (context, i) {
                final p = playlists[i];
                final isActive = _spotifyActivePlaylistId == p['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _loadSpotifyPlaylist(p['id']!, p['title']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? spotifyColor : (app.isLight ? Colors.white : const Color(0xFF1C2230)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isActive ? spotifyColor : (app.isLight ? const Color(0xFFE2E8F0) : Colors.white12)),
                      ),
                      child: Center(
                        child: Text(
                          '${p['icon']} ${p['title']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? Colors.white : app.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 6),
        // Songs List
        Expanded(
          child: _spotifySearching
              ? _buildSongList(_spotifyResults, _spotifyLoading, 'No Spotify tracks found')
              : _buildSongList(_spotifyPlaylistSongs, _spotifyLoadingPlaylist, 'Loading Spotify playlist...'),
        ),
      ],
    );
  }

  // =========================================================================
  // 5. EMBEDDED RADIO SCREEN (Live FM 24x7)
  // =========================================================================
  Widget _buildRadioScreenWrapper() {
    const radioColor = Color(0xFFFF8C00);
    return Column(
      children: [
        SizedBox(height: widget.topOffset),
        _buildTopPlatformHeader('Live FM & Radio 24x7', radioColor),
        Expanded(
          child: RadioScreen(
            topOffset: 8,
            bottomOffset: widget.bottomOffset,
          ),
        ),
      ],
    );
  }

  // Generic Song List Builder
  Widget _buildSongList(List<OnlineSong> songs, bool loading, String emptyText) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (songs.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: app.secondaryTextColor, fontSize: 14)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 6, 16, math.max(160.0, widget.bottomOffset)),
      itemCount: songs.length,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OnlineSongTile(
            song: songs[i],
            onTap: () => _playSong(songs, i),
          ),
        );
      },
    );
  }

  // Dedicated Platform Search Bar Widget
  Widget _buildDedicatedSearchBar({
    required TextEditingController controller,
    required String hint,
    required Color accentColor,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    final app = AppState.instance;
    final isLight = app.isLight;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF181E2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white12,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: accentColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: app.textColor,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: app.secondaryTextColor.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, size: 18, color: app.secondaryTextColor),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Online Song Tile Widget (320kbps badge, download, favorite, three-dot menu)
// ---------------------------------------------------------------------------
class _OnlineSongTile extends StatelessWidget {
  final OnlineSong song;
  final VoidCallback onTap;

  const _OnlineSongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final isFav = app.isFavorite(song.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF181E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail / Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 50,
                height: 50,
                child: Image.network(
                  song.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: app.accentColor.withValues(alpha: 0.2),
                    child: Icon(Icons.music_note_rounded, color: app.accentColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Song Info
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          song.id.startsWith('yt_') ? 'YouTube Audio' : '320 kbps HD',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: song.id.startsWith('yt_') ? const Color(0xFFFF0033) : const Color(0xFF10B981),
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

            // Download Button
            ListenableBuilder(
              listenable: DownloadService.instance,
              builder: (context, _) {
                final isDl = DownloadService.instance.isDownloaded(song.id);
                final isDownloading = DownloadService.instance.isDownloading(song.id);

                return IconButton(
                  icon: isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                        )
                      : Icon(
                          isDl ? Icons.download_done_rounded : Icons.download_rounded,
                          color: isDl ? Colors.green : app.secondaryTextColor.withValues(alpha: 0.6),
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

            // Favorite Button
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFFF2A85) : app.secondaryTextColor.withValues(alpha: 0.5),
                size: 21,
              ),
              onPressed: () => app.toggleFavorite(song.id),
            ),

            // Popup Actions Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: app.secondaryTextColor, size: 20),
              color: isLight ? Colors.white : const Color(0xFF14192B),
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
                } else if (val == 'add_queue') {
                  AudioController.instance.addOnlineToQueue(song);
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
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, color: app.secondaryTextColor, size: 20),
                      const SizedBox(width: 10),
                      Text('Download Offline', style: TextStyle(color: app.textColor)),
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
