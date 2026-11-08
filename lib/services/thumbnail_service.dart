import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_file.dart';

class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  static const _channel = MethodChannel('com.rvbhati.player/thumbnail');

  // In-memory thumbnail cache keyed by file path or entity id
  final Map<String, Uint8List?> _cache = {};

  bool isCached(String key) => _cache.containsKey(key);
  Uint8List? getCached(String key) => _cache[key];

  Future<Uint8List?> getVideoThumbnail(MediaFile file, {int timeUs = 1000000}) async {
    final key = file.path.isNotEmpty ? file.path : file.id;
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // 1. Try native MediaMetadataRetriever (fastest, supports MKV/MP4/WEBM at 1s frame)
    try {
      if (file.path.isNotEmpty) {
        final bytes = await _channel.invokeMethod<Uint8List>('getVideoThumbnail', {
          'path': file.path,
          'timeUs': timeUs,
        });
        if (bytes != null && bytes.isNotEmpty) {
          _cache[key] = bytes;
          return bytes;
        }
      }
    } catch (_) {}

    // 2. Fallback to PhotoManager MediaStore thumbnail
    try {
      final pmBytes = await file.entity.thumbnailDataWithSize(
        const ThumbnailSize(360, 240),
        quality: 80,
      );
      if (pmBytes != null && pmBytes.isNotEmpty) {
        _cache[key] = pmBytes;
        return pmBytes;
      }
    } catch (_) {}

    try {
      final rawBytes = await file.entity.thumbnailData;
      if (rawBytes != null && rawBytes.isNotEmpty) {
        _cache[key] = rawBytes;
        return rawBytes;
      }
    } catch (_) {}

    _cache[key] = null;
    return null;
  }
}
