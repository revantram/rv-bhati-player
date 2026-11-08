import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable Apple iOS Spring Scale Animation & Taptic Haptic Feedback wrapper.
class iOSBounceButton extends StatefulWidget {
  const iOSBounceButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.pressedOpacity = 0.88,
    this.hapticOnDown = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double pressedOpacity;
  final bool hapticOnDown;

  @override
  State<iOSBounceButton> createState() => _iOSBounceButtonState();
}

class _iOSBounceButtonState extends State<iOSBounceButton> {
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
        duration: Duration(milliseconds: _down ? 90 : 250),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _down ? widget.pressedOpacity : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Convenience typedef / alias for iOSBounceButton
typedef GlassTapWrapper = iOSBounceButton;
typedef BouncingButton = iOSBounceButton;
