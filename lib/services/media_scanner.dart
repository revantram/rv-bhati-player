import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';

/// Permission handling + MediaStore scan for .mp4 / .mkv / .mp3 files.
class MediaScanner {
  MediaScanner._();

  static List<MediaFile> lastScannedAudios = [];

  static const _videoExt = {'mp4', 'mkv', 'webm'};
  static const _audioExt = {'mp3'};

  /// Android 13+ (API 33): READ_MEDIA_VIDEO + READ_MEDIA_AUDIO + POST_NOTIFICATIONS
  /// Android 12 and older:  READ_EXTERNAL_STORAGE + POST_NOTIFICATIONS
  static Future<bool> requestPermissions() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 33) {
      final res = await [
        Permission.videos,
        Permission.audio,
        Permission.notification,
      ].request();
      return (res[Permission.videos]?.isGranted ?? false) ||
          (res[Permission.audio]?.isGranted ?? false);
    }
    final status = await Permission.storage.request();
    try {
      await Permission.notification.request();
    } catch (_) {}
    return status.isGranted;
  }

  static Future<List<MediaFile>> scan(MediaKind kind) async {
    // Permissions are already handled with permission_handler above.
    await PhotoManager.setIgnorePermissionCheck(true);

    final isVideo = kind == MediaKind.video;
    final allowed = isVideo ? _videoExt : _audioExt;

    final albums = await PhotoManager.getAssetPathList(
      type: isVideo ? RequestType.video : RequestType.audio,
      onlyAll: true,
    );
    if (albums.isEmpty) return [];

    final all = albums.first;
    final total = await all.assetCountAsync;
    final assets = await all.getAssetListRange(start: 0, end: total);

    final result = <MediaFile>[];
    for (final a in assets) {
      final title = a.title ?? await a.titleAsync;
      final dot = title.lastIndexOf('.');
      final ext = dot >= 0 ? title.substring(dot + 1).toLowerCase() : '';
      if (!allowed.contains(ext)) continue;

      final path = await _resolvePath(a, title);
      if (path == null) continue;

      int? size;
      try {
        final f = File(path);
        if (f.existsSync()) {
          size = f.lengthSync();
        }
      } catch (_) {}

      result.add(MediaFile(
        id: a.id,
        title: title,
        path: path,
        kind: kind,
        duration: Duration(seconds: a.duration),
        entity: a,
        fileSize: size,
        modifiedDate: a.createDateTime,
      ));
    }

    if (!isVideo) {
      result.sort((x, y) =>
          x.displayTitle.toLowerCase().compareTo(y.displayTitle.toLowerCase()));
      lastScannedAudios = result;
    }
    return result;
  }

  /// Fast path: primary-storage path built from MediaStore relative path
  /// (no file copying). Falls back to photo_manager's file resolver.
  static Future<String?> _resolvePath(AssetEntity a, String title) async {
    final rel = a.relativePath;
    if (rel != null && rel.isNotEmpty) {
      final sep = rel.endsWith('/') ? '' : '/';
      final candidate = '/storage/emulated/0/$rel$sep$title';
      if (File(candidate).existsSync()) return candidate;
    }
    final f = await a.originFile;
    return f?.path;
  }
}
