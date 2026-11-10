import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_file.dart';

class VideoMetadataInfo {
  final int width;
  final int height;
  final int bitrate;
  final int rotation;
  final String resolutionLabel;
  final String mimeType;

  VideoMetadataInfo({
    required this.width,
    required this.height,
    required this.bitrate,
    required this.rotation,
    required this.resolutionLabel,
    required this.mimeType,
  });
}

class MediaActionService {
  MediaActionService._();

  static const _shareChannel = MethodChannel('com.rvbhati.player/share');
  static const _mediaChannel = MethodChannel('com.rvbhati.player/media_manager');

  /// Share video file using native Android Intent.ACTION_SEND + FileProvider
  static Future<bool> shareVideo(String filePath, {String? title}) async {
    try {
      if (filePath.isEmpty) return false;
      final file = File(filePath);
      if (!file.existsSync()) return false;

      final res = await _shareChannel.invokeMethod<bool>('shareFile', {
        'path': filePath,
        'title': title ?? 'Share Video',
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Share error: $e');
      return false;
    }
  }

  /// Delete video from Android Scoped Storage (Android 11, 12, 13, 14+)
  /// Triggers official Android MediaStore.createDeleteRequest prompt if required.
  static Future<bool> deleteVideo(MediaFile video) async {
    bool deleted = false;

    // 1. PhotoManager Scoped Storage Delete (Handles Android 11+ system permission modal)
    try {
      if (video.id.isNotEmpty) {
        final res = await PhotoManager.editor.deleteWithIds([video.id]);
        if (res.contains(video.id)) {
          deleted = true;
        }
      }
    } catch (e) {
      debugPrint('PhotoManager Scoped delete exception: $e');
    }

    // 2. Direct File deletion fallback (App internal or legacy storage)
    if (!deleted && video.path.isNotEmpty) {
      try {
        final f = File(video.path);
        if (f.existsSync()) {
          f.deleteSync();
          deleted = !f.existsSync();
        }
      } catch (e) {
        debugPrint('Direct File.delete exception: $e');
      }
    }

    // 3. Native channel ContentResolver delete fallback
    if (!deleted && (video.path.isNotEmpty || video.id.isNotEmpty)) {
      try {
        final res = await _mediaChannel.invokeMethod<bool>('deleteMedia', {
          'path': video.path,
          'id': video.id,
        });
        deleted = res == true;
      } catch (e) {
        debugPrint('Native channel deleteMedia exception: $e');
      }
    }

    // Final verification: check if file is gone from filesystem
    if (video.path.isNotEmpty) {
      try {
        if (!File(video.path).existsSync()) {
          deleted = true;
        }
      } catch (_) {}
    }

    return deleted;
  }

  /// Retrieve comprehensive video metadata (resolution, bitrate, mimeType)
  static Future<VideoMetadataInfo> getVideoMetadata(MediaFile video) async {
    int w = video.entity?.width ?? 0;
    int h = video.entity?.height ?? 0;
    int rot = 0;
    int br = 0;
    String mime = 'video/${video.extension.toLowerCase()}';

    // If width/height is missing or 0, query native MediaMetadataRetriever
    if (w <= 0 || h <= 0) {
      try {
        final res = await _mediaChannel.invokeMapMethod<String, dynamic>('getVideoInfo', {
          'path': video.path,
        });
        if (res != null) {
          w = (res['width'] as num?)?.toInt() ?? w;
          h = (res['height'] as num?)?.toInt() ?? h;
          rot = (res['rotation'] as num?)?.toInt() ?? rot;
          br = (res['bitrate'] as num?)?.toInt() ?? br;
          final m = res['mimeType'] as String?;
          if (m != null && m.isNotEmpty) mime = m;
        }
      } catch (e) {
        debugPrint('getVideoInfo exception: $e');
      }
    }

    // Handle orientation swap if 90 or 270 degrees
    if (rot == 90 || rot == 270) {
      final tmp = w;
      w = h;
      h = tmp;
    }

    final resolutionLabel = _computeResolutionLabel(w, h);

    return VideoMetadataInfo(
      width: w,
      height: h,
      bitrate: br,
      rotation: rot,
      resolutionLabel: resolutionLabel,
      mimeType: mime,
    );
  }

  static String _computeResolutionLabel(int w, int h) {
    if (w <= 0 && h <= 0) return 'Standard Video';
    final maxDim = w > h ? w : h;
    final minDim = w > h ? h : w;

    if (maxDim >= 3840 || minDim >= 2160) {
      return '4K Ultra HD ($w × $h)';
    } else if (maxDim >= 2560 || minDim >= 1440) {
      return '2K QHD ($w × $h)';
    } else if (maxDim >= 1920 || minDim >= 1080) {
      return '1080p Full HD ($w × $h)';
    } else if (maxDim >= 1280 || minDim >= 720) {
      return '720p HD ($w × $h)';
    } else if (maxDim >= 854 || minDim >= 480) {
      return '480p SD ($w × $h)';
    }
    return '$w × $h';
  }

  /// Triggers Android MediaScannerConnection to register downloaded audio/video
  /// in the system MediaStore so that ALL media players on the device can see it.
  static Future<void> scanFile(String filePath) async {
    try {
      if (filePath.isEmpty) return;
      await _mediaChannel.invokeMethod('scanFile', {'path': filePath});
    } catch (e) {
      debugPrint('MediaActionService scanFile error: $e');
    }
  }
}
