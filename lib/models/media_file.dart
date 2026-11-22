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
    this.entity,
    this.artist,
    this.album,
    this.embeddedArt,
    this.fileSize,
    this.modifiedDate,
    this.qualityUrls,
    this.customFolderName,
  });

  final String id;

  /// File name with extension, e.g. "song.mp3".
  final String title;
  final String path;
  final MediaKind kind;
  final Duration duration;
  final AssetEntity? entity;
  final Map<String, String>? qualityUrls;
  final String? customFolderName;

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
    if (customFolderName != null && customFolderName!.isNotEmpty) {
      return customFolderName!;
    }
    try {
      final parts = path.split('/');
      if (parts.length >= 2) {
        return parts[parts.length - 2];
      }
    } catch (_) {}
    return 'Internal Storage';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'kind': kind == MediaKind.video ? 'video' : 'audio',
        'durationMs': duration.inMilliseconds,
        'artist': artist,
        'album': album,
        'fileSize': fileSize,
        'modifiedDate': modifiedDate?.millisecondsSinceEpoch,
        'customFolderName': customFolderName,
        if (qualityUrls != null) 'qualityUrls': qualityUrls,
      };

  factory MediaFile.fromJson(Map<String, dynamic> map) {
    return MediaFile(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      kind: map['kind'] == 'audio' ? MediaKind.audio : MediaKind.video,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      artist: map['artist']?.toString(),
      album: map['album']?.toString(),
      fileSize: (map['fileSize'] as num?)?.toInt(),
      modifiedDate: map['modifiedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['modifiedDate'] as num).toInt())
          : null,
      customFolderName: map['customFolderName']?.toString(),
      qualityUrls: map['qualityUrls'] is Map
          ? (map['qualityUrls'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
    );
  }
}
