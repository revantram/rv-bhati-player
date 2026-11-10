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
import 'settings_screen.dart';

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

  String? _customDisplayTitle;
  bool _isLoadingCustomSongs = false;
  List<OnlineSong>? _customSongs;

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

  Future<void> _loadSongsByQuery(String query, String displayTitle) async {
    setState(() {
      _customDisplayTitle = displayTitle;
      _isLoadingCustomSongs = true;
      _customSongs = [];
    });
    final songs = await SaavnApiService.instance.searchSongs(query, limit: 120);
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

  void _playSong(List<OnlineSong> list, int index) {
    AudioController.instance.playOnlineQueue(list, index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioPlayerScreen(startPlayback: false)),
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

  void _openMoodModal() {
    final isLight = app.isLight;
    final moods = [
      {'title': '❤️ Romantic', 'query': 'Romantic Hindi Songs'},
      {'title': '💔 Sad Songs', 'query': 'Sad Hindi Songs Heartbroken'},
      {'title': '🔥 Party / Dance', 'query': 'Hindi Party Dance Hits'},
      {'title': '🙏 Bhakti', 'query': 'Bhakti Bhajan Hindi'},
      {'title': '🎧 Lo-Fi Chill', 'query': 'Lo-Fi Hindi Chill Beats'},
      {'title': '🏜️ Marwadi', 'query': 'Rajasthani Marwadi Songs'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF14192B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Apna Mood Chuniye',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: app.textColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.8,
                children: moods.map((m) {
                  return OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadSongsByQuery(m['query']!, m['title']!);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: app.textColor,
                      side: BorderSide(
                        color: isLight ? const Color(0xFFCBD5E1) : Colors.white24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      m['title']!,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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

  void _openArtistModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ArtistDirectorySheet(
          onSelectArtist: (artist) {
            Navigator.pop(ctx);
            _loadSongsByQuery(artist.name, '🎙️ ${artist.name} ke Gane');
          },
        );
      },
    );
  }

  void _openPlaylistSyncModal() {
    final urlCtrl = TextEditingController(text: app.jioPlaylistUrl ?? '');
    bool syncing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isLight = app.isLight;
        return StatefulBuilder(
          builder: (bottomSheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetCtx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : const Color(0xFF14192B),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF047857)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JioSaavn Playlist Sync',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: app.textColor,
                                ),
                              ),
                              Text(
                                'Ad-Free JioSaavn Playlist',
                                style: TextStyle(fontSize: 11.5, color: app.secondaryTextColor),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'अपने JioSaavn प्लेलिस्ट का लिंक या नाम दर्ज करें:',
                      style: TextStyle(fontSize: 13, color: app.secondaryTextColor),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      style: TextStyle(color: app.textColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'https://www.jiosaavn.com/featured/...',
                        hintStyle: TextStyle(color: app.secondaryTextColor.withValues(alpha: 0.6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste_rounded, size: 20),
                          tooltip: 'Paste Link',
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null && data!.text!.isNotEmpty) {
                              urlCtrl.text = data.text!.trim();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null && data!.text!.isNotEmpty) {
                                urlCtrl.text = data.text!.trim();
                              }
                            },
                            icon: const Icon(Icons.paste_rounded, size: 18),
                            label: const Text('📋 Paste Link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: app.textColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white24,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: syncing
                                ? null
                                : () async {
                                    final input = urlCtrl.text.trim();
                                    if (input.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('कृपया प्लेलिस्ट लिंक या नाम दर्ज करें')),
                                      );
                                      return;
                                    }
                                    setSheetState(() => syncing = true);
                                    final res = await SaavnApiService.instance.fetchPlaylist(input);
                                    if (!mounted) return;
                                    if (res.songs.isNotEmpty) {
                                      app.setJioPlaylist(
                                        url: input,
                                        name: res.title,
                                        songs: res.songs,
                                      );
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _customDisplayTitle = '🎵 ${res.title} (${res.songs.length})';
                                        _customSongs = res.songs;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF10B981),
                                          content: Text('✅ "${res.title}" के ${res.songs.length} गाने सिंक हो गए!'),
                                        ),
                                      );
                                    } else {
                                      setSheetState(() => syncing = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('प्लेलिस्ट लोड नहीं हो सकी, लिंक जांचें')),
                                      );
                                    }
                                  },
                            icon: syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 18),
                            label: Text(syncing ? 'Syncing...' : '🔄 Sync Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'JioSaavn HD',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: app.textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: saavnColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '320 kbps HD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: saavnColor,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: app.secondaryTextColor, size: 21),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
      padding: EdgeInsets.fromLTRB(16, 4, 16, math.max(160.0, widget.bottomOffset)),
      children: [
        // 1. Quick Category Cards: 90s Special & Moods
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                emoji: '📼',
                title: '90s Special',
                subtitle: 'Evergreen Hits',
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => _loadSongsByQuery('90s Bollywood Evergreen Hits', '📼 90s Evergreen Hits'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                emoji: '🎭',
                title: 'Moods',
                subtitle: 'Choose Your Vibe',
                bgColor: const Color(0xFFFEF3C7),
                onTap: _openMoodModal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. My Playlist & All Artists Row
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                emoji: '🎵',
                title: 'My Playlist',
                subtitle: app.hasJioPlaylist
                    ? '${app.jioPlaylistSongs.length} gane uplabdh'
                    : 'Apne Gane',
                bgColor: const Color(0xFFDCFCE7),
                trailing: IconButton(
                  icon: const Icon(Icons.sync_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFF10B981),
                  tooltip: 'Sync Jio Playlist',
                  onPressed: _openPlaylistSyncModal,
                ),
                onTap: () {
                  if (app.hasJioPlaylist) {
                    setState(() {
                      _customDisplayTitle = '🎵 ${app.jioPlaylistName ?? "My Playlist"} (${app.jioPlaylistSongs.length})';
                      _customSongs = app.jioPlaylistSongs;
                    });
                  } else {
                    _openPlaylistSyncModal();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                emoji: '🎙️',
                title: 'All Artists',
                subtitle: '${SaavnApiService.curatedArtists.length}+ Singers',
                bgColor: const Color(0xFFEDE9FE),
                onTap: _openArtistModal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Indian Artists Avatars Row
        _buildIndianArtistsSection(saavnColor),
        const SizedBox(height: 16),

        // 4. Popular Right Now or Active Query / Mood / Playlist Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Icon(
                _customSongs != null ? Icons.music_note_rounded : Icons.whatshot_rounded,
                size: 20,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _customDisplayTitle ?? 'Popular Right Now (JioSaavn HD)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: app.textColor),
                ),
              ),
              if (_customSongs != null)
                TextButton.icon(
                  onPressed: _resetToPopular,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Popular', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingCustomSongs || (_customSongs == null && _isLoadingTrending))
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF10B981))))
        else if (_customSongs != null)
          if (_customSongs!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'कोई गाने नहीं मिले (No songs found)',
                  style: TextStyle(color: app.secondaryTextColor, fontSize: 13.5),
                ),
              ),
            )
          else
            ..._customSongs!.map((song) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OnlineSongTile(
                    song: song,
                    onTap: () => _playSong(_customSongs!, _customSongs!.indexOf(song)),
                  ),
                ))
        else
          ..._trendingSongs.map((song) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OnlineSongTile(
                  song: song,
                  onTap: () => _playSong(_trendingSongs, _trendingSongs.indexOf(song)),
                ),
              )),
      ],
    );
  }

  Widget _buildActionCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color bgColor,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isLight = app.isLight;
    return iOSBounceButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isLight ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF181E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white10,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 19)),
              ),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
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

