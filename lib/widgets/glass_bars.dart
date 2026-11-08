import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import 'liquid_glass_container.dart';

/// Floating frosted capsule used as the top app bar.
class GlassTopBar extends StatelessWidget {
  const GlassTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: app.textColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
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
          ),
          ...actions,
        ],
      ),
    );
  }
}

class GlassNavItem {
  const GlassNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Floating frosted capsule bottom navigation bar.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<GlassNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final accent = app.accentColor;

    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.all(6),
      opacity: isLight ? 0.75 : 0.12,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i != index) {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: i == index
                        ? (isLight
                            ? accent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.20))
                        : Colors.transparent,
                    border: Border.all(
                      color: i == index
                          ? (isLight
                              ? accent.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.35))
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 24,
                        color: i == index
                            ? (isLight ? accent : Colors.white)
                            : (isLight ? app.secondaryTextColor : Colors.white60),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: i == index
                            ? Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  items[i].label,
                                  style: TextStyle(
                                    color: isLight ? accent : Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft fade + scale page transition (iOS-ish).
Route<T> glassRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
