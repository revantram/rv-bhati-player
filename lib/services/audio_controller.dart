import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/media_file.dart';
import '../models/online_song.dart';
import 'radio_controller.dart';

/// Single app-wide audio player. just_audio_background supports exactly one
/// AudioPlayer, and keeping it global lets music continue (notification +
/// lock-screen controls) after the screen closes or the app is minimised.
class AudioController {
  AudioController._();
  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  List<MediaFile> queue = const [];
  List<OnlineSong> onlineQueue = const [];

  bool get isPlayingOnline => onlineQueue.isNotEmpty;

  OnlineSong? get currentOnlineSong {
    final idx = player.currentIndex ?? 0;
    if (onlineQueue.isNotEmpty && idx >= 0 && idx < onlineQueue.length) {
      return onlineQueue[idx];
    }
    return null;
  }

  Future<void> playQueue(List<MediaFile> items, int startIndex) async {
    RadioController.instance.clear();
    onlineQueue = const [];
    queue = items;
    final source = ConcatenatingAudioSource(
      children: [
        for (final m in items)
          AudioSource.uri(
            Uri.file(m.path),
            tag: MediaItem(
              id: m.id,
              title: m.displayTitle,
              artist: m.artist,
              album: m.album ?? 'RV Bhati Player',
              duration: m.duration,
            ),
          ),
      ],
    );
    await player.setAudioSource(source, initialIndex: startIndex);
    player.play(); // not awaited: completes only when playback ends
  }

  Future<void> playOnlineQueue(List<OnlineSong> items, int startIndex) async {
    RadioController.instance.clear();
    queue = const [];
    onlineQueue = items;

    final source = ConcatenatingAudioSource(
      children: [
        for (final s in items)
          AudioSource.uri(
            Uri.parse(s.streamUrl),
            tag: MediaItem(
              id: s.id,
              title: s.title,
              artist: s.artist,
              album: s.album.isNotEmpty ? s.album : 'JioSaavn Online',
              duration: s.duration,
              artUri: Uri.tryParse(s.imageUrl),
            ),
          ),
      ],
    );
    await player.setAudioSource(source, initialIndex: startIndex);
    player.play();
  }

  void addOnlineToQueue(OnlineSong song) {
    onlineQueue = [...onlineQueue, song];
    final currentSource = player.audioSource;
    if (currentSource is ConcatenatingAudioSource) {
      currentSource.add(
        AudioSource.uri(
          Uri.parse(song.streamUrl),
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album.isNotEmpty ? song.album : 'JioSaavn Online',
            duration: song.duration,
            artUri: Uri.tryParse(song.imageUrl),
          ),
        ),
      );
    }
  }

  void playOnlineNext(OnlineSong song) {
    final currentIdx = player.currentIndex ?? 0;
    final list = List<OnlineSong>.from(onlineQueue);
    final insertIdx = list.isNotEmpty ? (currentIdx + 1).clamp(0, list.length) : 0;
    list.insert(insertIdx, song);
    onlineQueue = list;

    final currentSource = player.audioSource;
    if (currentSource is ConcatenatingAudioSource) {
      currentSource.insert(
        insertIdx,
        AudioSource.uri(
          Uri.parse(song.streamUrl),
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album.isNotEmpty ? song.album : 'JioSaavn Online',
            duration: song.duration,
            artUri: Uri.tryParse(song.imageUrl),
          ),
        ),
      );
    }
  }
}
