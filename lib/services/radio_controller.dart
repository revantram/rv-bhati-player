import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  final Map<String, String> _resolvedStreamUrls = {};

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

  Future<void> playStation(RadioStation station) async {
    AudioController.instance.ensureNotificationPermission();
    _currentStation = station;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final p = AudioController.instance.player;

    String targetUrl = station.streamUrl;
    if (targetUrl.isEmpty || !targetUrl.startsWith('http')) {
      targetUrl = await _resolveOnlineRadioFmStream(station.id) ?? '';
    }

    if (targetUrl.isEmpty) {
      _isLoading = false;
      _errorMessage = 'Live stream not available for this station';
      notifyListeners();
      return;
    }

    try {
      AudioController.instance.queue = [];
      AudioController.instance.onlineQueue = [];
      final source = AudioSource.uri(
        Uri.parse(targetUrl),
        tag: MediaItem(
          id: station.id,
          title: station.name,
          album: '🔴 Live Radio Stream',
          artist: '🔴 Live Radio Stream • ${station.frequency}',
          artUri: station.imageUrl != null ? Uri.tryParse(station.imageUrl!) : null,
        ),
      );
      await p.setAudioSource(source);
      p.play();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Try fallback if available
      if (station.fallbackStreamUrl != null &&
          station.fallbackStreamUrl!.isNotEmpty &&
          station.fallbackStreamUrl != targetUrl) {
        try {
          final fallbackSource = AudioSource.uri(
            Uri.parse(station.fallbackStreamUrl!),
            tag: MediaItem(
              id: station.id,
              title: station.name,
              album: '🔴 Live Radio Stream',
              artist: '🔴 Live Radio Stream • ${station.frequency}',
              artUri: station.imageUrl != null ? Uri.tryParse(station.imageUrl!) : null,
            ),
          );
          await p.setAudioSource(fallbackSource);
          p.play();
          _isLoading = false;
          notifyListeners();
          return;
        } catch (_) {}
      }

      // Try dynamic resolution from onlineradiofm
      final dynamicUrl = await _resolveOnlineRadioFmStream(station.id);
      if (dynamicUrl != null && dynamicUrl.isNotEmpty && dynamicUrl != targetUrl) {
        try {
          final dynamicSource = AudioSource.uri(
            Uri.parse(dynamicUrl),
            tag: MediaItem(
              id: station.id,
              title: station.name,
              album: '🔴 Live Radio Stream',
              artist: '🔴 Live Radio Stream • ${station.frequency}',
              artUri: station.imageUrl != null ? Uri.tryParse(station.imageUrl!) : null,
            ),
          );
          await p.setAudioSource(dynamicSource);
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
