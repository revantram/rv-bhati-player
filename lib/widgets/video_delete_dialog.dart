import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import 'liquid_glass_container.dart';

class VideoDeleteDialog extends StatelessWidget {
  final MediaFile video;

  const VideoDeleteDialog({super.key, required this.video});

  static Future<bool> show(BuildContext context, {required MediaFile video}) async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black65,
      builder: (_) => VideoDeleteDialog(video: video),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondary = app.secondaryTextColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            blur: 24,
            glow: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Destructive Trash Badge
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFFF3B30),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dialog Title
                Text(
                  'Delete Video?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Dialog Message
                Text(
                  'Are you sure you want to delete this file from your device storage? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: secondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // Video File Summary Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.movie_creation_rounded, size: 18, color: secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          video.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDuration(video.duration),
                        style: TextStyle(fontSize: 11.5, color: secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: PressableScale(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLight
                                  ? Colors.black.withValues(alpha: 0.06)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Destructive Delete Button
                    Expanded(
                      child: PressableScale(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          Navigator.pop(context, true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
