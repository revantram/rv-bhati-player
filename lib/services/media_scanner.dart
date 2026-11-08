import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';
import '../utils/id3_parser.dart';

/// Permission handling + MediaStore scan for .mp4 / .mkv / .mp3 files.
class MediaScanner {
  MediaScanner._();

  static const _videoExt = {'mp4', 'mkv'};
  static const _audioExt = {'mp3'};

  /// Android 13+ (API 33): READ_MEDIA_VIDEO + READ_MEDIA_AUDIO
  /// Android 12 and older:  READ_EXTERNAL_STORAGE
  static Future<bool> requestPermissions() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 33) {
      final res = await [Permission.videos, Permission.audio].request();
      return res.values.every((s) => s.isGranted || s.isLimited);
    }
    final status = await Permission.storage.request();
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

      int? fileSize;
      DateTime? modDate;
      try {
        final f = File(path);
        if (f.existsSync()) {
          final stat = f.statSync();
          fileSize = stat.size;
          modDate = stat.modified;
        }
      } catch (_) {}

      final media = MediaFile(
        id: a.id,
        title: title,
        path: path,
        kind: kind,
        duration: Duration(seconds: a.duration),
        entity: a,
        fileSize: fileSize,
        modifiedDate: modDate ?? a.createDateTime,
      );

      if (!isVideo) {
        // Pre-parse ID3 metadata in background
        Id3Parser.parse(path).then((meta) {
          if (meta != null) {
            media.artist = meta.artist;
            media.album = meta.album;
            media.embeddedArt = meta.albumArt;
          }
        }).catchError((_) {});
      }

      result.add(media);
    }

    if (!isVideo) {
      result.sort((x, y) =>
          x.displayTitle.toLowerCase().compareTo(y.displayTitle.toLowerCase()));
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