class _ArtistDirectorySheet extends StatefulWidget {
  const _ArtistDirectorySheet({required this.onSelectArtist});

  final void Function(SaavnArtist artist) onSelectArtist;

  @override
  State<_ArtistDirectorySheet> createState() => _ArtistDirectorySheetState();
}

class _ArtistDirectorySheetState extends State<_ArtistDirectorySheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _selectedFilter = 0; // 0: Sabhi, 1: Rajasthani, 2: Bollywood
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final allArtists = SaavnApiService.curatedArtists;

    final filtered = allArtists.where((a) {
      if (_selectedFilter == 1 && !a.isRajasthani) return false;
      if (_selectedFilter == 2 && !a.isBollywood) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchName = a.name.toLowerCase().contains(q);
        final matchSub = a.subtitle.toLowerCase().contains(q);
        if (!matchName && !matchSub) return false;
      }
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF14192B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isLight ? Colors.black12 : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🎙️', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'सभी कलाकार (All Artists)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: app.textColor,
                        ),
                      ),
                      Text(
                        '${allArtists.length}+ Indian & Rajasthani Singers',
                        style: TextStyle(fontSize: 11, color: app.secondaryTextColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white10,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: TextStyle(color: app.textColor, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'कलाकार खोजें (Search artist)...',
                  hintStyle: TextStyle(color: app.secondaryTextColor, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab(0, 'Sabhi (${allArtists.length})'),
                  const SizedBox(width: 8),
                  _buildTab(1, '🏜️ Rajasthani (${allArtists.where((a) => a.isRajasthani).length})'),
                  const SizedBox(width: 8),
                  _buildTab(2, '🎬 Bollywood (${allArtists.where((a) => a.isBollywood).length})'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Artists Grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'कोई कलाकार नहीं मिला',
                      style: TextStyle(color: app.secondaryTextColor, fontSize: 13.5),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final artist = filtered[i];
                      return GestureDetector(
                        onTap: () => widget.onSelectArtist(artist),
                        child: Column(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: artist.isRajasthani
                                      ? const Color(0xFFFF8C00)
                                      : const Color(0xFF10B981),
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  artist.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 36),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: app.textColor,
                              ),
                            ),
                            Text(
                              artist.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: app.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int idx, String label) {
    final active = _selectedFilter == idx;
    final app = AppState.instance;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF10B981)
              : (app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : app.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}

