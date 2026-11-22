import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import 'liquid_glass_container.dart';

/// Tactile, smooth Play/Pause button with iOS 18 Liquid Glass aesthetics,
/// fluid AnimatedIcon morphing (~220ms easeOutCubic curve),
/// strictly synchronized with player playback state, and tactile haptic feedback.
class LiquidGlassPlayPauseButton extends StatefulWidget {
  const LiquidGlassPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onToggle,
    this.size = 56.0,
    this.iconSize,
    this.color,
    this.iconColor,
    this.borderColor,
    this.isGlass = false,
    this.glow = true,
    this.pressedScale = 0.92,
    this.tooltip,
  });

  final bool isPlaying;
  final VoidCallback? onToggle;
  final double size;
  final double? iconSize;
  final Color? color;
  final Color? iconColor;
  final Color? borderColor;
  final bool isGlass;
  final bool glow;
  final double pressedScale;
  final String? tooltip;

  @override
  State<LiquidGlassPlayPauseButton> createState() => _LiquidGlassPlayPauseButtonState();
}

class _LiquidGlassPlayPauseButtonState extends State<LiquidGlassPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant LiquidGlassPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _animCtrl.animateTo(1.0, curve: Curves.easeOutCubic);
      } else {
        _animCtrl.animateTo(0.0, curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final accent = widget.color ?? app.accentColor;
    final iconCol = widget.iconColor ?? (widget.isGlass ? app.textColor : Colors.white);
    final effectiveIconSize = widget.iconSize ?? (widget.size * 0.50);

    final borderWidth = widget.size > 50 ? 1.5 : 1.1;

    final borderCol = widget.borderColor ??
        (widget.isGlass
            ? (isLight ? Colors.white.withValues(alpha: 0.6) : Colors.white12)
            : null);

    Widget content = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isGlass ? null : accent,
        gradient: widget.isGlass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isLight
                      ? Colors.white.withValues(alpha: 0.90)
                      : const Color(0xFF1E2230).withValues(alpha: 0.85),
                  isLight
                      ? const Color(0xFFF0F9FF).withValues(alpha: 0.82)
                      : const Color(0xFF0F121C).withValues(alpha: 0.85),
                ],
              )
            : null,
        border: borderCol != null ? Border.all(color: borderCol, width: 1.0) : null,
        boxShadow: widget.glow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.25),
                  blurRadius: widget.size > 50 ? 10 : 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: AnimatedIcon(
          icon: AnimatedIcons.play_pause,
          progress: _animCtrl,
          size: effectiveIconSize,
          color: iconCol,
        ),
      ),
    );

    if (widget.isGlass) {
      content = CustomPaint(
        foregroundPainter: _CircleGlassPainter(
          accent: accent,
          isLight: isLight,
          borderWidth: borderWidth,
        ),
        child: content,
      );
    }

    Widget button = PressableScale(
      pressedScale: widget.pressedScale,
      onTap: widget.onToggle != null ? _handleTap : null,
      borderRadius: BorderRadius.circular(widget.size / 2),
      child: content,
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// Circular Glass Specular Highlight & Inner Refraction Rim Painter
class _CircleGlassPainter extends CustomPainter {
  final Color accent;
  final bool isLight;
  final double borderWidth;

  _CircleGlassPainter({
    required this.accent,
    required this.isLight,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;

    // 1. 45° Specular Gradient Rim
    final borderGradient = LinearGradient(
      begin: const Alignment(-0.8, -0.8),
      end: const Alignment(0.8, 0.8),
      colors: [
        Colors.white.withValues(alpha: 0.90),
        accent.withValues(alpha: 0.50),
        accent.withValues(alpha: 0.20),
        Colors.white.withValues(alpha: 0.35),
      ],
      stops: const [0.0, 0.35, 0.70, 1.0],
    );

    final borderPaint = Paint()
      ..shader = borderGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawCircle(rect.center, (size.width - borderWidth) / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CircleGlassPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.isLight != isLight ||
        oldDelegate.borderWidth != borderWidth;
  }
}
