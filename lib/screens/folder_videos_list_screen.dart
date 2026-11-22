import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../models/video_folder.dart';
import '../services/app_state.dart';
import '../services/media_action_service.dart';
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

  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {};

  void _toggleSelect(MediaFile video) {
    HapticFeedback.selectionClick();
    final id = video.id.isNotEmpty ? video.id : video.path;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isMultiSelect = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterMultiSelect(MediaFile video) {
    HapticFeedback.heavyImpact();
    final id = video.id.isNotEmpty ? video.id : video.path;
    setState(() {
      _isMultiSelect = true;
      _selectedIds.add(id);
    });
  }

  void _selectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.length == widget.folder.videos.length) {
        _selectedIds.clear();
        _isMultiSelect = false;
      } else {
        _selectedIds.clear();
        for (final v in widget.folder.videos) {
          _selectedIds.add(v.id.isNotEmpty ? v.id : v.path);
        }
      }
    });
  }

  void _shareSelected() async {
    final selectedVideos = widget.folder.videos
        .where((v) => _selectedIds.contains(v.id.isNotEmpty ? v.id : v.path))
        .toList();
    if (selectedVideos.isEmpty) return;
    HapticFeedback.lightImpact();
    for (final v in selectedVideos) {
      await MediaActionService.shareVideo(v.path, title: v.displayTitle);
    }
  }

  void _deleteSelected() async {
    final selectedVideos = widget.folder.videos
        .where((v) => _selectedIds.contains(v.id.isNotEmpty ? v.id : v.path))
        .toList();
    if (selectedVideos.isEmpty) return;

    HapticFeedback.mediumImpact();

    int deletedCount = 0;
    for (final v in List<MediaFile>.from(selectedVideos)) {
      final ok = await MediaActionService.deleteVideo(v);
      if (ok) {
        deletedCount++;
        setState(() {
          widget.folder.videos.removeWhere((item) => item.id == v.id || item.path == v.path);
        });
        widget.onVideoDeleted?.call(v);
      }
    }

    setState(() {
      _selectedIds.clear();
      _isMultiSelect = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deletedCount video(s) deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.folder.videos.isEmpty) {
        Navigator.of(context).pop();
      }
    }
  }

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
      canPop: !_isMultiSelect,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isMultiSelect) {
          setState(() {
            _isMultiSelect = false;
            _selectedIds.clear();
          });
        }
      },
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
                  final videoKey = video.id.isNotEmpty ? video.id : video.path;
                  final isSelected = _selectedIds.contains(videoKey);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PressableScale(
                      hapticOnDown: false,
                      onTap: () {
                        if (_isMultiSelect) {
                          _toggleSelect(video);
                        } else {
                          _playVideo(i);
                        }
                      },
                      onLongPress: () {
                        if (_isMultiSelect) {
                          _toggleSelect(video);
                        } else {
                          _enterMultiSelect(video);
                        }
                      },
                      child: LiquidGlassContainer(
                        borderRadius: BorderRadius.circular(22),
                        padding: const EdgeInsets.all(10),
                        blur: 0,
                        glow: isSelected,
                        tint: isSelected ? accent.withValues(alpha: 0.18) : null,
                        borderWidth: isSelected ? 1.6 : 1.0,
                        borderColor: isSelected
                            ? accent
                            : (isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
                        child: Row(
                          children: [
                            if (_isMultiSelect) ...[
                              Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? accent : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? accent : (isLight ? Colors.black38 : Colors.white38),
                                    width: 1.8,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                    : null,
                              ),
                            ],
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
                  child: _isMultiSelect
                      ? Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: textColor),
                              onPressed: () {
                                setState(() {
                                  _isMultiSelect = false;
                                  _selectedIds.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_selectedIds.length} Selected',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _selectedIds.length == widget.folder.videos.length
                                    ? Icons.deselect_rounded
                                    : Icons.select_all_rounded,
                                color: accent,
                              ),
                              tooltip: 'Select All',
                              onPressed: _selectAll,
                            ),
                            IconButton(
                              icon: Icon(Icons.share_rounded, color: accent),
                              tooltip: 'Share',
                              onPressed: _shareSelected,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                              tooltip: 'Delete',
                              onPressed: _deleteSelected,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            PressableScale(
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
