import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Lightweight wrapper holding in-memory data, timestamp, and optional TTL.
class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final int? ttlSeconds;

  const CacheEntry({
    required this.data,
    required this.cachedAt,
    this.ttlSeconds,
  });

  bool get isExpired {
    if (ttlSeconds == null || ttlSeconds! <= 0) return false;
    return DateTime.now().difference(cachedAt).inSeconds > ttlSeconds!;
  }
}

/// Multi-tier (In-Memory + Persistent File Storage) Local Cache Service.
///
/// Ensures instant (0ms) data display across Videos, Music Hub, and FM Radio
/// on app open and tab switching without repeated reloading, spinners, or flickers.
class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  // Tier 1: In-memory cache layer for immediate zero-latency access
  final Map<String, CacheEntry<dynamic>> _memoryCache = {};

  Directory? _cacheDir;
  bool _isInitializing = false;

  /// Ensures cache directory exists in app storage
  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null && _cacheDir!.existsSync()) {
      return _cacheDir!;
    }

    try {
      Directory baseDir;
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        try {
          baseDir = await getApplicationSupportDirectory();
        } catch (_) {
          baseDir = Directory('/data/user/0/com.rvbhati.player/files');
        }
      }

      final cacheFolder = Directory('${baseDir.path}/local_cache');
      if (!cacheFolder.existsSync()) {
        cacheFolder.createSync(recursive: true);
      }
      _cacheDir = cacheFolder;
      return _cacheDir!;
    } catch (e) {
      debugPrint('[LocalCacheService] Directory init fallback error: $e');
      final fallback = Directory('/data/user/0/com.rvbhati.player/files/local_cache');
      try {
        if (!fallback.existsSync()) fallback.createSync(recursive: true);
      } catch (_) {}
      _cacheDir = fallback;
      return _cacheDir!;
    }
  }

  /// Sanitize cache key into a safe filename
  String _keyToFileName(String key) {
    final sanitized = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    return '$sanitized.json';
  }

  /// Synchronous in-memory lookup. Returns null if not in memory or expired.
  T? getMemory<T>(String key, {Duration? maxAge}) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    if (maxAge != null && DateTime.now().difference(entry.cachedAt) > maxAge) {
      _memoryCache.remove(key);
      return null;
    }
    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Store value in memory immediately
  void setMemory<T>(String key, T data, {Duration? ttl}) {
    _memoryCache[key] = CacheEntry<dynamic>(
      data: data,
      cachedAt: DateTime.now(),
      ttlSeconds: ttl?.inSeconds,
    );
  }

  /// Cache-First Read:
  /// 1. Reads from in-memory cache layer first (instant 0ms)
  /// 2. If absent from memory, reads from local cache file on disk
  /// 3. Populates in-memory cache for subsequent instant accesses
  /// 4. Checks timestamp and expiration
  Future<T?> get<T>(
    String key, {
    Duration? maxAge,
    required T Function(dynamic json) fromJson,
    bool allowExpiredIfOffline = false,
  }) async {
    // 1. Tier 1: In-memory cache check
    final mem = getMemory<T>(key, maxAge: maxAge);
    if (mem != null) return mem;

    // 2. Tier 2: Persistent disk file check
    try {
      final dir = await _getCacheDirectory();
      final file = File('${dir.path}/${_keyToFileName(key)}');
      if (!file.existsSync()) return null;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final Map<String, dynamic> root = jsonDecode(content);
      final cachedAtMs = (root['cachedAt'] as num?)?.toInt() ?? 0;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      final ttlSec = (root['ttl'] as num?)?.toInt();
      final rawData = root['data'];

      final isExpired = (maxAge != null && DateTime.now().difference(cachedAt) > maxAge) ||
          (ttlSec != null && ttlSec > 0 && DateTime.now().difference(cachedAt).inSeconds > ttlSec);

      if (isExpired && !allowExpiredIfOffline) {
        return null;
      }

      final parsed = fromJson(rawData);
      // Promote into in-memory cache
      _memoryCache[key] = CacheEntry<dynamic>(
        data: parsed,
        cachedAt: cachedAt,
        ttlSeconds: ttlSec,
      );
      return parsed;
    } catch (e) {
      debugPrint('[LocalCacheService] Corrupted or unreadable cache for key $key: $e');
      // Delete corrupted cache file gracefully
      try {
        final dir = await _getCacheDirectory();
        final file = File('${dir.path}/${_keyToFileName(key)}');
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
      return null;
    }
  }

  /// Cache-First Write:
  /// Writes data to both in-memory cache and atomic local disk cache file with timestamp.
  Future<void> set(
    String key,
    dynamic data, {
    Duration? ttl,
    dynamic Function(dynamic value)? toJson,
  }) async {
    final now = DateTime.now();

    // 1. Update in-memory cache immediately
    _memoryCache[key] = CacheEntry<dynamic>(
      data: data,
      cachedAt: now,
      ttlSeconds: ttl?.inSeconds,
    );

    // 2. Persist to local disk cache file
    try {
      final dir = await _getCacheDirectory();
      final file = File('${dir.path}/${_keyToFileName(key)}');
      final serializedData = toJson != null ? toJson(data) : data;

      final payload = jsonEncode({
        'key': key,
        'cachedAt': now.millisecondsSinceEpoch,
        if (ttl != null) 'ttl': ttl.inSeconds,
        'data': serializedData,
      });

      // Safe atomic write via temporary file
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(payload, flush: true);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await tmpFile.rename(file.path);
    } catch (e) {
      debugPrint('[LocalCacheService] Failed writing cache file for key $key: $e');
    }
  }

  /// Check if valid cache exists without parsing full payload
  Future<bool> hasValidCache(String key, {Duration? maxAge}) async {
    if (getMemory(key, maxAge: maxAge) != null) return true;
    try {
      final dir = await _getCacheDirectory();
      final file = File('${dir.path}/${_keyToFileName(key)}');
      if (!file.existsSync()) return false;
      if (maxAge == null) return true;
      final stat = await file.stat();
      return DateTime.now().difference(stat.modified) <= maxAge;
    } catch (_) {
      return false;
    }
  }

  /// Remove specific cache entry from memory and disk
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      final dir = await _getCacheDirectory();
      final file = File('${dir.path}/${_keyToFileName(key)}');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Clear all cached data files safely
  Future<void> clearAll() async {
    _memoryCache.clear();
    try {
      final dir = await _getCacheDirectory();
      if (dir.existsSync()) {
        for (final entity in dir.listSync()) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
