import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/media_file.dart';
import '../models/playlist_item.dart';
import 'audio_controller.dart';
import 'equalizer_service.dart';
import 'settings_service.dart';

enum AppLanguage { en, hi }

class AppStrings {
  static const Map<String, Map<String, String>> _values = {
    'app_name': {
      'en': 'RV Bhati Player',
      'hi': 'आरवी भाटी प्लेयर',
    },
    'videos': {
      'en': 'Videos',
      'hi': 'वीडियो',
    },
    'music': {
      'en': 'Music',
      'hi': 'म्यूजिक',
    },
    'online_music': {
      'en': 'Online Music',
      'hi': 'ऑनलाइन म्यूजिक',
    },
    'trending': {
      'en': 'Trending Hits',
      'hi': 'ट्रेंडिंग हिट्स',
    },
    'artists': {
      'en': 'Singers',
      'hi': 'गायक',
    },
    'search_online': {
      'en': 'Search songs, singers, movies...',
      'hi': 'गाने, गायक, फ़िल्में खोजें...',
    },
    'radio': {
      'en': 'Radio',
      'hi': 'रेडियो',
    },
    'live': {
      'en': 'LIVE',
      'hi': 'लाइव',
    },
    'now_streaming': {
      'en': 'Now Streaming Live',
      'hi': 'अभी लाइव चल रहा है',
    },
    'all_videos': {
      'en': 'All Videos',
      'hi': 'सभी वीडियो',
    },
    'folders': {
      'en': 'Folders',
      'hi': 'फ़ोल्डर्स',
    },
    'all_songs': {
      'en': 'All Songs',
      'hi': 'सभी गाने',
    },
    'favorites': {
      'en': 'Favorites',
      'hi': 'पसंदीदा',
    },
    'playlists': {
      'en': 'Playlists',
      'hi': 'प्लेलिस्ट',
    },
    'recently_played': {
      'en': 'Recently Played',
      'hi': 'हाल ही में चलाए गए',
    },
    'search_hint': {
      'en': 'Search videos, songs...',
      'hi': 'वीडियो, गाने खोजें...',
    },
    'sort_by': {
      'en': 'Sort by',
      'hi': 'क्रमबद्ध करें',
    },
    'sort_name_asc': {
      'en': 'Name (A to Z)',
      'hi': 'नाम (A से Z)',
    },
    'sort_name_desc': {
      'en': 'Name (Z to A)',
      'hi': 'नाम (Z से A)',
    },
    'sort_date_desc': {
      'en': 'Date (Newest first)',
      'hi': 'तारीख (नई पहले)',
    },
    'sort_date_asc': {
      'en': 'Date (Oldest first)',
      'hi': 'तारीख (पुरानी पहले)',
    },
    'sort_duration_desc': {
      'en': 'Duration (Longest)',
      'hi': 'अवधि (सबसे लंबी)',
    },
    'sort_duration_asc': {
      'en': 'Duration (Shortest)',
      'hi': 'अवधि (सबसे छोटी)',
    },
    'no_videos': {
      'en': 'No videos found',
      'hi': 'कोई वीडियो नहीं मिला',
    },
    'no_songs': {
      'en': 'No songs found',
      'hi': 'कोई गाना नहीं मिला',
    },
    'no_favorites': {
      'en': 'No favorites added yet',
      'hi': 'अभी तक कोई पसंदीदा नहीं जोड़ा',
    },
    'no_playlists': {
      'en': 'No playlists created',
      'hi': 'कोई प्लेलिस्ट नहीं बनी',
    },
    'create_playlist': {
      'en': 'New Playlist',
      'hi': 'नई प्लेलिस्ट',
    },
    'playlist_name': {
      'en': 'Playlist Name',
      'hi': 'प्लेलिस्ट का नाम',
    },
    'cancel': {
      'en': 'Cancel',
      'hi': 'रद्द करें',
    },
    'create': {
      'en': 'Create',
      'hi': 'बनाएं',
    },
    'add_to_playlist': {
      'en': 'Add to Playlist',
      'hi': 'प्लेलिस्ट में जोड़ें',
    },
    'sleep_timer': {
      'en': 'Sleep Timer',
      'hi': 'स्लीप टाइमर',
    },
    'end_of_song': {
      'en': 'End of this song',
      'hi': 'इस गाने के अंत में',
    },
    'timer_off': {
      'en': 'Turn Off',
      'hi': 'बंद करें',
    },
    'equalizer': {
      'en': 'Equalizer & Bass',
      'hi': 'इक्वलाइज़र और बास',
    },
    'bass_boost': {
      'en': 'Bass Booster',
      'hi': 'बास बूस्टर',
    },
    'virtualizer': {
      'en': '3D Surround Sound',
      'hi': '3D सराउंड साउंड',
    },
    'speed': {
      'en': 'Playback Speed',
      'hi': 'प्लेबैक स्पीड',
    },
    'subtitles': {
      'en': 'Subtitles',
      'hi': 'सबटाइटल',
    },
    'subtitles_off': {
      'en': 'Off',
      'hi': 'बंद',
    },
    'subtitles_delay': {
      'en': 'Delay',
      'hi': 'विलंब',
    },
    'subtitles_size': {
      'en': 'Text Size',
      'hi': 'अक्षर आकार',
    },
    'queue': {
      'en': 'Up Next / Queue',
      'hi': 'अगले गाने',
    },
    'lyrics': {
      'en': 'Lyrics',
      'hi': 'गीत के बोल',
    },
    'no_lyrics': {
      'en': 'No lyrics available for this track',
      'hi': 'इस गाने के बोल उपलब्ध नहीं हैं',
    },
    'resumed_playback': {
      'en': 'Resumed from',
      'hi': 'प्लेबैक फिर शुरू हुआ',
    },
    'restart': {
      'en': 'Restart',
      'hi': 'शुरू से',
    },
    'touch_locked': {
      'en': 'Screen Locked (Tap unlock icon)',
      'hi': 'स्क्रीन लॉक है (अनलॉक पर टैप करें)',
    },
    'touch_unlocked': {
      'en': 'Screen Unlocked',
      'hi': 'स्क्रीन अनलॉक हो गई',
    },
    'theme_color': {
      'en': 'Accent Color',
      'hi': 'थीम रंग',
    },
    'settings': {
      'en': 'Settings',
      'hi': 'सेटिंग्स',
    },
    'audio_quality': {
      'en': 'Audio Streaming Quality',
      'hi': 'ऑडियो स्ट्रीमिंग क्वालिटी',
    },
    'auto_quality': {
      'en': 'Smart Auto Quality',
      'hi': 'स्मार्ट ऑटो क्वालिटी',
    },
    'sleep_fade_out': {
      'en': 'Sleep Timer Fade-Out',
      'hi': 'स्लीप टाइमर फेड-आउट',
    },
    'crossfade': {
      'en': 'DJ Crossfade Duration',
      'hi': 'डीजे क्रॉसफ़ेड अवधि',
    },
    'theme_style': {
      'en': 'Theme Style',
      'hi': 'थीम शैली',
    },
  };

