import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';

/// Reusable Apple iOS Spring Scale Animation & Taptic Haptic Feedback wrapper.
/// Fully compatible with Android TV & Amazon Fire TV Stick remotes (D-pad focus & OK/Select button).
class iOSBounceButton extends StatefulWidget {
  const iOSBounceButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.pressedOpacity = 0.88,
    this.hapticOnDown = true,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double pressedOpacity;
  final bool hapticOnDown;
  final bool canRequestFocus;
  final bool autofocus;
  final FocusNode? focusNode;
  final BorderRadius? borderRadius;

  @override
  State<iOSBounceButton> createState() => _iOSBounceButtonState();
}

class _iOSBounceButtonState extends State<iOSBounceButton> {
  bool _down = false;
  bool _focused = false;
  FocusNode? _internalNode;

  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void dispose() {
    _internalNode?.dispose();
    super.dispose();
  }

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final accent = AppState.instance.accentColor;

    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: enabled && widget.canRequestFocus,
      onShowFocusHighlight: (v) {
        if (_focused != v && mounted) {
          setState(() => _focused = v);
          if (v) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            if (widget.onTap != null) {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
            return null;
          },
        ),
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: GestureDetector(
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
          scale: _down ? widget.pressedScale : (_focused ? 1.05 : 1.0),
          duration: Duration(milliseconds: _down ? 90 : 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _down ? widget.pressedOpacity : 1.0,
            duration: const Duration(milliseconds: 110),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                widget.child,
                if (_focused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: widget.borderRadius ?? BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white,
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.8),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
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

/// Convenience typedef / alias for iOSBounceButton
typedef GlassTapWrapper = iOSBounceButton;
typedef BouncingButton = iOSBounceButton;
