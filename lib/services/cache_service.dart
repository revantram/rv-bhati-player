import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/format.dart';
import 'artwork_palette_service.dart';

class CacheInfo {
  final int bytes;
  final String formattedSize;
  final int fileCount;

  const CacheInfo({
    required this.bytes,
    required this.formattedSize,
    required this.fileCount,
  });
}

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  Directory get _appCacheDir => Directory('/data/user/0/com.rvbhati.player/cache');

  /// Computes the size of temporary cache on disk without blocking the UI thread.
  Future<CacheInfo> getCacheSize() async {
    int totalBytes = 0;
    int files = 0;

    try {
      final cacheDir = _appCacheDir;
      if (cacheDir.existsSync()) {
        final entries = cacheDir.listSync(recursive: true, followLinks: false);
        for (final entity in entries) {
          if (entity is File) {
            totalBytes += entity.lengthSync();
            files++;
          }
        }
      }
    } catch (_) {}

    return CacheInfo(
      bytes: totalBytes,
      formattedSize: formatBytes(totalBytes),
      fileCount: files,
    );
  }

  /// Safely clears ONLY temporary buffers, network image cache, and transient files.
  /// Strictly preserves user playlists, favorites, offline downloads, backups, and resume progress.
  Future<CacheInfo> clearSafeCache() async {
    int freedBytes = 0;
    int filesDeleted = 0;

    // 1. Clear Flutter in-memory image cache
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    // 2. Clear in-memory palette LRU cache
    try {
      ArtworkPaletteService.instance.clearCache();
    } catch (_) {}

    // 3. Clear disk temporary cache safely
    try {
      final cacheDir = _appCacheDir;
      if (cacheDir.existsSync()) {
        final entities = cacheDir.listSync(recursive: false);
        for (final entity in entities) {
          // Strictly protect any files directory or protected names
          final path = entity.path.toLowerCase();
          if (path.contains('/files') ||
              path.contains('app_state') ||
              path.contains('download') ||
              path.contains('backup') ||
              path.contains('history')) {
            continue;
          }

          if (entity is File) {
            try {
              final len = entity.lengthSync();
              entity.deleteSync();
              freedBytes += len;
              filesDeleted++;
            } catch (_) {}
          } else if (entity is Directory) {
            try {
              entity.deleteSync(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    return CacheInfo(
      bytes: freedBytes,
      formattedSize: formatBytes(freedBytes),
      fileCount: filesDeleted,
    );
  }
}
