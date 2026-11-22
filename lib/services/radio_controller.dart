import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/radio_station.dart';
import 'app_state.dart';
import 'artwork_palette_service.dart';
import 'audio_controller.dart';

class RadioController extends ChangeNotifier {
  RadioController._() {
    final p = AudioController.instance.player;
    p.playerStateStream.listen((state) {
      if (state.playing) {
        _disarmWatchdog();
        if (_isLoading) {
          _isLoading = false;
          _errorMessage = null;
        }
      }
      if (state.processingState == ProcessingState.completed) {
        _disarmWatchdog();
        nextStation();
      }
      notifyListeners();
    });

    p.currentIndexStream.listen((idx) {
      if (_currentStation != null &&
          idx != null &&
          idx >= 0 &&
          idx < _stationQueue.length) {
        final target = _stationQueue[idx];
        if (_currentStation?.id != target.id) {
          _currentStation = target;
          _isLoading = false;
          _errorMessage = null;
          _disarmWatchdog();
          notifyListeners();
        }
      }
    });

    p.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        if (_currentStation != null) {
          debugPrint('[RadioController] Playback error: $e');
          _handleStreamError();
        }
      },
    );
  }
  static final RadioController instance = RadioController._();

  List<RadioStation> _stationQueue = RadioStation.stations;
  List<RadioStation> get stationQueue => _stationQueue;

  RadioStation? _currentStation;
  RadioStation? get currentStation => _currentStation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isHandlingError = false;

  final Map<String, String> _resolvedStreamUrls = {};

  bool isStationPlaying(String id) {
    final p = AudioController.instance.player;
    return _currentStation?.id == id && p.playing;
  }

  bool isStationActive(String id) {
    return _currentStation?.id == id;
  }

  Timer? _watchdogTimer;

  void _armWatchdog(String stationId) {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 12), () {
      final p = AudioController.instance.player;
      if (_currentStation?.id == stationId && (_isLoading || p.processingState == ProcessingState.buffering || p.processingState == ProcessingState.loading)) {
        if (!p.playing) {
          _isLoading = false;
          _errorMessage = 'Station stream is slow or unavailable. Tap to retry.';
          notifyListeners();
        }
      }
    });
  }

  void _disarmWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void clear() {
    _disarmWatchdog();
    _currentStation = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _handleStreamError() async {
    if (_isHandlingError || _currentStation == null) return;
    _isHandlingError = true;
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      final p = AudioController.instance.player;
      if (p.hasNext) {
        await p.seekToNext();
      } else if (_stationQueue.isNotEmpty) {
        await p.seek(Duration.zero, index: 0);
      }
    } catch (_) {
    } finally {
      _isHandlingError = false;
    }
  }

  Future<void> toggleStation(RadioStation station, {List<RadioStation>? customQueue}) async {
    final p = AudioController.instance.player;
    if (_currentStation?.id == station.id) {
      if (p.playing) {
        await p.pause();
      } else {
        await p.play();
      }
      notifyListeners();
      return;
    }

    if (_stationQueue.isNotEmpty && p.audioSource is ConcatenatingAudioSource) {
      final idx = _stationQueue.indexWhere((s) => s.id == station.id);
      if (idx >= 0) {
        _currentStation = station;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        try {
          await p.seek(Duration.zero, index: idx);
          p.play();
          return;
        } catch (_) {}
      }
    }

    await playStation(station, customQueue: customQueue);
  }

  Future<String?> _resolveOnlineRadioFmStream(String stationId) async {
    if (_resolvedStreamUrls.containsKey(stationId)) {
      return _resolvedStreamUrls[stationId];
    }
    try {
      final res = await http.get(
        Uri.parse('https://onlineradiofm.in/stations/$stationId'),
        headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 10)'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final m = RegExp(r'var\s+FILE\s*=\s*["\x27]([^"\x27]+)["\x27]').firstMatch(res.body);
        if (m != null) {
          final url = m.group(1);
          if (url != null && url.startsWith('http')) {
            _resolvedStreamUrls[stationId] = url;
            return url;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  AudioSource _buildStationAudioSource(RadioStation station) {
    final url = station.effectiveStreamUrl;
    return AudioSource.uri(
      Uri.parse(url),
      tag: MediaItem(
        id: station.id,
        title: station.name,
        album: '🔴 Live Radio Stream',
        artist: '🔴 Live Radio Stream • ${station.frequency}',
        artUri: station.imageUrl != null ? Uri.tryParse(station.imageUrl!) : null,
      ),
    );
  }

  Future<void> playStation(RadioStation station, {List<RadioStation>? customQueue}) async {
    _disarmWatchdog();
    AudioController.instance.ensureNotificationPermission();
    _currentStation = station;
    _isLoading = true;
    _errorMessage = null;
    _armWatchdog(station.id);

    if (station.imageUrl != null && station.imageUrl!.isNotEmpty) {
      ArtworkPaletteService.instance.extractAndApply(
        imageUrl: station.imageUrl,
        cacheKey: 'radio_${station.id}',
      );
    } else {
      AppState.instance.setDynamicAccentColor(station.color);
    }
    notifyListeners();

    final p = AudioController.instance.player;

    // Clear music queues to prevent conflict
    AudioController.instance.queue = const [];
    AudioController.instance.onlineQueue = const [];
    AudioController.instance.hybridQueue = const [];

    _stationQueue = (customQueue != null && customQueue.isNotEmpty)
        ? customQueue
        : RadioStation.stations;

    final targetIdx = _stationQueue.indexWhere((s) => s.id == station.id);
    final safeIdx = targetIdx >= 0 ? targetIdx : 0;

    try {
      final children = [
        for (final s in _stationQueue) _buildStationAudioSource(s),
      ];
      final concatSource = ConcatenatingAudioSource(children: children);

      try {
        await p.stop();
      } catch (_) {}

      await p.setVolume(1.0);
      await p.setAudioSource(concatSource, initialIndex: safeIdx);
      await p.setLoopMode(LoopMode.all);
      await p.setShuffleModeEnabled(false);
      p.play();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[RadioController] playStation error: $e');
      _isLoading = false;
      _errorMessage = 'Could not connect to live stream';
      notifyListeners();
    }
  }

  Future<void> nextStation() async {
    final p = AudioController.instance.player;
    if (p.hasNext) {
      await p.seekToNext();
    } else if (_stationQueue.isNotEmpty) {
      await p.seek(Duration.zero, index: 0);
    }
  }

  Future<void> previousStation() async {
    final p = AudioController.instance.player;
    if (p.hasPrevious) {
      await p.seekToPrevious();
    } else if (_stationQueue.isNotEmpty) {
      await p.seek(Duration.zero, index: _stationQueue.length - 1);
    }
  }

  Future<void> stop() async {
    final p = AudioController.instance.player;
    await p.stop();
    _currentStation = null;
    notifyListeners();
  }
}
