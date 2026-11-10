import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/media_file.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import 'app_state.dart';
import 'equalizer_service.dart';
import 'radio_controller.dart';
import 'yt_audio_resolver.dart';

/// Single app-wide audio player. just_audio_background supports exactly one
/// AudioPlayer, and keeping it global lets music continue (notification +
/// lock-screen controls) after the screen closes or the app is minimised.
class AudioController {
  AudioController._() {
    _initSleepListener();
    _initAudioSessionListener();
  }
  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  List<MediaFile> queue = const [];
  List<OnlineSong> onlineQueue = const [];
  List<PlaylistItem> hybridQueue = const [];

  Future<void> ensureNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  bool get isPlayingOnline => onlineQueue.isNotEmpty || (isPlayingHybrid && currentPlaylistItem?.isOnline == true);
  bool get isPlayingHybrid => hybridQueue.isNotEmpty;

  int? _lastPlayedIndex;

  void _initSleepListener() {
    player.currentIndexStream.listen((idx) {
      if (_lastPlayedIndex != null && idx != null && idx != _lastPlayedIndex) {
        if (AppState.instance.isSleepEndOfSong) {
          player.pause();
          AppState.instance.cancelSleepTimer();
        }
      }
      _lastPlayedIndex = idx;
    });

    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (AppState.instance.isSleepEndOfSong) {
          player.pause();
          AppState.instance.cancelSleepTimer();
        }
      }
    });
  }

  void _initAudioSessionListener() {
    player.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && sessionId > 0) {
        EqualizerService.instance.attachAudioSession(sessionId);
      }
    });
  }

  OnlineSong? get currentOnlineSong {
    final idx = player.currentIndex ?? 0;
    if (onlineQueue.isNotEmpty && idx >= 0 && idx < onlineQueue.length) {
      return onlineQueue[idx];
    }
    if (hybridQueue.isNotEmpty && idx >= 0 && idx < hybridQueue.length) {
      final item = hybridQueue[idx];
      if (item.isOnline && item.streamUrl != null) {
        return OnlineSong(
          id: item.id,
          title: item.title,
          artist: item.artist,
          album: item.album ?? '',
          duration: item.duration,
          streamUrl: item.streamUrl!,
          imageUrl: item.imageUrl ?? '',
        );
      }
    }
    return null;
  }

  PlaylistItem? get currentPlaylistItem {
    final idx = player.currentIndex ?? 0;
    if (hybridQueue.isNotEmpty && idx >= 0 && idx < hybridQueue.length) {
      return hybridQueue[idx];
    }
    return null;
  }

  Future<void> playQueue(List<MediaFile> items, int startIndex, {bool shuffle = false}) async {
    ensureNotificationPermission();
    RadioController.instance.clear();
    onlineQueue = const [];
    hybridQueue = const [];
    queue = items;
    _lastPlayedIndex = startIndex;
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
    if (shuffle) {
      await player.setShuffleModeEnabled(true);
      await player.shuffle();
    } else {
      await player.setShuffleModeEnabled(false);
    }
    player.play(); // not awaited: completes only when playback ends
    final sessId = player.androidAudioSessionId;
    if (sessId != null && sessId > 0) {
      EqualizerService.instance.attachAudioSession(sessId);
    }
  }

  Future<void> playOnlineQueue(List<OnlineSong> items, int startIndex, {bool shuffle = false}) async {
    ensureNotificationPermission();
    RadioController.instance.clear();
    queue = const [];
    hybridQueue = const [];

    final resolvedItems = List<OnlineSong>.from(items);
    if (resolvedItems.isNotEmpty && startIndex >= 0 && startIndex < resolvedItems.length) {
      final cur = resolvedItems[startIndex];
      if (cur.streamUrl.isEmpty || cur.id.startsWith('yt_')) {
        final ytId = cur.id.startsWith('yt_') ? cur.id.replaceFirst('yt_', '') : cur.id;
        final directUrl = await YtAudioResolver.resolveAudioStream(
          ytId,
          fallbackTitle: cur.title,
          fallbackArtist: cur.artist,
        );
        if (directUrl != null && directUrl.isNotEmpty) {
          resolvedItems[startIndex] = OnlineSong(
            id: cur.id,
            title: cur.title,
            artist: cur.artist,
            album: cur.album,
            duration: cur.duration,
            imageUrl: cur.imageUrl,
            streamUrl: directUrl,
          );
        }
      }
    }

    onlineQueue = resolvedItems;
    _lastPlayedIndex = startIndex;

    final audioSources = <AudioSource>[];
    int targetIndex = 0;

    for (var i = 0; i < resolvedItems.length; i++) {
      final s = resolvedItems[i];
      if (s.streamUrl.isEmpty) continue;

      final uri = s.streamUrl.startsWith('/') || s.streamUrl.startsWith('file:')
          ? (s.streamUrl.startsWith('file:') ? Uri.parse(s.streamUrl) : Uri.file(s.streamUrl))
          : Uri.parse(s.streamUrl);

      if (i == startIndex) {
        targetIndex = audioSources.length;
      }

      audioSources.add(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album.isNotEmpty ? s.album : 'RV Player',
            duration: s.duration,
            artUri: Uri.tryParse(s.imageUrl),
          ),
        ),
      );
    }

    if (audioSources.isEmpty) return;

    final source = ConcatenatingAudioSource(children: audioSources);
    await player.setAudioSource(source, initialIndex: targetIndex);
    if (shuffle) {
      await player.setShuffleModeEnabled(true);
      await player.shuffle();
    } else {
      await player.setShuffleModeEnabled(false);
    }
    player.play();
    final onlineSessId = player.androidAudioSessionId;
    if (onlineSessId != null && onlineSessId > 0) {
      EqualizerService.instance.attachAudioSession(onlineSessId);
    }
  }

  Future<void> playHybridQueue(List<PlaylistItem> items, int startIndex, {bool shuffle = false}) async {
    ensureNotificationPermission();
    RadioController.instance.clear();
    queue = const [];
    onlineQueue = const [];
    hybridQueue = items;
    _lastPlayedIndex = startIndex;

    final source = ConcatenatingAudioSource(
      children: [
        for (final item in items)
          if (item.isOnline && item.streamUrl != null)
            AudioSource.uri(
              Uri.parse(item.streamUrl!),
              tag: MediaItem(
                id: item.id,
                title: item.title,
                artist: item.artist,
                album: item.album ?? 'Custom Playlist',
                duration: item.duration,
                artUri: item.imageUrl != null ? Uri.tryParse(item.imageUrl!) : null,
              ),
            )
          else if (item.localPath != null)
            AudioSource.uri(
              Uri.file(item.localPath!),
              tag: MediaItem(
                id: item.id,
                title: item.title,
                artist: item.artist,
                album: item.album ?? 'RV Bhati Player',
                duration: item.duration,
              ),
            ),
      ],
    );
    await player.setAudioSource(source, initialIndex: startIndex);
    if (shuffle) {
      await player.setShuffleModeEnabled(true);
      await player.shuffle();
    } else {
      await player.setShuffleModeEnabled(false);
    }
    player.play();
    final hybridSessId = player.androidAudioSessionId;
    if (hybridSessId != null && hybridSessId > 0) {
      EqualizerService.instance.attachAudioSession(hybridSessId);
    }
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

  void next() {
    if (player.hasNext) player.seekToNext();
  }

  void previous() {
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      player.seek(Duration.zero);
    } else {
      player.seekToPrevious();
    }
  }
}

