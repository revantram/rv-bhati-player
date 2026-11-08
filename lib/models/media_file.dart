import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

enum MediaKind { video, audio }

class MediaFile {
  MediaFile({
    required this.id,
    required this.title,
    required this.path,
    required this.kind,
    required this.duration,
    required this.entity,
    this.artist,
    this.album,
    this.embeddedArt,
    this.fileSize,
    this.modifiedDate,
  });

  final String id;

  /// File name with extension, e.g. "song.mp3".
  final String title;
  final String path;
  final MediaKind kind;
  final Duration duration;
  final AssetEntity entity;

  String? artist;
  String? album;
  Uint8List? embeddedArt;
  int? fileSize;
  DateTime? modifiedDate;

  String get displayTitle {
    final dot = title.lastIndexOf('.');
    return dot > 0 ? title.substring(0, dot) : title;
  }

  String get extension {
    final dot = title.lastIndexOf('.');
    return dot >= 0 ? title.substring(dot + 1).toUpperCase() : '';
  }

  String get folderName {
    try {
      final parts = path.split('/');
      if (parts.length >= 2) {
        return parts[parts.length - 2];
      }
    } catch (_) {}
    return 'Internal Storage';
  }
}
