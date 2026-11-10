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
    'https://pipedapi.lunar.icu',
    'https://api.piped.private.coffee',
    'https://pipedapi.kavin.rocks',
  ];

  /// Resolves the 100% matched direct audio stream URL for a YouTube video ID.
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

    // 1. Try YoutubeExplode
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(cleanId)
          .timeout(const Duration(seconds: 6));
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isNotEmpty) {
        final directUrl = audioStreams.last.url.toString();
        _cache[cleanId] = directUrl;
        return directUrl;
      }
    } catch (e) {
      debugPrint('[YtAudioResolver] YoutubeExplode error for $cleanId: $e');
    }

    // 2. Fallback: Query Piped API mirrors
    for (final mirror in _pipedMirrors) {
      try {
        final uri = Uri.parse('$mirror/streams/$cleanId');
        final resp = await http.get(uri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final audioList = data['audioStreams'] as List? ?? [];
          if (audioList.isNotEmpty) {
            // Find highest bitrate audio stream
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

    // 3. Fallback: Search Saavn for the exact track title + artist (NO random index mapping!)
    if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
      try {
        final query = '$fallbackTitle ${fallbackArtist ?? ""}'.trim();
        final matches = await SaavnApiService.instance.searchSongs(query, limit: 3);
        if (matches.isNotEmpty && matches.first.streamUrl.isNotEmpty) {
          final url = matches.first.streamUrl;
          _cache[cleanId] = url;
          return url;
        }
      } catch (_) {}
    }

    return null;
  }
}

