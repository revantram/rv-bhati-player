import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/online_song.dart';

class AawazShow {
  final int id;
  final String title;
  final String uniqueSlug;
  final String shortUrl;
  final String featuredImageUrl;
  final String language;

  const AawazShow({
    required this.id,
    required this.title,
    required this.uniqueSlug,
    required this.shortUrl,
    required this.featuredImageUrl,
    required this.language,
  });

  factory AawazShow.fromJson(Map<String, dynamic> json) {
    return AawazShow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Aawaz Show',
      uniqueSlug: json['uniqueSlug']?.toString() ?? '',
      shortUrl: json['shortUrl']?.toString() ?? '',
      featuredImageUrl: json['featuredImageUrl']?.toString() ?? '',
      language: json['language']?.toString() ?? 'hi',
    );
  }

  String get category => 'Hindi Show';
  String get description => 'Aawaz Original Hindi Audio Show';
  int get totalEpisodes => 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'uniqueSlug': uniqueSlug,
        'shortUrl': shortUrl,
        'featuredImageUrl': featuredImageUrl,
        'language': language,
      };
}

class AawazEpisode {
  final int id;
  final String title;
  final String description;
  final String shortUrl;
  final String featuredImageUrl;
  final String audioFileUrl;
  final String episodeDuration;
  final String episodeNo;
  final String showTitle;

  const AawazEpisode({
    required this.id,
    required this.title,
    required this.description,
    required this.shortUrl,
    required this.featuredImageUrl,
    required this.audioFileUrl,
    required this.episodeDuration,
    required this.episodeNo,
    required this.showTitle,
  });

  factory AawazEpisode.fromJson(Map<String, dynamic> json, String defaultCover, String defaultShowTitle) {
    final rawAudio = json['audioFileUrl']?.toString() ?? '';
    final rawImg = json['featuredImageUrl']?.toString() ?? '';
    final fullImg = rawImg.isNotEmpty ? rawImg : defaultCover;

    return AawazEpisode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Episode',
      description: json['description']?.toString() ?? '',
      shortUrl: json['shortUrl']?.toString() ?? '',
      featuredImageUrl: fullImg,
      audioFileUrl: rawAudio,
      episodeDuration: json['episodeDuration']?.toString() ?? '05:00',
      episodeNo: json['episodeNo']?.toString() ?? '1',
      showTitle: json['showTitle']?.toString() ?? defaultShowTitle,
    );
  }

  int get episodeNumber => int.tryParse(episodeNo) ?? 1;

  Duration get parsedDuration {
    try {
      final parts = episodeDuration.trim().split(':').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      } else if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
    } catch (_) {}
    return const Duration(minutes: 5);
  }

  int get durationSeconds => parsedDuration.inSeconds;

  OnlineSong toOnlineSong(AawazShow show) {
    return OnlineSong(
      id: 'aawaz_$id',
      title: '$title (${show.title})',
      artist: 'Aawaz (आवाज़ हिन्दी)',
      album: show.title,
      duration: parsedDuration,
      imageUrl: featuredImageUrl.isNotEmpty ? featuredImageUrl : show.featuredImageUrl,
      streamUrl: audioFileUrl,
    );
  }
}

class AawazService {
  AawazService._() {
    _initBuiltin();
  }
  static final AawazService instance = AawazService._();

  static const String _categoryUrl = 'https://www.aawaz.com/category/hindi';
  static const String _showUrlPrefix = 'https://www.aawaz.com/show/';

  List<AawazShow> _cachedShows = [];
  final Map<String, List<AawazEpisode>> _cachedEpisodes = {};

  void _initBuiltin() {
    _cachedShows = _builtinShows.map((e) => AawazShow.fromJson(e)).toList();
  }

  List<AawazShow> get shows => List.unmodifiable(_cachedShows);

  File _getCacheFile() {
    return File('/data/user/0/com.rvbhati.player/files/aawaz_hindi_shows_v1.json');
  }

  Future<List<AawazShow>> fetchHindiShows({bool forceRefresh = false}) async {
    if (_cachedShows.isNotEmpty && !forceRefresh) {
      _fetchRemoteShows();
      return _cachedShows;
    }

    // 1. Try local disk cache for instant startup
    if (!forceRefresh) {
      try {
        final cache = _getCacheFile();
        if (cache.existsSync()) {
          final content = await cache.readAsString();
          final list = jsonDecode(content) as List?;
          if (list != null && list.isNotEmpty) {
            _cachedShows = list
                .map((e) => AawazShow.fromJson(e as Map<String, dynamic>))
                .where((s) => s.shortUrl.isNotEmpty && s.title.isNotEmpty)
                .toList();
            _fetchRemoteShows(); // update background
            return _cachedShows;
          }
        }
      } catch (e) {
        debugPrint('[AawazService] Cache load error: $e');
      }
    }

    return await _fetchRemoteShows();
  }

