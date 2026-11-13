import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/online_song.dart';

class BitArtist {
  final String name;
  final String category; // 'Modern Hits', '90s Icons', 'Legends', 'Rajasthani & Folk', 'Punjabi'
  final String subtitle;
  final String avatarUrl;

  const BitArtist({
    required this.name,
    required this.category,
    required this.subtitle,
    required this.avatarUrl,
  });

  bool get isRajasthani => category.toLowerCase().contains('rajasthan');
  bool get isBollywood => !isRajasthani;
}

class YtMusicSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String imageUrl;
  final String streamUrl;

  const YtMusicSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.imageUrl,
    required this.streamUrl,
  });

  OnlineSong toOnlineSong() {
    return OnlineSong(
      id: 'yt_$id',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      streamUrl: streamUrl,
      imageUrl: imageUrl,
    );
  }
}

class YtMusicService {
  YtMusicService._();
  static final YtMusicService instance = YtMusicService._();

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  final Map<String, List<OnlineSong>> _cache = {};
  List<OnlineSong>? _cachedTrending;

  static const List<String> _pipedSearchMirrors = [
    'https://api.piped.private.coffee',
    'https://pipedapi.adminforge.de',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.ducks.party',
  ];

  // Curated Indian, Global & Folk Artists for BitMusic Artists Hub
  static const List<BitArtist> curatedArtists = [
    BitArtist(
      name: 'Arijit Singh',
      category: 'Modern Hits',
      subtitle: 'The Soul of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_002_20230323062147_500x500.jpg',
    ),
    BitArtist(
      name: 'Atif Aslam',
      category: 'Modern Hits',
      subtitle: 'Romantic Melodies & Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg',
    ),
    BitArtist(
      name: 'Shreya Ghoshal',
      category: 'Modern Hits',
      subtitle: 'Melody Queen of Modern Era',
      avatarUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_500x500.jpg',
    ),
    BitArtist(
      name: 'Jubin Nautiyal',
      category: 'Modern Hits',
      subtitle: 'Heart-touching Chartbusters',
      avatarUrl: 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_500x500.jpg',
    ),
    BitArtist(
      name: 'Darshan Raval',
      category: 'Modern Hits',
      subtitle: 'Monsoon Melodies & Romance',
      avatarUrl: 'https://c.saavncdn.com/artists/Darshan_Raval_500x500.jpg',
    ),
    BitArtist(
      name: 'Anuv Jain',
      category: 'Modern Hits',
      subtitle: 'Indie Acoustic Sensation',
      avatarUrl: 'https://c.saavncdn.com/436/Husn-Hindi-2023-20231129054140-500x500.jpg',
    ),
    BitArtist(
      name: 'KK',
      category: 'Modern Hits',
      subtitle: 'Voice of Pure Emotions & Youth',
      avatarUrl: 'https://c.saavncdn.com/artists/KK_500x500.jpg',
    ),
    BitArtist(
      name: 'Mohit Chauhan',
      category: 'Modern Hits',
      subtitle: 'Soulful Indie & Rock Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Mohit_Chauhan_500x500.jpg',
    ),
    BitArtist(
      name: 'Vishal Mishra',
      category: 'Modern Hits',
      subtitle: 'Pehle Bhi Main & Soul Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Vishal_Mishra_005_20251120085316_500x500.jpg',
    ),
    BitArtist(
      name: 'King',
      category: 'Modern Hits',
      subtitle: 'Maan Meri Jaan & Tu Aake Dekhle',
      avatarUrl: 'https://c.saavncdn.com/artists/King_004_20240819092014_500x500.jpg',
    ),
    BitArtist(
      name: 'Pritam',
      category: 'Modern Hits',
      subtitle: 'The Hitmaker of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_500x500.jpg',
    ),
    BitArtist(
      name: 'A.R. Rahman',
      category: 'Legends',
      subtitle: 'The Mozart of Madras',
      avatarUrl: 'https://c.saavncdn.com/artists/AR_Rahman_500x500.jpg',
    ),
    BitArtist(
      name: 'Sunidhi Chauhan',
      category: 'Modern Hits',
      subtitle: 'Powerhouse of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Sunidhi_Chauhan_500x500.jpg',
    ),
    BitArtist(
      name: 'Neha Kakkar',
      category: 'Modern Hits',
      subtitle: 'Party & Dance Anthem Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Neha_Kakkar_500x500.jpg',
    ),
    BitArtist(
      name: 'Armaan Malik',
      category: 'Modern Hits',
      subtitle: 'Prince of Romance',
      avatarUrl: 'https://c.saavncdn.com/artists/Armaan_Malik_500x500.jpg',
    ),
    BitArtist(
      name: 'Anirudh Ravichander',
      category: 'Modern Hits',
      subtitle: 'Jawan & Pan-India Rockstar',
      avatarUrl: 'https://c.saavncdn.com/artists/Anirudh_Ravichander_005_20230818113524_500x500.jpg',
    ),
    BitArtist(
      name: 'Kumar Sanu',
      category: '90s Icons',
      subtitle: 'King of 90s Romance',
      avatarUrl: 'https://c.saavncdn.com/artists/Kumar_Sanu_500x500.jpg',
    ),
    BitArtist(
      name: 'Alka Yagnik',
      category: '90s Icons',
      subtitle: 'Golden Voice of 90s & 2000s',
      avatarUrl: 'https://c.saavncdn.com/artists/Alka_Yagnik_500x500.jpg',
    ),
    BitArtist(
      name: 'Udit Narayan',
      category: '90s Icons',
      subtitle: 'Evergreen Romantic Voice',
      avatarUrl: 'https://c.saavncdn.com/artists/Udit_Narayan_500x500.jpg',
    ),
    BitArtist(
      name: 'Sonu Nigam',
      category: '90s Icons',
      subtitle: 'The Lord of Melody',
      avatarUrl: 'https://c.saavncdn.com/artists/Sonu_Nigam_500x500.jpg',
    ),
    BitArtist(
      name: 'Shaan',
      category: '90s Icons',
      subtitle: 'Golden Voice & Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Shaan_500x500.jpg',
    ),
    BitArtist(
      name: 'Lucky Ali',
      category: '90s Icons',
      subtitle: 'O Sanam & Indipop Maestro',
      avatarUrl: 'https://c.saavncdn.com/artists/Lucky_Ali_500x500.jpg',
    ),
    BitArtist(
      name: 'Kishore Kumar',
      category: 'Legends',
      subtitle: 'The Incomparable Genius',
      avatarUrl: 'https://c.saavncdn.com/artists/Kishore_Kumar_500x500.jpg',
    ),
    BitArtist(
      name: 'Mohammed Rafi',
      category: 'Legends',
      subtitle: 'The Immortal Golden Voice',
      avatarUrl: 'https://c.saavncdn.com/artists/Mohammed_Rafi_500x500.jpg',
    ),
    BitArtist(
      name: 'Lata Mangeshkar',
      category: 'Legends',
      subtitle: 'Nightingale of India',
      avatarUrl: 'https://c.saavncdn.com/artists/Lata_Mangeshkar_500x500.jpg',
    ),
    BitArtist(
      name: 'Jagjit Singh',
      category: 'Legends',
      subtitle: 'The Ghazal King of India',
      avatarUrl: 'https://c.saavncdn.com/artists/Jagjit_Singh_500x500.jpg',
    ),
    BitArtist(
      name: 'Prakash Mali',
      category: 'Rajasthani & Folk',
      subtitle: 'Bhajan Samrat of Marwar',
      avatarUrl: 'https://c.saavncdn.com/artists/Prakash_Mali_500x500.jpg',
    ),
    BitArtist(
      name: 'Seema Mishra',
      category: 'Rajasthani & Folk',
      subtitle: 'Veena Folk & Ghoomar Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Seema_Mishra_500x500.jpg',
    ),
    BitArtist(
      name: 'Mame Khan',
      category: 'Rajasthani & Folk',
      subtitle: 'Chaudhary & Coke Studio Legend',
      avatarUrl: 'https://c.saavncdn.com/artists/Mame_Khan_500x500.jpg',
    ),
    BitArtist(
      name: 'Rani Rangili',
      category: 'Rajasthani & Folk',
      subtitle: 'Marwari DJ Dhamaka Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Rani_Rangili_20191129073418_500x500.jpg',
    ),
    BitArtist(
      name: 'Twinkle Vaishnav',
      category: 'Rajasthani & Folk',
      subtitle: 'Marwari Lokgeet & Dance',
      avatarUrl: 'https://c.saavncdn.com/artists/Twinkle_Vaishnav_500x500.jpg',
    ),
    BitArtist(
      name: 'Chhotu Singh Rawna',
      category: 'Rajasthani & Folk',
      subtitle: 'Veer Ras & Rajputana Hits',
      avatarUrl: 'https://c.saavncdn.com/640/Teen-Baan-Ke-Dhari-Hindi-2025-20260602191940-500x500.jpg',
    ),
    BitArtist(
      name: 'Gajendra Ajmera',
      category: 'Rajasthani & Folk',
      subtitle: 'Tejaji Bhajan & Folk Star',
      avatarUrl: 'https://c.saavncdn.com/artists/Gajendra_Ajmera_500x500.jpg',
    ),
    BitArtist(
      name: 'Ila Arun',
      category: 'Rajasthani & Folk',
      subtitle: 'Rajasthani Folk & Pop Icon',
      avatarUrl: 'https://c.saavncdn.com/artists/Ila_Arun_500x500.jpg',
    ),
    BitArtist(
      name: 'Diljit Dosanjh',
      category: 'Punjabi',
      subtitle: 'Global Punjabi Sensation',
      avatarUrl: 'https://c.saavncdn.com/artists/Diljit_Dosanjh_500x500.jpg',
    ),
    BitArtist(
      name: 'Sidhu Moose Wala',
      category: 'Punjabi',
      subtitle: 'The Legend • 295 & So High',
      avatarUrl: 'https://c.saavncdn.com/artists/Sidhu_Moose_Wala_500x500.jpg',
    ),
    BitArtist(
      name: 'Karan Aujla',
      category: 'Punjabi',
      subtitle: 'Tauba Tauba & Making Memories',
      avatarUrl: 'https://c.saavncdn.com/artists/Karan_Aujla_004_20240404092241_500x500.jpg',
    ),
    BitArtist(
      name: 'AP Dhillon',
      category: 'Punjabi',
      subtitle: 'Brown Munde & With You',
      avatarUrl: 'https://c.saavncdn.com/artists/AP_Dhillon_003_20230818113527_500x500.jpg',
    ),
    BitArtist(
      name: 'Shubh',
      category: 'Punjabi',
      subtitle: 'Cheques & Baller Anthems',
      avatarUrl: 'https://c.saavncdn.com/artists/Shubh_003_20230526063428_500x500.jpg',
    ),
    BitArtist(
      name: 'Badshah',
      category: 'Punjabi',
      subtitle: 'Desi Hip-Hop & Party Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Badshah_500x500.jpg',
    ),
    BitArtist(
      name: 'Yo Yo Honey Singh',
      category: 'Punjabi',
      subtitle: 'Desi Kalakaar & Rap King',
      avatarUrl: 'https://c.saavncdn.com/artists/Yo_Yo_Honey_Singh_500x500.jpg',
    ),
    BitArtist(
      name: 'B Praak',
      category: 'Punjabi',
      subtitle: 'Filhall & Teri Mitti Sensation',
      avatarUrl: 'https://c.saavncdn.com/artists/B_Praak_500x500.jpg',
    ),
    BitArtist(
      name: 'Hansraj Raghuwanshi',
      category: 'Legends',
      subtitle: 'Mera Bhola Hai Bhandari Star',
      avatarUrl: 'https://c.saavncdn.com/artists/Hansraj_Raghuwanshi_003_20220412093836_500x500.jpg',
    ),
    BitArtist(
      name: 'Kanhaiya Mittal',
      category: 'Legends',
      subtitle: 'Khatu Shyam Ji Ke Bhajan',
      avatarUrl: 'https://c.saavncdn.com/artists/Kanhaiya_Mittal_002_20220818131338_500x500.jpg',
    ),
  ];

