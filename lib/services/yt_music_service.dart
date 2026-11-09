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
    if (_cache.containsKey(clean)) return _cache[clean]!;

    try {
      final url = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(clean)}+music',
      );
      final req = await _client.getUrl(url);
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      req.headers.set('Accept-Language', 'en-US,en;q=0.9');

      final resp = await req.close();
      if (resp.statusCode != 200) return _fallbackSearch(clean);

      final html = await resp.transform(utf8.decoder).join();
      final regExp = RegExp(r'var ytInitialData = ({.*?});</script>');
      final match = regExp.firstMatch(html);

      if (match == null) return _fallbackSearch(clean);

      final jsonStr = match.group(1);
      if (jsonStr == null) return _fallbackSearch(clean);

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final contents = data['contents']?['twoColumnSearchResultsRenderer']
          ?['primaryContents']?['sectionListRenderer']?['contents'] as List?;

      if (contents == null || contents.isEmpty) return _fallbackSearch(clean);

      final ytItems = <Map<String, dynamic>>[];

      for (final section in contents) {
        final itemSection =
            section['itemSectionRenderer']?['contents'] as List?;
        if (itemSection == null) continue;

        for (final item in itemSection) {
          final vr = item['videoRenderer'] as Map<String, dynamic>?;
          if (vr == null) continue;

          final vid = vr['videoId']?.toString() ?? '';
          if (vid.isEmpty) continue;

          final titleRuns = vr['title']?['runs'] as List?;
          final title = (titleRuns != null && titleRuns.isNotEmpty)
              ? titleRuns[0]['text']?.toString() ?? 'Unknown'
              : 'Unknown';

          final ownerRuns = vr['ownerText']?['runs'] as List?;
          final artist = (ownerRuns != null && ownerRuns.isNotEmpty)
              ? ownerRuns[0]['text']?.toString() ?? 'YouTube Music'
              : 'YouTube Music';

          final durationText =
              vr['lengthText']?['simpleText']?.toString() ?? '3:30';
          final durationSec = _parseDuration(durationText);

          final thumbs = vr['thumbnail']?['thumbnails'] as List?;
          String thumbUrl =
              'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
          if (thumbs != null && thumbs.isNotEmpty) {
            thumbUrl = thumbs.last['url']?.toString() ?? thumbUrl;
          }

          ytItems.add({
            'vid': vid,
            'title': title,
            'artist': artist,
            'duration': durationSec,
            'thumb': thumbUrl,
          });

          if (ytItems.length >= 25) break;
        }
        if (ytItems.length >= 25) break;
      }

      if (ytItems.isEmpty) return _fallbackSearch(clean);

      // Fetch streaming matches from JioSaavn audio CDN
      final saavnMatches = await SaavnApiService.instance.searchSongs(clean, limit: 25);
      final results = <OnlineSong>[];

      for (var i = 0; i < ytItems.length; i++) {
        final yt = ytItems[i];
        final streamUrl = i < saavnMatches.length
            ? saavnMatches[i].streamUrl
            : (saavnMatches.isNotEmpty ? saavnMatches[0].streamUrl : '');

        if (streamUrl.isNotEmpty) {
          results.add(
            OnlineSong(
              id: 'yt_${yt['vid']}',
              title: yt['title'] as String,
              artist: yt['artist'] as String,
              album: 'YouTube Music',
              duration: Duration(seconds: yt['duration'] as int),
              imageUrl: yt['thumb'] as String,
              streamUrl: streamUrl,
            ),
          );
        }
      }

      if (results.isEmpty) {
        return saavnMatches;
      }

      _cache[clean] = results;
      return results;
    } catch (_) {
      return _fallbackSearch(clean);
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
