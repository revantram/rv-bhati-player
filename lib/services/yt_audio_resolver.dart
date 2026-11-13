import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'settings_service.dart';
import 'yt_webview_extractor.dart';

class ResolvedAudioStream {
  final String url;
  final Map<String, String>? headers;
  final bool isHls;
  final String source;
  final String? mimeHint;
  final StreamInfo? ytStreamInfo;
  final YoutubeExplode? ytClient;

  const ResolvedAudioStream({
    required this.url,
    this.headers,
    this.isHls = false,
    this.source = 'yt',
    this.mimeHint,
    this.ytStreamInfo,
    this.ytClient,
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
    ..connectionTimeout = const Duration(seconds: 6)
    ..autoUncompress = true;

  static String? _cachedVisitorData;
  static DateTime? _visitorExpiresAt;

  static const List<String> _pipedMirrors = [
    'https://api.piped.private.coffee',
    'https://pipedapi.adminforge.de',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.ducks.party',
    'https://pipedapi.ngn.tf',
    'https://pipedapi.lunar.icu',
  ];

  static const List<String> _invidiousMirrors = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
    'https://invidious.perennialte.ch',
    'https://iv.datura.network',
    'https://invidious.privacyredirect.com',
  ];

  static const String _androidVrUa =
      'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
  static const String _androidVr156Ua =
      'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
  static const String _iosUa =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
  static const String _androidUa =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  static const String _androidMusicUa =
      'com.google.android.apps.youtube.music/7.29.52 (Linux; U; Android 13; en_IN) gzip';
  static const String _browserUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36';

  static void invalidateCache(String videoId) {
    final cleanId = videoId.replaceFirst('yt_', '').trim();
    if (cleanId.isEmpty) return;
    _cache.removeWhere((k, _) => k.startsWith('${cleanId}_'));
  }

  static void _rememberVisitorData(String? vd) {
    if (vd != null && vd.isNotEmpty) {
      _cachedVisitorData = vd;
      _visitorExpiresAt = DateTime.now().add(const Duration(minutes: 45));
    }
  }

  static Future<String?> _getVisitorData() async {
    if (_cachedVisitorData != null &&
        _visitorExpiresAt != null &&
        DateTime.now().isBefore(_visitorExpiresAt!)) {
      return _cachedVisitorData;
    }

    // 1. Primary: youtubei/v1/visitor_id
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
            'userAgent': _androidVrUa,
            'osName': 'Android',
            'osVersion': '12L',
            'androidSdkVersion': 32,
            'hl': 'en',
            'gl': 'IN',
          },
        },
      })));
      final resp = await req.close().timeout(const Duration(milliseconds: 1400));
      if (resp.statusCode == 200) {
        final raw = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final vd = data['responseContext']?['visitorData']?.toString();
        if (vd != null && vd.isNotEmpty) {
          _rememberVisitorData(vd);
          return vd;
        }
      } else {
        await resp.drain<void>();
      }
    } catch (_) {}

    // 2. Fallback: youtube.com/sw.js_data
    try {
      final req = await _httpClient.getUrl(Uri.parse('https://www.youtube.com/sw.js_data'));
      req.headers.set('User-Agent', _browserUa);
      final resp = await req.close().timeout(const Duration(milliseconds: 1400));
      if (resp.statusCode == 200) {
        final raw = await resp.transform(utf8.decoder).join();
        final m = RegExp(r'"(Cg[A-Za-z0-9%_-]{12,})"').firstMatch(raw);
        final vd = m?.group(1);
        if (vd != null && vd.isNotEmpty) {
          final decoded = Uri.decodeComponent(vd);
          _rememberVisitorData(decoded);
          return decoded;
        }
      } else {
        await resp.drain<void>();
      }
    } catch (_) {}

    return _cachedVisitorData;
  }

  /// Resolves verified playable audio stream candidates using a fast race-to-first-valid
  /// pipeline so playback starts in ~1-2s instead of stalling on slow/dead mirrors.
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

    // Ensure visitorData is ready before Round 1 InnerTube calls (bounded at ~1s on cold start)
    String? visitorData = _cachedVisitorData;
    if (visitorData == null) {
      try {
        visitorData = await _getVisitorData().timeout(const Duration(milliseconds: 1000));
      } catch (_) {
        visitorData = _cachedVisitorData;
      }
    }

    final verifiedYt = <ResolvedAudioStream>[];
    final verifiedFallback = <ResolvedAudioStream>[];
    final seenUrls = <String>{};
    final firstYtProgReady = Completer<void>();
    final firstFallbackReady = Completer<void>();

    Future<void> probeBatch(
      List<ResolvedAudioStream> rawList, {
      required bool isFallback,
    }) async {
      final unique = <ResolvedAudioStream>[];
      for (final item in rawList) {
        if (item.url.isNotEmpty && seenUrls.add(item.url)) {
          unique.add(item);
        }
      }
      if (unique.isEmpty) return;

      final probeResults = await Future.wait(
        unique.map((c) async {
          if (c.ytStreamInfo != null && c.source == 'yt_explode_stream') {
            return c;
          }
          return (await _probePlayable(c)) ? c : null;
        }),
      );
      final target = isFallback ? verifiedFallback : verifiedYt;
      bool addedProg = false;
      bool addedAny = false;
      for (final ok in probeResults) {
        if (ok != null) {
          target.add(ok);
          addedAny = true;
          if (!ok.isHls) addedProg = true;
        }
      }
      if (addedAny) {
        if (!isFallback && addedProg && !firstYtProgReady.isCompleted) {
          firstYtProgReady.complete();
        } else if (isFallback && !firstFallbackReady.isCompleted) {
          firstFallbackReady.complete();
        }
      }
    }

    // Fast Round 1: Direct YouTube Innertube (ANDROID_VR 1.60/1.56 + IOS) + Unblocked Catalog CDN
    final ytTasks = <Future<void>>[
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
          'userAgent': _androidVrUa,
          'deviceMake': 'Oculus',
          'deviceModel': 'Quest 3',
          'osName': 'Android',
          'osVersion': '12L',
          'androidSdkVersion': 32,
          'hl': 'en',
          'gl': 'IN',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      ).then((l) => probeBatch(l, isFallback: false)),
      _fetchInnertubePlayer(
        videoId: cleanId,
        quality: quality,
        clientName: 'ANDROID_VR_156',
        clientVersion: '1.56.21',
        clientId: '28',
        userAgent: _androidVr156Ua,
        visitorData: visitorData,
        clientBody: {
          'clientName': 'ANDROID_VR',
          'clientVersion': '1.56.21',
          'userAgent': _androidVr156Ua,
          'deviceMake': 'Oculus',
          'deviceModel': 'Quest 3',
          'osName': 'Android',
          'osVersion': '12',
          'androidSdkVersion': 32,
          'hl': 'en',
          'gl': 'IN',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      ).then((l) => probeBatch(l, isFallback: false)),
      _fetchInnertubePlayer(
        videoId: cleanId,
        quality: quality,
        clientName: 'IOS',
        clientVersion: '20.10.4',
        clientId: '5',
        userAgent: _iosUa,
        visitorData: visitorData,
        playerUrl:
            'https://www.youtube.com/youtubei/v1/player?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc&prettyPrint=false',
        clientBody: {
          'clientName': 'IOS',
          'clientVersion': '20.10.4',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'userAgent': _iosUa,
          'platform': 'MOBILE',
          'osName': 'IOS',
          'osVersion': '18.3.2.22D82',
          'hl': 'en',
          'gl': 'IN',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      ).then((l) => probeBatch(l, isFallback: false)),
    ];

    final allFastYtDone = Future.wait(ytTasks);

    final Future<void> catalogTask;
    if (fallbackTitle != null && fallbackTitle.trim().isNotEmpty) {
      catalogTask = _resolveViaCatalogCdn(
        title: fallbackTitle,
        artist: fallbackArtist ?? '',
        quality: quality,
      ).then((l) => probeBatch(l, isFallback: true));
    } else {
      catalogTask = Future.value();
    }

    // Race fast YouTube progressive vs Catalog CDN; wait at most ~1.8s when YT is slow
    await Future.any<void>([
      firstYtProgReady.future,
      allFastYtDone,
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);

    if (verifiedYt.any((s) => !s.isHls)) {
      if (!firstFallbackReady.isCompleted) {
        await Future.any<void>([
          catalogTask,
          Future.delayed(const Duration(milliseconds: 450)),
        ]);
      }
    } else {
      await Future.any<void>([
        firstYtProgReady.future,
        firstFallbackReady.future,
        Future.wait([allFastYtDone, catalogTask]),
        Future.delayed(const Duration(milliseconds: 2600)),
      ]);
    }

    // Round 2: Run YoutubeExplode + Piped/Invidious + ANDROID/MUSIC/TV + WebView
    // whenever Round 1 did not yield a reliable ANDROID_VR progressive or Catalog CDN stream.
    final hasVrOrCdn =
        verifiedYt.any((s) => !s.isHls && s.source.startsWith('ANDROID_VR')) ||
            verifiedFallback.isNotEmpty;
    if (!hasVrOrCdn) {
      final round2 = await resolveDeepFallbackCandidates(
        cleanId,
        fallbackTitle: fallbackTitle,
        fallbackArtist: fallbackArtist,
        alreadySeenUrls: seenUrls,
      );
      for (final c in round2) {
        if (c.source.startsWith('bit_cdn')) {
          verifiedFallback.add(c);
        } else {
          verifiedYt.add(c);
        }
      }
    }

    // Order: ANDROID_VR progressive -> other YT progressive -> verified Catalog CDN ->
    // YoutubeExplode chunked stream -> HLS fallback
    final vrProg = verifiedYt
        .where((s) =>
            !s.isHls && s.source.startsWith('ANDROID_VR') && s.source != 'yt_explode_stream')
        .toList();
    final otherProg = verifiedYt
        .where((s) =>
            !s.isHls && !s.source.startsWith('ANDROID_VR') && s.source != 'yt_explode_stream')
        .toList();
    final ytExplodeStreams = verifiedYt.where((s) => s.source == 'yt_explode_stream').toList();
    final hlsYt = verifiedYt.where((s) => s.isHls).toList();

    final verified = <ResolvedAudioStream>[
      ...vrProg,
      ...otherProg,
      ...verifiedFallback,
      ...ytExplodeStreams,
      ...hlsYt,
    ];

    if (verified.isNotEmpty) {
      _cache[cacheKey] = _CachedCandidates(
        List.unmodifiable(verified),
        DateTime.now().add(const Duration(minutes: 45)),
      );
    }

    return verified;
  }

  /// Deep fallback resolver invoked automatically when primary fast candidates fail
  /// in ExoPlayer or are blocked/unavailable: tries ANDROID, ANDROID_MUSIC, TVHTML5,
  /// youtube_explode_dart (with explicit androidVr/ios/tv clients), Piped/Invidious
  /// mirrors, and headless WebView extraction.
  static Future<List<ResolvedAudioStream>> resolveDeepFallbackCandidates(
    String videoId, {
    String? fallbackTitle,
    String? fallbackArtist,
    Set<String>? alreadySeenUrls,
  }) async {
    final cleanId = videoId.replaceFirst('yt_', '').trim();
    if (cleanId.isEmpty) return const [];

    final quality = SettingsService.instance.audioQuality;
    final visitorData = _cachedVisitorData ?? await _getVisitorData();
    final seenUrls = alreadySeenUrls ?? <String>{};
    final out = <ResolvedAudioStream>[];
    final firstReady = Completer<void>();

    Future<void> probeAndAdd(List<ResolvedAudioStream> rawList) async {
      final unique = <ResolvedAudioStream>[];
      for (final item in rawList) {
        if (item.url.isNotEmpty && seenUrls.add(item.url)) {
          unique.add(item);
        }
      }
      if (unique.isEmpty) return;

      final probeResults = await Future.wait(
        unique.map((c) async {
          if (c.ytStreamInfo != null && c.source == 'yt_explode_stream') {
            return c;
          }
          return (await _probePlayable(c)) ? c : null;
        }),
      );
      bool addedProg = false;
      for (final ok in probeResults) {
        if (ok != null) {
          out.add(ok);
          if (!ok.isHls) addedProg = true;
        }
      }
      if (addedProg && !firstReady.isCompleted) {
        firstReady.complete();
      }
    }

    final tasks = <Future<void>>[
      _resolveViaYoutubeExplode(cleanId, quality).then(probeAndAdd),
      _resolveViaMirrorsParallel(cleanId, quality).then(probeAndAdd),
      _fetchInnertubePlayer(
        videoId: cleanId,
        quality: quality,
        clientName: 'ANDROID',
        clientVersion: '20.10.38',
        clientId: '3',
        userAgent: _androidUa,
        visitorData: visitorData,
        clientBody: {
          'clientName': 'ANDROID',
          'clientVersion': '20.10.38',
          'userAgent': _androidUa,
          'osName': 'Android',
          'osVersion': '11',
          'androidSdkVersion': 30,
          'hl': 'en',
          'gl': 'IN',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      ).then(probeAndAdd),
      _fetchInnertubePlayer(
        videoId: cleanId,
        quality: quality,
        clientName: 'ANDROID_MUSIC',
        clientVersion: '7.29.52',
        clientId: '21',
        userAgent: _androidMusicUa,
        visitorData: visitorData,
        playerUrl:
            'https://music.youtube.com/youtubei/v1/player?key=AIzaSyAOghZGza2MQSZkY_zfZ370N-PUdXEo8AI&prettyPrint=false',
        clientBody: {
          'clientName': 'ANDROID_MUSIC',
          'clientVersion': '7.29.52',
          'userAgent': _androidMusicUa,
          'osName': 'Android',
          'osVersion': '13',
          'androidSdkVersion': 33,
          'hl': 'en',
          'gl': 'IN',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      ).then(probeAndAdd),
      if (fallbackTitle != null && fallbackTitle.trim().isNotEmpty)
        _resolveViaCatalogCdn(
          title: fallbackTitle,
          artist: fallbackArtist ?? '',
          quality: quality,
        ).then(probeAndAdd),
      YtWebViewExtractor.extractAudioStreams(cleanId).then(probeAndAdd),
    ];

    final allDone = Future.wait(tasks);
    await Future.any<void>([
      firstReady.future,
      allDone,
      Future.delayed(const Duration(seconds: 6)),
    ]);

    if (out.isNotEmpty) {
      await Future.any<void>([
        allDone,
        Future.delayed(const Duration(milliseconds: 900)),
      ]);
    } else {
      await Future.any<void>([
        allDone,
        Future.delayed(const Duration(seconds: 3)),
      ]);
    }

    final prog = out.where((s) => !s.isHls && s.source != 'yt_explode_stream').toList();
    final explodeProxies = out.where((s) => s.source == 'yt_explode_stream').toList();
    final hls = out.where((s) => s.isHls).toList();
    return [...prog, ...explodeProxies, ...hls];
  }

  /// Verifies with a tiny Range/GET request that the stream actually returns HTTP 200/206,
  /// has a media content-type (never Cloudflare HTML / JSON error pages), and works cleanly.
  static Future<bool> _probePlayable(ResolvedAudioStream candidate) async {
    try {
      var uri = Uri.parse(candidate.url);
      if (!uri.hasScheme || uri.host.isEmpty) return false;
      if (uri.queryParameters['ump'] == '1' || uri.queryParameters['sabr'] == '1') {
        return false;
      }
      for (int hop = 0; hop < 4; hop++) {
        final req = await _httpClient.getUrl(uri);
        req.followRedirects = false;
        candidate.headers?.forEach((k, v) => req.headers.set(k, v));
        req.headers.set(HttpHeaders.acceptHeader, '*/*');
        if (!candidate.isHls) {
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-255');
        }

        final resp = await req.close().timeout(const Duration(milliseconds: 2800));
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

        final ct = (resp.headers.value(HttpHeaders.contentTypeHeader) ?? '').toLowerCase();
        if (ct.contains('text/html') ||
            ct.contains('text/plain') ||
            ct.contains('application/json') ||
            ct.contains('application/xml') ||
            ct.contains('yt-ump')) {
          await resp.drain<void>();
          debugPrint('[YtAudioResolver] probe ${candidate.source} rejected non-media ($ct)');
          return false;
        }

        if (candidate.isHls) {
          final chunk = await resp.first.timeout(const Duration(milliseconds: 1800));
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

  static String _cleanSearchTerm(String raw) {
    return raw
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]|\{.*?\}'), ' ')
        .replaceAll(
          RegExp(
            r'\b(official|video|audio|lyric|lyrics|lyrical|full\s*song|hd|4k|8k|remix|status|lofi|slowed|reverb|jukebox|teaser|trailer)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'feat\..*|ft\..*', caseSensitive: false), ' ')
        .split(RegExp(r'[\|\•\-–—]'))
        .first
        .replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Resolves a direct 160/320kbps AAC/M4A stream by track title+artist via direct
  /// unblocked CDN when YouTube refuses extraction with LOGIN_REQUIRED / 403.
  static Future<List<ResolvedAudioStream>> _resolveViaCatalogCdn({
    required String title,
    required String artist,
    required AudioQuality quality,
  }) async {
    final cleanTitle = _cleanSearchTerm(title);
    final cleanArtist = _cleanSearchTerm(
      artist
          .replaceAll('YouTube Music', '')
          .replaceAll('Topic', '')
          .replaceAll('VEVO', ''),
    );
    if (cleanTitle.isEmpty) return const [];

    final queries = <String>[
      if (cleanArtist.isNotEmpty) '$cleanTitle $cleanArtist',
      cleanTitle,
    ];

    final artistTokens = cleanArtist
        .toLowerCase()
        .split(' ')
        .where((w) => w.length >= 3)
        .toSet();
    final titleTokens = cleanTitle
        .toLowerCase()
        .split(' ')
        .where((w) => w.length >= 3)
        .toSet();

    for (final q in queries) {
      final isTitleOnlyQuery = q == cleanTitle && artistTokens.isNotEmpty;
      try {
        final searchUri = Uri.https('www.jiosaavn.com', '/api.php', {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'cc': 'in',
          'includeMetaTags': '1',
          'api_version': '4',
          'ctx': 'web6dot0',
          'q': q,
        });
        final resp = await http
            .get(searchUri, headers: const {'User-Agent': _browserUa})
            .timeout(const Duration(seconds: 3));
        if (resp.statusCode != 200) continue;

        final data = jsonDecode(resp.body);
        if (data is! Map<String, dynamic>) continue;
        final results = (data['results'] as List? ?? []).whereType<Map>().toList();
        if (results.isEmpty) continue;

        Map? bestMatch;
        Map? fallbackExactTitle;
        final cleanTitleLower = cleanTitle.toLowerCase();
        for (final r in results.take(6)) {
          final enc = r['more_info']?['encrypted_media_url']?.toString() ?? '';
          if (enc.isEmpty) continue;
          final rTitle = (r['title']?.toString() ?? '')
              .replaceAll('&quot;', '"')
              .replaceAll('&amp;', '&')
              .replaceAll('&#039;', "'")
              .toLowerCase();
          final rSub = (r['subtitle']?.toString() ?? '').toLowerCase();
          final primaryArtists = (r['more_info']?['artistMap']?['primary_artists'] as List? ?? [])
              .whereType<Map>()
              .map((a) => (a['name']?.toString() ?? '').toLowerCase())
              .join(' ');
          final combinedArtistInfo = '$rSub $primaryArtists';

          final titleMatches =
              titleTokens.isEmpty || titleTokens.any((tok) => rTitle.contains(tok));
          final artistMatches = artistTokens.isEmpty ||
              artistTokens.any((tok) => combinedArtistInfo.contains(tok));

          if (titleMatches && artistMatches) {
            bestMatch = r;
            break;
          }
          if (!isTitleOnlyQuery && rTitle.contains(cleanTitleLower)) {
            fallbackExactTitle ??= r;
          }
        }
        bestMatch ??= fallbackExactTitle;
        if (bestMatch == null) continue;

        final encUrl = bestMatch['more_info']?['encrypted_media_url']?.toString() ?? '';
        if (encUrl.isEmpty) continue;

        final bitrate = quality == AudioQuality.saver96
            ? '96'
            : (quality == AudioQuality.standard160 ? '160' : '320');

        final authUri = Uri.https('www.jiosaavn.com', '/api.php', {
          '__call': 'song.generateAuthToken',
          'url': encUrl,
          'bitrate': bitrate,
          'api_version': '4',
          '_format': 'json',
          'ctx': 'web6dot0',
          '_marker': '0',
        });
        final authResp = await http
            .get(authUri, headers: const {'User-Agent': _browserUa})
            .timeout(const Duration(seconds: 4));
        if (authResp.statusCode != 200) continue;

        final authData = jsonDecode(authResp.body);
        final rawAuthUrl = (authData is Map ? authData['auth_url']?.toString() : null) ?? '';
        if (rawAuthUrl.isEmpty) continue;

        final parsed = Uri.tryParse(rawAuthUrl);
        if (parsed == null || parsed.path.isEmpty) continue;

        final cdnUrl = 'https://aac.saavncdn.com${parsed.path}';
        final cdn160 = cdnUrl.replaceAll('_320.mp4', '_160.mp4');
        return [
          ResolvedAudioStream(
            url: cdnUrl,
            headers: const {'User-Agent': _browserUa},
            source: 'bit_cdn_$bitrate',
            mimeHint: 'audio/mp4',
          ),
          if (rawAuthUrl != cdnUrl)
            ResolvedAudioStream(
              url: rawAuthUrl,
              headers: const {'User-Agent': _browserUa},
              source: 'bit_cdn_auth',
              mimeHint: 'audio/mp4',
            ),
          if (cdn160 != cdnUrl)
            ResolvedAudioStream(
              url: cdn160,
              headers: const {'User-Agent': _browserUa},
              source: 'bit_cdn_160',
              mimeHint: 'audio/mp4',
            ),
        ];
      } catch (e) {
        debugPrint('[YtAudioResolver] catalog CDN fallback error: $e');
      }
    }
    return const [];
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
    String? playerUrl,
  }) async {
    try {
      final uri = Uri.parse(
        playerUrl ?? 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      );
      final effectiveClient = Map<String, dynamic>.from(clientBody);
      if (visitorData != null && visitorData.isNotEmpty) {
        effectiveClient['visitorData'] = visitorData;
      }

      final bodyMap = <String, dynamic>{
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
        'context': {
          'client': effectiveClient,
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
      _rememberVisitorData(data['responseContext']?['visitorData']?.toString());

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
          mimeHint: bestM4a['mimeType']?.toString() ?? 'audio/mp4',
        ));
      }

      final bestOther = pickByQuality(otherAudio);
      if (bestOther != null) {
        out.add(ResolvedAudioStream(
          url: bestOther['url'].toString(),
          headers: headers,
          source: '${clientName}_webm',
          mimeHint: bestOther['mimeType']?.toString() ?? 'audio/webm',
        ));
      }

      for (final f in muxed) {
        final u = f['url']?.toString() ?? '';
        if (u.isNotEmpty) {
          out.add(ResolvedAudioStream(
            url: u,
            headers: headers,
            source: '${clientName}_mux',
            mimeHint: f['mimeType']?.toString() ?? 'video/mp4',
          ));
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
    final out = <ResolvedAudioStream>[];

    Future<void> tryClient(
      YoutubeApiClient client, {
      required Map<String, String> headers,
      required String tag,
      bool requireWatchPage = false,
      Duration timeout = const Duration(milliseconds: 4800),
    }) async {
      try {
        final manifest = await _sharedYt.videos.streamsClient
            .getManifest(
              cleanId,
              ytClients: [client],
              requireWatchPage: requireWatchPage,
            )
            .timeout(timeout);

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
          out.add(ResolvedAudioStream(
            url: chosen.url.toString(),
            headers: headers,
            source: 'yt_explode_$tag',
            mimeHint:
                chosen.container.name.toLowerCase() == 'webm' ? 'audio/webm' : 'audio/mp4',
            ytStreamInfo: chosen,
            ytClient: _sharedYt,
          ));

          // Direct YoutubeExplode chunked-stream fallback marker for LocalStreamProxy
          out.add(ResolvedAudioStream(
            url: '${chosen.url}#yt_stream_$tag',
            headers: headers,
            source: 'yt_explode_stream',
            mimeHint:
                chosen.container.name.toLowerCase() == 'webm' ? 'audio/webm' : 'audio/mp4',
            ytStreamInfo: chosen,
            ytClient: _sharedYt,
          ));
        }

        if (audioStreams.isNotEmpty) {
          final alt = audioStreams.last;
          if (!out.any((s) => s.url == alt.url.toString())) {
            out.add(ResolvedAudioStream(
              url: alt.url.toString(),
              headers: headers,
              source: 'yt_explode_${tag}_alt',
              mimeHint:
                  alt.container.name.toLowerCase() == 'webm' ? 'audio/webm' : 'audio/mp4',
              ytStreamInfo: alt,
              ytClient: _sharedYt,
            ));
          }
        }

        if (manifest.muxed.isNotEmpty) {
          final mux = manifest.muxed.first;
          out.add(ResolvedAudioStream(
            url: mux.url.toString(),
            headers: headers,
            source: 'yt_explode_${tag}_mux',
            mimeHint: 'video/mp4',
            ytStreamInfo: mux,
            ytClient: _sharedYt,
          ));
        }
      } catch (e) {
        debugPrint('[YtAudioResolver] YoutubeExplode($tag) error for $cleanId: $e');
      }
    }

    // Race ANDROID_VR and IOS first (fast, no WatchPage HTML fetch required)
    await Future.wait([
      tryClient(
        YoutubeApiClient.androidVr,
        headers: const {'User-Agent': _androidVr156Ua},
        tag: 'vr',
      ),
      tryClient(
        YoutubeApiClient.ios,
        headers: const {'User-Agent': _iosUa},
        tag: 'ios',
      ),
    ]);

    if (out.isEmpty) {
      await tryClient(
        YoutubeApiClient.tv,
        headers: const {'User-Agent': _browserUa},
        tag: 'tv',
        requireWatchPage: true,
        timeout: const Duration(milliseconds: 6200),
      );
    }

    return out;
  }

  static Future<List<ResolvedAudioStream>> _resolveViaMirrorsParallel(
    String cleanId,
    AudioQuality quality,
  ) async {
    final futures = <Future<List<ResolvedAudioStream>>>[
      for (final m in _pipedMirrors) _fetchPipedSingle(m, cleanId, quality),
      for (final m in _invidiousMirrors) _fetchInvidiousSingle(m, cleanId, quality),
    ];

    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  static Future<List<ResolvedAudioStream>> _fetchPipedSingle(
    String mirror,
    String cleanId,
    AudioQuality quality,
  ) async {
    try {
      final base = Uri.parse(mirror);
      final resp = await http
          .get(base.resolve('/streams/$cleanId'), headers: const {'User-Agent': _browserUa})
          .timeout(const Duration(milliseconds: 3500));
      if (resp.statusCode != 200) return const [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final out = <ResolvedAudioStream>[];
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
            .where((a) => (a['mimeType']?.toString() ?? '').toLowerCase().contains('mp4'))
            .toList();
        final opus = audioList
            .where((a) => !(a['mimeType']?.toString() ?? '').toLowerCase().contains('mp4'))
            .toList();

        Map<String, dynamic>? pick(List<Map<String, dynamic>> pool) {
          if (pool.isEmpty) return null;
          if (quality == AudioQuality.saver96) return pool.first;
          if (quality == AudioQuality.standard160 && pool.length > 2) {
            return pool[pool.length ~/ 2];
          }
          return pool.last;
        }

        final bestM4a = pick(m4a);
        if (bestM4a != null) {
          final rawU = bestM4a['url']?.toString() ?? '';
          if (rawU.isNotEmpty) {
            out.add(ResolvedAudioStream(
              url: base.resolve(rawU).toString(),
              source: 'piped',
              mimeHint: bestM4a['mimeType']?.toString() ?? 'audio/mp4',
            ));
          }
        }
        final bestOpus = pick(opus);
        if (bestOpus != null) {
          final rawU = bestOpus['url']?.toString() ?? '';
          if (rawU.isNotEmpty) {
            out.add(ResolvedAudioStream(
              url: base.resolve(rawU).toString(),
              source: 'piped_webm',
              mimeHint: bestOpus['mimeType']?.toString() ?? 'audio/webm',
            ));
          }
        }
      }
      final hls = data['hls']?.toString() ?? '';
      if (hls.isNotEmpty) {
        out.add(ResolvedAudioStream(
          url: base.resolve(hls).toString(),
          isHls: true,
          source: 'piped_hls',
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ResolvedAudioStream>> _fetchInvidiousSingle(
    String mirror,
    String cleanId,
    AudioQuality quality,
  ) async {
    try {
      final base = Uri.parse(mirror);
      final resp = await http
          .get(
            base.resolve('/api/v1/videos/$cleanId'),
            headers: const {'User-Agent': _browserUa},
          )
          .timeout(const Duration(milliseconds: 3500));
      if (resp.statusCode != 200) return const [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final out = <ResolvedAudioStream>[];
      final adaptive = (data['adaptiveFormats'] as List? ?? [])
          .whereType<Map>()
          .where((f) => (f['type']?.toString() ?? '').toLowerCase().startsWith('audio/'))
          .toList();
      if (adaptive.isNotEmpty) {
        adaptive.sort((a, b) {
          final brA = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
          final brB = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
          return brA.compareTo(brB);
        });
        final m4a = adaptive
            .where((a) => (a['type']?.toString() ?? '').toLowerCase().contains('mp4'))
            .toList();
        final pool = m4a.isNotEmpty ? m4a : adaptive;
        final chosen = quality == AudioQuality.saver96 ? pool.first : pool.last;
        final rawU = chosen['url']?.toString() ?? '';
        if (rawU.isNotEmpty) {
          out.add(ResolvedAudioStream(
            url: base.resolve(rawU).toString(),
            source: 'invidious',
            mimeHint: chosen['type']?.toString(),
          ));
        }
        if (m4a.isNotEmpty && adaptive.last != chosen) {
          final altU = adaptive.last['url']?.toString() ?? '';
          if (altU.isNotEmpty) {
            out.add(ResolvedAudioStream(
              url: base.resolve(altU).toString(),
              source: 'invidious_webm',
              mimeHint: adaptive.last['type']?.toString(),
            ));
          }
        }
      }
      final hls = data['hlsUrl']?.toString() ?? '';
      if (hls.isNotEmpty) {
        out.add(ResolvedAudioStream(
          url: base.resolve(hls).toString(),
          isHls: true,
          source: 'invidious_hls',
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
