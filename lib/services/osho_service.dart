import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/online_song.dart';

class OshoSeries {
  final String id;
  final String title;
  final String slug;
  final String imageUrl;
  final int count;

  const OshoSeries({
    required this.id,
    required this.title,
    required this.slug,
    required this.imageUrl,
    required this.count,
  });

  factory OshoSeries.fromJson(Map<String, dynamic> json) {
    final rawImg = json['image']?.toString() ?? '';
    final fullImg = rawImg.isEmpty || rawImg == 'uploads/no_image.png'
        ? 'https://oshoworld.com/wp-content/uploads/osho_cover.jpg'
        : (rawImg.startsWith('http')
            ? rawImg
            : 'https://oshoworld.com/$rawImg');

    return OshoSeries(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Osho Discourse',
      slug: json['slug']?.toString() ?? '',
      imageUrl: fullImg,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'slug': slug,
        'image': imageUrl,
        'count': count,
      };
}

class OshoTrack {
  final String id;
  final String title;
  final Duration duration;
  final String file;
  final String imageUrl;

  const OshoTrack({
    required this.id,
    required this.title,
    required this.duration,
    required this.file,
    required this.imageUrl,
  });

  factory OshoTrack.fromJson(Map<String, dynamic> json, String defaultImage) {
    final rawFile = json['file']?.toString() ?? json['audioFile']?.toString() ?? '';
    final rawImg = json['imageFile']?.toString() ?? '';
    final fullImg = rawImg.isNotEmpty && rawImg != 'uploads/no_image.png'
        ? (rawImg.startsWith('http') ? rawImg : 'https://oshoworld.com/$rawImg')
        : defaultImage;

    return OshoTrack(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Discourse Track',
      duration: _parseDuration(json['duration']?.toString() ?? '00:00:00'),
      file: rawFile,
      imageUrl: fullImg,
    );
  }

  static Duration _parseDuration(String timeStr) {
    try {
      final parts = timeStr.trim().split(':').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      } else if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
    } catch (_) {}
    return const Duration(minutes: 60);
  }

  String get streamUrl {
    if (file.isEmpty) return '';
    if (file.startsWith('http://') || file.startsWith('https://')) {
      return file;
    }
    final clean = file.startsWith('/') ? file : '/$file';
    return 'https://oshoworld.com$clean';
  }

  OnlineSong toOnlineSong(OshoSeries series) {
    return OnlineSong(
      id: 'osho_$id',
      title: title.replaceAll('_', ' '),
      artist: 'Osho (ओशो)',
      album: series.title,
      duration: duration,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : series.imageUrl,
      streamUrl: streamUrl,
    );
  }
}

class OshoService {
  OshoService._();
  static final OshoService instance = OshoService._();

  static const String _catalogApi = 'https://oshoworld.com/api/audio/catalog/hindi';
  static const String _seriesApiPrefix = 'https://oshoworld.com/api/audio/get-all-audios-list/';

  List<OshoSeries> _cachedSeries = [];
  final Map<String, List<OshoTrack>> _cachedTracks = {};

  List<OshoSeries> get series => List.unmodifiable(_cachedSeries);

  File _getCacheFile() {
    return File('/data/user/0/com.rvbhati.player/files/osho_catalog_v1.json');
  }

  Future<List<OshoSeries>> fetchHindiSeries({bool forceRefresh = false}) async {
    if (_cachedSeries.isNotEmpty && !forceRefresh) {
      return _cachedSeries;
    }

    // 1. Try reading from local disk cache first for instant 0ms load
    if (!forceRefresh) {
      try {
        final cache = _getCacheFile();
        if (cache.existsSync()) {
          final content = await cache.readAsString();
          final list = jsonDecode(content) as List?;
          if (list != null && list.isNotEmpty) {
            _cachedSeries = list
                .map((e) => OshoSeries.fromJson(e as Map<String, dynamic>))
                .toList();
            // Fetch fresh in background
            _fetchRemoteCatalog();
            return _cachedSeries;
          }
        }
      } catch (e) {
        debugPrint('[OshoService] Cache load error: $e');
      }
    }

    return await _fetchRemoteCatalog();
  }

  Future<List<OshoSeries>> _fetchRemoteCatalog() async {
    try {
      final resp = await http.get(Uri.parse(_catalogApi)).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawSeries = data['series'] as List? ?? [];
        final parsed = rawSeries
            .map((e) => OshoSeries.fromJson(e as Map<String, dynamic>))
            .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
            .toList();

        if (parsed.isNotEmpty) {
          _cachedSeries = parsed;
          // Persist to local disk cache
          try {
            final cache = _getCacheFile();
            if (!cache.parent.existsSync()) {
              cache.parent.createSync(recursive: true);
            }
            final jsonStr = jsonEncode(parsed.map((s) => s.toJson()).toList());
            await cache.writeAsString(jsonStr);
          } catch (_) {}
          return _cachedSeries;
        }
      }
    } catch (e) {
      debugPrint('[OshoService] Fetch catalog error: $e');
    }
    return _cachedSeries;
  }

  Future<List<OshoTrack>> fetchSeriesTracks(OshoSeries series) async {
    if (_cachedTracks.containsKey(series.id) && _cachedTracks[series.id]!.isNotEmpty) {
      return _cachedTracks[series.id]!;
    }

    try {
      final url = '$_seriesApiPrefix${series.id}';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List? ?? [];
        final tracks = list
            .map((e) => OshoTrack.fromJson(e as Map<String, dynamic>, series.imageUrl))
            .where((t) => t.file.isNotEmpty)
            .toList();

        if (tracks.isNotEmpty) {
          _cachedTracks[series.id] = tracks;
          return tracks;
        }
      }
    } catch (e) {
      debugPrint('[OshoService] Fetch series tracks error: $e');
    }
    return _cachedTracks[series.id] ?? const [];
  }

  List<OshoSeries> searchSeries(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _cachedSeries;
    return _cachedSeries.where((s) {
      return s.title.toLowerCase().contains(q) || s.slug.toLowerCase().contains(q);
    }).toList();
  }
}
