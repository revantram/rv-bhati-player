import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';

/// Permission handling + fast native MediaStore + PhotoManager + Storage scan
/// for device videos and audio files across Android 8 - 16.
class MediaScanner {
  MediaScanner._();

  static const _mediaChannel = MethodChannel('com.rvbhati.player/media_manager');

  static List<MediaFile> lastScannedAudios = [];
  static List<MediaFile> lastScannedVideos = [];
  static bool lastVideoGranted = true;
  static bool lastAudioGranted = true;

  static const _videoExt = {
    'mp4',
    'mkv',
    'webm',
    'mov',
    '3gp',
    'avi',
    'm4v',
    'ts',
    'flv',
    'wmv',
  };
  static const _audioExt = {
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'wma',
  };

  static bool _isAllowedStatus(PermissionStatus? s) =>
      s != null && (s.isGranted || s.isLimited);

  /// Android 13+ (API 33): READ_MEDIA_VIDEO + READ_MEDIA_AUDIO + POST_NOTIFICATIONS
  /// Android 12 and older: READ_EXTERNAL_STORAGE + POST_NOTIFICATIONS
  static Future<bool> requestPermissions() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 33) {
      final res = await [
        Permission.videos,
        Permission.audio,
        Permission.notification,
      ].request();
      lastVideoGranted = _isAllowedStatus(res[Permission.videos]);
      lastAudioGranted = _isAllowedStatus(res[Permission.audio]);
      return lastVideoGranted || lastAudioGranted;
    }
    final status = await Permission.storage.request();
    lastVideoGranted = _isAllowedStatus(status);
    lastAudioGranted = _isAllowedStatus(status);
    try {
      await Permission.notification.request();
    } catch (_) {}
    return lastVideoGranted;
  }

  static Future<List<MediaFile>> scan(MediaKind kind) async {
    final isVideo = kind == MediaKind.video;
    final allowed = isVideo ? _videoExt : _audioExt;
    final byPath = <String, MediaFile>{};

    // 1. Primary fast path: native Android ContentResolver MediaStore query
    try {
      final rawList = await _mediaChannel.invokeMethod<List<dynamic>>(
        'scanMedia',
        {'kind': isVideo ? 'video' : 'audio'},
      );
      if (rawList != null) {
        for (final entry in rawList) {
          if (entry is! Map) continue;
          final path = entry['path']?.toString() ?? '';
          if (path.isEmpty) continue;
          final rawTitle = entry['title']?.toString() ?? '';
          final fileName = rawTitle.isNotEmpty
              ? rawTitle
              : path.split('/').last;
          final ext = _extOf(path.isNotEmpty ? path : fileName);
          if (ext.isNotEmpty && !allowed.contains(ext)) continue;

          final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
          final size = (entry['size'] as num?)?.toInt();
          final dateSec = (entry['dateModifiedSec'] as num?)?.toInt();
          final artist = entry['artist']?.toString();
          final album = entry['album']?.toString();

          byPath[path] = MediaFile(
            id: entry['id']?.toString() ?? path,
            title: fileName,
            path: path,
            kind: kind,
            duration: Duration(milliseconds: durMs),
            fileSize: size,
            modifiedDate: dateSec != null && dateSec > 0
                ? DateTime.fromMillisecondsSinceEpoch(dateSec * 1000)
                : null,
            artist: (artist != null && artist.isNotEmpty && artist != '<unknown>')
                ? artist
                : null,
            album: (album != null && album.isNotEmpty) ? album : null,
          );
        }
      }
    } catch (e) {
      debugPrint('[MediaScanner] native scanMedia error: $e');
    }

    // 2. Fallback/supplement via PhotoManager if native MediaStore returned 0
    if (byPath.isEmpty) {
      try {
        await PhotoManager.setIgnorePermissionCheck(true);
        final albums = await PhotoManager.getAssetPathList(
          type: isVideo ? RequestType.video : RequestType.audio,
          onlyAll: true,
        );
        if (albums.isNotEmpty) {
          final all = albums.first;
          final total = await all.assetCountAsync;
          if (total > 0) {
            final assets = await all.getAssetListRange(start: 0, end: total);
            for (final a in assets) {
              final rawTitle = a.title ?? await a.titleAsync;
              final path = await _resolvePath(a, rawTitle);
              if (path == null || path.isEmpty) continue;
              if (byPath.containsKey(path)) continue;

              final pathExt = _extOf(path);
              final titleExt = _extOf(rawTitle);
              final ext = pathExt.isNotEmpty ? pathExt : titleExt;
              if (ext.isNotEmpty && !allowed.contains(ext)) continue;

              int? size;
              try {
                final f = File(path);
                if (f.existsSync()) size = f.lengthSync();
              } catch (_) {}

              final fileTitle = rawTitle.contains('.')
                  ? rawTitle
                  : path.split('/').last;

              byPath[path] = MediaFile(
                id: a.id,
                title: fileTitle,
                path: path,
                kind: kind,
                duration: Duration(seconds: a.duration),
                entity: a,
                fileSize: size,
                modifiedDate: a.createDateTime,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[MediaScanner] PhotoManager scan error: $e');
      }
    }

    // 3. Direct storage folder scan fallback if MediaStore is empty or un-indexed
    if (byPath.isEmpty) {
      await _scanStorageFoldersFallback(isVideo: isVideo, allowed: allowed, out: byPath);
    }

    final result = byPath.values.toList();
    if (!isVideo) {
      result.sort((x, y) =>
          x.displayTitle.toLowerCase().compareTo(y.displayTitle.toLowerCase()));
      lastScannedAudios = result;
    } else {
      result.sort((x, y) => (y.modifiedDate ?? DateTime(2000))
          .compareTo(x.modifiedDate ?? DateTime(2000)));
      lastScannedVideos = result;
    }
    return result;
  }

  static Future<void> _scanStorageFoldersFallback({
    required bool isVideo,
    required Set<String> allowed,
    required Map<String, MediaFile> out,
  }) async {
    final dirs = isVideo
        ? const [
            '/storage/emulated/0/Movies',
            '/storage/emulated/0/DCIM',
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Downloads',
            '/storage/emulated/0/Videos',
            '/storage/emulated/0/Video',
            '/storage/emulated/0/Pictures',
            '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
            '/storage/emulated/0/Telegram/Telegram Video',
          ]
        : const [
            '/storage/emulated/0/Music',
            '/storage/emulated/0/Audio',
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Downloads',
            '/storage/emulated/0/Recordings',
            '/storage/emulated/0/Ringtones',
            '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
          ];

    for (final dirPath in dirs) {
      try {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final p = entity.path;
          if (out.containsKey(p)) continue;
          final ext = _extOf(p);
          if (!allowed.contains(ext)) continue;
          try {
            final stat = entity.statSync();
            if (stat.size <= 0) continue;
            out[p] = MediaFile(
              id: p,
              title: p.split('/').last,
              path: p,
              kind: isVideo ? MediaKind.video : MediaKind.audio,
              duration: Duration.zero,
              fileSize: stat.size,
              modifiedDate: stat.modified,
            );
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  static String _extOf(String s) {
    final dot = s.lastIndexOf('.');
    if (dot < 0 || dot == s.length - 1) return '';
    return s.substring(dot + 1).toLowerCase();
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
    try {
      final f = await a.originFile;
      if (f != null && f.path.isNotEmpty) return f.path;
    } catch (_) {}
    try {
      final f = await a.file;
      return f?.path;
    } catch (_) {
      return null;
    }
  }
}
