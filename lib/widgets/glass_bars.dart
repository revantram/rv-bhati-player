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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      opacity: isLight ? 0.80 : 0.16,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: i == index
                              ? (isLight
                                  ? accent.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.20))
                              : Colors.transparent,
                          border: Border.all(
                            color: i == index
                                ? (isLight
                                    ? accent.withValues(alpha: 0.40)
                                    : Colors.white.withValues(alpha: 0.35))
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          items[i].icon,
                          size: 22,
                          color: i == index
                              ? (isLight ? accent : Colors.white)
                              : (isLight ? app.secondaryTextColor : Colors.white60),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].label,
                            maxLines: 1,
                            style: TextStyle(
                              color: i == index
                                  ? (isLight ? accent : Colors.white)
                                  : (isLight ? app.secondaryTextColor : Colors.white60),
                              fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 11,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
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

/// Native material page route supporting Android predictive back gestures & swipe back
Route<T> glassRoute<T>(Widget page) {
  return MaterialPageRoute<T>(builder: (_) => page);
}

