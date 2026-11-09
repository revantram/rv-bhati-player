import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/radio_station.dart';
import '../services/app_state.dart';
import '../services/radio_controller.dart';
import '../widgets/liquid_glass_container.dart';

class RadioScreen extends StatelessWidget {
  final double topOffset;
  final double bottomOffset;

  const RadioScreen({
    super.key,
    this.topOffset = 90,
    this.bottomOffset = 150,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final radio = RadioController.instance;

    return ListView(
      // 1. Bottom Clearance Fix: Ensures last station card is never obscured by mini-player
      padding: EdgeInsets.fromLTRB(16, topOffset, 16, math.max(140.0, bottomOffset)),
      children: [
        // 4. Top Header Optimization: Sleek compact frosted glass header & Quick Stations row
        _buildQuickHeader(context, app, radio),
        const SizedBox(height: 16),

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

        // Section 1: Rajasthan Regional Stations
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.location_on_rounded, size: 19, color: app.accentColor),
              const SizedBox(width: 6),
              Text(
                'Rajasthan & Regional Stations',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...RadioStation.stations
            .where((s) => s.category.contains('Rajasthan'))
            .map((s) => _FrostedRadioStationCard(station: s)),

        const SizedBox(height: 16),

        // Section 2: National AIR & Live FM
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.podcasts_rounded, size: 19, color: app.accentColor),
              const SizedBox(width: 6),
              Text(
                'National AIR & Live FM',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: app.textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...RadioStation.stations
            .where((s) => !s.category.contains('Rajasthan'))
            .map((s) => _FrostedRadioStationCard(station: s)),
      ],
    );
  }

  // 4. Compact Sleek Glass Header & Quick Recent Stations Row
  Widget _buildQuickHeader(BuildContext context, AppState app, RadioController radio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          blur: 16,
          opacity: 0.12,
          borderWidth: 1,
          borderColor: Colors.white.withValues(alpha: 0.15),
          tint: app.accentColor.withValues(alpha: 0.08),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [app.accentColor, const Color(0xFF00D2FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: app.accentColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.podcasts_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          app.tr('radio'),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: app.textColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'HD 24x7',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF00E676), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Direct low-latency streams with background playback',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: app.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick Station Circles Horizontal Row
        SizedBox(
          height: 62,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: RadioStation.stations.length,
            itemBuilder: (context, i) {
              final station = RadioStation.stations[i];
              return ListenableBuilder(
                listenable: radio,
                builder: (context, _) {
                  final isPlaying = radio.isStationPlaying(station.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: PressableScale(
                      pressedScale: 0.92,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        radio.toggleStation(station);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? station.color.withValues(alpha: 0.22)
                              : (app.isLight
                                  ? Colors.black.withValues(alpha: 0.04)
                                  : Colors.white.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isPlaying
                                ? station.color.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1.2,
                          ),
                          boxShadow: isPlaying
                              ? [
                                  BoxShadow(
                                    color: station.color.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: station.color.withValues(alpha: 0.85),
                              ),
                              child: Center(
                                child: isPlaying
                                    ? const Icon(Icons.equalizer_rounded, color: Colors.white, size: 18)
                                    : const Icon(Icons.radio_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  station.name.split('(').first.trim(),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                                    color: isPlaying ? station.color : app.textColor,
                                  ),
                                ),
                                Text(
                                  station.frequency,
                                  style: TextStyle(
                                    fontSize: 10,
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
              );
            },
          ),
        ),
      ],
    );
  }
}

// 2. Frosted Station Card with Liquid Glassmorphism & Animations
class _FrostedRadioStationCard extends StatelessWidget {
  const _FrostedRadioStationCard({required this.station});
  final RadioStation station;

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

        // 5. Card Interaction: Smooth spring-scale haptic feedback
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PressableScale(
            pressedScale: 0.96,
            onTap: () {
              HapticFeedback.lightImpact();
              radio.toggleStation(station);
            },
            child: LiquidGlassContainer(
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.all(12),
              blur: 16,
              opacity: 0.10,
              borderWidth: 1,
              borderColor: isActive
                  ? station.color.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
              tint: isActive ? station.color.withValues(alpha: 0.12) : null,
              glow: true,
              child: Row(
                children: [
                  // 2. Frosted Icon Box: Semi-transparent frosted glass + ambient glow
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          station.color.withValues(alpha: 0.35),
                          station.color.withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(
                        color: station.color.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: station.color.withValues(alpha: isPlaying ? 0.40 : 0.15),
                          blurRadius: isPlaying ? 16 : 10,
                          spreadRadius: isPlaying ? 1 : 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isPlaying
                          ? _RadioEqualizerBars(color: station.color)
                          : Icon(
                              Icons.radio_rounded,
                              size: 32,
                              color: station.color,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Middle: Station Info & Status Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            // 3. Live / Connecting State Pill with Pulsing Animation
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isPlaying
                                    ? const Color(0xFF00E676).withValues(alpha: 0.20)
                                    : (isLoading
                                        ? const Color(0xFFFFD600).withValues(alpha: 0.20)
                                        : (app.isLight
                                            ? Colors.black.withValues(alpha: 0.05)
                                            : Colors.white.withValues(alpha: 0.09))),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPlaying
                                      ? const Color(0xFF00E676).withValues(alpha: 0.55)
                                      : (isLoading
                                          ? const Color(0xFFFFD600).withValues(alpha: 0.55)
                                          : (app.isLight
                                              ? Colors.black.withValues(alpha: 0.08)
                                              : Colors.white24)),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLoading)
                                    const _PulsingDot(color: Color(0xFFFFD600))
                                  else
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isPlaying
                                            ? const Color(0xFF00E676)
                                            : app.secondaryTextColor,
                                      ),
                                    ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isPlaying
                                        ? 'LIVE'
                                        : (isLoading ? 'CONNECTING...' : 'ONLINE'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isPlaying
                                          ? const Color(0xFF00E676)
                                          : (isLoading
                                              ? const Color(0xFFFFD600)
                                              : app.secondaryTextColor),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Frequency tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: station.color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                station.frequency,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: station.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          station.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: app.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          station.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: app.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right: Translucent Play / Pause / Loading button
                  LiquidGlassButton(
                    icon: isLoading
                        ? null
                        : (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    size: 44,
                    iconSize: 24,
                    tint: isActive ? station.color : app.accentColor,
                    onTap: () => radio.toggleStation(station),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// 3. Subtle Pulsing Circle Animation for Connecting state
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
            width: 6,
            height: 6,
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

// 3. Animated mini equalizer bars for Live playback state
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
