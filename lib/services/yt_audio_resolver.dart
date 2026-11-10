import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'saavn_api_service.dart';

class YtAudioResolver {
  YtAudioResolver._();

  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, String> _cache = {};

  static const List<String> _pipedMirrors = [
    'https://api.piped.private.coffee',
    'https://pipedapi.lunar.icu',
    'https://pipedapi.kavin.rocks',
  ];

  /// Cleans technical YouTube video title tags
  static String cleanTrackTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'(\(.*?\)|\[.*?\])', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'(\|.*|Official Video.*|Video Song.*|Full Song.*|Audio Song.*|DJ Remix.*|Lyrical Video.*|HD Video.*|New Song.*|202[0-9].*)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Verifies whether the fallback title actually matches the candidate song
  static bool _isTitleMatching(String searchTitle, String candidateTitle) {
    final s1 = searchTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final s2 = candidateTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (s1.isEmpty || s2.isEmpty) return false;
    return s1.contains(s2) || s2.contains(s1);
  }

  /// Resolves direct audio stream for a YouTube video ID with zero audio mismatch.
  static Future<String?> resolveAudioStream(
    String videoId, {
    String? fallbackTitle,
    String? fallbackArtist,
  }) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    if (_cache.containsKey(cleanId) && _cache[cleanId]!.isNotEmpty) {
      return _cache[cleanId];
    }

    // 1. Try YoutubeExplode with 12s timeout
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(cleanId)
          .timeout(const Duration(seconds: 12));
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isNotEmpty) {
        final directUrl = audioStreams.last.url.toString();
        _cache[cleanId] = directUrl;
        return directUrl;
      }
    } catch (e) {
      debugPrint('[YtAudioResolver] YoutubeExplode error for $cleanId: $e');
    }

    // 2. Query Piped API mirrors
    for (final mirror in _pipedMirrors) {
      try {
        final uri = Uri.parse('$mirror/streams/$cleanId');
        final resp = await http.get(uri).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final audioList = data['audioStreams'] as List? ?? [];
          if (audioList.isNotEmpty) {
            audioList.sort((a, b) {
              final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
              final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
              return brA.compareTo(brB);
            });
            final streamUrl = audioList.last['url']?.toString();
            if (streamUrl != null && streamUrl.isNotEmpty) {
              _cache[cleanId] = streamUrl;
              return streamUrl;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Search Saavn ONLY if title matches strictly (never play random Hindi songs!)
    if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
      final clean = cleanTrackTitle(fallbackTitle);
      if (clean.isNotEmpty) {
        try {
          final matches = await SaavnApiService.instance.searchSongs(clean, limit: 5);
          for (final m in matches) {
            if (m.streamUrl.isNotEmpty && _isTitleMatching(clean, m.title)) {
              _cache[cleanId] = m.streamUrl;
              return m.streamUrl;
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }
}
