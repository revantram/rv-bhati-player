import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'saavn_api_service.dart';

class YtAudioResolver {
  YtAudioResolver._();

  static final Map<String, String> _cache = {};

  static const List<String> _pipedMirrors = [
    'https://pipedapi.lunar.icu',
    'https://api.piped.private.coffee',
    'https://pipedapi.kavin.rocks',
  ];

  /// Extracts multiple search candidate strings from a YouTube video title
  static List<String> extractSearchCandidates(String rawTitle, [String? artist]) {
    final candidates = <String>{};

    // 1. Clean brackets like (Official Video), [DJ Remix]
    final noBrackets = rawTitle
        .replaceAll(RegExp(r'\((.*?)\)'), '')
        .replaceAll(RegExp(r'\[(.*?)\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 2. Split by common delimiters like |, -, /, •
    final parts = noBrackets.split(RegExp(r'[\|\-•/]+'));
    for (final p in parts) {
      final clean = p
          .replaceAll(
            RegExp(
              r'(Official Video|Video Song|Full Song|Audio Song|DJ Remix|Lyrical Video|HD Video|New Song|202[0-9])',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (clean.length >= 3) {
        candidates.add(clean);
      }
    }

    if (noBrackets.isNotEmpty && noBrackets.length >= 3) {
      candidates.add(noBrackets);
    }

    // 3. Add artist + main title candidate
    if (artist != null && artist.isNotEmpty && artist != 'YouTube Music' && artist.length >= 3) {
      candidates.add(artist);
      if (parts.isNotEmpty && parts.first.trim().length >= 3) {
        candidates.add('${parts.first.trim()} $artist');
      }
    }

    return candidates.toList();
  }

  /// Verifies whether the candidate song matches the search query.
  /// Unicode-aware: preserves Devanagari (Hindi/Marwadi/Rajasthani) characters!
  static bool _isTitleMatching(String searchTitle, String candidateTitle, [String? artist]) {
    // Strip only punctuation and spaces, keeping letters, digits, and Unicode characters
    final s1 = searchTitle.toLowerCase().replaceAll(RegExp(r'[\s\-_\.,\|/!?:;()\[\]{}]+'), '');
    final s2 = candidateTitle.toLowerCase().replaceAll(RegExp(r'[\s\-_\.,\|/!?:;()\[\]{}]+'), '');
    if (s1.isEmpty || s2.isEmpty) return false;
    if (s1.contains(s2) || s2.contains(s1)) return true;

    // Check shared significant words (length >= 3)
    final w1 = searchTitle.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
    final w2 = candidateTitle.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
    if (w1.intersection(w2).isNotEmpty) return true;

    // Check artist match
    if (artist != null && artist.isNotEmpty && artist.length >= 3) {
      final aLower = artist.toLowerCase();
      if (candidateTitle.toLowerCase().contains(aLower)) return true;
    }

    return false;
  }

  /// Resolves direct audio stream for a YouTube video ID.
  /// 1. Tries YoutubeExplode native audio stream.
  /// 2. Tries multi-candidate high-bitrate studio audio match on Saavn.
  /// 3. Tries Piped mirrors.
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

    // 1. Try YoutubeExplode native audio extraction with fresh instance
    try {
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient
          .getManifest(cleanId)
          .timeout(const Duration(milliseconds: 7000));
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isNotEmpty) {
        final directUrl = audioStreams.last.url.toString();
        _cache[cleanId] = directUrl;
        yt.close();
        return directUrl;
      }
      yt.close();
    } catch (e) {
      debugPrint('[YtAudioResolver] YoutubeExplode error for $cleanId: $e');
    }

    // 2. High-precision Saavn Multi-Candidate Resolution (320kbps CD Quality)
    if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
      final candidates = extractSearchCandidates(fallbackTitle, fallbackArtist);
      for (final cand in candidates) {
        try {
          final matches = await SaavnApiService.instance.searchSongs(cand, limit: 6);
          for (final m in matches) {
            if (m.streamUrl.isNotEmpty && _isTitleMatching(cand, m.title, m.artist)) {
              _cache[cleanId] = m.streamUrl;
              return m.streamUrl;
            }
          }
        } catch (_) {}
      }
    }

    // 3. Query Piped API mirrors
    for (final mirror in _pipedMirrors) {
      try {
        final uri = Uri.parse('$mirror/streams/$cleanId');
        final resp = await http.get(uri).timeout(const Duration(milliseconds: 3000));
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

    // 4. Fallback: If not strictly matched yet, search Saavn with fallbackTitle directly
    if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
      try {
        final broadMatches = await SaavnApiService.instance.searchSongs(fallbackTitle, limit: 3);
        if (broadMatches.isNotEmpty && broadMatches.first.streamUrl.isNotEmpty) {
          final directUrl = broadMatches.first.streamUrl;
          _cache[cleanId] = directUrl;
          return directUrl;
        }
      } catch (_) {}
    }

    return null;
  }
}
