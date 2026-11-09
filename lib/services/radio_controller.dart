import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/radio_station.dart';
import 'audio_controller.dart';

class RadioController extends ChangeNotifier {
  RadioController._() {
    AudioController.instance.player.playerStateStream.listen((_) {
      notifyListeners();
    });
  }
  static final RadioController instance = RadioController._();

  RadioStation? _currentStation;
  RadioStation? get currentStation => _currentStation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool isStationPlaying(String id) {
    final p = AudioController.instance.player;
    return _currentStation?.id == id && p.playing;
  }

  bool isStationActive(String id) {
    return _currentStation?.id == id;
  }

  void clear() {
    _currentStation = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> toggleStation(RadioStation station) async {
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

    await playStation(station);
  }

  Future<void> playStation(RadioStation station) async {
    AudioController.instance.ensureNotificationPermission();
    _currentStation = station;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final p = AudioController.instance.player;
    try {
      AudioController.instance.queue = [];
      AudioController.instance.onlineQueue = [];
      final source = AudioSource.uri(
        Uri.parse(station.streamUrl),
        tag: MediaItem(
          id: station.id,
          title: station.name,
          album: 'Live Radio (${station.frequency})',
          artist: station.tagline,
        ),
      );
      await p.setAudioSource(source);
      p.play();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Try fallback if available
      if (station.fallbackStreamUrl != null && station.fallbackStreamUrl != station.streamUrl) {
        try {
          final fallbackSource = AudioSource.uri(
            Uri.parse(station.fallbackStreamUrl!),
            tag: MediaItem(
              id: station.id,
              title: station.name,
              album: 'Live Radio (${station.frequency})',
              artist: station.tagline,
            ),
          );
          await p.setAudioSource(fallbackSource);
          p.play();
          _isLoading = false;
          notifyListeners();
          return;
        } catch (_) {}
      }

      _isLoading = false;
      _errorMessage = 'Could not connect to live stream';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final p = AudioController.instance.player;
    await p.stop();
    _currentStation = null;
    notifyListeners();
  }
}
