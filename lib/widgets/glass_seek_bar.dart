import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../utils/format.dart';
import 'liquid_glass_container.dart';

/// Sleek translucent seek bar inside a glass capsule (video + audio).
class GlassSeekBar extends StatefulWidget {
  const GlassSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.accent = Colors.white,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color accent;

  @override
  State<GlassSeekBar> createState() => _GlassSeekBarState();
}

class _GlassSeekBarState extends State<GlassSeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final total = math.max(widget.duration.inMilliseconds, 1).toDouble();
    final current =
        (_drag ?? widget.position.inMilliseconds.toDouble()).clamp(0.0, total).toDouble();
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          Text(formatDuration(Duration(milliseconds: current.round())), style: style),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: widget.accent.withValues(alpha: 0.95),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.14),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: current,
                min: 0,
                max: total,
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  widget.onSeek(Duration(milliseconds: v.round()));
                  setState(() => _drag = null);
                },
              ),
            ),
          ),
          Text(formatDuration(widget.duration), style: style),
        ],
      ),
    );
  }
}
