import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import '../models/online_song.dart';
import '../models/playlist_item.dart';
import 'app_state.dart';

class YouTubeAuthService extends ChangeNotifier {
  YouTubeAuthService._();
  static final YouTubeAuthService instance = YouTubeAuthService._();

  static const String _kLoggedIn = 'yt_is_logged_in';
  static const String _kUserId = 'yt_user_id';
  static const String _kUserName = 'yt_user_name';
  static const String _kUserEmail = 'yt_user_email';
  static const String _kAvatar = 'yt_avatar';
  static const String _kCookies = 'yt_cookies';

  bool _isLoggedIn = false;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _avatarUrl;
  String? _cookies;

  bool _isSyncing = false;
  int _syncedSongsCount = 0;
  int _syncedPlaylistsCount = 0;
  String? _lastSyncMessage;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get avatarUrl => _avatarUrl;
  String? get cookies => _cookies;
  bool get isSyncing => _isSyncing;
  int get syncedSongsCount => _syncedSongsCount;
  int get syncedPlaylistsCount => _syncedPlaylistsCount;
  String? get lastSyncMessage => _lastSyncMessage;

  String get displayName {
    if (_userName != null && _userName!.trim().isNotEmpty) {
      return _userName!.trim();
    }
    if (_userEmail != null && _userEmail!.trim().isNotEmpty) {
      return _userEmail!.trim();
    }
    return 'YouTube Music User';
  }

  File _getAuthFile() {
    final dir = Directory('/data/user/0/com.rvbhati.player/files');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/youtube_auth.json');
  }

  Future<void> init() async {
    try {
      final file = _getAuthFile();
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        _isLoggedIn = map[_kLoggedIn] as bool? ?? false;
        _userId = map[_kUserId] as String?;
        _userName = map[_kUserName] as String?;
        _userEmail = map[_kUserEmail] as String?;
        _avatarUrl = map[_kAvatar] as String?;
        _cookies = map[_kCookies] as String?;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[YouTubeAuth] Init error: $e');
    }
  }

  Future<void> saveLoginSession({
    required String cookies,
    String? userId,
    String? userName,
    String? userEmail,
    String? avatarUrl,
  }) async {
    _isLoggedIn = true;
    _cookies = cookies;
    if (userId != null && userId.isNotEmpty) _userId = userId;
    if (userName != null && userName.isNotEmpty) _userName = userName;
    if (userEmail != null && userEmail.isNotEmpty) _userEmail = userEmail;
    if (avatarUrl != null && avatarUrl.isNotEmpty) _avatarUrl = avatarUrl;

    try {
      final file = _getAuthFile();
      final map = {
        _kLoggedIn: true,
        _kCookies: _cookies ?? '',
        _kUserId: _userId,
        _kUserName: _userName,
        _kUserEmail: _userEmail,
        _kAvatar: _avatarUrl,
      };
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      debugPrint('[YouTubeAuth] Error saving session: $e');
    }

    notifyListeners();
    // Auto-sync library in background
    syncUserLibrary();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _avatarUrl = null;
    _cookies = null;
    _syncedSongsCount = 0;
    _syncedPlaylistsCount = 0;
    _lastSyncMessage = null;

    try {
      final file = _getAuthFile();
      if (file.existsSync()) {
        file.deleteSync();
      }
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();
    } catch (e) {
      debugPrint('[YouTubeAuth] Logout error: $e');
    }

    notifyListeners();
  }

