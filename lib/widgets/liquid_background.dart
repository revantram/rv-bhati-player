import 'package:flutter/material.dart';

import '../services/app_state.dart';

/// BitChord Apple Music-inspired Backdrop:
/// Combines Pure OLED Black (#000000), Apple Dark (#0B0C10), or Crisp Light (#F5F7FA)
/// with a smooth subtle radial ambient glow matching the active accent/artwork color.
class LiquidBackground extends StatelessWidget {
  const LiquidBackground({
    super.key,
    this.accent,
    this.child,
  });

  final Color? accent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final isOled = app.isOled;
    final glowColor = accent ?? app.accentColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: app.backgroundColor,
        gradient: isLight
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFFFFFFFF), glowColor, 0.04)!,
                  const Color(0xFFF5F7FA),
                  const Color(0xFFEEF2F7),
                ],
                stops: const [0.0, 0.5, 1.0],
              )
            : (isOled
                ? RadialGradient(
                    center: const Alignment(0.0, -0.85),
                    radius: 1.25,
                    colors: [
                      glowColor.withValues(alpha: 0.14),
                      const Color(0xFF060609),
                      const Color(0xFF000000),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  )
                : RadialGradient(
                    center: const Alignment(0.0, -0.85),
                    radius: 1.25,
                    colors: [
                      glowColor.withValues(alpha: 0.16),
                      const Color(0xFF0E1017),
                      const Color(0xFF0B0C10),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  )),
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}
