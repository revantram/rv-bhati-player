import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Optional colour tint for the glass (e.g. accent play button).
  final Color? tint;

  /// Soft shadow + white halo around the panel.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? Colors.white;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.04),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        foregroundPainter: _GlassBorderPainter(
          radius: borderRadius,
          width: borderWidth,
          opacity: borderOpacity,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    base.withValues(alpha: (opacity + 0.10).clamp(0.0, 1.0)),
                    base.withValues(alpha: (opacity * 0.6).clamp(0.0, 1.0)),
                  ],
                ),
              ),
              child: child,
            ),
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
  });

  final BorderRadius radius;
  final double width;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: opacity),
          Colors.white.withValues(alpha: opacity * 0.12),
          Colors.white.withValues(alpha: opacity * 0.5),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter old) =>
      old.radius != radius || old.width != width || old.opacity != opacity;
}

/// Press micro-animation: scale down + opacity dip + iOS-like haptic tick.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.pressedOpacity = 0.85,
    this.hapticOnDown = true,
  });

  final Widget child;
  final VoidCallback? onTap;
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
    final enabled = widget.onTap != null;
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
      onTap: enabled
          ? () {
              if (!widget.hapticOnDown) HapticFeedback.selectionClick();
              widget.onTap!();
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
    required this.icon,
    this.onTap,
    this.size = 56,
    this.iconSize,
    this.label,
    this.tint,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double? iconSize;
  final String? label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: iconSize ?? size * 0.48, color: Colors.white);
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
          opacity: tint == null ? 0.14 : 0.28,
          tint: tint,
          padding: isPill ? EdgeInsets.symmetric(horizontal: size * 0.42) : null,
          child: isPill
              ? Center(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(width: 8),
                      Text(
                        label!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(child: iconWidget),
        ),
      ),
    );
  }
}
