import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/media_action_service.dart';
import '../utils/format.dart';
import 'liquid_glass_container.dart';
import 'liquid_toast.dart';
import 'video_delete_dialog.dart';
import 'video_details_dialog.dart';
import 'video_thumbnail_widget.dart';

class VideoOptionsSheet extends StatelessWidget {
  final MediaFile video;
  final VoidCallback onPlay;
  final ValueChanged<MediaFile>? onDeleted;

  const VideoOptionsSheet({
    super.key,
    required this.video,
    required this.onPlay,
    this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required MediaFile video,
    required VoidCallback onPlay,
    ValueChanged<MediaFile>? onDeleted,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VideoOptionsSheet(
        video: video,
        onPlay: onPlay,
        onDeleted: onDeleted,
      ),
    );
  }

  void _handleShare(BuildContext context) async {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    final success = await MediaActionService.shareVideo(
      video.path,
      title: video.displayTitle,
    );
    if (!success && context.mounted) {
      LiquidToast.show(
        context,
        message: 'Could not open share menu',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  void _handleDetails(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    VideoDetailsDialog.show(
      context,
      video: video,
      onPlay: onPlay,
    );
  }

  void _handleDelete(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final confirm = await VideoDeleteDialog.show(context, video: video);
    if (!confirm) return;

    if (!context.mounted) return;

    // Execute Scoped Storage Deletion
    final deleted = await MediaActionService.deleteVideo(video);

    if (deleted) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss bottom sheet
        onDeleted?.call(video);
        LiquidToast.show(
          context,
          message: 'Video deleted successfully',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFFF3B30),
        );
      }
    } else {
      if (context.mounted) {
        LiquidToast.show(
          context,
          message: 'Deletion was cancelled or not permitted',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondary = app.secondaryTextColor;
    final accent = app.accentColor;

    final sizeBytes = video.fileSize ??
        (video.path.isNotEmpty && File(video.path).existsSync()
            ? File(video.path).lengthSync()
            : 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(32),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          blur: 28,
          glow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // iOS Drag Handle
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),

              // Header: Thumbnail + Title + Meta
              Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 52,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: VideoThumbnailWidget(
                            video: video,
                            borderRadius: BorderRadius.circular(12),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              formatDuration(video.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                video.extension,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatBytes(sizeBytes),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('•', style: TextStyle(color: secondary, fontSize: 10)),
                            const SizedBox(width: 6),
                            Text(
                              video.folderName,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grouped Actions List
              Container(
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    // Action 1: Play Video
                    _buildActionTile(
                      icon: Icons.play_arrow_rounded,
                      iconColor: accent,
                      iconBg: accent.withValues(alpha: 0.15),
                      title: 'Play Video',
                      subtitle: 'Open in gesture player',
                      textColor: textColor,
                      secondary: secondary,
                      onTap: () {
                        Navigator.pop(context);
                        onPlay();
                      },
                    ),
                    _buildDivider(isLight),

                    // Action 2: Video Details / Info
                    _buildActionTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF007AFF),
                      iconBg: const Color(0xFF007AFF).withValues(alpha: 0.15),
                      title: 'Video Details / Info',
                      subtitle: 'Resolution, size, duration & path',
                      textColor: textColor,
                      secondary: secondary,
                      onTap: () => _handleDetails(context),
                    ),
                    _buildDivider(isLight),

                    // Action 3: Share Video
                    _buildActionTile(
                      icon: Icons.share_rounded,
                      iconColor: const Color(0xFF34C759),
                      iconBg: const Color(0xFF34C759).withValues(alpha: 0.15),
                      title: 'Share Video',
                      subtitle: 'Send to WhatsApp, Telegram, etc.',
                      textColor: textColor,
                      secondary: secondary,
                      onTap: () => _handleShare(context),
                    ),
                    _buildDivider(isLight),

                    // Action 4: Delete Video (Destructive red)
                    _buildActionTile(
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFFF3B30),
                      iconBg: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                      title: 'Delete Video',
                      subtitle: 'Permanently remove from device',
                      textColor: const Color(0xFFFF3B30),
                      secondary: const Color(0xFFFF3B30).withValues(alpha: 0.7),
                      isDestructive: true,
                      onTap: () => _handleDelete(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isLight) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 54,
      endIndent: 16,
      color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color secondary,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDestructive
                  ? const Color(0xFFFF3B30).withValues(alpha: 0.5)
                  : secondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