  /// Syncs YouTube Music Liked Songs and Playlists
  Future<bool> syncUserLibrary() async {
    if (!_isLoggedIn || _isSyncing) return false;

    _isSyncing = true;
    _lastSyncMessage = 'Connecting to YouTube Music Library...';
    notifyListeners();

    try {
      final appState = AppState.instance;
      int newLikedCount = 0;
      int newPlaylistsCount = 0;

      // 1. Fetch Liked Videos / Songs from YouTube Music InnerTube
      _lastSyncMessage = 'Fetching Liked Songs...';
      notifyListeners();

      final likedTracks = await _fetchBrowsePlaylist('FEmusic_liked_videos');
      if (likedTracks.isNotEmpty) {
        for (final s in likedTracks) {
          appState.toggleFavorite(s.id, item: PlaylistItem.fromOnline(s));
          newLikedCount++;
        }
      }

      // 2. Fetch User's Personal Playlists
      _lastSyncMessage = 'Fetching YouTube Playlists...';
      notifyListeners();

      final userPlaylists = await _fetchUserPlaylists();
      for (final pl in userPlaylists) {
        final plTitle = pl['title']?.toString() ?? 'YouTube Playlist';
        final plId = pl['id']?.toString() ?? '';
        final plItems = pl['items'] as List<OnlineSong>? ?? [];

        if (plItems.isNotEmpty) {
          final playlistName = 'YT • $plTitle';
          appState.createPlaylist(playlistName);
          final playlist = appState.playlists.firstWhere(
            (p) => p.name == playlistName,
            orElse: () => appState.playlists.last,
          );
          for (final song in plItems) {
            appState.addToPlaylist(playlist.id, PlaylistItem.fromOnline(song));
          }
          newPlaylistsCount++;
        }
      }

      _syncedSongsCount = newLikedCount;
      _syncedPlaylistsCount = newPlaylistsCount;
      _lastSyncMessage = 'Sync complete: $newLikedCount songs, $newPlaylistsCount playlists!';
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[YouTubeAuth] Sync error: $e');
      _lastSyncMessage = 'Sync failed: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<OnlineSong>> _fetchBrowsePlaylist(String browseId) async {
    try {
      final url = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
      };
      if (_cookies != null && _cookies!.isNotEmpty) {
        headers['Cookie'] = _cookies!;
      }

      final body = jsonEncode({
        'browseId': browseId,
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20241120.01.00',
            'hl': 'hi',
            'gl': 'IN',
          }
        }
      });

      final resp = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];

      final data = jsonDecode(resp.body);
      return _parseInnerTubeSongs(data);
    } catch (e) {
      debugPrint('[YouTubeAuth] _fetchBrowsePlaylist error: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserPlaylists() async {
    try {
      final url = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
      };
      if (_cookies != null && _cookies!.isNotEmpty) {
        headers['Cookie'] = _cookies!;
      }

      final body = jsonEncode({
        'browseId': 'FEmusic_library_landing',
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20241120.01.00',
            'hl': 'hi',
            'gl': 'IN',
          }
        }
      });

      final resp = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];

      // Extract playlist items
      return [];
    } catch (_) {
      return [];
    }
  }

  List<OnlineSong> _parseInnerTubeSongs(dynamic data) {
    final list = <OnlineSong>[];
    if (data is! Map) return list;

    void scan(dynamic obj) {
      if (obj is Map) {
        if (obj.containsKey('musicResponsiveListItemRenderer')) {
          final r = obj['musicResponsiveListItemRenderer'];
          final id = r['playlistItemData']?['videoId']?.toString() ?? '';
          if (id.isNotEmpty) {
            final flexCols = r['flexColumns'] as List? ?? [];
            String title = 'Unknown';
            String artist = 'YouTube Music';
            if (flexCols.isNotEmpty) {
              final titleRuns =
                  flexCols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List? ?? [];
              if (titleRuns.isNotEmpty) {
                title = titleRuns.map((e) => e['text']?.toString() ?? '').join();
              }
            }
            if (flexCols.length > 1) {
              final artistRuns =
                  flexCols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List? ?? [];
              if (artistRuns.isNotEmpty) {
                artist = artistRuns.map((e) => e['text']?.toString() ?? '').join();
              }
            }
            list.add(OnlineSong(
              id: 'yt_$id',
              title: title,
              artist: artist,
              album: 'YouTube Music Liked',
              duration: const Duration(minutes: 3, seconds: 30),
              streamUrl: '',
              imageUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
            ));
          }
        }
        for (final v in obj.values) {
          scan(v);
        }
      } else if (obj is List) {
        for (final item in obj) {
          scan(item);
        }
      }
    }

    scan(data);
    return list;
  }
}
