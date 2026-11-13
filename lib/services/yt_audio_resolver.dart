import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'settings_service.dart';

class ResolvedAudioStream {
  final String url;
  final Map<String, String>? headers;
  final bool isHls;
  final String source;

  const ResolvedAudioStream({
    required this.url,
    this.headers,
    this.isHls = false,
    this.source = 'yt',
  });
}

class _CachedCandidates {
  final List<ResolvedAudioStream> streams;
  final DateTime expiresAt;
  const _CachedCandidates(this.streams, this.expiresAt);
}

class YtAudioResolver {
  YtAudioResolver._();

  static final Map<String, _CachedCandidates> _cache = {};
  static final YoutubeExplode _sharedYt = YoutubeExplode();
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  static const List<String> _pipedMirrors = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
    'https://api.piped.private.coffee',
    'https://pipedapi.lunar.icu',
  ];

  static const List<String> _invidiousMirrors = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
  ];

  static const String _androidVrUa =
      'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
  static const String _iosUa =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X; en_IN)';
  static const String _androidTestUa =
      'com.google.android.youtube/19.29.37 (Linux; U; Android 13; en_US) gzip';

  /// Resolves multiple playable direct audio stream candidates for ExoPlayer / just_audio
  /// using fast direct InnerTube player clients first, then YoutubeExplode, then parallel mirrors.
  static Future<List<ResolvedAudioStream>> resolveAudioCandidates(
    String videoId, {
    String? fallbackTitle,
    String? fallbackArtist,
  }) async {
    final cleanId = videoId.replaceFirst('yt_', '').trim();
    if (cleanId.isEmpty) return const [];

    final quality = SettingsService.instance.audioQuality;
    final cacheKey = '${cleanId}_${quality.name}';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.streams;
    }

    final candidates = <ResolvedAudioStream>[];
    final seenUrls = <String>{};

    void addCandidate(ResolvedAudioStream s) {
      if (s.url.isNotEmpty && seenUrls.add(s.url)) {
        candidates.add(s);
      }
    }

    // 1. Direct InnerTube ANDROID_VR + IOS in parallel (fastest & PO-token free)
    final vrFuture = _fetchInnertubePlayer(
      videoId: cleanId,
      quality: quality,
      clientName: 'ANDROID_VR',
      clientVersion: '1.60.19',
      clientId: '28',
      userAgent: _androidVrUa,
      clientBody: {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.60.19',
        'deviceMake': 'Oculus',
        'deviceModel': 'Quest 3',
        'osName': 'Android',
        'osVersion': '12L',
        'androidSdkVersion': 32,
        'hl': 'en',
        'gl': 'IN',
      },
    );

    final iosFuture = _fetchInnertubePlayer(
      videoId: cleanId,
      quality: quality,
      clientName: 'IOS',
      clientVersion: '20.10.4',
      clientId: '5',
      userAgent: _iosUa,
      clientBody: {
        'clientName': 'IOS',
        'clientVersion': '20.10.4',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'osName': 'iPhone',
        'osVersion': '18.3.2.22D82',
        'hl': 'en',
        'gl': 'IN',
      },
    );

    final innertubeBatch = await Future.wait([vrFuture, iosFuture]);
    for (final list in innertubeBatch) {
      for (final item in list) {
        addCandidate(item);
      }
    }

    // 2. ANDROID_TESTSUITE InnerTube fallback if needed
    if (candidates.isEmpty) {
      final testsuiteStreams = await _fetchInnertubePlayer(
        videoId: cleanId,
        quality: quality,
        clientName: 'ANDROID_TESTSUITE',
        clientVersion: '1.9',
        clientId: '30',
        userAgent: _androidTestUa,
        clientBody: {
          'clientName': 'ANDROID_TESTSUITE',
          'clientVersion': '1.9',
          'osName': 'Android',
          'osVersion': '13',
          'androidSdkVersion': 33,
          'hl': 'en',
          'gl': 'IN',
        },
      );
      for (final item in testsuiteStreams) {
        addCandidate(item);
      }
    }

    // 3. YoutubeExplode fallback (audioOnly M4A -> audioOnly -> muxed MP4)
    if (candidates.isEmpty) {
      final ytStreams = await _resolveViaYoutubeExplode(cleanId, quality);
      for (final item in ytStreams) {
        addCandidate(item);
      }
    }

    // 4. Parallel Piped + Invidious mirror fallback (3.5s max wait)
    if (candidates.isEmpty) {
      final mirrorStreams = await _resolveViaMirrorsParallel(cleanId, quality);
      for (final item in mirrorStreams) {
        addCandidate(item);
      }
    }

    if (candidates.isNotEmpty) {
      _cache[cacheKey] = _CachedCandidates(
        List.unmodifiable(candidates),
        DateTime.now().add(const Duration(hours: 2)),
      );
    }

    return candidates;
  }

  /// Backward-compatible helper returning the best single URL (prefers non-HLS).
  static Future<String?> resolveAudioStream(
    String videoId, {
    String? fallbackTitle,
    String? fallbackArtist,
  }) async {
    final best = await resolveBestForDownload(
      videoId,
      fallbackTitle: fallbackTitle,
      fallbackArtist: fallbackArtist,
    );
    if (best != null) return best.url;
    final all = await resolveAudioCandidates(
      videoId,
      fallbackTitle: fallbackTitle,
      fallbackArtist: fallbackArtist,
    );
    return all.isNotEmpty ? all.first.url : null;
  }

  /// Returns a direct downloadable audio stream (never HLS .m3u8) with its headers.
  static Future<ResolvedAudioStream?> resolveBestForDownload(
    String videoId, {
    String? fallbackTitle,
    String? fallbackArtist,
  }) async {
    final candidates = await resolveAudioCandidates(
      videoId,
      fallbackTitle: fallbackTitle,
      fallbackArtist: fallbackArtist,
    );
    for (final c in candidates) {
      if (!c.isHls) return c;
    }
    return null;
  }

  static Future<List<ResolvedAudioStream>> _fetchInnertubePlayer({
    required String videoId,
    required AudioQuality quality,
    required String clientName,
    required String clientVersion,
    required String clientId,
    required String userAgent,
    required Map<String, dynamic> clientBody,
  }) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
      final payload = jsonEncode({
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
        'context': {
          'client': clientBody,
        },
      });

      final req = await _httpClient.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('User-Agent', userAgent);
      req.headers.set('X-YouTube-Client-Name', clientId);
      req.headers.set('X-YouTube-Client-Version', clientVersion);
      req.add(utf8.encode(payload));

      final resp = await req.close().timeout(const Duration(milliseconds: 4500));
      if (resp.statusCode != 200) return const [];

      final raw = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final status = data['playabilityStatus']?['status']?.toString() ?? '';
      if (status != 'OK' && data['streamingData'] == null) {
        return const [];
      }

      final streaming = data['streamingData'] as Map<String, dynamic>?;
      if (streaming == null) return const [];

      final headers = {'User-Agent': userAgent};
      final adaptive = (streaming['adaptiveFormats'] as List? ?? []).whereType<Map>();
      final muxed = (streaming['formats'] as List? ?? []).whereType<Map>();

      final m4aAudio = <Map>[];
      final otherAudio = <Map>[];

      for (final f in adaptive) {
        final directUrl = f['url']?.toString() ?? '';
        if (directUrl.isEmpty) continue;
        final mime = (f['mimeType']?.toString() ?? '').toLowerCase();
        if (mime.startsWith('audio/mp4')) {
          m4aAudio.add(f);
        } else if (mime.startsWith('audio/')) {
          otherAudio.add(f);
        }
      }

      int byBitrate(Map a, Map b) {
        final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
        final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
        return brA.compareTo(brB);
      }

      m4aAudio.sort(byBitrate);
      otherAudio.sort(byBitrate);

      final out = <ResolvedAudioStream>[];
      Map? pickByQuality(List<Map> list) {
        if (list.isEmpty) return null;
        if (quality == AudioQuality.saver96) return list.first;
        if (quality == AudioQuality.standard160 && list.length > 2) {
          return list[list.length ~/ 2];
        }
        return list.last;
      }

      final bestM4a = pickByQuality(m4aAudio);
      if (bestM4a != null) {
        out.add(ResolvedAudioStream(
          url: bestM4a['url'].toString(),
          headers: headers,
          source: clientName,
        ));
      }

      final bestOther = pickByQuality(otherAudio);
      if (bestOther != null) {
        out.add(ResolvedAudioStream(
          url: bestOther['url'].toString(),
          headers: headers,
          source: clientName,
        ));
      }

      // Muxed MP4 fallback
      for (final f in muxed) {
        final u = f['url']?.toString() ?? '';
        if (u.isNotEmpty) {
          out.add(ResolvedAudioStream(url: u, headers: headers, source: '${clientName}_mux'));
          break;
        }
      }

      // HLS manifest fallback (especially reliable on iOS client)
      final hls = streaming['hlsManifestUrl']?.toString() ?? '';
      if (hls.isNotEmpty) {
        out.add(ResolvedAudioStream(
          url: hls,
          headers: headers,
          isHls: true,
          source: '${clientName}_hls',
        ));
      }

      return out;
    } catch (e) {
      debugPrint('[YtAudioResolver] $clientName error for $videoId: $e');
      return const [];
    }
  }

  static Future<List<ResolvedAudioStream>> _resolveViaYoutubeExplode(
    String cleanId,
    AudioQuality quality,
  ) async {
    try {
      final manifest = await _sharedYt.videos.streamsClient
          .getManifest(cleanId)
          .timeout(const Duration(milliseconds: 5500));

      final out = <ResolvedAudioStream>[];
      final audioStreams = manifest.audioOnly.sortByBitrate().toList();

      // Prefer MP4/M4A for ExoPlayer compatibility
      final mp4Audio = audioStreams
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList();
      final primaryList = mp4Audio.isNotEmpty ? mp4Audio : audioStreams;

      if (primaryList.isNotEmpty) {
        AudioOnlyStreamInfo chosen;
        if (quality == AudioQuality.saver96) {
          chosen = primaryList.first;
        } else if (quality == AudioQuality.standard160 && primaryList.length > 2) {
          chosen = primaryList[primaryList.length ~/ 2];
        } else {
          chosen = primaryList.last;
        }
        out.add(ResolvedAudioStream(url: chosen.url.toString(), source: 'yt_explode'));
      }

      if (audioStreams.isNotEmpty && audioStreams.last.url.toString() != out.firstOrNull?.url) {
        out.add(ResolvedAudioStream(
          url: audioStreams.last.url.toString(),
          source: 'yt_explode_alt',
        ));
      }

      if (manifest.muxed.isNotEmpty) {
        out.add(ResolvedAudioStream(
          url: manifest.muxed.first.url.toString(),
          source: 'yt_explode_muxed',
        ));
      }

      return out;
    } catch (e) {
      debugPrint('[YtAudioResolver] YoutubeExplode error for $cleanId: $e');
      return const [];
    }
  }

  static Future<List<ResolvedAudioStream>> _resolveViaMirrorsParallel(
    String cleanId,
    AudioQuality quality,
  ) async {
    final futures = <Future<ResolvedAudioStream?>>[
      for (final m in _pipedMirrors) _fetchPipedSingle(m, cleanId, quality),
      for (final m in _invidiousMirrors) _fetchInvidiousSingle(m, cleanId, quality),
    ];

    final results = await Future.wait(futures);
    return results.whereType<ResolvedAudioStream>().toList();
  }

  static Future<ResolvedAudioStream?> _fetchPipedSingle(
    String mirror,
    String cleanId,
    AudioQuality quality,
  ) async {
    try {
      final resp = await http
          .get(Uri.parse('$mirror/streams/$cleanId'))
          .timeout(const Duration(milliseconds: 3500));
      if (resp.statusCode != 200) return null;

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
        final m4a = audioList
            .where((a) => (a['mimeType']?.toString() ?? '').contains('mp4'))
            .toList();
        final pool = m4a.isNotEmpty ? m4a : audioList;
        final chosen = quality == AudioQuality.saver96
            ? pool.first
            : (quality == AudioQuality.standard160 && pool.length > 2
                ? pool[pool.length ~/ 2]
                : pool.last);
        final u = chosen['url']?.toString() ?? '';
        if (u.isNotEmpty) {
          return ResolvedAudioStream(url: u, source: 'piped');
        }
      }
      final hls = data['hls']?.toString() ?? '';
      if (hls.isNotEmpty) {
        return ResolvedAudioStream(url: hls, isHls: true, source: 'piped_hls');
      }
    } catch (_) {}
    return null;
  }

  static Future<ResolvedAudioStream?> _fetchInvidiousSingle(
    String mirror,
    String cleanId,
    AudioQuality quality,
  ) async {
    try {
      final resp = await http
          .get(Uri.parse('$mirror/api/v1/videos/$cleanId'))
          .timeout(const Duration(milliseconds: 3500));
      if (resp.statusCode != 200) return null;

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
        final u = chosen['url']?.toString() ?? '';
        if (u.isNotEmpty) {
          return ResolvedAudioStream(url: u, source: 'invidious');
        }
      }
      final hls = data['hlsUrl']?.toString() ?? '';
      if (hls.isNotEmpty) {
        return ResolvedAudioStream(url: hls, isHls: true, source: 'invidious_hls');
      }
    } catch (_) {}
    return null;
  }
}
