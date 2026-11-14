import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum AudioQuality {
  hd320('320 kbps Hi-Res', 'Studio high bitrate audio (Wi-Fi recommended)', 320),
  standard160('160 kbps Balanced', 'Balanced clarity & mobile data', 160),
  saver96('96 kbps Saver', 'Fast instant buffering on slow networks', 96);

  const AudioQuality(this.label, this.description, this.kbps);
  final String label;
  final String description;
  final int kbps;
}

enum MusicEngine {
  youtube('YouTube Music', 'Universal Search (Songs, Covers, Mashups, Live)', 'YouTube'),
  jiosaavn('JioSaavn HD', 'Lossless 320kbps High Fidelity Audio', 'JioSaavn'),
  spotify('Spotify Music', 'Spotify Top Charts, Hot Hits & Viral Engine', 'Spotify');

  const MusicEngine(this.label, this.description, this.shortName);
  final String label;
  final String description;
  final String shortName;
}

enum AppThemeMode {
  oled('Pure OLED', 'True #000000 BitChord Apple Music Dark'),
  dark('Apple Dark', 'Deep elevated slate glass'),
  light('Apple Light', 'Crisp frosted porcelain white'),
  system('System', 'Follow device theme');

  const AppThemeMode(this.label, this.description);
  final String label;
  final String description;
}

enum PlayerThemeStyle {
  frosted('Frosted Glass', 'Translucent Apple Music blur & depth'),
  vibrant('Vibrant Glow', 'Dynamic crimson & artwork radial wash'),
  minimal('Minimal OLED', 'Pure black zero-distraction studio');

  const PlayerThemeStyle(this.label, this.description);
  final String label;
  final String description;
}

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  AudioQuality _audioQuality = AudioQuality.hd320;
  AudioQuality get audioQuality => _audioQuality;

  MusicEngine _musicEngine = MusicEngine.youtube;
  MusicEngine get musicEngine => _musicEngine;

  bool _autoQuality = true;
  bool get autoQuality => _autoQuality;

  bool _sleepFadeOut = true;
  bool get sleepFadeOut => _sleepFadeOut;

  int _crossfadeSeconds = 3; // 0..12 seconds (AutoMix Crossfade)
  int get crossfadeSeconds => _crossfadeSeconds;

  bool _skipSilence = false;
  bool get skipSilence => _skipSilence;

  AppThemeMode _themeMode = AppThemeMode.oled; // BitChord default OLED dark
  AppThemeMode get themeMode => _themeMode;

  PlayerThemeStyle _playerThemeStyle = PlayerThemeStyle.frosted;
  PlayerThemeStyle get playerThemeStyle => _playerThemeStyle;

  bool _glassBlurEnabled = false;
  bool get glassBlurEnabled => _glassBlurEnabled;

  bool _dynamicArtworkColors = true;
  bool get dynamicArtworkColors => _dynamicArtworkColors;

  bool get isLight => _themeMode == AppThemeMode.light;
  bool get isOled => _themeMode == AppThemeMode.oled;

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
            orElse: () => AudioQuality.hd320,
          );
        }
        if (map['musicEngine'] != null) {
          _musicEngine = MusicEngine.values.firstWhere(
            (e) => e.name == map['musicEngine'] || (map['musicEngine'] == 'bitmusic' && e == MusicEngine.youtube),
            orElse: () => MusicEngine.youtube,
          );
        }
        if (map['autoQuality'] != null) {
          _autoQuality = map['autoQuality'] as bool;
        }
        if (map['sleepFadeOut'] != null) {
          _sleepFadeOut = map['sleepFadeOut'] as bool;
        }
        if (map['crossfadeSeconds'] != null) {
          _crossfadeSeconds = (map['crossfadeSeconds'] as num).toInt().clamp(0, 12);
        }
        if (map['skipSilence'] != null) {
          _skipSilence = map['skipSilence'] as bool;
        }
        if (map['themeMode'] != null) {
          _themeMode = AppThemeMode.values.firstWhere(
            (t) => t.name == map['themeMode'],
            orElse: () => AppThemeMode.oled,
          );
        }
        if (map['playerThemeStyle'] != null) {
          _playerThemeStyle = PlayerThemeStyle.values.firstWhere(
            (p) => p.name == map['playerThemeStyle'],
            orElse: () => PlayerThemeStyle.frosted,
          );
        }
        if (map['glassBlurEnabled'] != null) {
          _glassBlurEnabled = map['glassBlurEnabled'] as bool;
        }
        if (map['dynamicArtworkColors'] != null) {
          _dynamicArtworkColors = map['dynamicArtworkColors'] as bool;
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
        'musicEngine': _musicEngine.name,
        'autoQuality': _autoQuality,
        'sleepFadeOut': _sleepFadeOut,
        'crossfadeSeconds': _crossfadeSeconds,
        'skipSilence': _skipSilence,
        'themeMode': _themeMode.name,
        'playerThemeStyle': _playerThemeStyle.name,
        'glassBlurEnabled': _glassBlurEnabled,
        'dynamicArtworkColors': _dynamicArtworkColors,
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

  void setMusicEngine(MusicEngine engine) {
    if (_musicEngine == engine) return;
    _musicEngine = engine;
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
    final clamped = seconds.clamp(0, 12);
    if (_crossfadeSeconds == clamped) return;
    _crossfadeSeconds = clamped;
    _save();
    notifyListeners();
  }

  void setSkipSilence(bool enabled) {
    if (_skipSilence == enabled) return;
    _skipSilence = enabled;
    _save();
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _save();
    notifyListeners();
  }

  void setPlayerThemeStyle(PlayerThemeStyle style) {
    if (_playerThemeStyle == style) return;
    _playerThemeStyle = style;
    _save();
    notifyListeners();
  }

  void setGlassBlurEnabled(bool enabled) {
    if (_glassBlurEnabled == enabled) return;
    _glassBlurEnabled = enabled;
    _save();
    notifyListeners();
  }

  void setDynamicArtworkColors(bool enabled) {
    if (_dynamicArtworkColors == enabled) return;
    _dynamicArtworkColors = enabled;
    _save();
    notifyListeners();
  }
}
