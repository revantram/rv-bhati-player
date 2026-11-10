import 'package:flutter/material.dart';

import '../services/app_state.dart';

/// Modern Studio Fluid Background:
/// High-performance, zero-lag background with deep AMOLED Black / Crisp Porcelain White.
class LiquidBackground extends StatelessWidget {
  const LiquidBackground({
    super.key,
    this.accent = const Color(0xFF7C6CFF),
    this.child,
  });

  final Color accent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;

    return Container(
      decoration: BoxDecoration(
        color: app.backgroundColor,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight
              ? const [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8FAFC),
                  Color(0xFFF1F5F9),
                ]
              : const [
                  Color(0xFF0F1420),
                  Color(0xFF090D16),
                  Color(0xFF06090F),
                ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: child,
    );
  }
}
