import 'package:flutter/material.dart';

import '../services/stream_health_service.dart';
import 'ios_bounce_button.dart';

class StreamHealthBadge extends StatefulWidget {
  final bool compact;
  final Color? customAccent;

  const StreamHealthBadge({
    super.key,
    this.compact = false,
    this.customAccent,
  });

  @override
  State<StreamHealthBadge> createState() => _StreamHealthBadgeState();
}

class _StreamHealthBadgeState extends State<StreamHealthBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StreamHealthService.instance,
      builder: (context, _) {
        final info = StreamHealthService.instance.currentInfo;
        if (info.status == StreamHealthStatus.idle && widget.compact) {
          return const SizedBox.shrink();
        }

        Color dotColor;
        Color badgeBg;
        Color borderColor;
        Color textColor = Colors.white;

        switch (info.status) {
          case StreamHealthStatus.live:
            dotColor = const Color(0xFF00E676); // Emerald Green
            badgeBg = const Color(0xFF00E676).withValues(alpha: 0.16);
            borderColor = const Color(0xFF00E676).withValues(alpha: 0.4);
            break;
          case StreamHealthStatus.playing:
            dotColor = widget.customAccent ?? const Color(0xFF00E5FF); // Cyan
            badgeBg = dotColor.withValues(alpha: 0.14);
            borderColor = dotColor.withValues(alpha: 0.35);
            break;
          case StreamHealthStatus.buffering:
          case StreamHealthStatus.loading:
            dotColor = const Color(0xFFFFB300); // Amber
            badgeBg = const Color(0xFFFFB300).withValues(alpha: 0.15);
            borderColor = const Color(0xFFFFB300).withValues(alpha: 0.4);
            break;
          case StreamHealthStatus.offline:
            dotColor = const Color(0xFFFF7043); // Deep Orange
            badgeBg = const Color(0xFFFF7043).withValues(alpha: 0.18);
            borderColor = const Color(0xFFFF7043).withValues(alpha: 0.5);
            break;
          case StreamHealthStatus.error:
            dotColor = const Color(0xFFFF5252); // Red
            badgeBg = const Color(0xFFFF5252).withValues(alpha: 0.18);
            borderColor = const Color(0xFFFF5252).withValues(alpha: 0.5);
            break;
          case StreamHealthStatus.idle:
            dotColor = Colors.white54;
            badgeBg = Colors.white.withValues(alpha: 0.08);
            borderColor = Colors.white.withValues(alpha: 0.18);
            break;
        }

        final isPulsing = info.status == StreamHealthStatus.live ||
            info.status == StreamHealthStatus.buffering ||
            info.status == StreamHealthStatus.loading;

        final badgeContent = AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 11,
            vertical: widget.compact ? 3.5 : 5,
          ),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.18),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPulsing)
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    width: widget.compact ? 6.5 : 8,
                    height: widget.compact ? 6.5 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: widget.compact ? 6.5 : 8,
                  height: widget.compact ? 6.5 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
              const SizedBox(width: 5),
              Text(
                info.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: widget.compact ? 10 : 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              if (info.canRetry) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dotColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 11, color: dotColor),
                      const SizedBox(width: 2),
                      Text(
                        'Retry',
                        style: TextStyle(
                          color: dotColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

        if (info.canRetry) {
          return iOSBounceButton(
            onTap: () => StreamHealthService.instance.retryActiveStream(),
            child: badgeContent,
          );
        }

        return badgeContent;
      },
    );
  }
}
