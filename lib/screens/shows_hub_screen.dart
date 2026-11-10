import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/online_song.dart';
import '../services/aawaz_service.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/desifm_service.dart';
import '../services/download_service.dart';
import '../services/osho_service.dart';
import '../widgets/ios_bounce_button.dart';
import 'audio_player_screen.dart';

class ShowsHubScreen extends StatefulWidget {
  const ShowsHubScreen({super.key});

  @override
  State<ShowsHubScreen> createState() => _ShowsHubScreenState();
}

class _ShowsHubScreenState extends State<ShowsHubScreen> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  AppState get app => AppState.instance;

  // Osho state
  List<OshoSeries> _oshoSeries = [];
  bool _isLoadingOsho = false;
  OshoSeries? _selectedOshoSeries;
  List<OshoTrack> _oshoTracks = [];
  bool _isLoadingOshoTracks = false;

  // Desi FM state
  List<DesiFmSeries> _desiFmSeries = [];
  bool _isLoadingDesiFm = false;
  DesiFmSeries? _selectedDesiSeries;
  List<DesiFmEpisode> _desiEpisodes = [];
  bool _isLoadingDesiEpisodes = false;

  // Aawaz state
  List<AawazShow> _aawazShows = [];
  bool _isLoadingAawaz = false;
  AawazShow? _selectedAawazShow;
  List<AawazEpisode> _aawazEpisodes = [];
  bool _isLoadingAawazEpisodes = false;

  static const List<String> _categories = [
    '🧘 Osho World (ओशो अमृतवाणी)',
    '📻 Desi FM Series (देसी एफएम)',
    '🎙️ Aawaz Shows (आवाज़ हिन्दी)',
  ];

  @override
  void initState() {
    super.initState();
    _loadOshoSeries();
    _loadDesiFmSeries();
    _loadAawazShows();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOshoSeries({bool force = false}) async {
    setState(() => _isLoadingOsho = true);
    final list = await OshoService.instance.fetchHindiSeries(forceRefresh: force);
    if (mounted) {
      setState(() {
        _oshoSeries = list;
        _isLoadingOsho = false;
      });
    }
  }

  Future<void> _loadDesiFmSeries({bool force = false}) async {
    setState(() => _isLoadingDesiFm = true);
    final list = await DesiFmService.instance.fetchSeriesList(forceRefresh: force);
    if (mounted) {
      setState(() {
        _desiFmSeries = list;
        _isLoadingDesiFm = false;
      });
    }
  }

  Future<void> _loadAawazShows({bool force = false}) async {
    setState(() => _isLoadingAawaz = true);
    final list = await AawazService.instance.fetchHindiShows(forceRefresh: force);
    if (mounted) {
      setState(() {
        _aawazShows = list;
        _isLoadingAawaz = false;
      });
    }
  }

  Future<void> _selectOshoSeries(OshoSeries series) async {
    setState(() {
      _selectedOshoSeries = series;
      _isLoadingOshoTracks = true;
      _oshoTracks = [];
    });

    final tracks = await OshoService.instance.fetchSeriesTracks(series);
    if (mounted) {
      setState(() {
        _oshoTracks = tracks;
        _isLoadingOshoTracks = false;
      });
    }
  }

  Future<void> _selectDesiSeries(DesiFmSeries series) async {
    setState(() {
      _selectedDesiSeries = series;
      _isLoadingDesiEpisodes = true;
      _desiEpisodes = [];
    });

    final episodes = await DesiFmService.instance.fetchSeriesEpisodes(series);
    if (mounted) {
      setState(() {
        _desiEpisodes = episodes;
        _isLoadingDesiEpisodes = false;
      });
    }
  }

  Future<void> _selectAawazShow(AawazShow show) async {
    setState(() {
      _selectedAawazShow = show;
      _isLoadingAawazEpisodes = true;
      _aawazEpisodes = [];
    });

    final episodes = await AawazService.instance.fetchShowEpisodes(show);
    if (mounted) {
      setState(() {
        _aawazEpisodes = episodes;
        _isLoadingAawazEpisodes = false;
      });
    }
  }

  void _playOshoTrack(int index) {
    if (_selectedOshoSeries == null || _oshoTracks.isEmpty) return;
    final onlineSongs = _oshoTracks.map((t) => t.toOnlineSong(_selectedOshoSeries!)).toList();
    AudioController.instance.playOnlineQueue(onlineSongs, index);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AudioPlayerScreen(startPlayback: false),
      ),
    );
  }

  void _playDesiEpisode(int index) {
    if (_selectedDesiSeries == null || _desiEpisodes.isEmpty) return;
    final onlineSongs = _desiEpisodes.map((ep) => ep.toOnlineSong(_selectedDesiSeries!)).toList();
    AudioController.instance.playOnlineQueue(onlineSongs, index);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AudioPlayerScreen(startPlayback: false),
      ),
    );
  }

  void _playAawazEpisode(int index) {
    if (_selectedAawazShow == null || _aawazEpisodes.isEmpty) return;
    final onlineSongs = _aawazEpisodes.map((ep) => ep.toOnlineSong(_selectedAawazShow!)).toList();
    AudioController.instance.playOnlineQueue(onlineSongs, index);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AudioPlayerScreen(startPlayback: false),
      ),
    );
  }

  bool get _isInSubView => _selectedOshoSeries != null || _selectedDesiSeries != null || _selectedAawazShow != null;

  void _closeSubView() {
    setState(() {
      _selectedOshoSeries = null;
      _oshoTracks = [];
      _selectedDesiSeries = null;
      _desiEpisodes = [];
      _selectedAawazShow = null;
      _aawazEpisodes = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;
    final pad = MediaQuery.paddingOf(context);

    String topTitle = 'Shows & Audio Series Hub';
    String topSubtitle = 'Osho World, Desi FM & Aawaz Shows';

    if (_selectedOshoSeries != null) {
      topTitle = _selectedOshoSeries!.title;
      topSubtitle = 'Osho World Hindi Discourses';
    } else if (_selectedDesiSeries != null) {
      topTitle = _selectedDesiSeries!.title;
      topSubtitle = 'Desi FM • ${_selectedDesiSeries!.genre.toUpperCase()}';
    } else if (_selectedAawazShow != null) {
      topTitle = _selectedAawazShow!.title;
      topSubtitle = 'Aawaz Shows • ${_selectedAawazShow!.category}';
    }

    return PopScope(
      canPop: !_isInSubView,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isInSubView) {
          _closeSubView();
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
                color: (isLight ? Colors.white : const Color(0xFF0F172A))
                    .withValues(alpha: 0.95),
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
                          if (_isInSubView) {
                            _closeSubView();
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
                              topTitle,
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
                              topSubtitle,
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
                      if (!_isInSubView)
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: accent),
                          onPressed: () {
                            if (_selectedCategoryIndex == 0) {
                              _loadOshoSeries(force: true);
                            } else if (_selectedCategoryIndex == 1) {
                              _loadDesiFmSeries(force: true);
                            } else {
                              _loadAawazShows(force: true);
                            }
                          },
                        ),
                    ],
                  ),
                  if (!_isInSubView) ...[
                    const SizedBox(height: 12),
                    // Three Category Chips (Osho World, Desi FM Series, Aawaz Shows)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_categories.length, (i) {
                          final isSel = _selectedCategoryIndex == i;
                          return Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : 8,
                              right: i == _categories.length - 1 ? 0 : 8,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedCategoryIndex = i;
                                  _searchCtrl.clear();
                                });
                                if (i == 1 && _desiFmSeries.isEmpty) {
                                  _loadDesiFmSeries();
                                } else if (i == 2 && _aawazShows.isEmpty) {
                                  _loadAawazShows();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? accent
                                      : (isLight
                                          ? Colors.black.withValues(alpha: 0.05)
                                          : Colors.white.withValues(alpha: 0.06)),
                                  borderRadius: BorderRadius.circular(19),
                                  border: Border.all(
                                    color: isSel
                                        ? accent
                                        : (isLight
                                            ? Colors.black.withValues(alpha: 0.08)
                                            : Colors.white.withValues(alpha: 0.1)),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _categories[i],
                                    style: TextStyle(
                                      color: isSel ? Colors.white : secondaryTextColor,
                                      fontSize: 12.5,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: _selectedOshoSeries != null
                  ? _buildOshoSeriesDetail(textColor, secondaryTextColor, accent, isLight)
                  : (_selectedDesiSeries != null
                      ? _buildDesiSeriesDetail(textColor, secondaryTextColor, accent, isLight)
                      : (_selectedAawazShow != null
                          ? _buildAawazShowDetail(textColor, secondaryTextColor, accent, isLight)
                          : (_selectedCategoryIndex == 0
                              ? _buildOshoSection(textColor, secondaryTextColor, accent, isLight)
                              : (_selectedCategoryIndex == 1
                                  ? _buildDesiFmSection(textColor, secondaryTextColor, accent, isLight)
                                  : _buildAawazSection(textColor, secondaryTextColor, accent, isLight))))),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== OSHO SECTION ====================

  Widget _buildOshoSection(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    if (_isLoadingOsho) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accent, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text('Loading Osho World Catalog...', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
          ],
        ),
      );
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _oshoSeries
        : _oshoSeries.where((s) {
            return s.title.toLowerCase().contains(query) || s.slug.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        // Search Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search 170+ Discourses (Geeta, Kabir, Dhyan...)',
                hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: secondaryTextColor, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: secondaryTextColor, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Count row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Series (${filtered.length})',
                style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'oshoworld.com',
                style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ),
        ),

        // Series List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No discourses found', style: TextStyle(color: secondaryTextColor)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return iOSBounceButton(
                      onTap: () => _selectOshoSeries(s),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                s.imageUrl,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 62,
                                  height: 62,
                                  color: accent.withValues(alpha: 0.15),
                                  child: Icon(Icons.self_improvement_rounded, color: accent, size: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${s.count} Discourses',
                                          style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: secondaryTextColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
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

  Widget _buildOshoSeriesDetail(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final s = _selectedOshoSeries!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: (isLight ? Colors.white : const Color(0xFF131A2A)).withValues(alpha: 0.7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  s.imageUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: accent.withValues(alpha: 0.2),
                    child: Icon(Icons.self_improvement_rounded, color: accent, size: 36),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Text('${s.count} Discourse Episodes', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                    const SizedBox(height: 8),
                    if (_oshoTracks.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _playOshoTrack(0),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play All Discourses', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingOshoTracks
              ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5))
              : _oshoTracks.isEmpty
                  ? Center(child: Text('No tracks found', style: TextStyle(color: secondaryTextColor)))
                  : ListenableBuilder(
                      listenable: DownloadService.instance,
                      builder: (context, _) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _oshoTracks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final track = _oshoTracks[idx];
                            final onlineSong = track.toOnlineSong(s);
                            final isDl = DownloadService.instance.isDownloaded(onlineSong.id);
                            final isDownloading = DownloadService.instance.isDownloading(onlineSong.id);

                            return iOSBounceButton(
                              onTap: () => _playOshoTrack(idx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.white : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
                                      child: Center(
                                        child: Text('${idx + 1}', style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${track.duration.inMinutes} mins • High Quality Audio', style: TextStyle(color: secondaryTextColor, fontSize: 11.5)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: isDownloading
                                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                                          : Icon(isDl ? Icons.check_circle_rounded : Icons.download_rounded, color: isDl ? Colors.green : secondaryTextColor, size: 22),
                                      onPressed: () {
                                        if (!isDl && !isDownloading) {
                                          DownloadService.instance.downloadSong(onlineSong);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Downloading: ${track.title}'), backgroundColor: accent),
                                          );
                                        }
                                      },
                                    ),
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ==================== DESI FM SECTION ====================

  Widget _buildDesiFmSection(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    if (_isLoadingDesiFm) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accent, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text('Loading Desi FM Audio Series...', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
          ],
        ),
      );
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _desiFmSeries
        : _desiFmSeries.where((s) {
            return s.title.toLowerCase().contains(query) ||
                s.genre.toLowerCase().contains(query) ||
                s.description.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        // Search Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search Audio Series (Horror, Crime, Drama...)',
                hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: secondaryTextColor, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: secondaryTextColor, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Count row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Desi FM Series (${filtered.length})',
                style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'desifm.app/series',
                style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ),
        ),

        // Series List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No series found', style: TextStyle(color: secondaryTextColor)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return iOSBounceButton(
                      onTap: () => _selectDesiSeries(s),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                s.coverUrl,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: accent.withValues(alpha: 0.15),
                                  child: Icon(Icons.podcasts_rounded, color: accent, size: 30),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          s.genre.toUpperCase(),
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.format_list_numbered_rounded, size: 14, color: accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${s.totalEpisodes} Episodes',
                                        style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '• Desi FM Original',
                                        style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: secondaryTextColor.withValues(alpha: 0.6),
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

  Widget _buildDesiSeriesDetail(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final s = _selectedDesiSeries!;

    return Column(
      children: [
        // Series Banner
        Container(
          padding: const EdgeInsets.all(16),
          color: (isLight ? Colors.white : const Color(0xFF131A2A)).withValues(alpha: 0.7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  s.coverUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: accent.withValues(alpha: 0.2),
                    child: Icon(Icons.podcasts_rounded, color: accent, size: 36),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.genre.toUpperCase()} • ${s.totalEpisodes} Full Episodes',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (_desiEpisodes.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _playDesiEpisode(0),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play All Episodes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Episodes List
        Expanded(
          child: _isLoadingDesiEpisodes
              ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5))
              : _desiEpisodes.isEmpty
                  ? Center(child: Text('No episodes found', style: TextStyle(color: secondaryTextColor)))
                  : ListenableBuilder(
                      listenable: DownloadService.instance,
                      builder: (context, _) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _desiEpisodes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final ep = _desiEpisodes[idx];
                            final onlineSong = ep.toOnlineSong(s);
                            final isDl = DownloadService.instance.isDownloaded(onlineSong.id);
                            final isDownloading = DownloadService.instance.isDownloading(onlineSong.id);

                            final durMin = (ep.durationSeconds / 60).ceil();

                            return iOSBounceButton(
                              onTap: () => _playDesiEpisode(idx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.white : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
                                      child: Center(
                                        child: Text('${ep.episodeNumber}', style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ep.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$durMin mins • Desi FM Audio',
                                            style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: isDownloading
                                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                                          : Icon(isDl ? Icons.check_circle_rounded : Icons.download_rounded, color: isDl ? Colors.green : secondaryTextColor, size: 22),
                                      onPressed: () {
                                        if (!isDl && !isDownloading) {
                                          DownloadService.instance.downloadSong(onlineSong);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Downloading: ${ep.title}'), backgroundColor: accent),
                                          );
                                        }
                                      },
                                    ),
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ==================== AAWAZ SECTION ====================

  Widget _buildAawazSection(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    if (_isLoadingAawaz && _aawazShows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accent, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'Loading Aawaz Hindi Shows...',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _aawazShows
        : _aawazShows.where((s) {
            return s.title.toLowerCase().contains(query) ||
                s.category.toLowerCase().contains(query) ||
                s.description.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        // Search Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search Aawaz Shows (Kahaniyan, Crime, Audiobooks...)',
                hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: secondaryTextColor, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: secondaryTextColor, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Count row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aawaz Hindi Shows (${filtered.length})',
                style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'aawaz.com/category/hindi',
                style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ),
        ),

        // Shows List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No shows found', style: TextStyle(color: secondaryTextColor)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return iOSBounceButton(
                      onTap: () => _selectAawazShow(s),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                s.featuredImageUrl,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: accent.withValues(alpha: 0.15),
                                  child: Icon(Icons.mic_external_on_rounded, color: accent, size: 30),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (s.category.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            s.category.toUpperCase(),
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.description.isNotEmpty ? s.description : 'Hindi audio show on Aawaz.com',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.format_list_numbered_rounded, size: 14, color: accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.totalEpisodes > 0 ? '${s.totalEpisodes} Episodes' : 'Audio Series',
                                        style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '• Aawaz Original',
                                        style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: secondaryTextColor.withValues(alpha: 0.6),
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

  Widget _buildAawazShowDetail(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final s = _selectedAawazShow!;

    return Column(
      children: [
        // Show Banner
        Container(
          padding: const EdgeInsets.all(16),
          color: (isLight ? Colors.white : const Color(0xFF131A2A)).withValues(alpha: 0.7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  s.featuredImageUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: accent.withValues(alpha: 0.2),
                    child: Icon(Icons.mic_external_on_rounded, color: accent, size: 36),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.category.toUpperCase()} • ${_aawazEpisodes.length} Episodes Available',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (_aawazEpisodes.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _playAawazEpisode(0),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play All Episodes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Episodes List
        Expanded(
          child: _isLoadingAawazEpisodes
              ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5))
              : _aawazEpisodes.isEmpty
                  ? Center(child: Text('No episodes found', style: TextStyle(color: secondaryTextColor)))
                  : ListenableBuilder(
                      listenable: DownloadService.instance,
                      builder: (context, _) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _aawazEpisodes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final ep = _aawazEpisodes[idx];
                            final onlineSong = ep.toOnlineSong(s);
                            final isDl = DownloadService.instance.isDownloaded(onlineSong.id);
                            final isDownloading = DownloadService.instance.isDownloading(onlineSong.id);

                            final durMin = ep.durationSeconds > 0 ? (ep.durationSeconds / 60).ceil() : null;

                            return iOSBounceButton(
                              onTap: () => _playAawazEpisode(idx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.white : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.07),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
                                      child: Center(
                                        child: Text('${ep.episodeNumber}', style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ep.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            durMin != null ? '$durMin mins • Aawaz Hindi' : 'Aawaz Hindi Audio',
                                            style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: isDownloading
                                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                                          : Icon(isDl ? Icons.check_circle_rounded : Icons.download_rounded, color: isDl ? Colors.green : secondaryTextColor, size: 22),
                                      onPressed: () {
                                        if (!isDl && !isDownloading) {
                                          DownloadService.instance.downloadSong(onlineSong);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Downloading: ${ep.title}'), backgroundColor: accent),
                                          );
                                        }
                                      },
                                    ),
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
