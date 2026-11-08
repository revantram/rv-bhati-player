import 'package:flutter/material.dart';

/// Deep gradient + soft colour orbs. Glass panels need something colourful
/// behind them to refract - this is that "wallpaper".
class LiquidBackground extends StatelessWidget {
  const LiquidBackground({super.key, this.accent = const Color(0xFF6C5CE7)});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: accent),
      duration: const Duration(milliseconds: 700),
      builder: (context, color, _) {
        final c = color ?? accent;
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B0F1E), Color(0xFF111736), Color(0xFF0A0D1A)],
                ),
              ),
            ),
            _Orb(alignment: const Alignment(-0.95, -0.75), size: 340, color: c.withValues(alpha: 0.55)),
            _Orb(alignment: const Alignment(1.05, -0.1), size: 300, color: const Color(0xFF00D2FF).withValues(alpha: 0.28)),
            _Orb(alignment: const Alignment(-0.4, 1.05), size: 380, color: const Color(0xFFFF4D9D).withValues(alpha: 0.26)),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.alignment, required this.size, required this.color});

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
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
