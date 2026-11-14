import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_file.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import 'app_state.dart';
import 'equalizer_service.dart';
import 'local_stream_proxy.dart';
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
    _initLazyQueuePrefetch();
    SettingsService.instance.addListener(_applyPlaybackSettings);
    _applyPlaybackSettings();
  }
  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  List<MediaFile> queue = const [];
  List<OnlineSong> onlineQueue = const [];
  List<PlaylistItem> hybridQueue = const [];

  List<OnlineSong> _pendingOnlineSongs = const [];
  int _pendingNextRawIdx = 0;
  ConcatenatingAudioSource? _activeOnlineConcat;
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
  bool _wasFaded = false;

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

  /// Lazily resolve ONLY 1 upcoming track when listener nears the end of resolved onlineQueue
  void _initLazyQueuePrefetch() {
    player.currentIndexStream.listen((idx) {
      if (idx == null || onlineQueue.isEmpty || _pendingOnlineSongs.isEmpty) return;
      if (idx >= onlineQueue.length - 1) {
        _appendNextPendingTrack(_queueSessionGen);
      }
    });
  }

  /// BitChord-style AutoMix fade transition when crossfadeSeconds > 0
  void _initAutoMixListener() {
    player.positionStream.listen((pos) async {
      final cfSec = SettingsService.instance.crossfadeSeconds;
      if (cfSec <= 0 || _isAutoMixing || !player.playing) {
        if (_wasFaded && !AppState.instance.isSleepTimerActive) {
          _wasFaded = false;
          try {
            await player.setVolume(1.0);
          } catch (_) {}
        }
        return;
      }

      final dur = player.duration;
      if (dur == null || dur.inSeconds <= cfSec + 4) return;
      final remainingMs = (dur - pos).inMilliseconds;
      if (remainingMs > 0 && remainingMs <= cfSec * 1000) {
        _wasFaded = true;
        final ratio = (remainingMs / (cfSec * 1000)).clamp(0.18, 1.0);
        try {
          await player.setVolume(ratio);
        } catch (_) {}
        if (remainingMs <= 650 && player.hasNext) {
          _isAutoMixing = true;
          _wasFaded = false;
          try {
            await player.seekToNext();
            await player.setVolume(1.0);
          } catch (_) {}
          Future.delayed(const Duration(milliseconds: 900), () {
            _isAutoMixing = false;
          });
        }
      } else if (_wasFaded && !AppState.instance.isSleepTimerActive) {
        _wasFaded = false;
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
        debugPrint('[AudioController] Playback error: $e');
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
    _pendingOnlineSongs = const [];
    _activeOnlineConcat = null;
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

  Future<AudioSource> _buildAudioSource(
    OnlineSong s, {
    Map<String, String>? headers,
    bool isHls = false,
    bool? useProxy,
    String? mimeHint,
    StreamInfo? ytStreamInfo,
    YoutubeExplode? ytClient,
  }) async {
    final rawUrl = s.streamUrl;
    final cleanUrl = rawUrl.contains('#yt_stream_') ? rawUrl.split('#').first : rawUrl;
    final isExplodeProxy = rawUrl.contains('#yt_stream_') && ytStreamInfo != null;
    final isLocalFile =
        cleanUrl.startsWith('/') ||
        cleanUrl.startsWith('file:') ||
        cleanUrl.startsWith('http://127.0.0.1');

    Uri playUri;
    Map<String, String>? effectiveHeaders = headers;

    if (isLocalFile && !isExplodeProxy) {
      playUri = cleanUrl.startsWith('file:')
          ? Uri.parse(cleanUrl)
          : (cleanUrl.startsWith('http://') ? Uri.parse(cleanUrl) : Uri.file(cleanUrl));
    } else {
      final shouldProxy = isExplodeProxy || (!isHls && (useProxy ?? false));
      if (shouldProxy) {
        final proxiedUrl = await LocalStreamProxy.instance.register(
          cleanUrl,
          headers: headers,
          mimeHint: mimeHint,
          ytStreamInfo: ytStreamInfo,
          ytClient: ytClient,
          preferExplodeStream: isExplodeProxy,
        );
        playUri = Uri.parse(proxiedUrl);
        effectiveHeaders = null;
      } else {
        playUri = Uri.parse(cleanUrl);
      }
    }

    return AudioSource.uri(
      playUri,
      headers: effectiveHeaders,
      tag: MediaItem(
        id: s.id,
        title: s.title,
        artist: s.artist,
        album: s.album.isNotEmpty ? s.album : 'BitMusic',
        duration: s.duration,
        artUri: s.imageUrl.isNotEmpty ? Uri.tryParse(s.imageUrl) : null,
      ),
    );
  }

  static const String playbackCancelledToken = '__cancelled__';

  /// Resolves and starts playback of [items[startIndex]].
  /// Returns `null` on success, `playbackCancelledToken` if superseded by a newer tap,
  /// or an error message string if stream extraction/playback failed.
  Future<String?> playOnlineQueue(
    List<OnlineSong> items,
    int startIndex, {
    bool shuffle = false,
  }) async {
    if (items.isEmpty) return 'Empty song queue';
    final gen = ++_queueSessionGen;
    ensureNotificationPermission();
    RadioController.instance.clear();
    queue = const [];
    hybridQueue = const [];
    _pendingOnlineSongs = const [];
    _activeOnlineConcat = null;

    final safeStart = startIndex.clamp(0, items.length - 1);
    final target = items[safeStart];

    // If song already carries a direct non-YT or decrypted media streamUrl
    final String directUrl = target.getStreamUrlForBitrate(SettingsService.instance.audioQuality.kbps);
    final List<ResolvedAudioStream> candidates;
    if (directUrl.isNotEmpty) {
      candidates = [ResolvedAudioStream(url: directUrl, source: 'direct')];
    } else if (target.streamUrl.isNotEmpty) {
      candidates = [ResolvedAudioStream(url: target.streamUrl, source: 'direct')];
    } else {
      final ytId = target.id.startsWith('yt_') ? target.id.replaceFirst('yt_', '') : target.id;
      candidates = await YtAudioResolver.resolveAudioCandidates(
        ytId,
        fallbackTitle: target.title,
        fallbackArtist: target.artist,
      );
    }

    // Try up to 10 resolved candidates in Round 1; if all fail on a YT track,
    // invalidate stale cache and run deep Piped/Invidious/YoutubeExplode/WebView fallback.
    final triedUrls = <String>{for (final c in candidates) c.url};
    Object? lastErr;

    Future<String?> tryCandidateList(List<ResolvedAudioStream> list) async {
      for (final candidate in list.take(10)) {
        if (gen != _queueSessionGen) return playbackCancelledToken;
        final isRemote = !candidate.url.startsWith('/') &&
            !candidate.url.startsWith('file:') &&
            !candidate.url.startsWith('http://127.0.0.1');
        final isYtStreamProxy = candidate.source == 'yt_explode_stream' ||
            candidate.url.contains('#yt_stream_');
        final isGoogleVideo = candidate.url.contains('googlevideo.com');

        final List<bool> proxyModes;
        if (isYtStreamProxy) {
          proxyModes = const [true];
        } else if (isRemote && !candidate.isHls) {
          proxyModes = isGoogleVideo ? const [true, false] : const [false, true];
        } else {
          proxyModes = const [false];
        }

        for (final proxyMode in proxyModes) {
          if (gen != _queueSessionGen) return playbackCancelledToken;
          try {
            final resolvedSong = target.copyWith(streamUrl: candidate.url);
            final audioSource = await _buildAudioSource(
              resolvedSong,
              headers: candidate.headers,
              isHls: candidate.isHls,
              useProxy: proxyMode,
              mimeHint: candidate.mimeHint,
              ytStreamInfo: candidate.ytStreamInfo,
              ytClient: candidate.ytClient,
            );
            if (gen != _queueSessionGen) return playbackCancelledToken;

            final concatSource = ConcatenatingAudioSource(children: [audioSource]);

            try {
              await player.stop();
            } catch (_) {}
            await player.setVolume(1.0);
            await player
                .setAudioSource(concatSource, initialIndex: 0)
                .timeout(const Duration(seconds: 7));

            if (gen != _queueSessionGen) return playbackCancelledToken;

            onlineQueue = [resolvedSong];
            _activeOnlineConcat = concatSource;
            _lastPlayedIndex = 0;

            _pendingOnlineSongs = [
              for (int i = safeStart + 1; i < items.length; i++) items[i],
              for (int i = 0; i < safeStart; i++) items[i],
            ];
            if (shuffle && _pendingOnlineSongs.length > 1) {
              _pendingOnlineSongs.shuffle();
            }
            _pendingNextRawIdx = 0;

            await player.setShuffleModeEnabled(false);
            await player.setLoopMode(LoopMode.all);
            player.play();

            final onlineSessId = player.androidAudioSessionId;
            if (onlineSessId != null && onlineSessId > 0) {
              EqualizerService.instance.attachAudioSession(onlineSessId);
            }

            Future.delayed(const Duration(milliseconds: 1600), () {
              if (gen == _queueSessionGen) {
                _appendNextPendingTrack(gen);
              }
            });

            return null;
          } catch (e) {
            lastErr = e;
            debugPrint('[AudioController] Candidate ${candidate.source} (proxy=$proxyMode) failed: $e');
          }
        }
      }
      return '__exhausted__';
    }

    if (candidates.isNotEmpty) {
      final firstPass = await tryCandidateList(candidates);
      if (firstPass != '__exhausted__') return firstPass;
    }

    // Deep fallback escalation for YouTube tracks when Round 1 streams fail
    if (target.streamUrl.isEmpty) {
      if (gen != _queueSessionGen) return playbackCancelledToken;
      final ytId = target.id.startsWith('yt_') ? target.id.replaceFirst('yt_', '') : target.id;
      YtAudioResolver.invalidateCache(ytId);
      final deepCandidates = await YtAudioResolver.resolveDeepFallbackCandidates(
        ytId,
        fallbackTitle: target.title,
        fallbackArtist: target.artist,
        alreadySeenUrls: triedUrls,
      );
      if (gen != _queueSessionGen) return playbackCancelledToken;
      if (deepCandidates.isNotEmpty) {
        final secondPass = await tryCandidateList(deepCandidates);
        if (secondPass != '__exhausted__') return secondPass;
      }
    }

    if (candidates.isEmpty && lastErr == null) {
      return 'Could not find playable audio stream for "${target.title}".';
    }
    return 'Playback failed (${lastErr ?? "stream blocked"}). Try another song.';
  }

  bool _appendingTrack = false;

  Future<void> _appendNextPendingTrack(int gen) async {
    if (_appendingTrack || gen != _queueSessionGen) return;
    if (_pendingNextRawIdx >= _pendingOnlineSongs.length) return;
    final concat = _activeOnlineConcat;
    if (concat == null) return;

    _appendingTrack = true;
    try {
      while (_pendingNextRawIdx < _pendingOnlineSongs.length && gen == _queueSessionGen) {
        final nextSong = _pendingOnlineSongs[_pendingNextRawIdx++];
        final String directUrl = nextSong.getStreamUrlForBitrate(SettingsService.instance.audioQuality.kbps);
        List<ResolvedAudioStream> candidates;
        if (directUrl.isNotEmpty) {
          candidates = [ResolvedAudioStream(url: directUrl, source: 'direct')];
        } else if (nextSong.streamUrl.isNotEmpty) {
          candidates = [ResolvedAudioStream(url: nextSong.streamUrl, source: 'direct')];
        } else {
          final ytId = nextSong.id.startsWith('yt_')
              ? nextSong.id.replaceFirst('yt_', '')
              : nextSong.id;
          candidates = await YtAudioResolver.resolveAudioCandidates(
            ytId,
            fallbackTitle: nextSong.title,
            fallbackArtist: nextSong.artist,
          );
        }
        if (gen != _queueSessionGen) return;
        if (candidates.isNotEmpty) {
          final best = candidates.first;
          final resolved = nextSong.copyWith(streamUrl: best.url);
          final src = await _buildAudioSource(
            resolved,
            headers: best.headers,
            isHls: best.isHls,
            useProxy: best.url.contains('googlevideo.com') || best.source == 'yt_explode_stream',
            mimeHint: best.mimeHint,
            ytStreamInfo: best.ytStreamInfo,
            ytClient: best.ytClient,
          );
          if (gen != _queueSessionGen) return;
          onlineQueue = [...onlineQueue, resolved];
          await concat.add(src);
          return;
        }
      }
    } catch (e) {
      debugPrint('[AudioController] Lazy append error: $e');
    } finally {
      _appendingTrack = false;
    }
  }

  Future<void> playHybridQueue(List<PlaylistItem> items, int startIndex, {bool shuffle = false}) async {
    _queueSessionGen++;
    ensureNotificationPermission();
    RadioController.instance.clear();
    queue = const [];
    onlineQueue = const [];
    _pendingOnlineSongs = const [];
    _activeOnlineConcat = null;
    hybridQueue = items;
    _lastPlayedIndex = startIndex;

    final children = <AudioSource>[];
    for (final item in items) {
      if (item.isOnline) {
        var streamUrl = item.streamUrl ?? '';
        Map<String, String>? headers;
        bool isHls = false;
        ResolvedAudioStream? picked;
        if (streamUrl.isEmpty) {
          final ytId = item.id.startsWith('yt_') ? item.id.replaceFirst('yt_', '') : item.id;
          final list = await YtAudioResolver.resolveAudioCandidates(
            ytId,
            fallbackTitle: item.title,
            fallbackArtist: item.artist,
          );
          if (list.isNotEmpty) {
            picked = list.first;
            streamUrl = picked.url;
            headers = picked.headers;
            isHls = picked.isHls;
          }
        }
        if (streamUrl.isNotEmpty) {
          final onlineStub = OnlineSong(
            id: item.id,
            title: item.title,
            artist: item.artist,
            album: item.album ?? 'BitMusic Playlist',
            duration: item.duration,
            streamUrl: streamUrl,
            imageUrl: item.imageUrl ?? '',
          );
          children.add(
            await _buildAudioSource(
              onlineStub,
              headers: headers,
              isHls: isHls,
              useProxy: !isHls &&
                  (streamUrl.contains('googlevideo.com') || picked?.source == 'yt_explode_stream'),
              mimeHint: picked?.mimeHint,
              ytStreamInfo: picked?.ytStreamInfo,
              ytClient: picked?.ytClient,
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
    final ytId = song.id.startsWith('yt_') ? song.id.replaceFirst('yt_', '') : song.id;
    final candidates = song.streamUrl.isNotEmpty
        ? [ResolvedAudioStream(url: song.streamUrl)]
        : await YtAudioResolver.resolveAudioCandidates(ytId, fallbackTitle: song.title, fallbackArtist: song.artist);
    if (candidates.isEmpty) return;

    final best = candidates.first;
    final resolved = song.copyWith(streamUrl: best.url);
    final src = await _buildAudioSource(
      resolved,
      headers: best.headers,
      isHls: best.isHls,
      useProxy: best.url.contains('googlevideo.com') || best.source == 'yt_explode_stream',
      mimeHint: best.mimeHint,
      ytStreamInfo: best.ytStreamInfo,
      ytClient: best.ytClient,
    );
    onlineQueue = [...onlineQueue, resolved];
    final currentSource = player.audioSource;
    if (currentSource is ConcatenatingAudioSource) {
      await currentSource.add(src);
    }
  }

  Future<void> playOnlineNext(OnlineSong song) async {
    final ytId = song.id.startsWith('yt_') ? song.id.replaceFirst('yt_', '') : song.id;
    final candidates = song.streamUrl.isNotEmpty
        ? [ResolvedAudioStream(url: song.streamUrl)]
        : await YtAudioResolver.resolveAudioCandidates(ytId, fallbackTitle: song.title, fallbackArtist: song.artist);
    if (candidates.isEmpty) return;

    final best = candidates.first;
    final resolved = song.copyWith(streamUrl: best.url);
    final src = await _buildAudioSource(
      resolved,
      headers: best.headers,
      isHls: best.isHls,
      useProxy: best.url.contains('googlevideo.com') || best.source == 'yt_explode_stream',
      mimeHint: best.mimeHint,
      ytStreamInfo: best.ytStreamInfo,
      ytClient: best.ytClient,
    );
    final currentIdx = player.currentIndex ?? 0;
    final list = List<OnlineSong>.from(onlineQueue);
    final insertIdx = list.isNotEmpty ? (currentIdx + 1).clamp(0, list.length) : 0;
    list.insert(insertIdx, resolved);
    onlineQueue = list;

    final currentSource = player.audioSource;
    if (currentSource is ConcatenatingAudioSource) {
      await currentSource.insert(insertIdx, src);
    }
  }

  Future<void> next() async {
    if (onlineQueue.isNotEmpty) {
      final cur = player.currentIndex ?? 0;
      if (cur < onlineQueue.length - 1) {
        await player.seekToNext();
        return;
      }
      if (_pendingNextRawIdx < _pendingOnlineSongs.length) {
        final beforeLen = onlineQueue.length;
        await _appendNextPendingTrack(_queueSessionGen);
        if (onlineQueue.length > beforeLen) {
          await player.seek(Duration.zero, index: onlineQueue.length - 1);
          player.play();
          return;
        }
      }
      await player.seek(Duration.zero, index: 0);
      return;
    }

    if (player.hasNext) {
      await player.seekToNext();
    } else if (queue.isNotEmpty || hybridQueue.isNotEmpty) {
      await player.seek(Duration.zero, index: 0);
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