  Future<List<AawazShow>> _fetchRemoteShows() async {
    try {
      final resp = await http.get(
        Uri.parse(_categoryUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Accept-Language': 'hi-IN,hi;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final html = resp.body;
        final regExp = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>');
        final match = regExp.firstMatch(html);

        if (match != null) {
          final jsonStr = match.group(1);
          if (jsonStr != null) {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final rawShows = data['props']?['pageProps']?['category']?['shows'] as List? ?? [];
            final parsed = rawShows
                .map((e) => AawazShow.fromJson(e as Map<String, dynamic>))
                .where((s) => s.shortUrl.isNotEmpty && s.title.isNotEmpty)
                .toList();

            if (parsed.isNotEmpty) {
              _cachedShows = parsed;
              try {
                final cache = _getCacheFile();
                if (!cache.parent.existsSync()) {
                  cache.parent.createSync(recursive: true);
                }
                await cache.writeAsString(jsonEncode(parsed.map((s) => s.toJson()).toList()));
              } catch (_) {}
              return _cachedShows;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AawazService] Fetch remote shows error: $e');
    }
    return _cachedShows;
  }

  Future<List<AawazEpisode>> fetchShowEpisodes(AawazShow show) async {
    if (_cachedEpisodes.containsKey(show.shortUrl) && _cachedEpisodes[show.shortUrl]!.isNotEmpty) {
      return _cachedEpisodes[show.shortUrl]!;
    }

    try {
      final url = '$_showUrlPrefix${show.shortUrl}';
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Accept-Language': 'hi-IN,hi;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final html = resp.body;
        final regExp = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>');
        final match = regExp.firstMatch(html);

        if (match != null) {
          final jsonStr = match.group(1);
          if (jsonStr != null) {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final epiData = data['props']?['pageProps']?['EpiData']?['results'] as List? ?? [];
            final episodes = epiData
                .map((e) => AawazEpisode.fromJson(e as Map<String, dynamic>, show.featuredImageUrl, show.title))
                .where((ep) => ep.audioFileUrl.isNotEmpty)
                .toList();

            if (episodes.isNotEmpty) {
              _cachedEpisodes[show.shortUrl] = episodes;
              return episodes;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AawazService] Fetch episodes error: $e');
    }
    return _cachedEpisodes[show.shortUrl] ?? const [];
  }

  List<AawazShow> searchShows(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _cachedShows;
    return _cachedShows.where((s) {
      return s.title.toLowerCase().contains(q) || s.shortUrl.toLowerCase().contains(q);
    }).toList();
  }

  static const List<Map<String, dynamic>> _builtinShows = [
    {
      "id": 803,
      "title": "विष्णु भक्त प्रह्लाद",
      "uniqueSlug": "shw-9b397b",
      "shortUrl": "vishnu-bhakt-pralad",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-9b397b-featured-image-1710496057.webp",
      "language": "hi"
    },
    {
      "id": 802,
      "title": "रामायण: भगवान राम की कथा",
      "uniqueSlug": "shw-f013ef",
      "shortUrl": "ramayan-bhawan-ram-ki-katha",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-f013ef-featured-image-1705573289.webp",
      "language": "hi"
    },
    {
      "id": 796,
      "title": "प्रकाशों का त्योहार! दिवाली स्पेशल",
      "uniqueSlug": "shw-941d8f",
      "shortUrl": "prakasho-ka-tyohar-diwali-special",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-941d8f-featured-image-1699526220.webp",
      "language": "hi"
    },
    {
      "id": 789,
      "title": "सुन्दरकाण्ड",
      "uniqueSlug": "shw-436eb0",
      "shortUrl": "sunderkand",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-436eb0-featured-image-1686913148.webp",
      "language": "hi"
    },
    {
      "id": 785,
      "title": "दादासाहेब फाल्के पुरस्कार",
      "uniqueSlug": "shw-f57875",
      "shortUrl": "dadasaheb-phalke-puraskar",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-f57875-featured-image-1677474186.webp",
      "language": "hi"
    },
    {
      "id": 781,
      "title": "किस्से बाज़",
      "uniqueSlug": "shw-6ab3f1",
      "shortUrl": "kisse-baaz",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-6ab3f1-featured-image-1676530145.webp",
      "language": "hi"
    },
    {
      "id": 779,
      "title": "भारत मेरा नाम",
      "uniqueSlug": "shw-eaebee",
      "shortUrl": "bharat-mera-naam",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-eaebee-featured-image-1676021795.webp",
      "language": "hi"
    },
    {
      "id": 775,
      "title": "नाम में क्या रखा है",
      "uniqueSlug": "shw-442f08",
      "shortUrl": "naam-me-kya-rakkha-hai",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-442f08-featured-image-1675504200.webp",
      "language": "hi"
    },
    {
      "id": 774,
      "title": "खेल खेल में",
      "uniqueSlug": "shw-4b938d",
      "shortUrl": "khel-khel-me",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-4b938d-featured-image-1675429233.webp",
      "language": "hi"
    },
    {
      "id": 763,
      "title": "बातें सितारों की - मुकेश",
      "uniqueSlug": "shw-649dc2",
      "shortUrl": "baate-sitaro-ki-mukesh",
      "featuredImageUrl": "https://storage.googleapis.com/prod-aawz2-bckt/optimised/show/shw-649dc2-featured-image-1673594540.webp",
      "language": "hi"
    }
  ];
}
