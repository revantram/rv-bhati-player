import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import 'liquid_glass_container.dart';

/// Floating BitChord frosted capsule used as the top app bar.
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
      blur: 18,
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
                      letterSpacing: -0.2,
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

/// BitChord Apple Music-inspired frosted capsule bottom navigation bar.
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

    final navBg = isLight
        ? (app.isIosLiquid
            ? Colors.white.withValues(alpha: 0.96)
            : const Color(0xFFFFFFFF).withValues(alpha: 0.95))
        : (app.isOled
            ? const Color(0xFF000000).withValues(alpha: 0.96)
            : app.surfaceColor.withValues(alpha: 0.95));

    return LiquidGlassContainer(
      borderRadius: LiquidGlassContainer.capsuleRadius,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      blur: 22,
      tint: navBg,
      borderWidth: 1.1,
      borderColor: isLight
          ? (app.isIosLiquid ? const Color(0xFF0088FF).withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08))
          : Colors.white.withValues(alpha: 0.15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabCount = items.length;
          final tabWidth = constraints.maxWidth / tabCount;
          final pillWidth = math.min(tabWidth - 6, 68.0);
          final safeIndex = index.clamp(0, tabCount - 1);

          return Stack(
            children: [
              // Smooth sliding active-tab indicator pill underneath selected tab
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: safeIndex * tabWidth + (tabWidth - pillWidth) / 2,
                top: 2,
                width: pillWidth,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: isLight ? 0.20 : 0.28),
                        accent.withValues(alpha: isLight ? 0.08 : 0.15),
                      ],
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.65),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Interactive Tab Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < tabCount; i++)
                    Expanded(
                      flex: 1,
                      child: PressableScale(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          if (i != index) {
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          }
                        },
                        child: SizedBox(
                          height: 48,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                items[i].icon,
                                size: 21,
                                color: i == safeIndex
                                    ? accent
                                    : (isLight ? const Color(0xFF64748B) : Colors.white70),
                              ),
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Text(
                                    items[i].label,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: i == safeIndex
                                          ? accent
                                          : (isLight ? const Color(0xFF64748B) : Colors.white70),
                                      fontWeight: i == safeIndex ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 10,
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
            ],
          );
        },
      ),
    );
  }
}

Route<T> glassRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}
