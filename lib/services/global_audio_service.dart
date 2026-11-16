import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Single global AudioPlayer instance shared across the entire application
/// (BitMusic, FM Radio, Shows & Osho, Local Playlists).
/// just_audio_background strictly requires exactly one AudioPlayer instance.
class GlobalAudioService {
  GlobalAudioService._();
  static final GlobalAudioService instance = GlobalAudioService._();

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  /// Helper to safely build an AudioSource with a complete MediaItem tag
  /// required for Android Notification and Lock-Screen media controls.
  static AudioSource createMediaSource({
    required String id,
    required String url,
    required String title,
    String? artist,
    String? album,
    String? artUrl,
    Duration? duration,
    Map<String, String>? headers,
  }) {
    return AudioSource.uri(
      Uri.parse(url),
      headers: headers,
      tag: MediaItem(
        id: id.isNotEmpty ? id : url,
        title: title.isNotEmpty ? title : 'Playing Audio',
        artist: (artist != null && artist.isNotEmpty) ? artist : 'RV Bhati Player',
        album: (album != null && album.isNotEmpty) ? album : 'BitMusic',
        artUri: (artUrl != null && artUrl.isNotEmpty) ? Uri.tryParse(artUrl) : null,
        duration: (duration != null && duration > Duration.zero) ? duration : null,
      ),
    );
  }
}
