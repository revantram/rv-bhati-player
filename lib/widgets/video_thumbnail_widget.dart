import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/thumbnail_service.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final MediaFile video;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const VideoThumbnailWidget({
    super.key,
    required this.video,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id || oldWidget.video.path != widget.video.path) {
      _loadThumb();
    }
  }

  void _loadThumb() {
    final key = widget.video.path.isNotEmpty ? widget.video.path : widget.video.id;
    if (ThumbnailService.instance.isCached(key)) {
      _thumbBytes = ThumbnailService.instance.getCached(key);
      return;
    }

    _loading = true;
    ThumbnailService.instance.getVideoThumbnail(widget.video).then((bytes) {
      if (mounted) {
        setState(() {
          _thumbBytes = bytes;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final r = widget.borderRadius ?? BorderRadius.circular(16);

    Widget content;
    if (_thumbBytes != null && _thumbBytes!.isNotEmpty) {
      content = Image.memory(
        _thumbBytes!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildPlaceholder(app),
      );
    } else if (_loading) {
      content = Container(
        color: app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
        child: Center(
          child: Icon(
            Icons.movie_rounded,
            color: app.secondaryTextColor.withValues(alpha: 0.4),
            size: 26,
          ),
        ),
      );
    } else {
      content = _buildPlaceholder(app);
    }

    return ClipRRect(
      borderRadius: r,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      ),
    );
  }

  Widget _buildPlaceholder(AppState app) {
    return Container(
      decoration: BoxDecoration(
        color: app.isLight
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: app.accentColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: app.accentColor.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: app.accentColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.video_library_rounded,
              color: app.accentColor,
              size: 24,
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.video.extension.isNotEmpty ? widget.video.extension : 'VIDEO',
                style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
