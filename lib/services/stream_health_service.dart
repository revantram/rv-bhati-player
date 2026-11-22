import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_controller.dart';
import 'radio_controller.dart';

enum StreamHealthStatus {
  idle,
  loading,
  buffering,
  live,
  playing,
  offline,
  error,
}

enum StreamSourceKind {
  local,
  stream,
  radio,
  podcast,
}

class StreamHealthInfo {
  final StreamHealthStatus status;
  final StreamSourceKind sourceKind;
  final String label;
  final String? detailMessage;
  final bool canRetry;
  final int retryCount;

  const StreamHealthInfo({
    required this.status,
    required this.sourceKind,
    required this.label,
    this.detailMessage,
    this.canRetry = false,
    this.retryCount = 0,
  });

  bool get isLive => status == StreamHealthStatus.live;
  bool get isBuffering => status == StreamHealthStatus.buffering;
  bool get isLoading => status == StreamHealthStatus.loading;
  bool get isError => status == StreamHealthStatus.error || status == StreamHealthStatus.offline;
  bool get isHealthy => status == StreamHealthStatus.live || status == StreamHealthStatus.playing;
}

class StreamHealthService extends ChangeNotifier {
  StreamHealthService._() {
    _initListeners();
  }

  static final StreamHealthService instance = StreamHealthService._();

  StreamHealthStatus _status = StreamHealthStatus.idle;
  StreamHealthStatus get status => _status;

  StreamSourceKind _sourceKind = StreamSourceKind.stream;
  StreamSourceKind get sourceKind => _sourceKind;

  String _label = 'Ready';
  String get label => _label;

  String? _detailMessage;
  String? get detailMessage => _detailMessage;

  int _retryCount = 0;
  int get retryCount => _retryCount;

  bool _isAutoRetrying = false;
  Timer? _transientRetryTimer;

  StreamHealthInfo get currentInfo => StreamHealthInfo(
        status: _status,
        sourceKind: _sourceKind,
        label: _label,
        detailMessage: _detailMessage,
        canRetry: _status == StreamHealthStatus.error || _status == StreamHealthStatus.offline,
        retryCount: _retryCount,
      );

