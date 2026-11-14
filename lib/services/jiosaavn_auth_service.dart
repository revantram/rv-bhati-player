import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/online_song.dart';
import '../models/playlist_item.dart';
import 'app_state.dart';
import 'saavn_api_service.dart';

class JioSaavnAuthService extends ChangeNotifier {
  JioSaavnAuthService._();
  static final JioSaavnAuthService instance = JioSaavnAuthService._();

  static const String _kLoggedIn = 'jiosaavn_is_logged_in';
  static const String _kPhone = 'jiosaavn_phone';
  static const String _kUserId = 'jiosaavn_user_id';
  static const String _kUserName = 'jiosaavn_user_name';
  static const String _kAvatar = 'jiosaavn_avatar';
  static const String _kCookies = 'jiosaavn_cookies';

  bool _isLoggedIn = false;
  String? _phoneNumber;
  String? _userId;
  String? _userName;
  String? _avatarUrl;
  String? _cookies;

  bool _isSyncing = false;
  int _syncedSongsCount = 0;
  int _syncedPlaylistsCount = 0;
  String? _lastSyncMessage;

  bool get isLoggedIn => _isLoggedIn;
  String? get phoneNumber => _phoneNumber;
  String? get userId => _userId;
  String? get userName => _userName;
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
    if (_phoneNumber != null && _phoneNumber!.trim().isNotEmpty) {
      return _phoneNumber!.trim();
    }
    return 'JioSaavn User';
  }

  File _getAuthFile() {
    final dir = Directory('/data/user/0/com.rvbhati.player/files');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/jiosaavn_auth.json');
  }

  Future<void> init() async {
    try {
      final file = _getAuthFile();
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        _isLoggedIn = map[_kLoggedIn] as bool? ?? false;
        _phoneNumber = map[_kPhone] as String?;
        _userId = map[_kUserId] as String?;
        _userName = map[_kUserName] as String?;
        _avatarUrl = map[_kAvatar] as String?;
        _cookies = map[_kCookies] as String?;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[JioSaavnAuth] Init error: $e');
    }
  }

  Future<void> saveLoginSession({
    required String cookies,
    String? phoneNumber,
    String? userId,
    String? userName,
    String? avatarUrl,
  }) async {
    _isLoggedIn = true;
    _cookies = cookies;
    if (phoneNumber != null && phoneNumber.isNotEmpty) _phoneNumber = phoneNumber;
    if (userId != null && userId.isNotEmpty) _userId = userId;
    if (userName != null && userName.isNotEmpty) _userName = userName;
    if (avatarUrl != null && avatarUrl.isNotEmpty) _avatarUrl = avatarUrl;

    try {
      final file = _getAuthFile();
      final map = {
        _kLoggedIn: true,
        _kCookies: _cookies ?? '',
        _kPhone: _phoneNumber,
        _kUserId: _userId,
        _kUserName: _userName,
        _kAvatar: _avatarUrl,
      };
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      debugPrint('[JioSaavnAuth] Error saving session: $e');
    }

    notifyListeners();
    // Trigger automatic background sync of library
    syncUserLibrary();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _phoneNumber = null;
    _userId = null;
    _userName = null;
    _avatarUrl = null;
    _cookies = null;
    _syncedSongsCount = 0;
    _syncedPlaylistsCount = 0;
    _lastSyncMessage = null;

    try {
      final file = _getAuthFile();
      if (file.existsSync()) {
        await file.delete();
      }

      // Clear webview cookies
      try {
        final cookieManager = CookieManager.instance();
        await cookieManager.deleteAllCookies();
      } catch (_) {}
    } catch (e) {
      debugPrint('[JioSaavnAuth] Logout error: $e');
    }

    notifyListeners();
  }

  /// Syncs Liked Songs and Personal Playlists from JioSaavn
  Future<bool> syncUserLibrary() async {
    if (!_isLoggedIn || _isSyncing) return false;

    _isSyncing = true;
    _lastSyncMessage = 'Connecting to JioSaavn Library...';
    notifyListeners();

    try {
      final appState = AppState.instance;
      int newLikedCount = 0;
      int newPlaylistsCount = 0;

      // 1. Fetch library overview via library.getAll
      final libraryData = await _callApi('library.getAll', {
        'api_version': '4',
        '_format': 'json',
        '_marker': '0',
        'ctx': 'web6dot0',
      });

      List<String> songPids = [];
      List<String> playlistIds = [];

      if (libraryData != null) {
        if (libraryData['song'] is List) {
          songPids = (libraryData['song'] as List).map((e) => e.toString()).toList();
        } else if (libraryData['data'] is Map && libraryData['data']['song'] is List) {
          songPids = (libraryData['data']['song'] as List).map((e) => e.toString()).toList();
        }

        if (libraryData['playlist'] is List) {
          playlistIds = (libraryData['playlist'] as List).map((e) => e.toString()).toList();
        } else if (libraryData['data'] is Map && libraryData['data']['playlist'] is List) {
          playlistIds = (libraryData['data']['playlist'] as List).map((e) => e.toString()).toList();
        }
      }

      // Also try fetching playlists via user.getUserPlaylists if userId is available
      if (_userId != null && _userId!.isNotEmpty) {
        try {
          final plData = await _callApi('user.getUserPlaylists', {
            'api_version': '4',
            '_format': 'json',
            '_marker': '0',
            'ctx': 'web6dot0',
            'uid': _userId!,
            'type': 'public',
            'n': '50',
            'p': '1',
          });

          if (plData != null) {
            dynamic listNode = plData;
            if (plData is Map && plData['data'] != null) listNode = plData['data'];
            if (listNode is List) {
              for (final pl in listNode) {
                if (pl is Map && pl['id'] != null) {
                  final pid = pl['id'].toString();
                  if (!playlistIds.contains(pid)) {
                    playlistIds.add(pid);
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[JioSaavnAuth] getUserPlaylists error: $e');
        }
      }

      // 2. Fetch Liked Songs details
      if (songPids.isNotEmpty) {
        _lastSyncMessage = 'Syncing ${songPids.length} Liked Songs...';
        notifyListeners();

        final songs = await SaavnApiService.instance.fetchSongsByPids(songPids);
        for (final song in songs) {
          final item = PlaylistItem.fromOnlineSong(song);
          if (!appState.isFavorite(item.id)) {
            appState.addFavoriteItem(item);
            newLikedCount++;
          }
        }
      }

      // 3. Fetch and sync Playlists
      if (playlistIds.isNotEmpty) {
        _lastSyncMessage = 'Syncing ${playlistIds.length} Playlists...';
        notifyListeners();

        for (final plId in playlistIds) {
          try {
            final plResult = await SaavnApiService.instance.fetchPlaylist(plId);
            if (plResult.songs.isNotEmpty) {
              final plName = plResult.title.isNotEmpty ? plResult.title : 'JioSaavn Playlist';
              final appPlaylistName = 'JioSaavn: $plName';

              appState.createPlaylist(appPlaylistName);
              for (final song in plResult.songs) {
                appState.addToCustomPlaylist(appPlaylistName, PlaylistItem.fromOnlineSong(song));
              }
              newPlaylistsCount++;
            }
          } catch (e) {
            debugPrint('[JioSaavnAuth] Error syncing playlist $plId: $e');
          }
        }
      }

      appState.saveState();

      _syncedSongsCount = songPids.length;
      _syncedPlaylistsCount = playlistIds.length;
      _lastSyncMessage = 'Synced ${_syncedSongsCount} songs & ${_syncedPlaylistsCount} playlists';
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[JioSaavnAuth] syncUserLibrary error: $e');
      _lastSyncMessage = 'Sync error: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<dynamic> _callApi(String callName, Map<String, String> params) async {
    try {
      final queryParams = <String, String>{
        '__call': callName,
        ...params,
      };

      final uri = Uri.https('www.jiosaavn.com', '/api.php', queryParams);
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);

      request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
      request.headers.set('Accept', 'application/json, text/plain, */*');
      request.headers.set('Referer', 'https://www.jiosaavn.com/');

      if (_cookies != null && _cookies!.isNotEmpty) {
        request.headers.set('Cookie', _cookies!);
      }

      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body);
      }
    } catch (e) {
      debugPrint('[JioSaavnAuth] API $callName failed: $e');
    }
    return null;
  }
}
