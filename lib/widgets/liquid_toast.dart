import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import 'liquid_glass_container.dart';

class LiquidToast {
  LiquidToast._();

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color? iconColor,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    HapticFeedback.lightImpact();
    final app = AppState.instance;
    final isLight = app.isLight;
    final accent = iconColor ?? app.accentColor;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        padding: EdgeInsets.zero,
        content: Center(
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            blur: 20,
            glow: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isLight ? Colors.black87 : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
