import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/media_file.dart';

/// Single app-wide audio player. just_audio_background supports exactly one
/// AudioPlayer, and keeping it global lets music continue (notification +
/// lock-screen controls) after the screen closes or the app is minimised.
class AudioController {
  AudioController._();
  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  List<MediaFile> queue = const [];

  Future<void> playQueue(List<MediaFile> items, int startIndex) async {
    queue = items;
    final source = ConcatenatingAudioSource(
      children: [
        for (final m in items)
          AudioSource.uri(
            Uri.file(m.path),
            tag: MediaItem(
              id: m.id,
              title: m.displayTitle,
              album: 'RV Bhati Player',
              duration: m.duration,
            ),
          ),
      ],
    );
    await player.setAudioSource(source, initialIndex: startIndex);
    player.play(); // not awaited: completes only when playback ends
  }
}
