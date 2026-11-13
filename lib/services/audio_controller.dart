import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/media_file.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import 'app_state.dart';
import 'equalizer_service.dart';
import 'radio_controller.dart';
import 'settings_service.dart';
import 'yt_audio_resolver.dart';

/// Single app-wide audio player. just_audio_background supports exactly one
/// AudioPlayer, and keeping it global lets music continue (notification +
/// lock-screen controls) after the screen closes or the app is minimised.
class AudioController {
  AudioController._() {
    _initSleepListener();
    _initAudioSessionListener();
    _initAutoAdvanceListener();
    _initAutoMixListener();
    SettingsService.instance.addListener(_applyPlaybackSettings);
    _applyPlaybackSettings();
  }
  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  List<MediaFile> queue = const [];
  List<OnlineSong> onlineQueue = const [];
  List<PlaylistItem> hybridQueue = const [];

  int _queueSessionGen = 0;

  Future<void> _applyPlaybackSettings() async {
    try {
      await player.setSkipSilenceEnabled(SettingsService.instance.skipSilence);
    } catch (_) {}
  }

  Future<void> ensureNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  bool get isPlayingOnline =>
      onlineQueue.isNotEmpty || (isPlayingHybrid && currentPlaylistItem?.isOnline == true);
  bool get isPlayingHybrid => hybridQueue.isNotEmpty;

  int? _lastPlayedIndex;
  bool _isAutoMixing = false;

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

  /// BitChord-style AutoMix fade transition when crossfadeSeconds > 0
  void _initAutoMixListener() {
    player.positionStream.listen((pos) async {
      final cfSec = SettingsService.instance.crossfadeSeconds;
      if (cfSec <= 0 || _isAutoMixing || !player.playing) return;
      final dur = player.duration;
      if (dur == null || dur.inSeconds <= cfSec + 4) return;
      final remainingMs = (dur - pos).inMilliseconds;
      if (remainingMs > 0 && remainingMs <= cfSec * 1000) {
        // Gentle fade-out envelope toward the end of track before transition
        final ratio = (remainingMs / (cfSec * 1000)).clamp(0.15, 1.0);
        try {
          await player.setVolume(ratio);
        } catch (_) {}
        if (remainingMs <= 650 && player.hasNext) {
          _isAutoMixing = true;
          try {
            await player.seekToNext();
            await player.setVolume(1.0);
          } catch (_) {}
          Future.delayed(const Duration(milliseconds: 900), () {
            _isAutoMixing = false;
          });
        }
      } else if (!_isAutoMixing && player.volume < 0.99 && !AppState.instance.isSleepTimerActive) {
        try {
          await player.setVolume(1.0);
        } catch (_) {}
      }
    });
  }