  static BitArtist? findCuratedArtist(String name) {
    final clean = name.trim().toLowerCase();
    for (final artist in curatedArtists) {
      final aName = artist.name.toLowerCase();
      if (aName == clean || clean.contains(aName) || aName.contains(clean)) {
        return artist;
      }
    }
    return null;
  }

  /// BitChord Trending Discovery feed
  Future<List<OnlineSong>> getTrendingSongs({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTrending != null && _cachedTrending!.isNotEmpty) {
      return _cachedTrending!;
    }
    final list = await _fetchMultiQueries([
      'Trending Hindi Songs 2025 Audio',
      'Top Bollywood Hits 2025 Official Audio',
      'Global Top 50 Music Hits',
    ]);
    if (list.isNotEmpty) {
      _cachedTrending = list;
    }
    return list;
  }

  /// Live YouTube Music search suggestions for BitMusic search bar
  Future<List<String>> getSuggestions(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];
    try {
      final uri = Uri.https('suggestqueries-clients6.youtube.com', '/complete/search', {
        'client': 'youtube',
        'ds': 'yt',
        'q': clean,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final body = res.body;
        final start = body.indexOf('(');
        final end = body.lastIndexOf(')');
        if (start != -1 && end > start) {
          final jsonStr = body.substring(start + 1, end);
          final parsed = jsonDecode(jsonStr);
          if (parsed is List && parsed.length > 1 && parsed[1] is List) {
            return (parsed[1] as List)
                .map((e) => e is List && e.isNotEmpty ? e[0].toString() : '')
                .where((s) => s.isNotEmpty)
                .take(8)
                .toList();
          }
        }
      }
    } catch (_) {}
    return const [];
  }

