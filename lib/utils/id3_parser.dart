import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class AudioMetadata {
  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArt,
  });

  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? albumArt;
}

class Id3Parser {
  static final Map<String, AudioMetadata> _cache = {};

  static Future<AudioMetadata?> parse(String filePath) async {
    if (_cache.containsKey(filePath)) {
      return _cache[filePath];
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final raf = await file.open(mode: FileMode.read);
      try {
        final length = await raf.length();
        if (length < 128) return null;

        // Try ID3v2 first from beginning
        final header = await raf.read(10);
        if (header.length == 10 &&
            header[0] == 0x49 &&
            header[1] == 0x44 &&
            header[2] == 0x33) {
          final version = header[3];
          final tagSize = _synchsafeToInt(header.sublist(6, 10));

          // Read up to 8MB or tagSize, whichever is smaller
          final readBytes = tagSize.clamp(0, 8 * 1024 * 1024);
          final tagData = await raf.read(readBytes);

          final meta = _parseId3v2(version, tagData);
          if (meta != null) {
            _cache[filePath] = meta;
            return meta;
          }
        }

        // Fallback: Check ID3v1 at the end
        if (length >= 128) {
          await raf.setPosition(length - 128);
          final v1 = await raf.read(128);
          if (v1.length == 128 &&
              v1[0] == 0x54 &&
              v1[1] == 0x41 &&
              v1[2] == 0x47) {
            final title = _cleanString(latin1.decode(v1.sublist(3, 33)));
            final artist = _cleanString(latin1.decode(v1.sublist(33, 63)));
            final album = _cleanString(latin1.decode(v1.sublist(63, 93)));
            final meta = AudioMetadata(
              title: title.isNotEmpty ? title : null,
              artist: artist.isNotEmpty ? artist : null,
              album: album.isNotEmpty ? album : null,
            );
            _cache[filePath] = meta;
            return meta;
          }
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}

    return null;
  }

  static int _synchsafeToInt(Uint8List b) {
    return (b[0] << 21) | (b[1] << 14) | (b[2] << 7) | b[3];
  }

  static AudioMetadata? _parseId3v2(int version, Uint8List data) {
    String? title;
    String? artist;
    String? album;
    Uint8List? albumArt;

    int offset = 0;
    while (offset + 10 <= data.length) {
      final frameId = String.fromCharCodes(data.sublist(offset, offset + 4));
      if (frameId.codeUnits.any((c) => c == 0 || c > 127)) break;

      final frameSize = version == 4
          ? _synchsafeToInt(data.sublist(offset + 4, offset + 8))
          : ((data[offset + 4] << 24) |
              (data[offset + 5] << 16) |
              (data[offset + 6] << 8) |
              data[offset + 7]);

      offset += 10;
      if (frameSize <= 0 || offset + frameSize > data.length) break;

      final frameData = data.sublist(offset, offset + frameSize);
      offset += frameSize;

      if (frameId == 'TIT2') {
        title = _decodeTextFrame(frameData);
      } else if (frameId == 'TPE1') {
        artist = _decodeTextFrame(frameData);
      } else if (frameId == 'TALB') {
        album = _decodeTextFrame(frameData);
      } else if (frameId == 'APIC' && albumArt == null) {
        albumArt = _decodeApicFrame(frameData);
      }
    }

    if (title != null || artist != null || album != null || albumArt != null) {
      return AudioMetadata(
        title: title,
        artist: artist,
        album: album,
        albumArt: albumArt,
      );
    }
    return null;
  }

  static String? _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return null;
    final encoding = data[0];
    final bytes = data.sublist(1);
    try {
      if (encoding == 0) {
        return _cleanString(latin1.decode(bytes));
      } else if (encoding == 1 || encoding == 2) {
        // UTF-16 with or without BOM
        return _cleanString(_decodeUtf16(bytes));
      } else if (encoding == 3) {
        return _cleanString(utf8.decode(bytes, allowMalformed: true));
      }
    } catch (_) {}
    return null;
  }

  static String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) return '';
    bool littleEndian = true;
    int start = 0;
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      littleEndian = true;
      start = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      littleEndian = false;
      start = 2;
    }
    final chars = <int>[];
    for (int i = start; i + 1 < bytes.length; i += 2) {
      final code = littleEndian
          ? (bytes[i] | (bytes[i + 1] << 8))
          : ((bytes[i] << 8) | bytes[i + 1]);
      if (code == 0) break;
      chars.add(code);
    }
    return String.fromCharCodes(chars);
  }

  static Uint8List? _decodeApicFrame(Uint8List data) {
    if (data.length < 10) return null;
    final encoding = data[0];
    int offset = 1;

    // MIME type (ASCII null-terminated)
    while (offset < data.length && data[offset] != 0) {
      offset++;
    }
    offset++; // skip null terminator
    if (offset >= data.length) return null;

    // Picture type (1 byte)
    offset++;
    if (offset >= data.length) return null;

    // Description (null-terminated string according to encoding)
    if (encoding == 0 || encoding == 3) {
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      offset++; // skip null
    } else {
      // UTF-16 null terminator is 0x00 0x00
      while (offset + 1 < data.length &&
          !(data[offset] == 0 && data[offset + 1] == 0)) {
        offset += 2;
      }
      offset += 2;
    }

    if (offset < data.length) {
      return data.sublist(offset);
    }
    return null;
  }

  static String _cleanString(String s) {
    return s.replaceAll('\u0000', '').trim();
  }
}
