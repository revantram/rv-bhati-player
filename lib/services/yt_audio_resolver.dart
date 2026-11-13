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
    ..connectionTimeout = const Duration(seconds: 5)
    ..autoUncompress = true;

  static String? _cachedVisitorData;
  static DateTime? _visitorExpiresAt;

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
    'https://invidious.privacyredirect.com',
  ];

  static const String _androidVrUa =
      'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
  static const String _iosUa =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X; en_IN)';
  static const String _androidTestUa =
      'com.google.android.youtube/19.29.37 (Linux; U; Android 13; en_US) gzip';
  static const String _tvEmbedUa =
      'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version';

  static Future<String?> _getVisitorData() async {
    if (_cachedVisitorData != null &&
        _visitorExpiresAt != null &&
        DateTime.now().isBefore(_visitorExpiresAt!)) {
      return _cachedVisitorData;
    }
    try {
      final req = await _httpClient.postUrl(
        Uri.parse('https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false'),
      );
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('User-Agent', _androidVrUa);
      req.headers.set('X-YouTube-Client-Name', '28');
      req.headers.set('X-YouTube-Client-Version', '1.60.19');
      req.add(utf8.encode(jsonEncode({
        'context': {
          'client': {
            'clientName': 'ANDROID_VR',
            'clientVersion': '1.60.19',
            'osName': 'Android',
            'osVersion': '12L',
            'androidSdkVersion': 32,
            'hl': 'en',
            'gl': 'IN',
          },
        },
      })));
      final resp = await req.close().timeout(const Duration(milliseconds: 2200));
      if (resp.statusCode == 200) {
        final raw = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final vd = data['responseContext']?['visitorData']?.toString();
        if (vd != null && vd.isNotEmpty) {
          _cachedVisitorData = vd;
          _visitorExpiresAt = DateTime.now().add(const Duration(minutes: 45));
          return vd;
        }
      } else {
        await resp.drain<void>();
      }
    } catch (_) {}
    return _cachedVisitorData;
  }

  /// Resolves verified playable audio stream candidates across multiple YouTube
  /// engines and mirrors. Probes streams with a tiny HTTP Range check so 403/dead
  /// URLs are filtered out immediately before ExoPlayer touches them.
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

    final visitorData = await _getVisitorData();
    final verified = <ResolvedAudioStream>[];
    final seenUrls = <String>{};

    Future<void> probeAndCollect(List<ResolvedAudioStream> rawList) async {
      final unique = <ResolvedAudioStream>[];
      for (final item in rawList) {
        if (item.url.isNotEmpty && seenUrls.add(item.url)) {
          unique.add(item);
        }
      }
      if (unique.isEmpty) return;

      final probeResults = await Future.wait(
        unique.map((c) async => (await _probePlayable(c)) ? c : null),
      );
      for (final ok in probeResults) {
        if (ok != null) verified.add(ok);
      }
    }

    // Round 1: Parallel ANDROID_VR + TVHTML5_SIMPLY_EMBEDDED + YoutubeExplode
    final round1Lists = await Future.wait([
      _fetchInnertubePlayer(
        videoId: cleanId,
        quality: quality,
        clientName: 'ANDROID_VR',
        clientVersion: '1.60.19',
        clientId: '28',
        userAgent: _androidVrUa,
        visitorData: visitorData,
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
      ),
      _fetchInnertubePlayer(
        videoId: cleanId,
        quality: quality,
        clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
        clientVersion: '2.0',
        clientId: '85',
        userAgent: _tvEmbedUa,
        visitorData: visitorData,
        thirdPartyEmbedUrl: 'https://www.youtube.com/watch?v=$cleanId',
        clientBody: {
          'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          'clientVersion': '2.0',
          'hl': 'en',
          'gl': 'IN',
        },
      ),
      _resolveViaYoutubeExplode(cleanId, quality),
    ]);

    final round1Raw = <ResolvedAudioStream>[
      for (final list in round1Lists) ...list,
    ];
    await probeAndCollect(round1Raw);

    // Round 2: If Round 1 failed verification (e.g. 403/PO-token), try IOS + ANDROID_TESTSUITE + Mirrors
    if (verified.isEmpty) {
      final round2Lists = await Future.wait([
        _fetchInnertubePlayer(
          videoId: cleanId,
          quality: quality,
          clientName: 'IOS',
          clientVersion: '20.10.4',
          clientId: '5',
          userAgent: _iosUa,
          visitorData: visitorData,
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
        ),
        _fetchInnertubePlayer(
          videoId: cleanId,
          quality: quality,
          clientName: 'ANDROID_TESTSUITE',
          clientVersion: '1.9',
          clientId: '30',
          userAgent: _androidTestUa,
          visitorData: visitorData,
          clientBody: {
            'clientName': 'ANDROID_TESTSUITE',
            'clientVersion': '1.9',
            'osName': 'Android',
            'osVersion': '13',
            'androidSdkVersion': 33,
            'hl': 'en',
            'gl': 'IN',
          },
        ),
        _resolveViaMirrorsParallel(cleanId, quality),
      ]);

      final round2Raw = <ResolvedAudioStream>[
        for (final list in round2Lists) ...list,
      ];
      await probeAndCollect(round2Raw);
    }

    // Prefer non-HLS progressive streams first for reliable seeking & proxy support
    verified.sort((a, b) {
      if (a.isHls == b.isHls) return 0;
      return a.isHls ? 1 : -1;
    });

    if (verified.isNotEmpty) {
      _cache[cacheKey] = _CachedCandidates(
        List.unmodifiable(verified),
        DateTime.now().add(const Duration(minutes: 90)),
      );
    }

    return verified;
  }

  /// Verifies with a tiny Range/GET request that the stream actually returns HTTP 200/206
  /// and is NOT an expired/403/PO-token blocked googlevideo URL.
  static Future<bool> _probePlayable(ResolvedAudioStream candidate) async {
    try {
      var uri = Uri.parse(candidate.url);
      for (int hop = 0; hop < 4; hop++) {
        final req = await _httpClient.getUrl(uri);
        req.followRedirects = false;
        candidate.headers?.forEach((k, v) => req.headers.set(k, v));
        req.headers.set(HttpHeaders.acceptHeader, '*/*');
        if (!candidate.isHls) {
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-63');
        }

        final resp = await req.close().timeout(const Duration(milliseconds: 2600));
        if (resp.isRedirect ||
            resp.statusCode == 301 ||
            resp.statusCode == 302 ||
            resp.statusCode == 303 ||
            resp.statusCode == 307 ||
            resp.statusCode == 308) {
          final loc = resp.headers.value(HttpHeaders.locationHeader);
          await resp.drain<void>();
          if (loc == null || loc.isEmpty) return false;
          uri = uri.resolve(loc);
          continue;
        }

        final okStatus = resp.statusCode == 200 || resp.statusCode == 206;
        if (!okStatus) {
          await resp.drain<void>();
          debugPrint('[YtAudioResolver] probe ${candidate.source} rejected (${resp.statusCode})');
          return false;
        }

        if (candidate.isHls) {
          final chunk = await resp.first.timeout(const Duration(milliseconds: 1500));
          final text = utf8.decode(chunk, allowMalformed: true);
          return text.contains('#EXTM3U');
        }

        await resp.drain<void>();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
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
    String? visitorData,
    String? thirdPartyEmbedUrl,
  }) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
      final bodyMap = <String, dynamic>{
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
        'context': {
          'client': clientBody,
          if (thirdPartyEmbedUrl != null)
            'thirdParty': {'embedUrl': thirdPartyEmbedUrl},
        },
      };

      final req = await _httpClient.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('User-Agent', userAgent);
      req.headers.set('X-YouTube-Client-Name', clientId);
      req.headers.set('X-YouTube-Client-Version', clientVersion);
      if (visitorData != null && visitorData.isNotEmpty) {
        req.headers.set('X-Goog-Visitor-Id', visitorData);
      }
      req.add(utf8.encode(jsonEncode(bodyMap)));

      final resp = await req.close().timeout(const Duration(milliseconds: 4500));
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return const [];
      }

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

      for (final f in muxed) {
        final u = f['url']?.toString() ?? '';
        if (u.isNotEmpty) {
          out.add(ResolvedAudioStream(url: u, headers: headers, source: '${clientName}_mux'));
          break;
        }
      }

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
      // Invidious server-proxied M4A fallback (bypasses googlevideo IP locks)
      for (final m in _invidiousMirrors)
        Future.value(ResolvedAudioStream(
          url: '$m/latest_version?id=$cleanId&itag=140&local=true',
          source: 'invidious_proxy',
        )),
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
