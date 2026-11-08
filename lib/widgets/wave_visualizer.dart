import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/app_state.dart';

/// Animated Apple iOS style audio waveform visualizer.
/// Displays bouncy, sleek vertical bars that animate while playing
/// and gracefully rest when paused.
class WaveVisualizer extends StatefulWidget {
  const WaveVisualizer({
    super.key,
    this.barCount = 4,
    this.height = 20,
    this.barWidth = 3,
    this.spacing = 2.5,
    this.color,
    this.isPlaying = true,
  });

  final int barCount;
  final double height;
  final double barWidth;
  final double spacing;
  final Color? color;
  final bool isPlaying;

  @override
  State<WaveVisualizer> createState() => _WaveVisualizerState();
}

class _WaveVisualizerState extends State<WaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppState.instance.accentColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              // Wave height based on sin/cos waves with phase offset for each bar
              double factor;
              if (widget.isPlaying) {
                final phase = i * (math.pi / widget.barCount) * 1.5;
                final raw = (math.sin(t * 1.4 + phase) + math.cos(t * 0.8 + phase * 2)) / 2;
                factor = 0.25 + 0.75 * ((raw + 1) / 2);
              } else {
                factor = 0.25;
              }

              final barH = (widget.height * factor).clamp(widget.height * 0.15, widget.height);

              return Container(
                margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                width: widget.barWidth,
                height: barH,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: widget.isPlaying ? 0.95 : 0.45),
                  borderRadius: BorderRadius.circular(widget.barWidth),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
