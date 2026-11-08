import 'dart:convert';
import 'dart:io';

import '../models/online_song.dart';

class SaavnArtist {
  final String name;
  final String category; // 'Legends', '90s Icons', 'Modern Hits'
  final String subtitle;
  final String avatarUrl;

  const SaavnArtist({
    required this.name,
    required this.category,
    required this.subtitle,
    required this.avatarUrl,
  });
}

class SaavnApiService {
  SaavnApiService._();
  static final SaavnApiService instance = SaavnApiService._();

  static const String _baseUrl = 'https://www.jiosaavn.com/api.php';
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  // In-memory caches to make UI snappy
  final Map<String, List<OnlineSong>> _cachedQueries = {};
  List<OnlineSong>? _cachedTrending;
  final Map<String, List<OnlineSong>> _cachedPlaylists = {};
  final Map<String, List<OnlineSong>> _cachedArtists = {};

  // Curated Artists Catalog as requested
  static const List<SaavnArtist> curatedArtists = [
    // Modern Hits
    SaavnArtist(
      name: 'Arijit Singh',
      category: 'Modern Hits',
      subtitle: 'The Soul of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_002_20230323062147_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Atif Aslam',
      category: 'Modern Hits',
      subtitle: 'Romantic Melodies & Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Jubin Nautiyal',
      category: 'Modern Hits',
      subtitle: 'Heart-touching Chartbusters',
      avatarUrl: 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20230526115945_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shreya Ghoshal',
      category: 'Modern Hits',
      subtitle: 'Melody Queen of Modern Era',
      avatarUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_004_20230323062024_500x500.jpg',
    ),

    // 90s Icons
    SaavnArtist(
      name: 'Kumar Sanu',
      category: '90s Icons',
      subtitle: 'King of 90s Romance',
      avatarUrl: 'https://c.saavncdn.com/artists/Kumar_Sanu_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Alka Yagnik',
      category: '90s Icons',
      subtitle: 'Golden Voice of 90s & 2000s',
      avatarUrl: 'https://c.saavncdn.com/artists/Alka_Yagnik_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Udit Narayan',
      category: '90s Icons',
      subtitle: 'Evergreen Romantic Voice',
      avatarUrl: 'https://c.saavncdn.com/artists/Udit_Narayan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sonu Nigam',
      category: '90s Icons',
      subtitle: 'The Voice of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Sonu_Nigam_500x500.jpg',
    ),

    // Legends
    SaavnArtist(
      name: 'Kishore Kumar',
      category: 'Legends',
      subtitle: 'The Incomparable Genius',
      avatarUrl: 'https://c.saavncdn.com/artists/Kishore_Kumar_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mohammed Rafi',
      category: 'Legends',
      subtitle: 'The Immortal Golden Voice',
      avatarUrl: 'https://c.saavncdn.com/artists/Mohammed_Rafi_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Lata Mangeshkar',
      category: 'Legends',
      subtitle: 'Nightingale of India',
      avatarUrl: 'https://c.saavncdn.com/artists/Lata_Mangeshkar_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mukesh',
      category: 'Legends',
      subtitle: 'The Soulful Legend',
      avatarUrl: 'https://c.saavncdn.com/artists/Mukesh_500x500.jpg',
    ),
  ];

  Future<String?> _get(String url) async {
    try {
      final req = await _client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      req.headers.set('Accept', 'application/json, text/plain, */*');
      final res = await req.close();
      if (res.statusCode == 200) {
        return await utf8.decodeStream(res);
      }
    } catch (_) {}
    return null;
  }

  /// 1. Search Query:
  /// Song name, movie, ya artist search karne par accurate results
  Future<List<OnlineSong>> searchSongs(String query, {int page = 1, int limit = 30}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final cacheKey = '${cleanQuery.toLowerCase()}_${page}_$limit';
    if (_cachedQueries.containsKey(cacheKey)) {
      return _cachedQueries[cacheKey]!;
    }

    try {
      final q = Uri.encodeComponent(cleanQuery);
      final url =
          '$_baseUrl?__call=search.getResults&q=$q&_format=json&_marker=0&api_version=4&n=$limit&p=$page';

      final body = await _get(url);
      if (body == null) return const [];

      final data = json.decode(body);
      if (data is Map && data['results'] is List) {
        final list = <OnlineSong>[];
        for (final item in data['results']) {
          if (item is Map<String, dynamic>) {
            final song = OnlineSong.fromJson(item);
            if (song != null) list.add(song);
          }
        }
        if (list.isNotEmpty) {
          _cachedQueries[cacheKey] = list;
        }
        return list;
      }
    } catch (_) {}

    return const [];
  }

  /// 2. Trending / Top Charts:
  /// Most-played weekly chartbusters aur recommendation list fetch karna
  Future<List<OnlineSong>> getTrendingSongs({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTrending != null && _cachedTrending!.isNotEmpty) {
      return _cachedTrending!;
    }

    try {
      // Fetch 'Trending Today' playlist (listid=110858205) or 'India Superhits Top 50'
      const playlistUrl =
          '$_baseUrl?__call=playlist.getDetails&listid=110858205&_format=json&api_version=4&_marker=0';
      final body = await _get(playlistUrl);

      if (body != null) {
        final data = json.decode(body);
        if (data is Map && data['list'] is List) {
          final list = <OnlineSong>[];
          for (final item in data['list']) {
            if (item is Map<String, dynamic>) {
              final song = OnlineSong.fromJson(item);
              if (song != null) list.add(song);
            }
          }
          if (list.isNotEmpty) {
            _cachedTrending = list;
            return list;
          }
        }
      }
    } catch (_) {}

    // Fallback: search top trending
    final fallback = await searchSongs('Hindi Trending Hits', limit: 25);
    if (fallback.isNotEmpty) {
      _cachedTrending = fallback;
    }
    return fallback;
  }

  /// 3. Categorized Playlists:
  /// - 'New Bollywood Hits' (Latest releases)
  /// - 'Evergreen Classics' (70s, 80s, 90s Golden Hits)
  Future<List<OnlineSong>> getCategorizedPlaylist(String category) async {
    if (_cachedPlaylists.containsKey(category)) {
      return _cachedPlaylists[category]!;
    }

    final query = category == 'New Bollywood Hits'
        ? 'Latest Bollywood Songs 2025'
        : 'Bollywood Retro Classics 70s 80s 90s';

    final songs = await searchSongs(query, limit: 35);
    if (songs.isNotEmpty) {
      _cachedPlaylists[category] = songs;
    }
    return songs;
  }

  /// 4. Artist Catalog Fetcher:
  /// Specific Artist query se us singer ke top 20-30 songs dynamically load karna
  Future<List<OnlineSong>> getArtistSongs(String artistName, {int limit = 30}) async {
    final key = artistName.trim().toLowerCase();
    if (_cachedArtists.containsKey(key)) {
      return _cachedArtists[key]!;
    }

    final songs = await searchSongs(artistName, limit: limit);
    if (songs.isNotEmpty) {
      _cachedArtists[key] = songs;
    }
    return songs;
  }
}
