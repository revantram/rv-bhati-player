import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../services/yt_music_service.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/ios_bounce_button.dart';
import '../widgets/liquid_background.dart';

class ArtistsHubScreen extends StatefulWidget {
  const ArtistsHubScreen({super.key});

  @override
  State<ArtistsHubScreen> createState() => _ArtistsHubScreenState();
}

class _ArtistsHubScreenState extends State<ArtistsHubScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<BitArtist> _onlineSearchResults = [];
  Timer? _debounceTimer;

  AppState get app => AppState.instance;

  static const List<String> _categories = [
    'All',
    'Modern Hits',
    '90s Icons',
    'Legends',
    'Rajasthani & Folk',
    'Punjabi',
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val.trim());
    _debounceTimer?.cancel();
    if (_searchQuery.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
        final results = await YtMusicService.instance.searchArtists(_searchQuery);
        if (mounted && _searchQuery.isNotEmpty) {
          setState(() {
            _onlineSearchResults = results;
          });
        }
      });
    } else {
      setState(() => _onlineSearchResults = []);
    }
  }

  List<BitArtist> get _filteredArtists {
    var list = YtMusicService.curatedArtists;
    if (_selectedCategory != 'All') {
      list = list.where((a) {
        if (_selectedCategory == 'Punjabi') {
          return a.subtitle.toLowerCase().contains('punjabi') ||
              a.category == 'Punjabi' ||
              a.name.toLowerCase().contains('diljit') ||
              a.name.toLowerCase().contains('sidhu') ||
              a.name.toLowerCase().contains('badshah') ||
              a.name.toLowerCase().contains('honey');
        }
        return a.category == _selectedCategory;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final local = list
          .where((a) =>
              a.name.toLowerCase().contains(q) ||
              a.subtitle.toLowerCase().contains(q))
          .toList();
      final seen = local.map((a) => a.name.toLowerCase()).toSet();
      for (final a in _onlineSearchResults) {
        if (seen.add(a.name.toLowerCase())) {
          local.add(a);
        }
      }
      return local;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;
    final pad = MediaQuery.paddingOf(context);
    final artists = _filteredArtists;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: app.backgroundColor,
        body: LiquidBackground(
          accent: accent,
          child: Column(
            children: [
              // Top App Bar
              Container(
                padding: EdgeInsets.only(
                  top: pad.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  color: app.surfaceColor.withValues(alpha: 0.88),
                  border: Border(
                    bottom: BorderSide(color: app.dividerColor),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        iOSBounceButton(
                          onTap: () => Navigator.pop(context),
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
                                'BitMusic Artists',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                '${YtMusicService.curatedArtists.length} Curated Masters & Legends',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: app.surfaceColorSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: app.cardBorderColor),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 20, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              style: TextStyle(color: textColor, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search artist name...',
                                hintStyle: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: secondaryTextColor,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Category Filter Horizontal Chips
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cat = _categories[i];
                          final isSel = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? accent
                                    : (isLight
                                        ? Colors.black.withValues(alpha: 0.05)
                                        : Colors.white.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSel ? accent : app.cardBorderColor,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : secondaryTextColor,
                                    fontSize: 12.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Artists Grid
              Expanded(
                child: artists.isEmpty
                    ? Center(
                        child: Text(
                          'No artists found for "$_searchQuery"',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: artists.length,
                        itemBuilder: (context, index) {
                          final a = artists[index];
                          return iOSBounceButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ArtistSongsSheet.show(
                                context,
                                artist: a,
                                artistName: a.name,
                                avatarUrl: a.avatarUrl,
                                subtitle: a.subtitle,
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.65),
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      a.avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: accent.withValues(alpha: 0.15),
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 40,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  a.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 10.5,
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
        ),
      ),
    );
  }
}
