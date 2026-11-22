import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../services/settings_service.dart';

/// BitChord Dynamic Liquid Backdrop:
/// Generates tailored atmospheric mesh radial gradients for Pure OLED, Cyberpunk Neon,
/// Royal Obsidian Gold, Cosmic Aurora, Sunset Bliss, and Apple Light themes.
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
    final mode = SettingsService.instance.themeMode;
    final isLight = app.isLight;
    final glowColor = accent ?? app.accentColor;

    final Gradient gradient;
    if (mode == AppThemeMode.iosLiquid) {
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE0F2FE), // Soft ice blue
          Color(0xFFFFFFFF), // Pure white
          Color(0xFFF0F9FF), // Light sky mist
        ],
        stops: [0.0, 0.45, 1.0],
      );
    } else if (isLight) {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(const Color(0xFFFFFFFF), glowColor, 0.05)!,
          const Color(0xFFF5F7FA),
          const Color(0xFFEEF2F7),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    } else {
      switch (mode) {
        case AppThemeMode.cyberpunk:
          gradient = RadialGradient(
            center: const Alignment(0.0, -0.85),
            radius: 1.35,
            colors: [
              glowColor.withValues(alpha: 0.22),
              const Color(0xFF00F0FF).withValues(alpha: 0.12),
              const Color(0xFF0A0F22),
              const Color(0xFF060814),
            ],
            stops: const [0.0, 0.35, 0.70, 1.0],
          );
          break;
        case AppThemeMode.royalGold:
          gradient = RadialGradient(
            center: const Alignment(0.0, -0.85),
            radius: 1.35,
            colors: [
              const Color(0xFFFFB800).withValues(alpha: 0.20),
              glowColor.withValues(alpha: 0.12),
              const Color(0xFF13100B),
              const Color(0xFF080705),
            ],
            stops: const [0.0, 0.35, 0.70, 1.0],
          );
          break;
        case AppThemeMode.aurora:
          gradient = RadialGradient(
            center: const Alignment(0.0, -0.85),
            radius: 1.35,
            colors: [
              const Color(0xFFA855F7).withValues(alpha: 0.22),
              const Color(0xFF06B6D4).withValues(alpha: 0.12),
              const Color(0xFF100B2B),
              const Color(0xFF070517),
            ],
            stops: const [0.0, 0.35, 0.70, 1.0],
          );
          break;
        case AppThemeMode.sunsetBliss:
          gradient = RadialGradient(
            center: const Alignment(0.0, -0.85),
            radius: 1.35,
            colors: [
              const Color(0xFFFF5E62).withValues(alpha: 0.22),
              const Color(0xFFFFA07A).withValues(alpha: 0.12),
              const Color(0xFF180B1E),
              const Color(0xFF0E0612),
            ],
            stops: const [0.0, 0.35, 0.70, 1.0],
          );
          break;
        case AppThemeMode.oled:
        case AppThemeMode.system:
          gradient = RadialGradient(
            center: const Alignment(0.0, -0.85),
            radius: 1.25,
            colors: [
              glowColor.withValues(alpha: 0.15),
              const Color(0xFF060609),
              const Color(0xFF000000),
            ],
            stops: const [0.0, 0.45, 1.0],
          );
          break;
        case AppThemeMode.dark:
        default:
          gradient = RadialGradient(
            center: const Alignment(0.0, -0.85),
            radius: 1.25,
            colors: [
              glowColor.withValues(alpha: 0.16),
              const Color(0xFF0E1017),
              const Color(0xFF0B0C10),
            ],
            stops: const [0.0, 0.5, 1.0],
          );
          break;
      }
    }

    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: app.backgroundColor,
          gradient: gradient,
        ),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}
