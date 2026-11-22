import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_state.dart';

/// Extracts vibrant and ambient dominant colors from cover artwork (local bytes or HTTP URL)
/// with safe caching and guaranteed text/glass contrast.
class ArtworkPaletteService {
  ArtworkPaletteService._();
  static final ArtworkPaletteService instance = ArtworkPaletteService._();

  final Map<String, Color> _colorCache = {};

  /// Extract dominant vibrant color from image bytes or URL and update AppState
  Future<Color?> extractAndApply({Uint8List? bytes, String? imageUrl, String? cacheKey}) async {
    final key = cacheKey ?? imageUrl ?? (bytes != null ? bytes.length.toString() : null);
    if (key != null && _colorCache.containsKey(key)) {
      final cached = _colorCache[key]!;
      AppState.instance.setDynamicAccentColor(cached);
      return cached;
    }

    try {
      Uint8List? imageBytes = bytes;
      if (imageBytes == null && imageUrl != null && imageUrl.isNotEmpty) {
        final uri = Uri.tryParse(imageUrl);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          final res = await http.get(uri).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            imageBytes = res.bodyBytes;
          }
        }
      }

      if (imageBytes == null || imageBytes.isEmpty) return null;

      final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 28, targetHeight: 28);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();

      if (byteData == null) return null;
      final raw = byteData.buffer.asUint8List();

      int bestR = 250, bestG = 45, bestB = 72; // default vibrant crimson
      double maxScore = -1;

      for (int i = 0; i < raw.length; i += 4) {
        final r = raw[i];
        final g = raw[i + 1];
        final b = raw[i + 2];
        final a = raw[i + 3];
        if (a < 128) continue;

        final maxVal = math.max(r, math.max(g, b));
        final minVal = math.min(r, math.min(g, b));
        final delta = maxVal - minVal;

        // Skip muddy grays, near-blacks, and pure whites
        if (delta < 22 || maxVal < 36 || minVal > 225) continue;

        final saturation = delta / maxVal;
        final brightness = maxVal / 255.0;
        final score = saturation * 1.6 + (1.0 - (brightness - 0.60).abs());

        if (score > maxScore) {
          maxScore = score;
          bestR = r;
          bestG = g;
          bestB = b;
        }
      }

      if (maxScore > 0) {
        final vibrant = Color.fromARGB(255, bestR, bestG, bestB);
        if (key != null) {
          _colorCache[key] = vibrant;
          if (_colorCache.length > 80) {
            _colorCache.remove(_colorCache.keys.first);
          }
        }
        AppState.instance.setDynamicAccentColor(vibrant);
        return vibrant;
      }
    } catch (_) {}
    return null;
  }
}