  /// Search artists dynamically via YouTube search
  Future<List<BitArtist>> searchArtists(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return curatedArtists;
    final matched = curatedArtists
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            a.subtitle.toLowerCase().contains(q) ||
            a.category.toLowerCase().contains(q))
        .toList();
    if (matched.isNotEmpty) return matched;
    final songs = await search('$query singer songs');
    if (songs.isEmpty) return const [];
    final first = songs.first;
    return [
      BitArtist(
        name: query.trim(),
        category: 'BitMusic',
        subtitle: '${songs.length} tracks on BitMusic',
        avatarUrl: first.imageUrl,
      ),
    ];
  }

  /// Fetch top songs for a specific artist
  Future<List<OnlineSong>> getArtistSongs(String artistName, {int limit = 40}) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return const [];
    final list = await search('$clean best songs audio');
    return list.take(limit).toList();
  }

  Future<List<OnlineSong>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    if (_cache.containsKey(clean) && _cache[clean]!.isNotEmpty) {
      return _cache[clean]!;
    }

    // Specialized multi-query presets
    if (clean == 'Rajasthani & Marwadi DJ') {
      final results = await _fetchMultiQueries([
        'Rajasthani Marwadi DJ Song 2025',
        'New Marwadi DJ Song Remix',
        'Rani Rangili Twinkle Vaishnav DJ Song',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    } else if (clean == 'Desi Bhajan & Aarti') {
      final results = await _fetchMultiQueries([
        'Rajasthani Desi Bhajan',
        'Prakash Mali Desi Bhajan Aarti',
        'Marwadi Desi Bhajan Geet',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    } else if (clean == 'Trending YouTube India') {
      final results = await _fetchMultiQueries([
        'Trending Songs India 2025',
        'Top Hindi Songs New',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    }

    // 1. Try YouTube Music InnerTube WEB_REMIX first (clean song metadata & square artwork)
    final ytMusicResults = await _searchYoutubeMusicRemix(clean);
    if (ytMusicResults.length >= 10) {
      _cache[clean] = ytMusicResults;
      return ytMusicResults;
    }

    // 2. Standard InnerTube WEB search
    final webResults = await _searchInnertube(clean);
    final combined = _mergeUnique(ytMusicResults, webResults);
    if (combined.isNotEmpty) {
      _cache[clean] = combined;
      return combined;
    }

    // 3. Scrape fallback
    final scraped = await _scrapeSearch(clean);
    if (scraped.isNotEmpty) {
      _cache[clean] = scraped;
      return scraped;
    }

    // 4. Piped Mirror search fallback
    final piped = await _searchPiped(clean);
    if (piped.isNotEmpty) {
      _cache[clean] = piped;
      return piped;
    }

    return const [];
  }

  Future<List<OnlineSong>> _fetchMultiQueries(List<String> queries) async {
    final futures = queries.map((q) => _searchYoutubeMusicRemix(q));
    final responses = await Future.wait(futures);
    final all = <OnlineSong>[];
    for (final res in responses) {
      all.addAll(res);
    }
    if (all.isEmpty) {
      final webFutures = queries.map((q) => _searchInnertube(q));
      final webResponses = await Future.wait(webFutures);
      for (final res in webResponses) {
        all.addAll(res);
      }
    }
    return _mergeUnique(all, const []);
  }

  List<OnlineSong> _mergeUnique(List<OnlineSong> a, List<OnlineSong> b) {
    final seen = <String>{};
    final result = <OnlineSong>[];
    for (final s in [...a, ...b]) {
      if (s.id.isNotEmpty && seen.add(s.id)) {
        result.add(s);
      }
    }
    return result;
  }

  Future<List<OnlineSong>> _searchYoutubeMusicRemix(String query) async {
    try {
      final url = Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false');
      final body = jsonEncode({
        'query': query,
        'params': 'EgWKAQIIAWoMEAMQBBAJEAoQBRAV', // Songs filter
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20241120.01.00',
            'hl': 'en',
            'gl': 'IN',
          }
        }
      });

      final req = await _client.postUrl(url);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Origin', 'https://music.youtube.com');
      req.headers.set('Referer', 'https://music.youtube.com/');
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      );
      req.add(utf8.encode(body));

      final resp = await req.close().timeout(const Duration(seconds: 7));
      if (resp.statusCode != 200) return const [];

      final respStr = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(respStr);

      final list = <OnlineSong>[];
      final seenIds = <String>{};

      void extractMusic(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('musicResponsiveListItemRenderer')) {
            final item = node['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
            if (item != null) {
              String? vid = item['playlistItemData']?['videoId']?.toString();
              vid ??= item['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                      ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
                  ?['watchEndpoint']?['videoId']?.toString();

              if (vid != null && vid.isNotEmpty && seenIds.add(vid)) {
                final flexCols = item['flexColumns'] as List? ?? [];
                String title = 'BitMusic Track';
                String artist = 'BitMusic Artist';
                String album = 'BitMusic';
                int durSec = 210;

                if (flexCols.isNotEmpty) {
                  final runs = flexCols[0]['musicResponsiveListItemFlexColumnRenderer']
                      ?['text']?['runs'] as List?;
                  if (runs != null && runs.isNotEmpty) {
                    title = runs[0]['text']?.toString() ?? title;
                  }
                }
                if (flexCols.length > 1) {
                  final runs = flexCols[1]['musicResponsiveListItemFlexColumnRenderer']
                      ?['text']?['runs'] as List?;
                  if (runs != null && runs.isNotEmpty) {
                    final parts = runs
                        .map((r) => r['text']?.toString() ?? '')
                        .where((t) => t.trim().isNotEmpty && t.trim() != '•')
                        .toList();
                    if (parts.isNotEmpty) {
                      artist = parts.first;
                      for (final p in parts.skip(1)) {
                        if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(p.trim())) {
                          durSec = _parseDuration(p.trim());
                        } else if (parts.length >= 2) {
                          album = p.trim();
                        }
                      }
                    }
                  }
                }

                String thumbUrl = 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
                final thumbs = item['thumbnail']?['musicThumbnailRenderer']
                    ?['thumbnail']?['thumbnails'] as List?;
                if (thumbs != null && thumbs.isNotEmpty) {
                  thumbUrl = OnlineSong.upgradeImageUrl(thumbs.last['url']?.toString());
                }

                list.add(OnlineSong(
                  id: 'yt_$vid',
                  title: title,
                  artist: artist,
                  album: album,
                  duration: Duration(seconds: durSec),
                  imageUrl: thumbUrl,
                  streamUrl: '',
                ));
              }
            }
          }
          for (final v in node.values) {
            extractMusic(v);
          }
        } else if (node is List) {
          for (final item in node) {
            extractMusic(item);
          }
        }
      }

      extractMusic(data);
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlineSong>> _searchInnertube(String query) async {
    try {
      final url = Uri.parse('https://www.youtube.com/youtubei/v1/search');
      final body = jsonEncode({
        'query': query,
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240313.00.00',
            'hl': 'hi',
            'gl': 'IN',
          }
        }
      });

      final req = await _client.postUrl(url);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      );
      req.add(utf8.encode(body));

      final resp = await req.close().timeout(const Duration(seconds: 7));
      if (resp.statusCode != 200) return const [];

      final respStr = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(respStr) as Map<String, dynamic>;
      return _extractVideoRenderers(data);
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlineSong>> _scrapeSearch(String query) async {
    try {
      final url = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}',
      );
      final req = await _client.getUrl(url);
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      );
      req.headers.set('Accept-Language', 'hi-IN,hi;q=0.9,en-US;q=0.8,en;q=0.7');

      final resp = await req.close().timeout(const Duration(seconds: 7));
      if (resp.statusCode != 200) return const [];

      final html = await resp.transform(utf8.decoder).join();
      final regExp = RegExp(r'var ytInitialData = ({.*?});</script>');
      final match = regExp.firstMatch(html);
      if (match == null) return const [];

      final jsonStr = match.group(1);
      if (jsonStr == null) return const [];

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _extractVideoRenderers(data);
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlineSong>> _searchPiped(String query) async {
    for (final mirror in _pipedSearchMirrors) {
      try {
        final uri = Uri.parse('$mirror/search?q=${Uri.encodeComponent(query)}&filter=music_songs');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final items = data['items'] as List? ?? [];
          final songs = <OnlineSong>[];
          for (final item in items) {
            if (item is Map) {
              final rawUrl = item['url']?.toString() ?? '';
              final vid = rawUrl.contains('v=')
                  ? rawUrl.split('v=').last.split('&').first
                  : rawUrl.replaceAll('/', '');
              if (vid.isEmpty) continue;
              final thumb = item['thumbnail']?.toString() ??
                  'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
              songs.add(OnlineSong(
                id: 'yt_$vid',
                title: item['title']?.toString() ?? 'BitMusic Song',
                artist: item['uploaderName']?.toString() ?? 'YouTube Music',
                album: 'BitMusic',
                duration: Duration(seconds: (item['duration'] as num?)?.toInt() ?? 210),
                imageUrl: OnlineSong.upgradeImageUrl(thumb),
                streamUrl: '',
              ));
            }
          }
          if (songs.isNotEmpty) return songs;
        }
      } catch (_) {}
    }
    return const [];
  }

  List<OnlineSong> _extractVideoRenderers(Map<String, dynamic> data) {
    final list = <OnlineSong>[];
    final seenIds = <String>{};

    void extract(dynamic node) {
      if (node is Map<String, dynamic>) {
        if (node.containsKey('videoRenderer')) {
          final vr = node['videoRenderer'] as Map<String, dynamic>?;
          if (vr != null) {
            final vid = vr['videoId']?.toString() ?? '';
            if (vid.isNotEmpty && seenIds.add(vid)) {
              final titleRuns = vr['title']?['runs'] as List?;
              final title = (titleRuns != null && titleRuns.isNotEmpty)
                  ? titleRuns[0]['text']?.toString() ?? 'BitMusic Song'
                  : 'BitMusic Song';

              final ownerRuns = vr['ownerText']?['runs'] as List?;
              final artist = (ownerRuns != null && ownerRuns.isNotEmpty)
                  ? ownerRuns[0]['text']?.toString() ?? 'YouTube Music'
                  : 'YouTube Music';

              final durText = vr['lengthText']?['simpleText']?.toString() ?? '3:30';
              final durSec = _parseDuration(durText);

              final thumbs = vr['thumbnail']?['thumbnails'] as List?;
              String thumbUrl = 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
              if (thumbs != null && thumbs.isNotEmpty) {
                thumbUrl = thumbs.last['url']?.toString() ?? thumbUrl;
              }

              list.add(OnlineSong(
                id: 'yt_$vid',
                title: title,
                artist: artist,
                album: 'BitMusic',
                duration: Duration(seconds: durSec),
                imageUrl: thumbUrl,
                streamUrl: '',
              ));
            }
          }
        }
        for (final val in node.values) {
          extract(val);
        }
      } else if (node is List) {
        for (final item in node) {
          extract(item);
        }
      }
    }

    extract(data);
    return list;
  }

  int _parseDuration(String text) {
    try {
      final parts = text.split(':').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts.length == 2) {
        return parts[0] * 60 + parts[1];
      } else if (parts.length == 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
      return 210;
    } catch (_) {
      return 210;
    }
  }
}
