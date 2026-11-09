import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EqualizerPreset {
  final String name;
  final List<int> levels; // 5 values from -1000 to 1000 mB
  final int bassStrength; // 0 to 1000
  final int virtualizerStrength; // 0 to 1000

  const EqualizerPreset({
    required this.name,
    required this.levels,
    required this.bassStrength,
    required this.virtualizerStrength,
  });
}

class EqualizerService extends ChangeNotifier {
  EqualizerService._();
  static final EqualizerService instance = EqualizerService._();

  static const _channel = MethodChannel('com.rvbhati.player/equalizer');

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  int? _activeSessionId;
  int? get activeSessionId => _activeSessionId;

  String _currentPreset = 'Flat';
  String get currentPreset => _currentPreset;

  List<int> _bands = [0, 0, 0, 0, 0];
  List<int> get bands => List.unmodifiable(_bands);

  int _bassStrength = 0; // 0..1000
  int get bassStrength => _bassStrength;

  int _virtualizerStrength = 0; // 0..1000
  int get virtualizerStrength => _virtualizerStrength;

  bool _surround3D = false;
  bool get surround3D => _surround3D;

  void attachAudioSession(int? sessionId) {
    if (sessionId == null || sessionId <= 0 || sessionId == _activeSessionId) return;
    _activeSessionId = sessionId;
    try {
      _channel.invokeMethod('setAudioSession', {'sessionId': sessionId});
      _syncHardware();
    } catch (_) {}
  }

  Future<bool> openSystemEqualizer() async {
    try {
      final res = await _channel.invokeMethod<bool>('openSystemEqualizer', {
        'sessionId': _activeSessionId ?? 0,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static const List<String> bandLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  static const Map<String, EqualizerPreset> presets = {
    'Flat': EqualizerPreset(
      name: 'Flat',
      levels: [0, 0, 0, 0, 0],
      bassStrength: 0,
      virtualizerStrength: 0,
    ),
    'Bass Boost': EqualizerPreset(
      name: 'Bass Boost',
      levels: [700, 450, 0, 0, 0],
      bassStrength: 850,
      virtualizerStrength: 200,
    ),
    'Vocal': EqualizerPreset(
      name: 'Vocal',
      levels: [-200, 200, 600, 400, 0],
      bassStrength: 100,
      virtualizerStrength: 250,
    ),
    'Rock': EqualizerPreset(
      name: 'Rock',
      levels: [500, 300, -100, 300, 500],
      bassStrength: 500,
      virtualizerStrength: 400,
    ),
    'Classical': EqualizerPreset(
      name: 'Classical',
      levels: [400, 300, 200, 200, -100],
      bassStrength: 200,
      virtualizerStrength: 500,
    ),
    'Pop': EqualizerPreset(
      name: 'Pop',
      levels: [-100, 300, 600, 300, -200],
      bassStrength: 350,
      virtualizerStrength: 300,
    ),
  };

  void initFromStorage({
    bool? isEnabled,
    String? preset,
    List<int>? bands,
    int? bass,
    int? virtualizer,
    bool? surround,
  }) {
    if (isEnabled != null) _isEnabled = isEnabled;
    if (preset != null && presets.containsKey(preset)) _currentPreset = preset;
    if (bands != null && bands.length == 5) _bands = List.from(bands);
    if (bass != null) _bassStrength = bass;
    if (virtualizer != null) _virtualizerStrength = virtualizer;
    if (surround != null) _surround3D = surround;
    _syncHardware();
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    notifyListeners();
    try {
      await _channel.invokeMethod('setEnabled', {
        'enabled': value,
        'sessionId': _activeSessionId,
      });
    } catch (_) {}
  }

  Future<void> selectPreset(String name) async {
    final p = presets[name];
    if (p == null) return;
    _currentPreset = name;
    _bands = List.from(p.levels);
    _bassStrength = p.bassStrength;
    _virtualizerStrength = p.virtualizerStrength;
    _surround3D = _virtualizerStrength > 0;
    notifyListeners();
    _syncHardware();
  }

  Future<void> setBandLevel(int index, int level) async {
    if (index < 0 || index >= _bands.length) return;
    _bands[index] = level.clamp(-1000, 1000);
    _currentPreset = 'Custom';
    notifyListeners();
    try {
      await _channel.invokeMethod('setBandLevel', {
        'band': index,
        'level': _bands[index],
        'sessionId': _activeSessionId,
      });
    } catch (_) {}
  }

  Future<void> setBassStrength(int value) async {
    _bassStrength = value.clamp(0, 1000);
    _currentPreset = 'Custom';
    notifyListeners();
    try {
      await _channel.invokeMethod('setBassBoost', {
        'strength': _bassStrength,
        'sessionId': _activeSessionId,
      });
    } catch (_) {}
  }

  Future<void> setVirtualizerStrength(int value) async {
    _virtualizerStrength = value.clamp(0, 1000);
    _surround3D = _virtualizerStrength > 0;
    _currentPreset = 'Custom';
    notifyListeners();
    try {
      await _channel.invokeMethod('setVirtualizer', {
        'strength': _virtualizerStrength,
        'sessionId': _activeSessionId,
      });
    } catch (_) {}
  }

  Future<void> toggleSurround(bool value) async {
    _surround3D = value;
    _virtualizerStrength = value ? 600 : 0;
    notifyListeners();
    try {
      await _channel.invokeMethod('setVirtualizer', {
        'strength': _virtualizerStrength,
        'sessionId': _activeSessionId,
      });
    } catch (_) {}
  }

  void _syncHardware() {
    try {
      if (_activeSessionId != null && _activeSessionId! > 0) {
        _channel.invokeMethod('setAudioSession', {'sessionId': _activeSessionId});
      }
      _channel.invokeMethod('setEnabled', {
        'enabled': _isEnabled,
        'sessionId': _activeSessionId,
      });
      for (var i = 0; i < _bands.length; i++) {
        _channel.invokeMethod('setBandLevel', {
          'band': i,
          'level': _bands[i],
          'sessionId': _activeSessionId,
        });
      }
      _channel.invokeMethod('setBassBoost', {
        'strength': _bassStrength,
        'sessionId': _activeSessionId,
      });
      _channel.invokeMethod('setVirtualizer', {
        'strength': _virtualizerStrength,
        'sessionId': _activeSessionId,
      });
    } catch (_) {}
  }
}
