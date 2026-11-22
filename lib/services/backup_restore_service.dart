import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/playlist_item.dart';
import 'app_state.dart';
import 'equalizer_service.dart';
import 'search_history_service.dart';
import 'settings_service.dart';

class BackupSummary {
  final DateTime timestamp;
  final String filePath;
  final int playlistsCount;
  final int customPlaylistsCount;
  final int favoriteSongsCount;
  final int favoriteStationsCount;
  final int videoPositionsCount;
  final int episodePositionsCount;
  final int searchHistoryCount;
  final String themeMode;

  const BackupSummary({
    required this.timestamp,
    required this.filePath,
    required this.playlistsCount,
    required this.customPlaylistsCount,
    required this.favoriteSongsCount,
    required this.favoriteStationsCount,
    required this.videoPositionsCount,
    required this.episodePositionsCount,
    required this.searchHistoryCount,
    required this.themeMode,
  });

  String get formattedDate {
    final y = timestamp.year;
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final h = timestamp.hour.toString().padLeft(2, '0');
    final min = timestamp.minute.toString().padLeft(2, '0');
    return '$d-$m-$y $h:$min';
  }
}

class BackupRestoreService {
  BackupRestoreService._();
  static final BackupRestoreService instance = BackupRestoreService._();

  Future<Directory> _getBackupDirectory() async {
    final publicDir = Directory('/storage/emulated/0/Download/RV-Bhati-Player/Backups');
    try {
      if (!publicDir.existsSync()) {
        publicDir.createSync(recursive: true);
      }
      return publicDir;
    } catch (_) {}

    final internalDir = Directory('/data/user/0/com.rvbhati.player/files/Backups');
    if (!internalDir.existsSync()) {
      internalDir.createSync(recursive: true);
    }
    return internalDir;
  }

