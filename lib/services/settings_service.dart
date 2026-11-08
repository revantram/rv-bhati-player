import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum AudioQuality {
  hd320('320 kbps', 'High Definition (Wi-Fi recommended)', 320),
  standard160('160 kbps', 'Standard (Balanced sound & data)', 160),
  saver96('96 kbps', 'Data Saver (Fast buffering)', 96);

  const AudioQuality(this.label, this.description, this.kbps);
  final String label;
  final String description;
  final int kbps;
}

enum AppThemeMode {
  light('Apple iOS Light', 'Clean white frosted liquid glass'),
  dark('Liquid Dark', 'Deep OLED dark glass'),
  system('System Default', 'Follow device settings');

  const AppThemeMode(this.label, this.description);
  final String label;
  final String description;
}

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  AudioQuality _audioQuality = AudioQuality.standard160;
  AudioQuality get audioQuality => _audioQuality;

  bool _autoQuality = true;
  bool get autoQuality => _autoQuality;

  bool _sleepFadeOut = true;
  bool get sleepFadeOut => _sleepFadeOut;

  int _crossfadeSeconds = 2; // 0..5 seconds
  int get crossfadeSeconds => _crossfadeSeconds;

  AppThemeMode _themeMode = AppThemeMode.light; // Defaulting to clean Apple iOS Light
  AppThemeMode get themeMode => _themeMode;

  bool get isLight => _themeMode == AppThemeMode.light;

  File? _settingsFile;

  Future<void> init() async {
    try {
      final dir = Directory('/data/user/0/com.rvbhati.player/files');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _settingsFile = File('${dir.path}/settings.json');
      if (_settingsFile!.existsSync()) {
        final content = _settingsFile!.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;

        if (map['audioQuality'] != null) {
          _audioQuality = AudioQuality.values.firstWhere(
            (q) => q.name == map['audioQuality'],
            orElse: () => AudioQuality.standard160,
          );
        }
        if (map['autoQuality'] != null) {
          _autoQuality = map['autoQuality'] as bool;
        }
        if (map['sleepFadeOut'] != null) {
          _sleepFadeOut = map['sleepFadeOut'] as bool;
        }
        if (map['crossfadeSeconds'] != null) {
          _crossfadeSeconds = (map['crossfadeSeconds'] as num).toInt();
        }
        if (map['themeMode'] != null) {
          _themeMode = AppThemeMode.values.firstWhere(
            (t) => t.name == map['themeMode'],
            orElse: () => AppThemeMode.light,
          );
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void _save() {
    try {
      if (_settingsFile == null) return;
      final data = {
        'audioQuality': _audioQuality.name,
        'autoQuality': _autoQuality,
        'sleepFadeOut': _sleepFadeOut,
        'crossfadeSeconds': _crossfadeSeconds,
        'themeMode': _themeMode.name,
      };
      _settingsFile!.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  void setAudioQuality(AudioQuality quality) {
    if (_audioQuality == quality) return;
    _audioQuality = quality;
    _save();
    notifyListeners();
  }

  void setAutoQuality(bool enabled) {
    if (_autoQuality == enabled) return;
    _autoQuality = enabled;
    _save();
    notifyListeners();
  }

  void setSleepFadeOut(bool enabled) {
    if (_sleepFadeOut == enabled) return;
    _sleepFadeOut = enabled;
    _save();
    notifyListeners();
  }

  void setCrossfadeSeconds(int seconds) {
    _crossfadeSeconds = seconds.clamp(0, 5);
    _save();
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _save();
    notifyListeners();
  }
}