  static String get(String key, AppLanguage lang) {
    final map = _values[key];
    if (map == null) return key;
    return map[lang == AppLanguage.hi ? 'hi' : 'en'] ?? map['en'] ?? key;
  }
}

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  AppLanguage _language = AppLanguage.en;
  AppLanguage get language => _language;

  String _userName = 'Revant Ram';
  String get userName => _userName;

  void setUserName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _userName = clean;
    _save();
    notifyListeners();
  }

  Color _accentColor = const Color(0xFF7C6CFF);
  Color? _dynamicAccentColor;
  Color get accentColor => _dynamicAccentColor ?? _accentColor;
  Color get staticAccentColor => _accentColor;

  void setDynamicAccentColor(Color? color) {
    if (_dynamicAccentColor == color) return;
    _dynamicAccentColor = color;
    notifyListeners();
  }

  void clearDynamicAccentColor() {
    if (_dynamicAccentColor != null) {
      _dynamicAccentColor = null;
      notifyListeners();
    }
  }

  bool get isLight => SettingsService.instance.isLight;
  bool get isDark => !isLight;
  Color get backgroundColor => isLight ? const Color(0xFFF8FAFC) : const Color(0xFF090D16);
  Color get surfaceColor => isLight ? Colors.white : const Color(0xFF131722);
  Color get surfaceColorSecondary => isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1C2230);
  Color get textColor => isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  Color get secondaryTextColor => isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get cardColor => surfaceColor;
  Color get cardBorderColor => isLight ? const Color(0xFFE2E8F0) : const Color(0x1FFFFFFF);
  Color get dividerColor => isLight ? const Color(0xFFE2E8F0) : const Color(0x14FFFFFF);

  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  final Map<String, List<String>> _playlists = {};
  Map<String, List<String>> get playlists => _playlists;

  // Hybrid Custom Playlists containing both local and online tracks
  final Map<String, List<PlaylistItem>> _customPlaylists = {};
  Map<String, List<PlaylistItem>> get customPlaylists => Map.unmodifiable(_customPlaylists);

  final List<String> _recentlyPlayed = [];
  List<String> get recentlyPlayed => _recentlyPlayed;

  final Map<String, int> _playCounts = {};
  Map<String, int> get playCounts => Map.unmodifiable(_playCounts);

  final Map<String, int> _videoPositions = {}; // path -> seconds

  // Sleep Timer
  Timer? _sleepTimer;
  DateTime? _sleepTargetTime;
  int _sleepMinutesRemaining = 0;
  int get sleepMinutesRemaining => _sleepMinutesRemaining;
  bool _sleepEndOfSong = false;
  bool get isSleepEndOfSong => _sleepEndOfSong;
  bool get isSleepTimerActive => _sleepMinutesRemaining > 0 || _sleepEndOfSong;

  String get sleepTimerFormatted {
    if (_sleepEndOfSong) return 'End of Song';
    if (_sleepTargetTime == null) return '';
    final diff = _sleepTargetTime!.difference(DateTime.now());
    if (diff.isNegative) return '';
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  File? _storageFile;

  static const List<Color> accentOptions = [
    Color(0xFF7C6CFF), // Electric Purple (Default)
    Color(0xFF00D2FF), // Cyber Cyan
    Color(0xFF00E676), // Emerald Green
    Color(0xFFFF6B6B), // Sunset Orange
    Color(0xFFFF2A85), // Neon Pink
    Color(0xFFFFD166), // Gold Amber
  ];

  Future<void> init() async {
    try {
      await SettingsService.instance.init();
      SettingsService.instance.addListener(() => notifyListeners());

      final dir = Directory('/data/user/0/com.rvbhati.player/files');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _storageFile = File('${dir.path}/app_state.json');
      if (_storageFile!.existsSync()) {
        final content = _storageFile!.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['language'] == 'hi') _language = AppLanguage.hi;
        if (map['userName'] != null) _userName = map['userName'] as String;
        if (map['accent'] != null) _accentColor = Color(map['accent'] as int);
        if (map['favorites'] is List) {
          _favorites.addAll((map['favorites'] as List).cast<String>());
        }
        if (map['recentlyPlayed'] is List) {
          _recentlyPlayed.addAll((map['recentlyPlayed'] as List).cast<String>());
        }
        if (map['playlists'] is Map) {
          final p = map['playlists'] as Map<String, dynamic>;
          for (final e in p.entries) {
            if (e.value is List) {
              _playlists[e.key] = (e.value as List).cast<String>();
            }
          }
        }
        if (map['customPlaylists'] is Map) {
          final cp = map['customPlaylists'] as Map<String, dynamic>;
          for (final e in cp.entries) {
            if (e.value is List) {
              _customPlaylists[e.key] = (e.value as List)
                  .map((item) => PlaylistItem.fromJson(item as Map<String, dynamic>))
                  .toList();
            }
          }
        }
        if (map['videoPositions'] is Map) {
          final vp = map['videoPositions'] as Map<String, dynamic>;
          for (final e in vp.entries) {
            _videoPositions[e.key] = (e.value as num).toInt();
          }
        }
        if (map['playCounts'] is Map) {
          final pc = map['playCounts'] as Map<String, dynamic>;
          for (final e in pc.entries) {
            if (e.value is num) {
              _playCounts[e.key] = (e.value as num).toInt();
            }
          }
        }

        // Initialize Equalizer from storage
        if (map['eq_enabled'] != null) {
          EqualizerService.instance.initFromStorage(
            isEnabled: map['eq_enabled'] as bool?,
            preset: map['eq_preset'] as String?,
            bands: (map['eq_bands'] as List?)?.cast<int>(),
            bass: map['eq_bass'] as int?,
            virtualizer: map['eq_virtualizer'] as int?,
            surround: map['eq_surround'] as bool?,
          );
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void _save() {
    try {
      if (_storageFile == null) return;
      final eq = EqualizerService.instance;
      final data = {
        'language': _language == AppLanguage.hi ? 'hi' : 'en',
        'userName': _userName,
        'accent': _accentColor.toARGB32(),
        'favorites': _favorites.toList(),
        'recentlyPlayed': _recentlyPlayed,
        'playlists': _playlists,
        'customPlaylists': _customPlaylists.map(
          (k, v) => MapEntry(k, v.map((item) => item.toJson()).toList()),
        ),
        'videoPositions': _videoPositions,
        'playCounts': _playCounts,
        'eq_enabled': eq.isEnabled,
        'eq_preset': eq.currentPreset,
        'eq_bands': eq.bands,
        'eq_bass': eq.bassStrength,
        'eq_virtualizer': eq.virtualizerStrength,
        'eq_surround': eq.surround3D,
      };
      _storageFile!.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    _save();
    notifyListeners();
  }

  void setAccentColor(Color color) {
    if (_accentColor == color) return;
    _accentColor = color;
    _save();
    notifyListeners();
  }

  bool isFavorite(String pathOrId) => _favorites.contains(pathOrId);

  void toggleFavorite(String pathOrId) {
    if (_favorites.contains(pathOrId)) {
      _favorites.remove(pathOrId);
    } else {
      _favorites.add(pathOrId);
    }
    _save();
    notifyListeners();
  }

  // --- Hybrid Custom Playlists ---
  void createPlaylist(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _playlists.putIfAbsent(clean, () => []);
    _customPlaylists.putIfAbsent(clean, () => []);
    _save();
    notifyListeners();
  }

  void deletePlaylist(String playlistName) {
    _playlists.remove(playlistName);
    _customPlaylists.remove(playlistName);
    _save();
    notifyListeners();
  }

  void addToPlaylist(String playlistName, String pathOrId) {
    final list = _playlists[playlistName];
    if (list != null && !list.contains(pathOrId)) {
      list.add(pathOrId);
      _save();
      notifyListeners();
    }
  }

  void addToCustomPlaylist(String playlistName, PlaylistItem item) {
    _customPlaylists.putIfAbsent(playlistName, () => []);
    final list = _customPlaylists[playlistName]!;
    if (!list.any((t) => t.id == item.id)) {
      list.add(item);
      _save();
      notifyListeners();
    }
  }

  void removeFromCustomPlaylist(String playlistName, String itemId) {
    final list = _customPlaylists[playlistName];
    if (list != null) {
      list.removeWhere((t) => t.id == itemId);
      _save();
      notifyListeners();
    }
  }

  void markPlayed(String pathOrId) {
    _recentlyPlayed.remove(pathOrId);
    _recentlyPlayed.insert(0, pathOrId);
    if (_recentlyPlayed.length > 20) {
      _recentlyPlayed.removeRange(20, _recentlyPlayed.length);
    }
    _playCounts[pathOrId] = (_playCounts[pathOrId] ?? 0) + 1;
    _save();
    notifyListeners();
  }

  int getVideoPosition(String path) {
    return _videoPositions[path] ?? 0;
  }

  void saveVideoPosition(String path, int seconds, int totalSeconds) {
    if (seconds > 5 && (totalSeconds - seconds > 10)) {
      _videoPositions[path] = seconds;
    } else if (totalSeconds - seconds <= 10) {
      _videoPositions.remove(path);
    }
    _save();
  }

  // --- Sleep timer ---
  void setSleepTimer(int minutes, VoidCallback onTrigger, {bool endOfSong = false}) {
    _sleepTimer?.cancel();
    _sleepEndOfSong = endOfSong;

    if (endOfSong) {
      _sleepMinutesRemaining = 0;
      _sleepTargetTime = null;
      notifyListeners();
      return;
    }

    if (minutes <= 0) {
      cancelSleepTimer();
      return;
    }

    _sleepMinutesRemaining = minutes;
    _sleepTargetTime = DateTime.now().add(Duration(minutes: minutes));
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTargetTime == null) {
        timer.cancel();
        return;
      }
      final diff = _sleepTargetTime!.difference(DateTime.now());
      if (diff.isNegative) {
        timer.cancel();
        _sleepMinutesRemaining = 0;
        _sleepTargetTime = null;
        _sleepEndOfSong = false;
        onTrigger();
        try {
          AudioController.instance.player.setVolume(1.0);
        } catch (_) {}
        notifyListeners();
      } else {
        final sec = diff.inSeconds;
        // Last 10s smooth volume fade-out if enabled
        if (SettingsService.instance.sleepFadeOut && sec <= 10 && sec > 0) {
          final vol = (sec / 10.0).clamp(0.02, 1.0);
          try {
            AudioController.instance.player.setVolume(vol);
          } catch (_) {}
        }
        final mins = (diff.inSeconds / 60).ceil();
        if (mins != _sleepMinutesRemaining) {
          _sleepMinutesRemaining = mins;
        }
        notifyListeners();
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepMinutesRemaining = 0;
    _sleepTargetTime = null;
    _sleepEndOfSong = false;
    try {
      AudioController.instance.player.setVolume(1.0);
    } catch (_) {}
    notifyListeners();
  }

  void saveEqualizer() {
    _save();
  }

  String tr(String key) => AppStrings.get(key, _language);
  static String translate(String key) => AppStrings.get(key, instance._language);
}
