import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/radio_station.dart';
import '../services/app_state.dart';
import '../services/radio_controller.dart';
import '../widgets/liquid_glass_container.dart';

class RadioScreen extends StatefulWidget {
  final double topOffset;
  final double bottomOffset;

  const RadioScreen({
    super.key,
    this.topOffset = 90,
    this.bottomOffset = 150,
  });

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final _categories = const [
    {'id': 'All', 'label': '🌟 All Stations (208)'},
    {'id': 'Rajasthan', 'label': '🏜️ Rajasthan (AIR & Regional)'},
    {'id': 'Top FM', 'label': '📻 Live Bollywood FM'},
    {'id': 'Bollywood & Hindi', 'label': '🎵 Bollywood & Hindi'},
    {'id': 'Retro & 90s', 'label': '📼 Retro & 90s'},
    {'id': 'Artists', 'label': '🌸 Artists (लता, किशोर, रफ़ी...)'},
    {'id': 'Bhakti', 'label': '🙏 Bhakti'},
    {'id': 'News', 'label': '📰 News (आज तक, BBC)'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final radio = RadioController.instance;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTabletOrTv = screenWidth > 600;
    final crossAxisCount = isTabletOrTv ? 4 : 2;

    final allStations = RadioStation.stations;
    final filteredStations = allStations.where((s) {
      if (_selectedCategory != 'All' && s.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return s.name.toLowerCase().contains(query) ||
            s.tagline.toLowerCase().contains(query) ||
            s.frequency.toLowerCase().contains(query) ||
            s.category.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, widget.topOffset, 16, math.max(140.0, widget.bottomOffset)),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Header: Live FM Radio India Title, Search & Category Filter
        _buildHeader(context, app, filteredStations.length),

        const SizedBox(height: 14),

        // Radio Error banner if any
        ListenableBuilder(
          listenable: radio,
          builder: (context, _) {
            if (radio.errorMessage == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        radio.errorMessage!,
                        style: TextStyle(color: app.textColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // 2. Radio Stations 2-Column Grid
        if (filteredStations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.radio_rounded, size: 48, color: app.secondaryTextColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(
                    'No stations found',
                    style: TextStyle(color: app.textColor, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredStations.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, i) {
              return _RadioStationGridCard(station: filteredStations[i]);
            },
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppState app, int stationCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '📻 Live FM Radio India',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: app.textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEF4444),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Desh bhar ke live stations sunein',
                  style: TextStyle(
                    fontSize: 12,
                    color: app.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$stationCount Stations',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: app.secondaryTextColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Search Bar for Radio Stations
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          blur: 10,
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: app.secondaryTextColor),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: app.textColor, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search station, singer or city...',
                    hintStyle: TextStyle(color: app.secondaryTextColor.withValues(alpha: 0.7), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchCtrl.clear();
                      _searchQuery = '';
                    });
                  },
                  child: Icon(Icons.close_rounded, size: 18, color: app.secondaryTextColor),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal Category Filter Pills (All, Artists, Top FM, Retro, Bhakti, Rajasthan)
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat['id'];
              return PressableScale(
                pressedScale: 0.94,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCategory = cat['id']!;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? app.accentColor
                        : (app.isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? app.accentColor
                          : Colors.white.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: app.accentColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      cat['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : app.textColor,
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
}

// 2. Radio Station Glass Card (Liquid Glass Design)
class _RadioStationGridCard extends StatelessWidget {
  final RadioStation station;
  const _RadioStationGridCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final radio = RadioController.instance;
    final app = AppState.instance;

    return ListenableBuilder(
      listenable: radio,
      builder: (context, _) {
        final isActive = radio.isStationActive(station.id);
        final isPlaying = radio.isStationPlaying(station.id);
        final isLoading = isActive && radio.isLoading;

        return PressableScale(
          pressedScale: 0.94,
          onTap: () {
            HapticFeedback.lightImpact();
            radio.toggleStation(station);
          },
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(12),
            blur: 0,
            opacity: app.isLight ? 0.85 : 0.12,
            borderWidth: isActive ? 1.5 : 1.0,
            borderColor: isActive
                ? station.color.withValues(alpha: 0.75)
                : (app.isLight
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12)),
            tint: isActive ? station.color.withValues(alpha: 0.12) : null,
            glow: isActive,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 52x52 Round Icon/Logo Container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: station.color.withValues(alpha: 0.15),
                    border: Border.all(
                      color: station.color.withValues(alpha: isPlaying ? 0.6 : 0.25),
                      width: 1.2,
                    ),
                    boxShadow: isPlaying
                        ? [
                            BoxShadow(
                              color: station.color.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isPlaying
                        ? _RadioEqualizerBars(color: station.color)
                        : (station.imageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  station.imageUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    station.icon,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              )
                            : Text(
                                station.icon,
                                style: const TextStyle(fontSize: 24),
                              )),
                  ),
                ),

                const SizedBox(height: 8),

                // Station Name
                Text(
                  station.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isPlaying ? station.color : app.textColor,
                  ),
                ),

                const SizedBox(height: 3),

                // Station Tagline
                Text(
                  station.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: app.secondaryTextColor,
                  ),
                ),

                const SizedBox(height: 8),

                // Live Badge & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? const Color(0xFF00E676)
                            : (isLoading ? const Color(0xFFFFB300) : const Color(0xFFEF4444)),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (isPlaying
                                    ? const Color(0xFF00E676)
                                    : (isLoading
                                        ? const Color(0xFFFFB300)
                                        : const Color(0xFFEF4444)))
                                .withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          else if (isPlaying)
                            const _PulsingDot(color: Colors.white)
                          else
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          const SizedBox(width: 4),
                          Text(
                            isPlaying
                                ? 'PLAYING'
                                : (isLoading ? 'CONNECTING' : '🔴 LIVE'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      station.frequency,
                      style: TextStyle(
                        fontSize: 9,
                        color: app.secondaryTextColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
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
  }
}

// 3. Subtle Pulsing Circle Animation for Connecting/Playing state
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 4. Animated mini equalizer bars for Live playback state
class _RadioEqualizerBars extends StatefulWidget {
  const _RadioEqualizerBars({required this.color});
  final Color color;

  @override
  State<_RadioEqualizerBars> createState() => _RadioEqualizerBarsState();
}

class _RadioEqualizerBarsState extends State<_RadioEqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        final h1 = 6.0 + 14.0 * ((v * 1.3) % 1.0);
        final h2 = 4.0 + 18.0 * (((v + 0.35) * 1.1) % 1.0);
        final h3 = 8.0 + 13.0 * (((v + 0.7) * 1.4) % 1.0);
        final h4 = 5.0 + 16.0 * (((v + 0.2) * 1.2) % 1.0);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [h1, h2, h3, h4].map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3.5,
              height: h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
