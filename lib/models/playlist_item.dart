import 'media_file.dart';
import 'online_song.dart';

/// Represents a track inside a user custom playlist.
/// Can be either an offline local MP3 file or an online JioSaavn stream.
class PlaylistItem {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final bool isOnline;
  final String? localPath;
  final String? streamUrl;
  final String? imageUrl;

  const PlaylistItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    required this.isOnline,
    this.localPath,
    this.streamUrl,
    this.imageUrl,
  });

  factory PlaylistItem.fromMediaFile(MediaFile m) {
    return PlaylistItem(
      id: m.id,
      title: m.displayTitle,
      artist: m.artist ?? 'Local Music',
      album: m.album,
      duration: m.duration,
      isOnline: false,
      localPath: m.path,
    );
  }

  factory PlaylistItem.fromOnlineSong(OnlineSong s) {
    return PlaylistItem(
      id: s.id,
      title: s.title,
      artist: s.artist,
      album: s.album,
      duration: s.duration,
      isOnline: true,
      streamUrl: s.streamUrl,
      imageUrl: s.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationSeconds': duration.inSeconds,
        'isOnline': isOnline,
        'localPath': localPath,
        'streamUrl': streamUrl,
        'imageUrl': imageUrl,
      };

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      album: json['album']?.toString(),
      duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
      isOnline: json['isOnline'] as bool? ?? false,
      localPath: json['localPath']?.toString(),
      streamUrl: json['streamUrl']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