  /// Creates a local JSON backup of all app data, settings, playlists, favorites, and resume progress.
  Future<BackupSummary> exportBackup() async {
    final dir = await _getBackupDirectory();
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    final filename = 'RV_Bhati_Player_Backup_${y}${m}${d}_${h}${min}${sec}.json';
    final targetFile = File('${dir.path}/$filename');

    final app = AppState.instance;
    final settings = SettingsService.instance;
    final search = SearchHistoryService.instance;
    final eq = EqualizerService.instance;

    final backupData = {
      'app': 'com.rvbhati.player',
      'schemaVersion': 1,
      'exportedAt': now.toIso8601String(),
      'profile': {
        'userName': app.userName,
        'userPhone': app.userPhone,
        'language': app.language == AppLanguage.hi ? 'hi' : 'en',
        'accent': app.accentColor.toARGB32(),
      },
      'settings': {
        'themeMode': settings.themeMode.name,
        'playerThemeStyle': settings.playerThemeStyle.name,
        'glassBlurEnabled': settings.glassBlurEnabled,
        'dynamicArtworkColors': settings.dynamicArtworkColors,
        'audioQuality': settings.audioQuality.name,
        'autoQuality': settings.autoQuality,
        'crossfadeSeconds': settings.crossfadeSeconds,
      },
      'equalizer': {
        'enabled': eq.isEnabled,
        'preset': eq.currentPreset,
        'bands': eq.bands,
        'bass': eq.bassStrength,
        'virtualizer': eq.virtualizerStrength,
        'surround': eq.surround3D,
      },
      'playlists': app.playlists,
      'customPlaylists': app.customPlaylists.map(
        (k, v) => MapEntry(k, v.map((item) => item.toJson()).toList()),
      ),
      'favorites': app.favorites.toList(),
      'favoriteStations': app.favoriteStations.toList(),
      'favoriteItems': app.favoriteItems.values.map((item) => item.toJson()).toList(),
      'recentlyPlayed': app.recentlyPlayed,
      'videoPositions': app.videoPositions,
      'episodePositions': app.episodePositions,
      'episodeDurations': app.episodeDurations,
      'playCounts': app.playCounts,
      'searchHistory': {
        'music': search.musicHistory,
        'shows': search.showsHistory,
      },
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
    await targetFile.writeAsString(jsonStr);

    return BackupSummary(
      timestamp: now,
      filePath: targetFile.path,
      playlistsCount: app.playlists.length,
      customPlaylistsCount: app.customPlaylists.length,
      favoriteSongsCount: app.favorites.length,
      favoriteStationsCount: app.favoriteStations.length,
      videoPositionsCount: app.videoPositions.length,
      episodePositionsCount: app.episodePositions.length,
      searchHistoryCount: search.musicHistory.length + search.showsHistory.length,
      themeMode: settings.themeMode.label,
    );
  }

  /// Lists all discovered JSON backup files ordered with most recent first.
  Future<List<File>> listBackups() async {
    final List<File> list = [];
    final dir = await _getBackupDirectory();
    if (dir.existsSync()) {
      final entries = dir.listSync();
      for (final e in entries) {
        if (e is File && e.path.endsWith('.json')) {
          list.add(e);
        }
      }
    }

    // Also check internal directory if public was different
    final internalDir = Directory('/data/user/0/com.rvbhati.player/files/Backups');
    if (internalDir.existsSync() && internalDir.path != dir.path) {
      for (final e in internalDir.listSync()) {
        if (e is File && e.path.endsWith('.json') && !list.any((f) => f.path == e.path)) {
          list.add(e);
        }
      }
    }

    list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return list;
  }

  /// Safely restores data from a JSON backup file with structural verification.
  Future<BackupSummary> restoreBackup(File file) async {
    if (!file.existsSync()) {
      throw Exception('Backup file not found on disk.');
    }

    final raw = await file.readAsString();
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw Exception('Invalid or corrupted JSON format in backup file.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Backup file does not contain a valid JSON object.');
    }

    if (decoded['app'] != 'com.rvbhati.player') {
      throw Exception('Incompatible backup file. Expected RV Bhati Player archive.');
    }

    final bool hasValidPayload = decoded.containsKey('playlists') ||
        decoded.containsKey('customPlaylists') ||
        decoded.containsKey('favorites') ||
        decoded.containsKey('favoriteStations') ||
        decoded.containsKey('settings') ||
        decoded.containsKey('videoPositions');
    if (!hasValidPayload) {
      throw Exception('Empty or malformed backup file. No recoverable data found.');
    }

    final app = AppState.instance;
    final settings = SettingsService.instance;
    final search = SearchHistoryService.instance;
    final eq = EqualizerService.instance;

    // 1. Profile / Settings
    if (decoded['profile'] is Map) {
      final prof = decoded['profile'] as Map<String, dynamic>;
      if (prof['language'] == 'hi') {
        app.setLanguage(AppLanguage.hi);
      } else if (prof['language'] == 'en') {
        app.setLanguage(AppLanguage.en);
      }
    }

    if (decoded['settings'] is Map) {
      final s = decoded['settings'] as Map<String, dynamic>;
      final themeStr = s['themeMode'] as String?;
      if (themeStr != null) {
        final mode = AppThemeMode.values.firstWhere(
          (m) => m.name == themeStr,
          orElse: () => AppThemeMode.iosLiquid,
        );
        settings.setThemeMode(mode);
      }
      final qStr = s['audioQuality'] as String?;
      if (qStr != null) {
        final q = AudioQuality.values.firstWhere(
          (aq) => aq.name == qStr,
          orElse: () => AudioQuality.hd320,
        );
        settings.setAudioQuality(q);
      }
      if (s['autoQuality'] is bool) {
        settings.setAutoQuality(s['autoQuality'] as bool);
      }
      if (s['crossfadeSeconds'] is num) {
        settings.setCrossfadeSeconds((s['crossfadeSeconds'] as num).toInt());
      }
    }

    // 2. Playlists
    int restoredPlaylists = 0;
    int restoredCustomPlaylists = 0;
    if (decoded['playlists'] is Map) {
      final pMap = decoded['playlists'] as Map<String, dynamic>;
      for (final e in pMap.entries) {
        if (e.value is List) {
          final list = (e.value as List).cast<String>();
          for (final songId in list) {
            app.addToPlaylist(e.key, songId);
          }
          restoredPlaylists++;
        }
      }
    }

    if (decoded['customPlaylists'] is Map) {
      final cpMap = decoded['customPlaylists'] as Map<String, dynamic>;
      for (final e in cpMap.entries) {
        if (e.value is List) {
          final items = <PlaylistItem>[];
          for (final itemJson in (e.value as List)) {
            if (itemJson is Map<String, dynamic>) {
              try {
                items.add(PlaylistItem.fromJson(itemJson));
              } catch (_) {}
            }
          }
          app.setCustomPlaylist(e.key, items);
          restoredCustomPlaylists++;
        }
      }
    }

    // 3. Favorites
    int restoredFavSongs = 0;
    int restoredFavStations = 0;
    if (decoded['favorites'] is List) {
      final favList = (decoded['favorites'] as List).cast<String>();
      for (final id in favList) {
        if (!app.isFavorite(id)) {
          app.toggleFavorite(id);
        }
      }
      restoredFavSongs = favList.length;
    }

    if (decoded['favoriteStations'] is List) {
      final favStList = (decoded['favoriteStations'] as List).cast<String>();
      for (final id in favStList) {
        if (!app.isStationFavorite(id)) {
          app.toggleStationFavorite(id);
        }
      }
      restoredFavStations = favStList.length;
    }

    if (decoded['favoriteItems'] is List) {
      for (final itemJson in decoded['favoriteItems'] as List) {
        try {
          final item = PlaylistItem.fromJson(itemJson as Map<String, dynamic>);
          app.addFavoriteItem(item);
        } catch (_) {}
      }
    }

    // 4. Video & Episode positions
    int restoredVideoPos = 0;
    int restoredEpisodePos = 0;
    if (decoded['videoPositions'] is Map) {
      final vp = decoded['videoPositions'] as Map<String, dynamic>;
      for (final e in vp.entries) {
        if (e.value is num) {
          app.saveVideoPosition(e.key, (e.value as num).toInt(), (e.value as num).toInt() + 100);
          restoredVideoPos++;
        }
      }
    }

    if (decoded['episodePositions'] is Map) {
      final ep = decoded['episodePositions'] as Map<String, dynamic>;
      for (final e in ep.entries) {
        if (e.value is num) {
          app.saveEpisodePosition(e.key, (e.value as num).toInt(), (e.value as num).toInt() + 100);
          restoredEpisodePos++;
        }
      }
    }

    // 5. Search history
    int restoredSearch = 0;
    if (decoded['searchHistory'] is Map) {
      final sh = decoded['searchHistory'] as Map<String, dynamic>;
      if (sh['music'] is List) {
        for (final q in (sh['music'] as List).cast<String>()) {
          search.addMusicQuery(q);
          restoredSearch++;
        }
      }
      if (sh['shows'] is List) {
        for (final q in (sh['shows'] as List).cast<String>()) {
          search.addShowsQuery(q);
          restoredSearch++;
        }
      }
    }

    final dateStr = decoded['exportedAt'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

    return BackupSummary(
      timestamp: date,
      filePath: file.path,
      playlistsCount: restoredPlaylists,
      customPlaylistsCount: restoredCustomPlaylists,
      favoriteSongsCount: restoredFavSongs,
      favoriteStationsCount: restoredFavStations,
      videoPositionsCount: restoredVideoPos,
      episodePositionsCount: restoredEpisodePos,
      searchHistoryCount: restoredSearch,
      themeMode: settings.themeMode.label,
    );
  }
}
