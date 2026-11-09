import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/format.dart';
import 'liquid_glass_container.dart';

/// Sleek Android 13/14-style squiggly wave seek bar inside a glass capsule.
/// Waves animate smoothly when music plays, and flatten to a straight line when paused.
class GlassSeekBar extends StatefulWidget {
  const GlassSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.isPlaying = false,
    this.accent = Colors.white,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool isPlaying;
  final Color accent;

  @override
  State<GlassSeekBar> createState() => _GlassSeekBarState();
}

class _GlassSeekBarState extends State<GlassSeekBar> with TickerProviderStateMixin {
  late AnimationController _phaseController;
  late AnimationController _amplitudeController;
  late Animation<double> _amplitudeAnimation;

  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    // Continuous flowing phase animation for waves
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Smooth transition between wavy (1.0) and straight line (0.0)
    _amplitudeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
    _amplitudeAnimation = CurvedAnimation(
      parent: _amplitudeController,
      curve: Curves.easeInOut,
    );

    if (widget.isPlaying) {
      _phaseController.repeat();
      _amplitudeController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant GlassSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_phaseController.isAnimating) {
          _phaseController.repeat();
        }
        _amplitudeController.forward();
      } else {
        _amplitudeController.reverse().then((_) {
          if (!widget.isPlaying && mounted) {
            _phaseController.stop();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _amplitudeController.dispose();
    super.dispose();
  }

  void _onSeekFromOffset(double localDx, double width) {
    if (width <= 0) return;
    final frac = (localDx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = frac);
  }

  void _finalizeSeek(double width) {
    if (_dragFraction != null) {
      final totalMs = math.max(widget.duration.inMilliseconds, 1);
      final targetMs = (_dragFraction! * totalMs).round();
      widget.onSeek(Duration(milliseconds: targetMs));
      setState(() => _dragFraction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = math.max(widget.duration.inMilliseconds, 1).toDouble();
    final currentMs = (_dragFraction != null
            ? (_dragFraction! * totalMs)
            : widget.position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs);
    final progressFraction = (currentMs / totalMs).clamp(0.0, 1.0);

    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.88),
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Elapsed time
          Text(
            formatDuration(Duration(milliseconds: currentMs.round())),
            style: style,
          ),
          const SizedBox(width: 8),

          // Squiggly interactive wave track
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragDown: (details) {
                    HapticFeedback.selectionClick();
                    _onSeekFromOffset(details.localPosition.dx, trackWidth);
                  },
                  onHorizontalDragUpdate: (details) {
                    _onSeekFromOffset(details.localPosition.dx, trackWidth);
                  },
                  onHorizontalDragEnd: (details) {
                    HapticFeedback.lightImpact();
                    _finalizeSeek(trackWidth);
                  },
                  onHorizontalDragCancel: () {
                    setState(() => _dragFraction = null);
                  },
                  onTapDown: (details) {
                    HapticFeedback.selectionClick();
                    _onSeekFromOffset(details.localPosition.dx, trackWidth);
                  },
                  onTapUp: (details) {
                    HapticFeedback.lightImpact();
                    _finalizeSeek(trackWidth);
                  },
                  child: SizedBox(
                    height: 32,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_phaseController, _amplitudeAnimation]),
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(trackWidth, 32),
                          painter: _SquigglyTrackPainter(
                            progress: progressFraction,
                            wavePhase: _phaseController.value * 2 * math.pi,
                            waveHeightFactor: _amplitudeAnimation.value,
                            activeColor: widget.accent,
                            inactiveColor: Colors.white.withValues(alpha: 0.22),
                            thumbColor: Colors.white,
                            isDragging: _dragFraction != null,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // Total duration
          Text(
            formatDuration(widget.duration),
            style: style,
          ),
        ],
      ),
    );
  }
}

class _SquigglyTrackPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final double wavePhase;
  final double waveHeightFactor;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final bool isDragging;

  _SquigglyTrackPainter({
    required this.progress,
    required this.wavePhase,
    required this.waveHeightFactor,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final totalWidth = size.width;
    final currentX = (totalWidth * progress).clamp(0.0, totalWidth);
    const trackHeight = 3.8;
    final thumbRadius = isDragging ? 8.5 : 7.0;

    // 1. Inactive Track (from thumb to end) - sleek straight line with round caps
    if (currentX < totalWidth) {
      final inactivePaint = Paint()
        ..color = inactiveColor
        ..strokeWidth = trackHeight
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(currentX, centerY),
        Offset(totalWidth, centerY),
        inactivePaint,
      );
    }

    // 2. Active Track (from start to thumb)
    if (currentX > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = trackHeight
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (waveHeightFactor > 0.01) {
        // Draw squiggly wave (Android 13/14 style)
        final path = Path();
        path.moveTo(0, centerY);

        const wavelength = 20.0;
        final maxAmplitude = 3.6 * waveHeightFactor;
        const step = 2.0;

        for (double x = 0; x <= currentX; x += step) {
          // Dampen amplitude at start and near the thumb for a seamless connection
          double damp = 1.0;
          if (x < 6.0) {
            damp = x / 6.0;
          } else if (currentX - x < 6.0) {
            damp = (currentX - x) / 6.0;
          }
          final y = centerY + math.sin((x / wavelength) * 2 * math.pi - wavePhase) * maxAmplitude * damp;
          path.lineTo(x, y);
        }
        path.lineTo(currentX, centerY);
        canvas.drawPath(path, activePaint);
      } else {
        // Smooth straight line when paused
        canvas.drawLine(
          Offset(0, centerY),
          Offset(currentX, centerY),
          activePaint,
        );
      }
    }

    // 3. Thumb Knob (matching white glowing circular knob)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(currentX, centerY + 1), thumbRadius, shadowPaint);

    final thumbPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, centerY), thumbRadius, thumbPaint);

    // Subtle accent center dot in thumb
    final innerDotPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, centerY), thumbRadius * 0.35, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _SquigglyTrackPainter old) {
    return old.progress != progress ||
        old.wavePhase != wavePhase ||
        old.waveHeightFactor != waveHeightFactor ||
        old.activeColor != activeColor ||
        old.isDragging != isDragging;
  }
}
