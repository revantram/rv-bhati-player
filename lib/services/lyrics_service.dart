import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/lrc_parser.dart';

class LyricsResult {
  final List<LrcLine> synced;
  final String? plain;

  const LyricsResult({
    this.synced = const [],
    this.plain,
  });

  bool get hasAny => synced.isNotEmpty || (plain != null && plain!.isNotEmpty);
}

class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  final Map<String, LyricsResult> _cache = {};

  static String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]|\{.*?\}'), '')
        .replaceAll(
          RegExp(
            r'\b(official|video|audio|lyric|lyrics|full song|hd|4k|remix|dj|status|lofi|slowed|reverb)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'feat\..*|ft\..*', caseSensitive: false), '')
        .split(RegExp(r'[\|\•]'))
        .first
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _cleanArtist(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final cleaned = raw
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll('YouTube Music', '')
        .replaceAll('VEVO', '')
        .replaceAll('Topic', '')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.toLowerCase() == 'unknown' ||
        cleaned.toLowerCase() == 'unknown artist') {
      return '';
    }
    return cleaned.split(',').first.trim();
  }

  /// Fetches synchronized (and fallback plain) lyrics from LRCLIB, plus local .lrc lookup.
  Future<LyricsResult> fetchLyrics({
    required String id,
    required String title,
    String? artist,
    Duration? duration,
    String? localPath,
  }) async {
    if (_cache.containsKey(id)) return _cache[id]!;

    // 1. Local sidecar .lrc / .txt file
    if (localPath != null && localPath.isNotEmpty) {
      try {
        final dot = localPath.lastIndexOf('.');
        if (dot > 0) {
          final base = localPath.substring(0, dot);
          for (final p in ['$base.lrc', '$base.LRC', '$base.txt']) {
            if (File(p).existsSync()) {
              final parsed = await LrcParser.parseFile(p);
              if (parsed.isNotEmpty) {
                final res = LyricsResult(synced: parsed);
                _cache[id] = res;
                return res;
              }
            }
          }
        }
      } catch (_) {}
    }

    final cleanTitle = _cleanTitle(title);
    final cleanArtist = _cleanArtist(artist);
    if (cleanTitle.isEmpty) return const LyricsResult();

    // 2. Exact match on LRCLIB /api/get
    try {
      final queryParams = <String, String>{
        'track_name': cleanTitle,
        if (cleanArtist.isNotEmpty) 'artist_name': cleanArtist,
        if (duration != null && duration.inSeconds > 0)
          'duration': duration.inSeconds.toString(),
      };
      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'RVBhatiPlayer/2.0 (BitMusic)'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final parsed = _parseLrclibItem(data);
        if (parsed.hasAny) {
          _cache[id] = parsed;
          return parsed;
        }
      }
    } catch (_) {}

    // 3. Fuzzy search on LRCLIB /api/search (handles Hindi / YouTube composite titles)
    try {
      final q = cleanArtist.isNotEmpty ? '$cleanTitle $cleanArtist' : cleanTitle;
      final uri = Uri.https('lrclib.net', '/api/search', {'q': q});
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'RVBhatiPlayer/2.0 (BitMusic)'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          // Prefer entries with syncedLyrics
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final synced = item['syncedLyrics']?.toString() ?? '';
              if (synced.isNotEmpty) {
                final parsed = _parseLrclibItem(item);
                if (parsed.hasAny) {
                  _cache[id] = parsed;
                  return parsed;
                }
              }
            }
          }
          final first = list.first;
          if (first is Map<String, dynamic>) {
            final parsed = _parseLrclibItem(first);
            if (parsed.hasAny) {
              _cache[id] = parsed;
              return parsed;
            }
          }
        }
      }
    } catch (_) {}

    const empty = LyricsResult();
    _cache[id] = empty;
    return empty;
  }

  LyricsResult _parseLrclibItem(Map<String, dynamic> data) {
    final synced = data['syncedLyrics']?.toString() ?? '';
    final plain = data['plainLyrics']?.toString();
    if (synced.isNotEmpty) {
      final lines = LrcParser.parseString(synced);
      if (lines.isNotEmpty) {
        return LyricsResult(synced: lines, plain: plain);
      }
    }
    if (plain != null && plain.trim().isNotEmpty) {
      return LyricsResult(plain: plain);
    }
    return const LyricsResult();
  }
}
