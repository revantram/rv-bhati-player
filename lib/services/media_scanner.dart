import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';

/// Permission handling + fast native MediaStore + PhotoManager + Safe Directory Walk
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

  /// Android 13+ (API 33): READ_MEDIA_VIDEO + READ_MEDIA_AUDIO (+ optional POST_NOTIFICATIONS)
  /// Android 12 and older: READ_EXTERNAL_STORAGE (+ optional POST_NOTIFICATIONS)
  static Future<bool> requestPermissions() async {
    int sdk = 33;
    try {
      sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {}

    bool manageGranted = false;
    try {
      manageGranted = await Permission.manageExternalStorage.isGranted;
    } catch (_) {}

    if (sdk >= 33) {
      PermissionStatus vidStatus = PermissionStatus.denied;
      PermissionStatus audStatus = PermissionStatus.denied;
      try {
        final res = await [
          Permission.videos,
          Permission.audio,
        ].request();
        vidStatus = res[Permission.videos] ?? await Permission.videos.status;
        audStatus = res[Permission.audio] ?? await Permission.audio.status;
      } catch (e) {
        debugPrint('[MediaScanner] SDK>=33 permission request error: $e');
      }
      lastVideoGranted = _isAllowedStatus(vidStatus) || manageGranted;
      lastAudioGranted = _isAllowedStatus(audStatus) || manageGranted;

      try {
        final notif = await Permission.notification.status;
        if (!notif.isGranted && !notif.isPermanentlyDenied) {
          await Permission.notification.request();
        }
      } catch (_) {}
      return lastVideoGranted || lastAudioGranted;
    }

    PermissionStatus status = PermissionStatus.denied;
    try {
      status = await Permission.storage.request();
    } catch (e) {
      debugPrint('[MediaScanner] legacy storage request error: $e');
    }
    lastVideoGranted = _isAllowedStatus(status) || manageGranted;
    lastAudioGranted = _isAllowedStatus(status) || manageGranted;
    try {
      final notif = await Permission.notification.status;
      if (!notif.isGranted && !notif.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}
    return lastVideoGranted || lastAudioGranted;
  }

  /// Explicitly requests video read permission:
  /// - Android 13+ (SDK >= 33): Permission.videos (READ_MEDIA_VIDEO)
  /// - Android 12 and older: Permission.storage (READ_EXTERNAL_STORAGE)
  static Future<bool> requestVideoPermission() async {
    int sdk = 33;
    try {
      sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {}

    bool manageGranted = false;
    try {
      manageGranted = await Permission.manageExternalStorage.isGranted;
    } catch (_) {}
    if (manageGranted) {
      lastVideoGranted = true;
      return true;
    }

    final perm = sdk >= 33 ? Permission.videos : Permission.storage;
    try {
      var status = await perm.status;
      if (!_isAllowedStatus(status) && !status.isPermanentlyDenied) {
        status = await perm.request();
      }
      lastVideoGranted = _isAllowedStatus(status);
      return lastVideoGranted;
    } catch (e) {
      debugPrint('[MediaScanner] requestVideoPermission error: $e');
      return false;
    }
  }

  static Future<bool> isVideoPermissionPermanentlyDenied() async {
    int sdk = 33;
    try {
      sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {}
    final perm = sdk >= 33 ? Permission.videos : Permission.storage;
    try {
      return await perm.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasVideoPermission() async {
    int sdk = 33;
    try {
      sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {}
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
    } catch (_) {}
    try {
      final s = sdk >= 33
          ? await Permission.videos.status
          : await Permission.storage.status;
      return _isAllowedStatus(s);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasAnyMediaPermission() async {
    if (await hasVideoPermission()) return true;
    try {
      return _isAllowedStatus(await Permission.audio.status);
    } catch (_) {
      return false;
    }
  }

  static Future<List<MediaFile>> scan(MediaKind kind) async {
    final isVideo = kind == MediaKind.video;
    final allowed = isVideo ? _videoExt : _audioExt;
    final byPath = <String, MediaFile>{};

    // 1. Primary fast path: native Android ContentResolver MediaStore query
    try {
      final rawList = await _mediaChannel
          .invokeMethod<List<dynamic>>('scanMedia', {'kind': isVideo ? 'video' : 'audio'})
          .timeout(const Duration(seconds: 6));
      if (rawList != null) {
        for (final entry in rawList) {
          if (entry is! Map) continue;
          final path = entry['path']?.toString() ?? '';
          if (path.isEmpty) continue;
          final rawTitle = entry['title']?.toString() ?? '';
          final fileName = rawTitle.isNotEmpty
              ? rawTitle
              : path.split('/').last;
          final mime = (entry['mimeType']?.toString() ?? '').toLowerCase();
          final ext = _extOf(path.startsWith('content://') ? fileName : path);
          if (ext.isNotEmpty && !allowed.contains(ext) && !mime.startsWith(isVideo ? 'video/' : 'audio/')) {
            continue;
          }

          final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
          final size = (entry['size'] as num?)?.toInt();
          final dateSec = (entry['dateModifiedSec'] as num?)?.toInt();
          final artist = entry['artist']?.toString();
          final album = entry['album']?.toString();
          final folder = entry['folderName']?.toString();

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
            customFolderName: (folder != null && folder.isNotEmpty) ? folder : null,
          );
        }
      }
    } catch (e) {
      debugPrint('[MediaScanner] native scanMedia error: $e');
    }

    // 2. PhotoManager fallback if native MediaStore returned 0
    if (byPath.isEmpty) {
      try {
        await PhotoManager.setIgnorePermissionCheck(true);
        final albums = await PhotoManager.getAssetPathList(
          type: isVideo ? RequestType.video : RequestType.audio,
          onlyAll: true,
        ).timeout(const Duration(seconds: 5));
        if (albums.isNotEmpty) {
          final all = albums.first;
          final total = (await all.assetCountAsync).clamp(0, 1500);
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

    // 3. Safe direct storage walk (catches un-indexed downloads/movies/folders)
    await _scanStorageFoldersSafe(isVideo: isVideo, allowed: allowed, out: byPath);

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

  /// Safe iterative BFS directory scanner that catches PathAccessException per-folder
  /// so one restricted directory never aborts scanning other folders.
  static Future<void> _scanStorageFoldersSafe({
    required bool isVideo,
    required Set<String> allowed,
    required Map<String, MediaFile> out,
  }) async {
    final seedDirs = isVideo
        ? const [
            '/storage/emulated/0/Movies',
            '/storage/emulated/0/DCIM',
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Downloads',
            '/storage/emulated/0/Videos',
            '/storage/emulated/0/Video',
            '/storage/emulated/0/Pictures',
            '/storage/emulated/0/SnapTube',
            '/storage/emulated/0/VidMate',
            '/storage/emulated/0/ShareMe',
            '/storage/emulated/0/MXShare',
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

    final visited = <String>{};
    final queue = <String>[...seedDirs];

    // Also include top-level custom folders in /storage/emulated/0
    try {
      final root = Directory('/storage/emulated/0');
      if (root.existsSync()) {
        for (final entry in root.listSync(followLinks: false)) {
          if (entry is Directory) {
            final name = entry.path.split('/').last;
            if (!name.startsWith('.') && name != 'Android') {
              queue.add(entry.path);
            }
          } else if (entry is File) {
            _tryAddFile(entry, isVideo: isVideo, allowed: allowed, out: out);
          }
        }
      }
    } catch (_) {}

    int scannedDirs = 0;
    while (queue.isNotEmpty && scannedDirs < 160) {
      final dirPath = queue.removeAt(0);
      if (!visited.add(dirPath)) continue;
      scannedDirs++;

      try {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;
        final children = dir.listSync(followLinks: false);
        for (final entity in children) {
          if (entity is File) {
            _tryAddFile(entity, isVideo: isVideo, allowed: allowed, out: out);
          } else if (entity is Directory) {
            final base = entity.path.split('/').last;
            if (!base.startsWith('.')) {
              queue.add(entity.path);
            }
          }
        }
      } catch (_) {}
    }
  }

  static void _tryAddFile(
    File file, {
    required bool isVideo,
    required Set<String> allowed,
    required Map<String, MediaFile> out,
  }) {
    final p = file.path;
    if (out.containsKey(p)) return;
    final ext = _extOf(p);
    if (!allowed.contains(ext)) return;
    try {
      final stat = file.statSync();
      if (stat.size <= 0) return;
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

  static String _extOf(String s) {
    final dot = s.lastIndexOf('.');
    if (dot < 0 || dot == s.length - 1) return '';
    return s.substring(dot + 1).toLowerCase();
  }

  static Future<String?> _resolvePath(AssetEntity a, String title) async {
    final rel = a.relativePath;
    if (rel != null && rel.isNotEmpty) {
      final sep = rel.endsWith('/') ? '' : '/';
      final candidate = '/storage/emulated/0/$rel$sep$title';
      if (File(candidate).existsSync()) return candidate;
    }
    try {
      final f = await a.originFile.timeout(const Duration(milliseconds: 500));
      if (f != null && f.path.isNotEmpty) return f.path;
    } catch (_) {}
    try {
      final f = await a.file.timeout(const Duration(milliseconds: 500));
      return f?.path;
    } catch (_) {
      return null;
    }
  }
}
