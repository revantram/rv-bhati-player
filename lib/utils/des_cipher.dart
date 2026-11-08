import 'dart:convert';
import 'dart:typed_data';

/// Pure Dart DES-ECB decryption for JioSaavn encrypted media URLs.
/// JioSaavn encrypts media URLs with DES in ECB mode using key: 38346591.
class DesCipher {
  DesCipher._();

  static const String _jioSaavnKey = '38346591';

  static const List<int> _ip = [
    58, 50, 42, 34, 26, 18, 10, 2,
    60, 52, 44, 36, 28, 20, 12, 4,
    62, 54, 46, 38, 30, 22, 14, 6,
    64, 56, 48, 40, 32, 24, 16, 8,
    57, 49, 41, 33, 25, 17, 9, 1,
    59, 51, 43, 35, 27, 19, 11, 3,
    61, 53, 45, 37, 29, 21, 13, 5,
    63, 55, 47, 39, 31, 23, 15, 7,
  ];

  static const List<int> _fp = [
    40, 8, 48, 16, 56, 24, 64, 32,
    39, 7, 47, 15, 55, 23, 63, 31,
    38, 6, 46, 14, 54, 22, 62, 30,
    37, 5, 45, 13, 53, 21, 61, 29,
    36, 4, 44, 12, 52, 20, 60, 28,
    35, 3, 43, 11, 51, 19, 59, 27,
    34, 2, 42, 10, 50, 18, 58, 26,
    33, 1, 41, 9, 49, 17, 57, 25,
  ];

  static const List<int> _pc1 = [
    57, 49, 41, 33, 25, 17, 9,
    1, 58, 50, 42, 34, 26, 18,
    10, 2, 59, 51, 43, 35, 27,
    19, 11, 3, 60, 52, 44, 36,
    63, 55, 47, 39, 31, 23, 15,
    7, 62, 54, 46, 38, 30, 22,
    14, 6, 61, 53, 45, 37, 29,
    21, 13, 5, 28, 20, 12, 4,
  ];

  static const List<int> _pc2 = [
    14, 17, 11, 24, 1, 5,
    3, 28, 15, 6, 21, 10,
    23, 19, 12, 4, 26, 8,
    16, 7, 27, 20, 13, 2,
    41, 52, 31, 37, 47, 55,
    30, 40, 51, 45, 33, 48,
    44, 49, 39, 56, 34, 53,
    46, 42, 50, 36, 29, 32,
  ];

  static const List<int> _shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

  static const List<int> _e = [
    32, 1, 2, 3, 4, 5,
    4, 5, 6, 7, 8, 9,
    8, 9, 10, 11, 12, 13,
    12, 13, 14, 15, 16, 17,
    16, 17, 18, 19, 20, 21,
    20, 21, 22, 23, 24, 25,
    24, 25, 26, 27, 28, 29,
    28, 29, 30, 31, 32, 1,
  ];

  static const List<List<int>> _sBoxes = [
    // S1
    [
      14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
      0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
      4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
      15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13,
    ],
    // S2
    [
      15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10,
      3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5,
      0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15,
      13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9,
    ],
    // S3
    [
      10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8,
      13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
      13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7,
      1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12,
    ],
    // S4
    [
      7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15,
      13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
      10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4,
      3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14,
    ],
    // S5
    [
      2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9,
      14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
      4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14,
      11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3,
    ],
    // S6
    [
      12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11,
      10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
      9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6,
      4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13,
    ],
    // S7
    [
      4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1,
      13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
      1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2,
      6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12,
    ],
    // S8
    [
      13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7,
      1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
      7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8,
      2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11,
    ],
  ];

  static const List<int> _p = [
    16, 7, 20, 21,
    29, 12, 28, 17,
    1, 15, 23, 26,
    5, 18, 31, 10,
    2, 8, 24, 14,
    32, 27, 3, 9,
    19, 13, 30, 6,
    22, 11, 4, 25,
  ];

  static List<int> _permute(List<int> bits, List<int> table) {
    return [for (final idx in table) bits[idx - 1]];
  }

  static List<int> _bytesToBits(List<int> bytes) {
    final res = <int>[];
    for (final b in bytes) {
      for (var bit = 7; bit >= 0; bit--) {
        res.add((b >> bit) & 1);
      }
    }
    return res;
  }

