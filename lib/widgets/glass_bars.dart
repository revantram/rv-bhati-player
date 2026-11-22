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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      blur: 22,
      tint: navBg,
      borderWidth: 1.1,
      borderColor: isLight
          ? (app.isIosLiquid ? const Color(0xFF0088FF).withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08))
          : Colors.white.withValues(alpha: 0.15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              flex: 1,
              child: PressableScale(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (i != index) {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  }
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 48,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: i == index
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accent.withValues(alpha: isLight ? 0.22 : 0.28),
                                    accent.withValues(alpha: isLight ? 0.12 : 0.18),
                                  ],
                                )
                              : null,
                          border: Border.all(
                            color: i == index
                                ? accent.withValues(alpha: 0.55)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                          boxShadow: i == index
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            items[i].icon,
                            size: 20,
                            color: i == index
                                ? accent
                                : (isLight ? const Color(0xFF4B5563) : Colors.white60),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
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
                              color: i == index
                                  ? accent
                                  : (isLight ? const Color(0xFF4B5563) : Colors.white60),
                              fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
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
    );
  }
}

Route<T> glassRoute<T>(Widget page) {
  return MaterialPageRoute<T>(builder: (_) => page);
}
