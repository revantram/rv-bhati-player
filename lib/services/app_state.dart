import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/media_file.dart';

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
      'hi': 'संगीत',
    },
    'online_music': {
      'en': 'Online Music',
      'hi': 'ऑनलाइन संगीत',
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
      'en': 'Live Radio',
      'hi': 'लाइव रेडियो',
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
      'hi': 'तारीख (नए पहले)',
    },
    'sort_date_asc': {
      'en': 'Date (Oldest first)',
      'hi': 'तारीख (पुराने पहले)',
    },
    'sort_duration_desc': {
      'en': 'Duration (Longest first)',
      'hi': 'अवधि (लंबे पहले)',
    },
    'sort_duration_asc': {
      'en': 'Duration (Shortest first)',
      'hi': 'अवधि (छोटे पहले)',
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
      'en': 'No favorite songs yet',
      'hi': 'कोई पसंदीदा गाना नहीं है',
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
    'timer_off': {
      'en': 'Turn Off',
      'hi': 'बंद करें',
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
      'en': 'No .lrc lyrics file found for this song',
      'hi': 'इस गाने के लिए कोई .lrc फ़ाइल नहीं मिली',
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

  Color _accentColor = const Color(0xFF7C6CFF);
  Color get accentColor => _accentColor;

  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  final Map<String, List<String>> _playlists = {};
  Map<String, List<String>> get playlists => _playlists;

  final List<String> _recentlyPlayed = [];
  List<String> get recentlyPlayed => _recentlyPlayed;

  final Map<String, int> _videoPositions = {}; // path -> seconds

  // Sleep Timer
  Timer? _sleepTimer;
  DateTime? _sleepTargetTime;
  int _sleepMinutesRemaining = 0;
  int get sleepMinutesRemaining => _sleepMinutesRemaining;
  bool get isSleepTimerActive => _sleepMinutesRemaining > 0;

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
      final dir = Directory('/data/user/0/com.rvbhati.player/files');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _storageFile = File('${dir.path}/app_state.json');
      if (_storageFile!.existsSync()) {
        final content = _storageFile!.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['language'] == 'hi') _language = AppLanguage.hi;
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
        if (map['videoPositions'] is Map) {
          final vp = map['videoPositions'] as Map<String, dynamic>;
          for (final e in vp.entries) {
            _videoPositions[e.key] = (e.value as num).toInt();
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void _save() {
    try {
      if (_storageFile == null) return;
      final data = {
        'language': _language == AppLanguage.hi ? 'hi' : 'en',
        'accent': _accentColor.toARGB32(),
        'favorites': _favorites.toList(),
        'recentlyPlayed': _recentlyPlayed,
        'playlists': _playlists,
        'videoPositions': _videoPositions,
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

  void createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    _playlists.putIfAbsent(name.trim(), () => []);
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

  void removeFromPlaylist(String playlistName, String pathOrId) {
    final list = _playlists[playlistName];
    if (list != null) {
      list.remove(pathOrId);
      _save();
      notifyListeners();
    }
  }

  void deletePlaylist(String playlistName) {
    _playlists.remove(playlistName);
    _save();
    notifyListeners();
  }

  void markPlayed(String pathOrId) {
    _recentlyPlayed.remove(pathOrId);
    _recentlyPlayed.insert(0, pathOrId);
    if (_recentlyPlayed.length > 20) {
      _recentlyPlayed.removeRange(20, _recentlyPlayed.length);
    }
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
  void setSleepTimer(int minutes, VoidCallback onTrigger) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      _sleepMinutesRemaining = 0;
      _sleepTargetTime = null;
      notifyListeners();
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
        onTrigger();
        notifyListeners();
      } else {
        final mins = (diff.inSeconds / 60).ceil();
        if (mins != _sleepMinutesRemaining) {
          _sleepMinutesRemaining = mins;
          notifyListeners();
        }
      }
    });
  }

  String tr(String key) => AppStrings.get(key, _language);
}
