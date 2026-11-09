import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';

/// Reusable Apple-iOS style "Liquid Glass" panel:
/// frosted blur (ImageFilter.blur 15/15) + translucent gradient fill +
/// glowing gradient border.
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blur = 15,
    this.opacity = 0.12,
    this.borderOpacity = 0.45,
    this.borderWidth = 1.2,
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

  /// Blur sigma (sigmaX = sigmaY). Default 15 as per design.
  final double blur;

  /// Base white opacity of the glass fill.
  final double opacity;

  /// Peak opacity of the border glow.
  final double borderOpacity;
  final double borderWidth;
  final Color? borderColor;

  /// Optional colour tint for the glass (e.g. accent play button).
  final Color? tint;

  /// Soft shadow + white halo around the panel.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final isLight = AppState.instance.isLight;
    final base = tint ?? (isLight ? Colors.white : const Color(0xFF1E2438));

    final baseOpacity = isLight
        ? (tint != null ? (opacity + 0.35).clamp(0.0, 1.0) : 0.94)
        : (tint != null ? (opacity + 0.20).clamp(0.0, 1.0) : 0.38);
    final borderCol = borderColor ?? (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.16));

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: glow
            ? (isLight
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.04),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                  ])
            : (isLight
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null),
      ),
      child: CustomPaint(
        foregroundPainter: _GlassBorderPainter(
          radius: borderRadius,
          width: isLight ? 1.2 : borderWidth,
          opacity: isLight ? 0.9 : borderOpacity,
          color: borderCol,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: blur > 0
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Container(
                    padding: padding,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          base.withValues(alpha: (baseOpacity + 0.04).clamp(0.0, 1.0)),
                          base.withValues(alpha: (baseOpacity * 0.92).clamp(0.0, 1.0)),
                        ],
                      ),
                    ),
                    child: child,
                  ),
                )
              : Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        base.withValues(alpha: (baseOpacity + 0.08).clamp(0.0, 1.0)),
                        base.withValues(alpha: (baseOpacity * 0.75).clamp(0.0, 1.0)),
                      ],
                    ),
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

/// Gradient "light-catching" border (bright top-left, faint middle, soft
/// bottom-right) - this is what gives the liquid glass edge glow.
class _GlassBorderPainter extends CustomPainter {
  _GlassBorderPainter({
    required this.radius,
    required this.width,
    required this.opacity,
    this.color,
  });

  final BorderRadius radius;
  final double width;
  final double opacity;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(width / 2);
    final baseColor = color ?? Colors.white;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseColor.withValues(alpha: opacity),
          baseColor.withValues(alpha: opacity * 0.12),
          baseColor.withValues(alpha: opacity * 0.5),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter old) =>
      old.radius != radius || old.width != width || old.opacity != opacity || old.color != color;
}

/// Press micro-animation: scale down + opacity dip + iOS-like haptic tick.
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

  /// true  -> light impact the moment the finger lands (buttons)
  /// false -> selection tick on tap only (list cards, so scrolling is silent)
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

/// Floating Liquid Glass bubble (round) or pill (when [label] is given).
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
    final isLight = AppState.instance.isLight;
    final defaultContentColor = isLight
        ? (tint != null ? Colors.white : const Color(0xFF0F172A))
        : Colors.white;

    final iconWidget = icon != null
        ? Icon(icon, size: iconSize ?? size * 0.48, color: defaultContentColor)
        : null;
    final isPill = label != null;
    return Opacity(
      opacity: onTap == null ? 0.35 : 1.0,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.86,
        pressedOpacity: 0.6,
        child: LiquidGlassContainer(
          width: isPill ? null : size,
          height: size,
          borderRadius: BorderRadius.circular(size),
          opacity: isLight ? (tint == null ? 0.94 : 0.96) : (tint == null ? 0.25 : 0.40),
          tint: tint,
          glow: true,
          padding: isPill ? EdgeInsets.symmetric(horizontal: size * 0.42) : null,
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