  void _initListeners() {
    final audio = AudioController.instance;
    final radio = RadioController.instance;

    // Listen to player state
    audio.player.playerStateStream.listen((state) {
      _evaluateHealth(state: state);
    });

    // Listen to radio changes
    radio.addListener(() {
      _evaluateHealth();
    });

    // Listen to playback error events from just_audio
    audio.player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        _handlePlaybackError(e.toString());
      },
    );
  }

  void _determineSourceKind() {
    final radio = RadioController.instance;
    final audio = AudioController.instance;

    if (radio.currentStation != null) {
      _sourceKind = StreamSourceKind.radio;
      return;
    }

    final onlineSong = audio.currentOnlineSong;
    if (onlineSong != null) {
      if (onlineSong.album.toLowerCase().contains('osho') ||
          onlineSong.album.toLowerCase().contains('desi fm') ||
          onlineSong.album.toLowerCase().contains('aawaz') ||
          onlineSong.artist.toLowerCase().contains('osho')) {
        _sourceKind = StreamSourceKind.podcast;
      } else {
        _sourceKind = StreamSourceKind.stream;
      }
      return;
    }

    final curLocal = audio.currentSong;
    if (curLocal != null) {
      _sourceKind = StreamSourceKind.local;
      return;
    }

    _sourceKind = StreamSourceKind.stream;
  }

  Future<void> _evaluateHealth({PlayerState? state}) async {
    final audio = AudioController.instance;
    final radio = RadioController.instance;
    final pState = state ?? audio.player.playerState;

    _determineSourceKind();

    // Radio handling
    if (radio.currentStation != null) {
      if (radio.isLoading) {
        _setStatus(StreamHealthStatus.loading, 'Connecting Live Stream...');
        return;
      }
      if (radio.errorMessage != null && radio.errorMessage!.isNotEmpty) {
        _setStatus(
          StreamHealthStatus.error,
          'Station Stream Drop',
          detail: radio.errorMessage,
        );
        _scheduleTransientRetry();
        return;
      }
      if (pState.processingState == ProcessingState.buffering) {
        _setStatus(StreamHealthStatus.buffering, 'Buffering Live Radio...');
        return;
      }
      if (pState.playing) {
        _retryCount = 0;
        _setStatus(StreamHealthStatus.live, 'LIVE • 128 kbps AAC');
        return;
      }
    }

    // Audio Player processing states
    switch (pState.processingState) {
      case ProcessingState.idle:
        if (_status != StreamHealthStatus.error && _status != StreamHealthStatus.offline) {
          _setStatus(StreamHealthStatus.idle, 'Ready');
        }
        break;

      case ProcessingState.loading:
        _setStatus(StreamHealthStatus.loading, 'Loading Audio Stream...');
        break;

      case ProcessingState.buffering:
        _setStatus(StreamHealthStatus.buffering, 'Buffering Audio...');
        break;

      case ProcessingState.ready:
        if (pState.playing) {
          _retryCount = 0;
          if (_sourceKind == StreamSourceKind.local) {
            _setStatus(StreamHealthStatus.playing, 'Lossless Local');
          } else if (_sourceKind == StreamSourceKind.podcast) {
            _setStatus(StreamHealthStatus.playing, 'HD Podcast • Crisp');
          } else {
            _setStatus(StreamHealthStatus.playing, 'HD Stream • 320 kbps');
          }
        } else {
          _setStatus(StreamHealthStatus.idle, 'Paused');
        }
        break;

      case ProcessingState.completed:
        _setStatus(StreamHealthStatus.idle, 'Completed');
        break;
    }
  }

  Future<void> _handlePlaybackError(String errorMsg) async {
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      _setStatus(
        StreamHealthStatus.offline,
        'Offline / No Network',
        detail: 'Check your Wi-Fi or Mobile Data connection',
      );
    } else {
      _setStatus(
        StreamHealthStatus.error,
        'Connection Interrupted',
        detail: 'Stream momentarily dropped or timed out',
      );
      _scheduleTransientRetry();
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final res = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(milliseconds: 1800));
      return res.isNotEmpty && res[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _scheduleTransientRetry() {
    if (_isAutoRetrying || _retryCount >= 2) return;
    _isAutoRetrying = true;
    _transientRetryTimer?.cancel();
    _transientRetryTimer = Timer(const Duration(milliseconds: 2500), () async {
      _isAutoRetrying = false;
      _retryCount++;
      await retryActiveStream(quiet: true);
    });
  }

  Future<void> retryActiveStream({bool quiet = false}) async {
    final radio = RadioController.instance;
    final audio = AudioController.instance;

    if (!quiet) {
      HapticFeedback.mediumImpact();
    }

    _setStatus(StreamHealthStatus.loading, 'Reconnecting...');

    try {
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        _setStatus(
          StreamHealthStatus.offline,
          'Offline',
          detail: 'No active internet connection. Please retry when connected.',
        );
        return;
      }

      if (radio.currentStation != null) {
        final cur = radio.currentStation!;
        await radio.toggleStation(cur);
      } else if (audio.currentOnlineSong != null) {
        if (audio.player.playing) {
          await audio.player.seek(audio.player.position);
          await audio.player.play();
        } else {
          await audio.player.play();
        }
      } else {
        await audio.player.play();
      }
    } catch (e) {
      _setStatus(
        StreamHealthStatus.error,
        'Stream Retry Failed',
        detail: 'Could not resume stream. Tap to retry.',
      );
    }
  }

  void _setStatus(StreamHealthStatus status, String label, {String? detail}) {
    if (_status == status && _label == label && _detailMessage == detail) return;
    _status = status;
    _label = label;
    _detailMessage = detail;
    notifyListeners();
  }

  @override
  void dispose() {
    _transientRetryTimer?.cancel();
    super.dispose();
  }
}
