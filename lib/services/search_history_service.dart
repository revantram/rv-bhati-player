import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Persistently manages recent search queries for Music, Artists, and Shows
class SearchHistoryService extends ChangeNotifier {
  SearchHistoryService._();
  static final SearchHistoryService instance = SearchHistoryService._();

  static const int _maxItems = 15;
  final List<String> _musicHistory = [];
  final List<String> _showsHistory = [];

  List<String> get musicHistory => List.unmodifiable(_musicHistory);
  List<String> get showsHistory => List.unmodifiable(_showsHistory);

  File? _file;

  Future<void> init() async {
    try {
      final dir = Directory('/data/user/0/com.rvbhati.player/files');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _file = File('${dir.path}/search_history.json');
      if (_file!.existsSync()) {
        final content = _file!.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['music'] is List) {
          _musicHistory.clear();
          for (final item in (map['music'] as List)) {
            final s = item.toString().trim();
            if (s.isNotEmpty && !_musicHistory.contains(s)) {
              _musicHistory.add(s);
            }
          }
        }
        if (map['shows'] is List) {
          _showsHistory.clear();
          for (final item in (map['shows'] as List)) {
            final s = item.toString().trim();
            if (s.isNotEmpty && !_showsHistory.contains(s)) {
              _showsHistory.add(s);
            }
          }
        }
      }
    } catch (_) {}
  }

  void addMusicQuery(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _musicHistory.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    _musicHistory.insert(0, clean);
    if (_musicHistory.length > _maxItems) {
      _musicHistory.removeRange(_maxItems, _musicHistory.length);
    }
    _save();
    notifyListeners();
  }

  void removeMusicQuery(String query) {
    _musicHistory.removeWhere((q) => q.toLowerCase() == query.trim().toLowerCase());
    _save();
    notifyListeners();
  }

  void clearMusicHistory() {
    _musicHistory.clear();
    _save();
    notifyListeners();
  }

  void addShowsQuery(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _showsHistory.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    _showsHistory.insert(0, clean);
    if (_showsHistory.length > _maxItems) {
      _showsHistory.removeRange(_maxItems, _showsHistory.length);
    }
    _save();
    notifyListeners();
  }

  void removeShowsQuery(String query) {
    _showsHistory.removeWhere((q) => q.toLowerCase() == query.trim().toLowerCase());
    _save();
    notifyListeners();
  }

  void clearShowsHistory() {
    _showsHistory.clear();
    _save();
    notifyListeners();
  }

  void _save() {
    try {
      if (_file == null) return;
      final data = {
        'music': _musicHistory,
        'shows': _showsHistory,
      };
      _file!.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }
}
