import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';

/// Modern Studio Fluid Container:
/// High-performance, zero-lag elevated surface with crisp contrast borders & subtle studio shadow.
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blur = 0,
    this.opacity = 1.0,
    this.borderOpacity = 0.5,
    this.borderWidth = 1.0,
    this.borderColor,
    this.tint,
    this.glow = true,
  });

  /// Fully rounded "capsule" radius (top bar, bottom nav, pills).
  static const BorderRadius capsuleRadius =
      BorderRadius.all(Radius.circular(999));

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  final double blur;
  final double opacity;
  final double borderOpacity;
  final double borderWidth;
  final Color? borderColor;
  final Color? tint;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;

    final baseBg = tint ?? (isLight ? Colors.white : const Color(0xFF131722));
    final borderCol = borderColor ?? (isLight ? const Color(0xFFE2E8F0) : const Color(0x1FFFFFFF));

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderCol,
          width: borderWidth,
        ),
        boxShadow: glow
            ? (isLight
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ])
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Press micro-animation: scale down + opacity dip + haptic tick.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.pressedOpacity = 0.85,
    this.hapticOnDown = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double pressedOpacity;
  final bool hapticOnDown;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              _set(true);
              if (widget.hapticOnDown) HapticFeedback.lightImpact();
            }
          : null,
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap != null
          ? () {
              if (!widget.hapticOnDown) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: Duration(milliseconds: _down ? 110 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _down ? widget.pressedOpacity : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Modern Studio Action Button (round or pill) with high contrast.
class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    super.key,
    this.icon,
    this.onTap,
    this.size = 56,
    this.iconSize,
    this.label,
    this.tint,
  });

  final IconData? icon;
  final VoidCallback? onTap;
  final double size;
  final double? iconSize;
  final String? label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final defaultContentColor = tint != null
        ? Colors.white
        : (isLight ? const Color(0xFF0F172A) : Colors.white);

    final iconWidget = icon != null
        ? Icon(icon, size: iconSize ?? size * 0.48, color: defaultContentColor)
        : null;
    final isPill = label != null;

    final btnBg = tint ?? (isLight ? Colors.white : const Color(0xFF1C2230));
    final btnBorder = isLight ? const Color(0xFFE2E8F0) : const Color(0x28FFFFFF);

    return Opacity(
      opacity: onTap == null ? 0.35 : 1.0,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.88,
        pressedOpacity: 0.7,
        child: Container(
          width: isPill ? null : size,
          height: size,
          padding: isPill ? EdgeInsets.symmetric(horizontal: size * 0.42) : null,
          decoration: BoxDecoration(
            color: btnBg,
            borderRadius: BorderRadius.circular(size),
            border: Border.all(color: btnBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: isPill
              ? Center(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (iconWidget != null) ...[
                        iconWidget,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label!,
                        style: TextStyle(
                          color: defaultContentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(child: iconWidget ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
