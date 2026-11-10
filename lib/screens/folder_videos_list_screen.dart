import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../models/video_folder.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/video_options_sheet.dart';
import '../widgets/video_thumbnail_widget.dart';
import 'video_player_screen.dart';

class FolderVideosListScreen extends StatefulWidget {
  final VideoFolder folder;
  final ValueChanged<MediaFile>? onVideoDeleted;

  const FolderVideosListScreen({
    super.key,
    required this.folder,
    this.onVideoDeleted,
  });

  @override
  State<FolderVideosListScreen> createState() => _FolderVideosListScreenState();
}

class _FolderVideosListScreenState extends State<FolderVideosListScreen> {
  AppState get app => AppState.instance;

  void _playVideo(int index) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          playlist: widget.folder.videos,
          startIndex: index,
        ),
      ),
    );
  }

  void _showVideoOptions(MediaFile video, int index) {
    VideoOptionsSheet.show(
      context,
      video: video,
      onPlay: () => _playVideo(index),
      onDeleted: (deleted) {
        setState(() {
          widget.folder.videos.removeWhere((v) => v.id == deleted.id || v.path == deleted.path);
        });
        widget.onVideoDeleted?.call(deleted);
        if (widget.folder.videos.isEmpty && mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LiquidBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              // Videos List
              ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 76, 16, 160),
                itemCount: widget.folder.videos.length,
                itemBuilder: (context, i) {
                  final video = widget.folder.videos[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PressableScale(
                      hapticOnDown: false,
                      onTap: () => _playVideo(i),
                      onLongPress: () => _showVideoOptions(video, i),
                      child: LiquidGlassContainer(
                        borderRadius: BorderRadius.circular(22),
                        padding: const EdgeInsets.all(10),
                        blur: 0,
                        glow: false,
                        child: Row(
                          children: [
                            // 16:9 Video Thumbnail Preview with Duration Badge
                            SizedBox(
                              width: 104,
                              height: 64,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: VideoThumbnailWidget(
                                      video: video,
                                      borderRadius: BorderRadius.circular(15),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Video Duration Overlay Badge
                                  Positioned(
                                    bottom: 5,
                                    right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        formatDuration(video.duration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Video Metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    video.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      // Format Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isLight
                                              ? Colors.black.withValues(alpha: 0.06)
                                              : Colors.white.withValues(alpha: 0.1),
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
                                      if (video.fileSize != null) ...[
                                        Text(
                                          formatBytes(video.fileSize!),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: secondaryTextColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('•', style: TextStyle(color: secondaryTextColor, fontSize: 10)),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        formatDuration(video.duration),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Subtle Frosted Three-Dot Menu
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showVideoOptions(video, i),
                              child: Container(
                                width: 32,
                                height: 38,
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.all(5.5),
                                  decoration: BoxDecoration(
                                    color: isLight
                                        ? Colors.black.withValues(alpha: 0.04)
                                        : Colors.white.withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.more_vert_rounded,
                                    color: secondaryTextColor,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Liquid Play Button
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _playVideo(i),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withValues(alpha: 0.15),
                                  border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: accent,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Studio Top Bar Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : const Color(0xFF090D16),
                    border: Border(
                      bottom: BorderSide(
                        color: isLight ? const Color(0xFFE2E8F0) : const Color(0x1FFFFFFF),
                        width: 1,
                      ),
                    ),
                  ),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isLight
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Folders',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  '${widget.folder.videoCount} Videos • ${formatBytes(widget.folder.totalSizeBytes)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          LiquidGlassButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Play All',
                            size: 38,
                            tint: accent,
                            onTap: () => _playVideo(0),
                          ),
                        ],
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
