import 'dart:convert';
import 'dart:io';

import '../models/online_song.dart';
import 'saavn_api_service.dart';

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

  Future<List<OnlineSong>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    if (_cache.containsKey(clean) && _cache[clean]!.isNotEmpty) {
      return _cache[clean]!;
    }

    // 1. Specialized multi-query for category chips to provide 30-50 authentic songs
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
    } else if (clean == 'Old Rajasthani Folk') {
      final results = await _fetchMultiQueries([
        'Old Rajasthani Folk Songs',
        'Seema Mishra Rajasthani Lokgeet',
        'Traditional Marwadi Folk Songs',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    } else if (clean == 'Marwadi Vivah Geet' || clean == 'Banna Banni Songs') {
      final results = await _fetchMultiQueries([
        'Marwadi Vivah Geet 2025',
        'Rajasthani Banna Banni Shaadi Song',
        'Traditional Marwadi Vivah DJ',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    } else if (clean == 'Prakash Mali Bhajan') {
      final results = await _fetchMultiQueries([
        'Prakash Mali Superhit Bhajan',
        'Prakash Mali Desi Bhajan Live',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    } else if (clean == 'Indie Pop & Mashup') {
      final results = await _fetchMultiQueries([
        'Indian Indie Pop Songs 2025',
        'Hindi Mashup Acoustic Songs',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    } else if (clean == 'Veena Rajasthani Hits') {
      final results = await _fetchMultiQueries([
        'Veena Music Rajasthani Superhit',
        'Seema Mishra Veena Music Hits',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    } else if (clean == 'Haryanvi Hits') {
      final results = await _fetchMultiQueries([
        'New Haryanvi Songs 2025',
        'Haryanvi DJ Dance Songs',
      ]);
      if (results.isNotEmpty) {
        _cache[clean] = results;
        return results;
      }
    }

    // 2. Custom User Search: Query Innertube API
    final list = await _searchInnertube(clean);
    if (list.length >= 20) {
      _cache[clean] = list;
      return list;
    }

    // If query returned fewer than 20 results, enhance with related variant
    if (!clean.toLowerCase().contains('song') && !clean.toLowerCase().contains('gana')) {
      final variant = await _searchInnertube('$clean song');
      final merged = _mergeUnique(list, variant);
      if (merged.isNotEmpty) {
        _cache[clean] = merged;
        return merged;
      }
    }

    if (list.isNotEmpty) {
      _cache[clean] = list;
      return list;
    }

    // 3. Fallback: Web Scraper
    final scraped = await _scrapeSearch(clean);
    if (scraped.isNotEmpty) {
      _cache[clean] = scraped;
      return scraped;
    }

    // 4. Fallback to Saavn if YouTube is blocked
    return _fallbackSearch(clean);
  }

  Future<List<OnlineSong>> _fetchMultiQueries(List<String> queries) async {
    final futures = queries.map((q) => _searchInnertube(q));
    final responses = await Future.wait(futures);
    final all = <OnlineSong>[];
    for (final res in responses) {
      all.addAll(res);
    }
    return _mergeUnique(all, const []);
  }

  List<OnlineSong> _mergeUnique(List<OnlineSong> a, List<OnlineSong> b) {
    final seen = <String>{};
    final result = <OnlineSong>[];
    for (final s in [...a, ...b]) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        result.add(s);
      }
    }
    return result;
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
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      req.add(utf8.encode(body));

      final resp = await req.close();
      if (resp.statusCode != 200) return const [];

      final respStr = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(respStr) as Map<String, dynamic>;

      final list = <OnlineSong>[];
      final seenIds = <String>{};

      void extract(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('videoRenderer')) {
            final vr = node['videoRenderer'] as Map<String, dynamic>?;
            if (vr != null) {
              final vid = vr['videoId']?.toString() ?? '';
              if (vid.isNotEmpty && !seenIds.contains(vid)) {
                seenIds.add(vid);
                final titleRuns = vr['title']?['runs'] as List?;
                final title = (titleRuns != null && titleRuns.isNotEmpty)
                    ? titleRuns[0]['text']?.toString() ?? 'YouTube Song'
                    : 'YouTube Song';

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
                  album: 'YouTube Music',
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
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      req.headers.set('Accept-Language', 'hi-IN,hi;q=0.9,en-US;q=0.8,en;q=0.7');

      final resp = await req.close();
      if (resp.statusCode != 200) return const [];

      final html = await resp.transform(utf8.decoder).join();
      final regExp = RegExp(r'var ytInitialData = ({.*?});</script>');
      final match = regExp.firstMatch(html);
      if (match == null) return const [];

      final jsonStr = match.group(1);
      if (jsonStr == null) return const [];

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = <OnlineSong>[];
      final seenIds = <String>{};

      void extract(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('videoRenderer')) {
            final vr = node['videoRenderer'] as Map<String, dynamic>?;
            if (vr != null) {
              final vid = vr['videoId']?.toString() ?? '';
              if (vid.isNotEmpty && !seenIds.contains(vid)) {
                seenIds.add(vid);
                final titleRuns = vr['title']?['runs'] as List?;
                final title = (titleRuns != null && titleRuns.isNotEmpty)
                    ? titleRuns[0]['text']?.toString() ?? 'YouTube Song'
                    : 'YouTube Song';

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
                  album: 'YouTube Music',
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
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlineSong>> _fallbackSearch(String query) async {
    return SaavnApiService.instance.searchSongs(query);
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
