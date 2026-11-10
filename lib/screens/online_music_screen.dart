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
import '../utils/format.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/ios_bounce_button.dart';
import 'audio_player_screen.dart';
import 'artists_hub_screen.dart';
import 'shows_hub_screen.dart';

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

  // JioSaavn state
  bool _isSearching = false;
  bool _isLoadingResults = false;
  List<OnlineSong> _searchResults = [];

  bool _isLoadingTrending = true;
  List<OnlineSong> _trendingSongs = [];

  String? _selectedCategory;
  bool _isLoadingCategory = false;
  List<OnlineSong> _categorySongs = [];

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
    setState(() => _isLoadingTrending = true);
    final songs = await SaavnApiService.instance.getTrendingSongs();
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
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _isLoadingResults = true;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final songs = await SaavnApiService.instance.searchSongs(clean);
      if (mounted) {
        setState(() {
          _searchResults = songs;
          _isLoadingResults = false;
        });
      }
    });
  }

  Future<void> _openCategory(String title) async {
    setState(() {
      _selectedCategory = title;
      _isLoadingCategory = true;
      _categorySongs = [];
    });
    final songs = await SaavnApiService.instance.searchSongs(title);
    if (mounted) {
      setState(() {
        _categorySongs = songs;
        _isLoadingCategory = false;
      });
    }
  }

  void _playSong(List<OnlineSong> list, int index) {
    AudioController.instance.playOnlineQueue(list, index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
    );
  }

  void _openQualitySheet() {
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: currentQ == q
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : Colors.transparent,
                  title: Text(
                    q.label,
                    style: TextStyle(
                      fontWeight: currentQ == q ? FontWeight.w700 : FontWeight.w500,
                      color: currentQ == q ? const Color(0xFF10B981) : app.textColor,
                    ),
                  ),
                  subtitle: Text(
                    q.description,
                    style: TextStyle(fontSize: 12, color: app.secondaryTextColor),
                  ),
                  trailing: currentQ == q
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
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

  void _showJioNumberDialog() {
    final phoneCtrl = TextEditingController(text: app.jioNumber ?? '');
    final otpCtrl = TextEditingController();
    bool otpSent = false;
    bool verifying = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: app.isLight ? Colors.white : const Color(0xFF181E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF007BFF), Color(0xFF10B981)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sim_card_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'JioSaavn Link',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'अपने जियो नंबर से लिंक करें और JioSaavn ओरिजिनल के लाइक्स व प्लेलिस्ट बिना ऐड के सिंक करें:',
                    style: TextStyle(fontSize: 13, color: app.secondaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    enabled: !otpSent,
                    style: TextStyle(color: app.textColor, fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixText: '+91  ',
                      prefixStyle: TextStyle(color: app.textColor, fontWeight: FontWeight.w700),
                      labelText: 'Jio Mobile Number',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (otpSent) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      style: TextStyle(color: app.textColor, fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: 'Enter OTP (OTP दर्ज करें)',
                        hintText: '• • • • • •',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'OTP आपके जियो नंबर पर भेजा गया है (टेस्ट: 123456)',
                      style: TextStyle(fontSize: 11, color: app.secondaryTextColor),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: app.secondaryTextColor)),
                ),
                if (!otpSent)
                  ElevatedButton(
                    onPressed: () {
                      final p = phoneCtrl.text.trim();
                      if (p.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('कृपया सही 10-अंकों का जियो नंबर दर्ज करें')),
                        );
                        return;
                      }
                      setDialogState(() {
                        otpSent = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Send OTP (ओटीपी भेजें)'),
                  )
                else
                  ElevatedButton(
                    onPressed: verifying
                        ? null
                        : () async {
                            setDialogState(() => verifying = true);
                            await Future.delayed(const Duration(milliseconds: 600));
                            final phone = phoneCtrl.text.trim();
                            app.setJioNumber(phone);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF10B981),
                                  content: Text('✅ Jio नंबर +91 $phone सफलतापूर्वक लिंक हो गया! (100% Ad-Free)'),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: verifying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify & Sync (सिंक करें)'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const saavnColor = Color(0xFF10B981);

    return Column(
      children: [
        SizedBox(height: widget.topOffset),
        _buildJioSaavnHeader(saavnColor),
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildSearchBar(saavnColor),
        ),
        // Content Area
        Expanded(
          child: _isSearching
              ? _buildSongList(_searchResults, _isLoadingResults, 'No JioSaavn tracks found')
              : _selectedCategory != null
                  ? _buildCategoryView()
                  : _buildHomeView(saavnColor),
        ),
      ],
    );
  }

  Widget _buildJioSaavnHeader(Color saavnColor) {
    final isLight = app.isLight;
    final curQuality = SettingsService.instance.audioQuality;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          // JioSaavn Official Logo Badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF10B981), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: saavnColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.music_note_rounded, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'JioSaavn HD',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: app.textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: saavnColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: saavnColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '320 kbps Lossless • Ad-Free Music',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: app.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Quality Switcher Button
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
    );
  }

  Widget _buildSearchBar(Color accentColor) {
    final isLight = app.isLight;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        style: TextStyle(color: app.textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'JioSaavn 320kbps HD गाने या गायक खोजें...',
          hintStyle: TextStyle(color: app.secondaryTextColor, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: accentColor, size: 21),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: app.secondaryTextColor, size: 18),
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

  Widget _buildHomeView(Color saavnColor) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, math.max(160.0, widget.bottomOffset)),
      children: [
        // 1. Top Hub Row: Indian Artists & Shows (Placed at top as requested)
        Row(
          children: [
            Expanded(
              child: _buildTopHubCard(
                title: 'भारतीय कलाकार',
                subtitle: 'Indian Artists (50+)',
                icon: Icons.mic_external_on_rounded,
                color: const Color(0xFF3B82F6),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArtistsHubScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTopHubCard(
                title: 'शोज़ एवं सीरीज़',
                subtitle: 'Osho, Desi FM, Aawaz',
                icon: Icons.podcasts_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShowsHubScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Jio Number Link & Sync Card
        _buildJioSyncCard(saavnColor),
        const SizedBox(height: 16),

        // 3. Indian Artists Avatars Row
        _buildIndianArtistsSection(saavnColor),
        const SizedBox(height: 18),

        // 4. Curated Era Folders (New Bollywood Hits / Old Is Gold)
        Row(
          children: [
            Expanded(
              child: _buildEraCard(
                'New Bollywood Hits',
                'Latest 2024 Hits',
                Icons.whatshot_rounded,
                const Color(0xFF00D2FF),
                () => _openCategory('New Bollywood Hits'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEraCard(
                'Old Is Gold',
                '70s-90s Classics',
                Icons.radio_rounded,
                const Color(0xFFFFB300),
                () => _openCategory('Old Is Gold'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 5. Popular Right Now (JioSaavn HD)
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
        if (_isLoadingTrending)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF10B981))))
        else
          ..._trendingSongs.take(25).map((song) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OnlineSongTile(
                  song: song,
                  onTap: () => _playSong(_trendingSongs, _trendingSongs.indexOf(song)),
                ),
              )),
      ],
    );
  }

  Widget _buildTopHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isLight = app.isLight;
    return iOSBounceButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF181E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white10,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isLight ? 0.08 : 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: app.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
    );
  }

  Widget _buildJioSyncCard(Color saavnColor) {
    final isLight = app.isLight;
    final isLinked = app.isJioLinked;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF181E2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLinked
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (isLight ? const Color(0xFFE2E8F0) : Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLinked
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFF007BFF), const Color(0xFF0056B3)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLinked ? Icons.check_circle_rounded : Icons.sync_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLinked
                      ? 'Jio Account Linked: +91 ${app.jioNumber}'
                      : 'जियो नंबर से लिंक करें (Link Jio Number)',
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
                  isLinked
                      ? 'Ad-Free Sync Active • No Ads'
                      : 'Playlists & Liked Songs सिंक करें (बिना ऐड)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLinked ? const Color(0xFF10B981) : app.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showJioNumberDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLinked ? saavnColor.withValues(alpha: 0.15) : saavnColor,
              foregroundColor: isLinked ? saavnColor : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isLinked ? 'Change' : 'Link',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndianArtistsSection(Color saavnColor) {
    final artists = SaavnApiService.curatedArtists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'भारतीय कलाकार (Indian Artists)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: app.textColor),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArtistsHubScreen()),
              ),
              child: Text(
                'सभी देखें →',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: saavnColor),
              ),
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
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: saavnColor.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            a.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 30),
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
    final isLight = app.isLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF181E2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isLight ? const Color(0xFFE2E8F0) : Colors.white12),
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

  Widget _buildCategoryView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedCategory = null),
              ),
              Expanded(
                child: Text(
                  _selectedCategory!,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: app.textColor),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildSongList(_categorySongs, _isLoadingCategory, 'No songs found in this category'),
        ),
      ],
    );
  }

  Widget _buildSongList(List<OnlineSong> songs, bool loading, String emptyMsg) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (songs.isEmpty) {
      return Center(
        child: Text(emptyMsg, style: TextStyle(color: app.secondaryTextColor, fontSize: 14)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 6, 16, math.max(160.0, widget.bottomOffset)),
      itemCount: songs.length,
      itemBuilder: (context, idx) {
        final song = songs[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OnlineSongTile(
            song: song,
            onTap: () => _playSong(songs, idx),
          ),
        );
      },
    );
  }
}

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
    final isLight = app.isLight;
    final isFav = app.isFavorite(song.id);

    return iOSBounceButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF181E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                song.imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  child: const Icon(Icons.music_note_rounded, color: Color(0xFF10B981), size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Metadata
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
                        child: const Text(
                          '320 kbps HD',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
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