  static Uint8List _bitsToBytes(List<int> bits) {
    final count = bits.length ~/ 8;
    final res = Uint8List(count);
    for (var i = 0; i < count; i++) {
      var byte = 0;
      final start = i * 8;
      for (var j = 0; j < 8; j++) {
        byte = (byte << 1) | bits[start + j];
      }
      res[i] = byte;
    }
    return res;
  }

  static List<List<int>> _generateSubkeys(List<int> keyBytes) {
    final bits = _bytesToBits(keyBytes);
    final permutedKey = _permute(bits, _pc1);
    var c = permutedKey.sublist(0, 28);
    var d = permutedKey.sublist(28);
    final subkeys = <List<int>>[];

    for (final shift in _shifts) {
      c = [...c.sublist(shift), ...c.sublist(0, shift)];
      d = [...d.sublist(shift), ...d.sublist(0, shift)];
      subkeys.add(_permute([...c, ...d], _pc2));
    }
    return subkeys;
  }

  static List<int> _feistel(List<int> r, List<int> subkey) {
    final expanded = _permute(r, _e);
    final xored = [for (var i = 0; i < 48; i++) expanded[i] ^ subkey[i]];
    final sOutput = <int>[];

    for (var i = 0; i < 8; i++) {
      final start = i * 6;
      final row = (xored[start] << 1) | xored[start + 5];
      final col = (xored[start + 1] << 3) |
          (xored[start + 2] << 2) |
          (xored[start + 3] << 1) |
          xored[start + 4];
      final val = _sBoxes[i][row * 16 + col];
      for (var bit = 3; bit >= 0; bit--) {
        sOutput.add((val >> bit) & 1);
      }
    }
    return _permute(sOutput, _p);
  }

  static Uint8List _decryptBlock(Uint8List blockBytes, List<List<int>> subkeys) {
    final bits = _bytesToBits(blockBytes);
    final ip = _permute(bits, _ip);
    var l = ip.sublist(0, 32);
    var r = ip.sublist(32);

    for (var i = subkeys.length - 1; i >= 0; i--) {
      final f = _feistel(r, subkeys[i]);
      final newR = [for (var j = 0; j < 32; j++) l[j] ^ f[j]];
      l = r;
      r = newR;
    }

    final preFp = [...r, ...l];
    return _bitsToBytes(_permute(preFp, _fp));
  }

  /// Decrypts a base64 encoded JioSaavn encrypted_media_url into a playable URL.
  /// Automatically upgrades bitrate from _96.mp4 to _320.mp4 (or requested quality).
  static String? decryptMediaUrl(String encryptedBase64, {int bitrate = 320}) {
    try {
      final clean = encryptedBase64.trim().replaceAll('\n', '').replaceAll('\r', '');
      final cipherBytes = Uint8List.fromList(base64.decode(clean));
      final keyBytes = utf8.encode(_jioSaavnKey);
      final subkeys = _generateSubkeys(keyBytes);

      final decryptedBytes = <int>[];
      for (var i = 0; i < cipherBytes.length; i += 8) {
        final block = Uint8List.sublistView(cipherBytes, i, i + 8);
        decryptedBytes.addAll(_decryptBlock(block, subkeys));
      }

      // PKCS5 unpadding
      if (decryptedBytes.isNotEmpty) {
        final pad = decryptedBytes.last;
        if (pad > 0 && pad <= 8) {
          decryptedBytes.removeRange(decryptedBytes.length - pad, decryptedBytes.length);
        }
      }

      var url = utf8.decode(decryptedBytes).trim();

      // Ensure proper media bitrate suffix (e.g. _320.mp4, _160.mp4, _96.mp4)
      if (bitrate == 320) {
        url = url.replaceFirst(RegExp(r'_(96|160)\.mp4'), '_320.mp4');
      } else if (bitrate == 160) {
        url = url.replaceFirst(RegExp(r'_(96|320)\.mp4'), '_160.mp4');
      } else if (bitrate == 96) {
        url = url.replaceFirst(RegExp(r'_(160|320)\.mp4'), '_96.mp4');
      }

      return url;
    } catch (_) {
      return null;
    }
  }
}
