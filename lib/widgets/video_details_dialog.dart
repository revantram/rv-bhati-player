import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/media_action_service.dart';
import '../utils/format.dart';
import 'liquid_glass_container.dart';
import 'liquid_toast.dart';
import 'video_thumbnail_widget.dart';

class VideoDetailsDialog extends StatefulWidget {
  final MediaFile video;
  final VoidCallback? onPlay;

  const VideoDetailsDialog({
    super.key,
    required this.video,
    this.onPlay,
  });

  static Future<void> show(BuildContext context, {required MediaFile video, VoidCallback? onPlay}) {
    HapticFeedback.lightImpact();
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => VideoDetailsDialog(video: video, onPlay: onPlay),
    );
  }

  @override
  State<VideoDetailsDialog> createState() => _VideoDetailsDialogState();
}

class _VideoDetailsDialogState extends State<VideoDetailsDialog> {
  VideoMetadataInfo? _meta;
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  void _loadMetadata() {
    MediaActionService.getVideoMetadata(widget.video).then((info) {
      if (mounted) {
        setState(() {
          _meta = info;
          _loadingMeta = false;
        });
      }
    });
  }

  void _copyPath() {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: widget.video.path));
    LiquidToast.show(
      context,
      message: 'File path copied to clipboard',
      icon: Icons.copy_rounded,
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $m ${dt.year}, $h:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondary = app.secondaryTextColor;
    final accent = app.accentColor;

    final sizeBytes = widget.video.fileSize ??
        (widget.video.path.isNotEmpty && File(widget.video.path).existsSync()
            ? File(widget.video.path).lengthSync()
            : 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            blur: 24,
            glow: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Title Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_rounded, color: accent, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Video Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 18, color: secondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Video Preview Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.03)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 86,
                          height: 56,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: VideoThumbnailWidget(
                                  video: widget.video,
                                  borderRadius: BorderRadius.circular(14),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 3,
                                right: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    formatDuration(widget.video.duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
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
                                widget.video.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.video.extension,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatBytes(sizeBytes),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Metadata Details Group (iOS Grouped Table)
                  Container(
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.02)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.title_rounded,
                          label: 'File Name',
                          value: widget.video.title,
                          isLight: isLight,
                          textColor: textColor,
                          secondary: secondary,
                        ),
                        _buildDivider(isLight),
                        _buildInfoRow(
                          icon: Icons.folder_open_rounded,
                          label: 'Folder',
                          value: widget.video.folderName,
                          isLight: isLight,
                          textColor: textColor,
                          secondary: secondary,
                        ),
                        _buildDivider(isLight),
                        _buildInfoRow(
                          icon: Icons.aspect_ratio_rounded,
                          label: 'Resolution',
                          value: _loadingMeta
                              ? 'Analyzing...'
                              : (_meta?.resolutionLabel ?? 'Standard'),
                          isLight: isLight,
                          textColor: textColor,
                          secondary: secondary,
                        ),
                        _buildDivider(isLight),
                        _buildInfoRow(
                          icon: Icons.timer_rounded,
                          label: 'Duration',
                          value: formatDuration(widget.video.duration),
                          isLight: isLight,
                          textColor: textColor,
                          secondary: secondary,
                        ),
                        _buildDivider(isLight),
                        _buildInfoRow(
                          icon: Icons.pie_chart_rounded,
                          label: 'File Size',
                          value: formatBytes(sizeBytes),
                          isLight: isLight,
                          textColor: textColor,
                          secondary: secondary,
                        ),
                        _buildDivider(isLight),
                        _buildInfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date Modified',
                          value: _formatDate(widget.video.modifiedDate),
                          isLight: isLight,
                          textColor: textColor,
                          secondary: secondary,
                        ),
                        _buildDivider(isLight),
                        _buildPathRow(
                          path: widget.video.path,
                          isLight: isLight,
                          textColor: textColor,
                          secondary: secondary,
                          accent: accent,
                          onCopy: _copyPath,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons (Play & Close)
                  Row(
                    children: [
                      Expanded(
                        child: PressableScale(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isLight
                                  ? Colors.black.withValues(alpha: 0.05)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.onPlay != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: PressableScale(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onPlay!();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 4),
                                    Text(
                                      'Play Video',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isLight) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.04),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isLight,
    required Color textColor,
    required Color secondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: secondary.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathRow({
    required String path,
    required bool isLight,
    required Color textColor,
    required Color secondary,
    required Color accent,
    required VoidCallback onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: secondary.withValues(alpha: 0.8)),
              const SizedBox(width: 10),
              Text(
                'File Path',
                style: TextStyle(
                  fontSize: 13,
                  color: secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onCopy,
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 12,
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SelectableText(
            path,
            style: TextStyle(
              fontSize: 11.5,
              color: secondary.withValues(alpha: 0.9),
              fontFamily: 'monospace',
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
