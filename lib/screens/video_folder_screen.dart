import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../models/video_folder.dart';
import '../services/app_state.dart';
import '../utils/format.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/video_thumbnail_widget.dart';
import 'folder_videos_list_screen.dart';

class VideoFolderScreen extends StatefulWidget {
  final List<MediaFile> videos;
  final double topOffset;
  final double bottomOffset;
  final ValueChanged<MediaFile>? onVideoDeleted;

  const VideoFolderScreen({
    super.key,
    required this.videos,
    this.topOffset = 68,
    this.bottomOffset = 160,
    this.onVideoDeleted,
  });

  // 1. Smart Folder & Video Name Cleaner: Strips technical release tags
  static String cleanFolderName(String name) {
    var s = name;
    s = s.replaceAll('_', ' ');
    final releasePatterns = [
      RegExp(r'\b(2160p|1080p|720p|480p|360p|4k|uhd|fhd|hd)\b', caseSensitive: false),
      RegExp(r'\b(web-?dl|web-?rip|bluray|brrip|dvdrip|hdrip|hdtv|remux)\b', caseSensitive: false),
      RegExp(r'\b(x264|x265|hevc|h\.?264|h\.?265|10bit|8bit|aac|ac3|eac3|dts|mp4|mkv)\b', caseSensitive: false),
      RegExp(r'\b(esub|esubs|sub|subbed|dubbed|dual-?audio|multi)\b', caseSensitive: false),
      RegExp(r'\b(sonyliv|hotstar|netflix|prime|zee5|jiocinema|mxplayer|voot|altbalaji)\b', caseSensitive: false),
      RegExp(r'\b(hindi|english|telugu|tamil|punjabi|malayalam|kannada)\b', caseSensitive: false),
      RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false),
    ];
    for (final p in releasePatterns) {
      s = s.replaceAll(p, ' ');
    }
    s = s.replaceAll(RegExp(r'\.+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? name : s;
  }

  @override
  State<VideoFolderScreen> createState() => _VideoFolderScreenState();
}

class _VideoFolderScreenState extends State<VideoFolderScreen> {
  FolderSortType _sortType = FolderSortType.count;
  AppState get app => AppState.instance;

  // 3. Sort Action Refactor: Frosted glass sorting sheet
  void _showSortSheet() {
    HapticFeedback.lightImpact();
    final isLight = app.isLight;
    final textColor = app.textColor;
    final accent = app.accentColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          blur: 20,
          opacity: 0.14,
          borderColor: Colors.white.withValues(alpha: 0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.sort_rounded, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Sort Folders by / फोल्डर क्रम',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSortOption(
                FolderSortType.count,
                'Video Count (सर्वाधिक वीडियो)',
                Icons.format_list_numbered_rounded,
              ),
              _buildSortOption(
                FolderSortType.size,
                'Storage Size (आकार / जीबी)',
                Icons.pie_chart_rounded,
              ),
              _buildSortOption(
                FolderSortType.name,
                'Folder Name (नाम अनुसार A-Z)',
                Icons.sort_by_alpha_rounded,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(FolderSortType type, String title, IconData icon) {
    final active = _sortType == type;
    final textColor = app.textColor;
    final accent = app.accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PressableScale(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _sortType = type);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? accent : (app.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white10),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: active ? accent : app.secondaryTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? accent : textColor,
                  ),
                ),
              ),
              if (active)
                Icon(Icons.check_rounded, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;

    final folders = VideoFolder.groupVideos(widget.videos, sortType: _sortType);

    if (folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_rounded, size: 52, color: secondaryTextColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No Video Folders Found',
              style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Videos will appear grouped by their storage directory.',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Folders List
        ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 68, 16, widget.bottomOffset),
          itemCount: folders.length,
          itemBuilder: (context, i) {
            final folder = folders[i];
            final displayName = VideoFolderScreen.cleanFolderName(folder.name);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PressableScale(
                pressedScale: 0.96,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => FolderVideosListScreen(
                        folder: folder,
                        onVideoDeleted: (deleted) {
                          setState(() {
                            widget.videos.removeWhere((v) => v.id == deleted.id || v.path == deleted.path);
                          });
                          widget.onVideoDeleted?.call(deleted);
                        },
                      ),
                    ),
                  );
                },
                // 5. Liquid Glass Card Styling: radius 20px, crisp border without heavy scroll blur
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.all(10),
                  blur: 0,
                  opacity: 0.10,
                  borderWidth: 1,
                  borderColor: Colors.white.withValues(alpha: 0.15),
                  glow: false,
                  child: Row(
                    children: [
                      // 2. Thumbnail Fallback & Overlay Cleanup: Clean thumbnail preview without covering badge
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 84,
                          height: 72,
                          child: VideoThumbnailWidget(
                            video: folder.coverVideo,
                            borderRadius: BorderRadius.circular(16),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Middle: Smart cleaned folder name & metadata badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${folder.videoCount} Videos',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatBytes(folder.totalSizeBytes),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Right: Smooth iOS chevron arrow (>) with subtle background
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: app.secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Studio Header (Title, Subtitle & Sort Action)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Video Folders',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '${folders.length} Folders • ${widget.videos.length} Videos',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refactored sleek frosted sort icon button
                    LiquidGlassButton(
                      icon: Icons.sort_rounded,
                      size: 38,
                      iconSize: 20,
                      tint: accent,
                      onTap: _showSortSheet,
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }
}
