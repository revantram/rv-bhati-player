import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/app_state.dart';

/// Dynamic Mesh Gradient / Fluid Background:
/// Smoothly animates soft ambient liquid color blobs behind white or dark frosted glass.
class LiquidBackground extends StatefulWidget {
  const LiquidBackground({
    super.key,
    this.accent = const Color(0xFF7C6CFF),
    this.child,
  });

  final Color accent;
  final Widget? child;

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppState.instance.isLight;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        final c = widget.accent;

        // Base gradient
        final baseColors = isLight
            ? const [
                Color(0xFFF2F4F7),
                Color(0xFFE5E9F0),
                Color(0xFFECEEF3),
              ]
            : const [
                Color(0xFF0B0F1E),
                Color(0xFF111736),
                Color(0xFF0A0D1A),
              ];

        // Animated orb positions
        final orb1Align = Alignment(
          -0.8 + 0.2 * math.sin(t * 2 * math.pi),
          -0.7 + 0.15 * math.cos(t * 2 * math.pi),
        );
        final orb2Align = Alignment(
          0.9 - 0.2 * math.cos(t * 2 * math.pi),
          -0.1 + 0.25 * math.sin(t * 2 * math.pi),
        );
        final orb3Align = Alignment(
          -0.3 + 0.25 * math.cos(t * 2 * math.pi),
          0.9 - 0.15 * math.sin(t * 2 * math.pi),
        );

        final orb1Alpha = isLight ? 0.22 : 0.45;
        final orb2Alpha = isLight ? 0.16 : 0.25;
        final orb3Alpha = isLight ? 0.15 : 0.22;

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: baseColors,
                ),
              ),
            ),
            // Orb 1: Dynamic Theme Accent
            _Orb(
              alignment: orb1Align,
              size: 360,
              color: c.withValues(alpha: orb1Alpha),
            ),
            // Orb 2: Cyan Ambient
            _Orb(
              alignment: orb2Align,
              size: 320,
              color: const Color(0xFF00D2FF).withValues(alpha: orb2Alpha),
            ),
            // Orb 3: Pink Ambient
            _Orb(
              alignment: orb3Align,
              size: 380,
              color: const Color(0xFFFF2A85).withValues(alpha: orb3Alpha),
            ),
            if (widget.child != null)
              Positioned.fill(child: widget.child!),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
