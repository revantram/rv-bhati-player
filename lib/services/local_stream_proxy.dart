import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class _ProxiedTarget {
  final String url;
  final Map<String, String> headers;
  const _ProxiedTarget(this.url, this.headers);
}

/// Lightweight local loopback HTTP proxy on 127.0.0.1 for ExoPlayer / just_audio.
/// Eliminates IPv4/IPv6 mismatches, header stripping across redirects, and HTTP 403
/// "(0) Source error" when ExoPlayer fetches googlevideo.com streams directly.
class LocalStreamProxy {
  LocalStreamProxy._();
  static final LocalStreamProxy instance = LocalStreamProxy._();

  HttpServer? _server;
  int _port = 0;
  int _counter = 0;
  final Map<String, _ProxiedTarget> _targets = {};
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..autoUncompress = false;

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handleRequest, onError: (e) {
      debugPrint('[LocalStreamProxy] server error: $e');
    });
    debugPrint('[LocalStreamProxy] listening on 127.0.0.1:$_port');
  }

  /// Registers a remote audio stream and returns a local `http://127.0.0.1:<port>/stream/<id>.m4a` URL.
  Future<String> register(String url, {Map<String, String>? headers}) async {
    await _ensureStarted();
    if (_targets.length > 40) {
      final oldestKeys = _targets.keys.take(_targets.length - 30).toList();
      for (final k in oldestKeys) {
        _targets.remove(k);
      }
    }
    final id = '${++_counter}_${DateTime.now().millisecondsSinceEpoch}';
    _targets[id] = _ProxiedTarget(url, headers ?? const {});
    return 'http://127.0.0.1:$_port/stream/$id.m4a';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final segments = req.uri.pathSegments;
    if (segments.length < 2 || segments.first != 'stream') {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    final rawId = segments[1].replaceFirst(RegExp(r'\.(m4a|mp3|webm|aac)$'), '');
    final target = _targets[rawId];
    if (target == null) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    StreamSubscription<List<int>>? sub;
    try {
      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      final upstreamResp = await _openFollowingRedirects(
        method: req.method,
        url: target.url,
        baseHeaders: target.headers,
        rangeHeader: rangeHeader,
      );

      req.response.statusCode = upstreamResp.statusCode;

      final contentType = upstreamResp.headers.value(HttpHeaders.contentTypeHeader);
      req.response.headers.set(
        HttpHeaders.contentTypeHeader,
        (contentType != null && contentType.isNotEmpty) ? contentType : 'audio/mp4',
      );

      final contentLength = upstreamResp.contentLength;
      if (contentLength >= 0) {
        req.response.contentLength = contentLength;
      }

      final contentRange = upstreamResp.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null) {
        req.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
      }

      req.response.headers.set(
        HttpHeaders.acceptRangesHeader,
        upstreamResp.headers.value(HttpHeaders.acceptRangesHeader) ?? 'bytes',
      );

      if (req.method.toUpperCase() == 'HEAD') {
        await upstreamResp.drain<void>();
        await req.response.close();
        return;
      }

      final completer = Completer<void>();
      sub = upstreamResp.listen(
        (chunk) {
          try {
            req.response.add(chunk);
          } catch (_) {
            sub?.cancel();
            if (!completer.isCompleted) completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
      await req.response.close();
    } catch (e) {
      debugPrint('[LocalStreamProxy] upstream error: $e');
      await sub?.cancel();
      try {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<HttpClientResponse> _openFollowingRedirects({
    required String method,
    required String url,
    required Map<String, String> baseHeaders,
    String? rangeHeader,
    int maxRedirects = 5,
  }) async {
    var currentUri = Uri.parse(url);
    for (int hop = 0; hop <= maxRedirects; hop++) {
      final outReq = await _client.openUrl(
        method.toUpperCase() == 'HEAD' ? 'HEAD' : 'GET',
        currentUri,
      );
      outReq.followRedirects = false;
      baseHeaders.forEach((k, v) => outReq.headers.set(k, v));
      outReq.headers.set(HttpHeaders.acceptHeader, '*/*');
      if (rangeHeader != null && rangeHeader.isNotEmpty) {
        outReq.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      }

      final resp = await outReq.close().timeout(const Duration(seconds: 12));
      if (resp.isRedirect ||
          resp.statusCode == 301 ||
          resp.statusCode == 302 ||
          resp.statusCode == 303 ||
          resp.statusCode == 307 ||
          resp.statusCode == 308) {
        final loc = resp.headers.value(HttpHeaders.locationHeader);
        await resp.drain<void>();
        if (loc == null || loc.isEmpty) return resp;
        currentUri = currentUri.resolve(loc);
        continue;
      }
      return resp;
    }
    throw Exception('Too many redirects');
  }
}
