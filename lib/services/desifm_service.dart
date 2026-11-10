import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/online_song.dart';

class DesiFmSeries {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final String genre;
  final int totalEpisodes;
  final int totalDurationSeconds;
  final String slug;

  const DesiFmSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.genre,
    required this.totalEpisodes,
    required this.totalDurationSeconds,
    required this.slug,
  });

  factory DesiFmSeries.fromJson(Map<String, dynamic> json) {
    return DesiFmSeries(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Desi FM Series',
      description: json['series_description']?.toString() ?? '',
      coverUrl: json['cover_art_url']?.toString() ?? '',
      genre: json['genre_slug']?.toString() ?? 'Drama',
      totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toInt() ?? 0,
      slug: json['slug']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'series_description': description,
        'cover_art_url': coverUrl,
        'genre_slug': genre,
        'total_episodes': totalEpisodes,
        'total_duration_seconds': totalDurationSeconds,
        'slug': slug,
      };
}

class DesiFmEpisode {
  final String id;
  final String seriesId;
  final String title;
  final String description;
  final String audioUrl;
  final String coverUrl;
  final int durationSeconds;
  final int episodeNumber;

  const DesiFmEpisode({
    required this.id,
    required this.seriesId,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.coverUrl,
    required this.durationSeconds,
    required this.episodeNumber,
  });

  factory DesiFmEpisode.fromJson(Map<String, dynamic> json, String defaultCover) {
    final rawCover = json['cover_art_url']?.toString() ?? '';
    final fullCover = rawCover.isNotEmpty ? rawCover : defaultCover;

    return DesiFmEpisode(
      id: json['id']?.toString() ?? '',
      seriesId: json['series_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Episode',
      description: json['episode_description']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString() ?? '',
      coverUrl: fullCover,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 1,
    );
  }

  OnlineSong toOnlineSong(DesiFmSeries series) {
    return OnlineSong(
      id: 'desifm_$id',
      title: '$title: ${series.title}',
      artist: 'Desi FM (${series.genre.toUpperCase()})',
      album: series.title,
      duration: Duration(seconds: durationSeconds),
      imageUrl: coverUrl.isNotEmpty ? coverUrl : series.coverUrl,
      streamUrl: audioUrl,
    );
  }
}

class DesiFmService {
  DesiFmService._();
  static final DesiFmService instance = DesiFmService._();

  static const String _seriesApi = 'https://api.desifm.app/series';

  List<DesiFmSeries> _cachedSeries = [];
  final Map<String, List<DesiFmEpisode>> _cachedEpisodes = {};

  List<DesiFmSeries> get series => List.unmodifiable(_cachedSeries);

  File _getCacheFile() {
    return File('/data/user/0/com.rvbhati.player/files/desifm_series_v1.json');
  }

  Future<List<DesiFmSeries>> fetchSeriesList({bool forceRefresh = false}) async {
    if (_cachedSeries.isNotEmpty && !forceRefresh) {
      return _cachedSeries;
    }

    // 1. Try local disk cache
    if (!forceRefresh) {
      try {
        final cache = _getCacheFile();
        if (cache.existsSync()) {
          final content = await cache.readAsString();
          final list = jsonDecode(content) as List?;
          if (list != null && list.isNotEmpty) {
            _cachedSeries = list
                .map((e) => DesiFmSeries.fromJson(e as Map<String, dynamic>))
                .toList();
            _fetchRemoteSeries(); // refresh background
            return _cachedSeries;
          }
        }
      } catch (e) {
        debugPrint('[DesiFmService] Cache load error: $e');
      }
    }

    return await _fetchRemoteSeries();
  }

  Future<List<DesiFmSeries>> _fetchRemoteSeries() async {
    try {
      final resp = await http.get(
        Uri.parse(_seriesApi),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List? ?? [];
        final parsed = list
            .map((e) => DesiFmSeries.fromJson(e as Map<String, dynamic>))
            .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
            .toList();

        if (parsed.isNotEmpty) {
          _cachedSeries = parsed;
          try {
            final cache = _getCacheFile();
            if (!cache.parent.existsSync()) {
              cache.parent.createSync(recursive: true);
            }
            await cache.writeAsString(jsonEncode(parsed.map((s) => s.toJson()).toList()));
          } catch (_) {}
          return _cachedSeries;
        }
      }
    } catch (e) {
      debugPrint('[DesiFmService] Fetch series error: $e');
    }
    return _cachedSeries;
  }

  Future<List<DesiFmEpisode>> fetchSeriesEpisodes(DesiFmSeries series) async {
    if (_cachedEpisodes.containsKey(series.slug) && _cachedEpisodes[series.slug]!.isNotEmpty) {
      return _cachedEpisodes[series.slug]!;
    }

    try {
      final targetKey = series.slug.isNotEmpty ? series.slug : series.id;
      final url = '$_seriesApi/$targetKey';
      final resp = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawEpisodes = data['episodes'] as List? ?? [];
        final episodes = rawEpisodes
            .map((e) => DesiFmEpisode.fromJson(e as Map<String, dynamic>, series.coverUrl))
            .where((ep) => ep.audioUrl.isNotEmpty)
            .toList();

        // Sort by episode number
        episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

        if (episodes.isNotEmpty) {
          _cachedEpisodes[series.slug] = episodes;
          return episodes;
        }
      }
    } catch (e) {
      debugPrint('[DesiFmService] Fetch episodes error: $e');
    }
    return _cachedEpisodes[series.slug] ?? const [];
  }

  List<DesiFmSeries> searchSeries(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _cachedSeries;
    return _cachedSeries.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q);
    }).toList();
  }
}