  void _initAutoAdvanceListener() {
    try {
      player.setLoopMode(LoopMode.all);
    } catch (_) {}

    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (AppState.instance.isSleepEndOfSong) {
          player.pause();
          AppState.instance.cancelSleepTimer();
          return;
        }
        if (player.hasNext) {
          player.seekToNext();
          player.play();
        } else if (queue.isNotEmpty || onlineQueue.isNotEmpty || hybridQueue.isNotEmpty) {
          player.seek(Duration.zero, index: 0);
          player.play();
        }
      }
    });

    player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        if (player.hasNext) {
          player.seekToNext();
          player.play();
        }
      },
    );
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
          album: item.album ?? 'BitMusic',
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
    _queueSessionGen++;
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
    await player.setVolume(1.0);
    await player.setAudioSource(source, initialIndex: startIndex);
    if (shuffle) {
      await player.setShuffleModeEnabled(true);
      await player.shuffle();
    } else {
      await player.setShuffleModeEnabled(false);
    }
    await player.setLoopMode(LoopMode.all);
    player.play();
    final sessId = player.androidAudioSessionId;
    if (sessId != null && sessId > 0) {
      EqualizerService.instance.attachAudioSession(sessId);
    }
  }

  Future<OnlineSong> _resolveSongIfNeeded(OnlineSong s) async {
    if (s.streamUrl.isNotEmpty && !s.id.startsWith('yt_')) return s;
    if (s.streamUrl.isNotEmpty) return s;
    final ytId = s.id.startsWith('yt_') ? s.id.replaceFirst('yt_', '') : s.id;
    final directUrl = await YtAudioResolver.resolveAudioStream(
      ytId,
      fallbackTitle: s.title,
      fallbackArtist: s.artist,
    );
    if (directUrl != null && directUrl.isNotEmpty) {
      return s.copyWith(streamUrl: directUrl);
    }
    return s;
  }

  AudioSource _toAudioSource(OnlineSong s) {
    final uri = s.streamUrl.startsWith('/') || s.streamUrl.startsWith('file:')
        ? (s.streamUrl.startsWith('file:') ? Uri.parse(s.streamUrl) : Uri.file(s.streamUrl))
        : Uri.parse(s.streamUrl);
    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: s.id,
        title: s.title,
        artist: s.artist,
        album: s.album.isNotEmpty ? s.album : 'BitMusic',
        duration: s.duration,
        artUri: Uri.tryParse(s.imageUrl),
      ),
    );
  }

  Future<void> playOnlineQueue(List<OnlineSong> items, int startIndex, {bool shuffle = false}) async {
    if (items.isEmpty) return;
    final gen = ++_queueSessionGen;
    ensureNotificationPermission();
    RadioController.instance.clear();
    queue = const [];
    hybridQueue = const [];

    final safeStart = startIndex.clamp(0, items.length - 1);
    final resolvedStart = await _resolveSongIfNeeded(items[safeStart]);
    if (gen != _queueSessionGen || resolvedStart.streamUrl.isEmpty) return;

    final mutableItems = List<OnlineSong>.from(items);
    mutableItems[safeStart] = resolvedStart;

    // Build initial source with the selected song so playback starts instantaneously
    final concatSource = ConcatenatingAudioSource(
      children: [_toAudioSource(resolvedStart)],
    );
    onlineQueue = [resolvedStart];
    _lastPlayedIndex = 0;

    await player.setVolume(1.0);
    await player.setAudioSource(concatSource, initialIndex: 0);
    await player.setShuffleModeEnabled(shuffle);
    await player.setLoopMode(LoopMode.all);
    player.play();

    final onlineSessId = player.androidAudioSessionId;
    if (onlineSessId != null && onlineSessId > 0) {
      EqualizerService.instance.attachAudioSession(onlineSessId);
    }

    // Lazily resolve upcoming songs in the background so Next / Previous & Queue work seamlessly
    unawaited(_resolveRemainingInBackground(
      gen: gen,
      allItems: mutableItems,
      startIndex: safeStart,
      concatSource: concatSource,
    ));
  }

  Future<void> _resolveRemainingInBackground({
    required int gen,
    required List<OnlineSong> allItems,
    required int startIndex,
    required ConcatenatingAudioSource concatSource,
  }) async {
    // Order: songs after startIndex first (up to 15), then wrap around before startIndex
    final indices = <int>[
      for (int i = startIndex + 1; i < allItems.length && i <= startIndex + 15; i++) i,
      for (int i = 0; i < startIndex && i < 6; i++) i,
    ];

    for (final idx in indices) {
      if (gen != _queueSessionGen) return;
      final resolved = await _resolveSongIfNeeded(allItems[idx]);
      if (gen != _queueSessionGen) return;
      if (resolved.streamUrl.isNotEmpty) {
        try {
          onlineQueue = [...onlineQueue, resolved];
          await concatSource.add(_toAudioSource(resolved));
        } catch (_) {}
      }
    }
  }

  Future<void> playHybridQueue(List<PlaylistItem> items, int startIndex, {bool shuffle = false}) async {
    _queueSessionGen++;
    ensureNotificationPermission();
    RadioController.instance.clear();
    queue = const [];
    onlineQueue = const [];
    hybridQueue = items;
    _lastPlayedIndex = startIndex;

    final children = <AudioSource>[];
    for (final item in items) {
      if (item.isOnline) {
        var streamUrl = item.streamUrl ?? '';
        if (streamUrl.isEmpty && item.id.startsWith('yt_')) {
          streamUrl = await YtAudioResolver.resolveAudioStream(
                item.id,
                fallbackTitle: item.title,
                fallbackArtist: item.artist,
              ) ??
              '';
        }
        if (streamUrl.isNotEmpty) {
          children.add(
            AudioSource.uri(
              Uri.parse(streamUrl),
              tag: MediaItem(
                id: item.id,
                title: item.title,
                artist: item.artist,
                album: item.album ?? 'BitMusic Playlist',
                duration: item.duration,
                artUri: item.imageUrl != null ? Uri.tryParse(item.imageUrl!) : null,
              ),
            ),
          );
        }
      } else if (item.localPath != null) {
        children.add(
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
        );
      }
    }
    if (children.isEmpty) return;

    final source = ConcatenatingAudioSource(children: children);
    await player.setVolume(1.0);
    await player.setAudioSource(
      source,
      initialIndex: startIndex.clamp(0, children.length - 1),
    );
    if (shuffle) {
      await player.setShuffleModeEnabled(true);
      await player.shuffle();
    } else {
      await player.setShuffleModeEnabled(false);
    }
    await player.setLoopMode(LoopMode.all);
    player.play();
    final hybridSessId = player.androidAudioSessionId;
    if (hybridSessId != null && hybridSessId > 0) {
      EqualizerService.instance.attachAudioSession(hybridSessId);
    }
  }

  Future<void> addOnlineToQueue(OnlineSong song) async {
    final resolved = await _resolveSongIfNeeded(song);
    if (resolved.streamUrl.isEmpty) return;
    onlineQueue = [...onlineQueue, resolved];
    final currentSource = player.audioSource;
    if (currentSource is ConcatenatingAudioSource) {
      await currentSource.add(_toAudioSource(resolved));
    }
  }

  Future<void> playOnlineNext(OnlineSong song) async {
    final resolved = await _resolveSongIfNeeded(song);
    if (resolved.streamUrl.isEmpty) return;
    final currentIdx = player.currentIndex ?? 0;
    final list = List<OnlineSong>.from(onlineQueue);
    final insertIdx = list.isNotEmpty ? (currentIdx + 1).clamp(0, list.length) : 0;
    list.insert(insertIdx, resolved);
    onlineQueue = list;

    final currentSource = player.audioSource;
    if (currentSource is ConcatenatingAudioSource) {
      await currentSource.insert(insertIdx, _toAudioSource(resolved));
    }
  }

  void next() {
    if (player.hasNext) {
      player.seekToNext();
    } else if (queue.isNotEmpty || onlineQueue.isNotEmpty || hybridQueue.isNotEmpty) {
      player.seek(Duration.zero, index: 0);
    }
  }

  void previous() {
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      player.seek(Duration.zero);
    } else {
      player.seekToPrevious();
    }
  }
}
