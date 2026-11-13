import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'settings_service.dart';

class _CachedStream {
  final String url;
  final DateTime expiresAt;
  const _CachedStream(this.url, this.expiresAt);
}

class YtAudioResolver {
  YtAudioResolver._();

  static final Map<String, _CachedStream> _cache = {};

  static const List<String> _pipedMirrors = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.lunar.icu',
    'https://api.piped.private.coffee',
  ];

  static const List<String> _invidiousMirrors = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
  ];

  /// Resolves direct audio stream for a YouTube video ID using:
  /// 1. Quality-aware YoutubeExplode audio-only stream
  /// 2. Piped API mirrors
  /// 3. Invidious API mirrors
  static Future<String?> resolveAudioStream(
    String videoId, {
    String? fallbackTitle,
    String? fallbackArtist,
  }) async {
    final cleanId = videoId.replaceFirst('yt_', '').trim();
    if (cleanId.isEmpty) return null;

    final quality = SettingsService.instance.audioQuality;
    final cacheKey = '${cleanId}_${quality.name}';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.url;
    }

    // 1. YoutubeExplode native audio extraction
    try {
      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient
            .getManifest(cleanId)
            .timeout(const Duration(milliseconds: 8000));
        final audioStreams = manifest.audioOnly.sortByBitrate().toList();
        if (audioStreams.isNotEmpty) {
          AudioOnlyStreamInfo chosen;
          if (quality == AudioQuality.saver96) {
            chosen = audioStreams.first;
          } else if (quality == AudioQuality.standard160 && audioStreams.length > 2) {
            chosen = audioStreams[audioStreams.length ~/ 2];
          } else {
            chosen = audioStreams.last;
          }
          final directUrl = chosen.url.toString();
          _cache[cacheKey] = _CachedStream(
            directUrl,
            DateTime.now().add(const Duration(hours: 3)),
          );
          return directUrl;
        }
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint('[YtAudioResolver] YoutubeExplode error for $cleanId: $e');
    }

    // 2. Piped API mirrors fallback
    for (final mirror in _pipedMirrors) {
      try {
        final uri = Uri.parse('$mirror/streams/$cleanId');
        final resp = await http.get(uri).timeout(const Duration(milliseconds: 3500));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final audioList = List<Map<String, dynamic>>.from(
            (data['audioStreams'] as List? ?? []).whereType<Map>(),
          );
          if (audioList.isNotEmpty) {
            audioList.sort((a, b) {
              final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
              final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
              return brA.compareTo(brB);
            });
            final chosen = quality == AudioQuality.saver96
                ? audioList.first
                : (quality == AudioQuality.standard160 && audioList.length > 2
                    ? audioList[audioList.length ~/ 2]
                    : audioList.last);
            final streamUrl = chosen['url']?.toString();
            if (streamUrl != null && streamUrl.isNotEmpty) {
              _cache[cacheKey] = _CachedStream(
                streamUrl,
                DateTime.now().add(const Duration(hours: 2)),
              );
              return streamUrl;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Invidious API mirrors fallback
    for (final mirror in _invidiousMirrors) {
      try {
        final uri = Uri.parse('$mirror/api/v1/videos/$cleanId');
        final resp = await http.get(uri).timeout(const Duration(milliseconds: 3500));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final adaptive = (data['adaptiveFormats'] as List? ?? [])
              .whereType<Map>()
              .where((f) => (f['type']?.toString() ?? '').startsWith('audio/'))
              .toList();
          if (adaptive.isNotEmpty) {
            adaptive.sort((a, b) {
              final brA = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
              final brB = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
              return brA.compareTo(brB);
            });
            final chosen = quality == AudioQuality.saver96 ? adaptive.first : adaptive.last;
            final streamUrl = chosen['url']?.toString();
            if (streamUrl != null && streamUrl.isNotEmpty) {
              _cache[cacheKey] = _CachedStream(
                streamUrl,
                DateTime.now().add(const Duration(hours: 2)),
              );
              return streamUrl;
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }
}
