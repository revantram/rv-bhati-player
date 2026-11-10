import '../services/settings_service.dart';
import '../utils/des_cipher.dart';

class OnlineSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? year;
  final Duration duration;
  final String imageUrl;
  final String encryptedMediaUrl;
  final String streamUrl;

  const OnlineSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.year,
    required this.duration,
    required this.imageUrl,
    this.encryptedMediaUrl = '',
    required this.streamUrl,
  });

  static String unescapeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static String upgradeImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'https://c.saavncdn.com/default_song_500x500.jpg';
    }
    // Convert 150x150 or 50x50 to 500x500 for crisp high-resolution covers
    return raw
        .replaceAll('150x150', '500x500')
        .replaceAll('50x50', '500x500')
        .replaceAll('http://', 'https://');
  }

  static OnlineSong? fromJson(Map<String, dynamic> json, {int? bitrate}) {
    try {
      final id = json['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final rawTitle = json['title']?.toString() ?? '';
      final title = unescapeHtml(rawTitle);

      final moreInfo = json['more_info'] is Map<String, dynamic>
          ? json['more_info'] as Map<String, dynamic>
          : <String, dynamic>{};

      // Extract artist from multiple JioSaavn schema sources
      String artist = '';
      if (moreInfo['artistMap'] is Map && moreInfo['artistMap']['primary_artists'] is List) {
        final artists = (moreInfo['artistMap']['primary_artists'] as List)
            .map((a) => a is Map ? a['name']?.toString() ?? '' : '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (artists.isNotEmpty) {
          artist = artists.join(', ');
        }
      }

      if (artist.isEmpty && moreInfo['music'] != null) {
        artist = moreInfo['music'].toString();
      }

      if (artist.isEmpty && json['subtitle'] != null) {
        artist = json['subtitle'].toString();
      }

      if (artist.isEmpty && json['header_desc'] != null) {
        artist = json['header_desc'].toString();
      }

      artist = unescapeHtml(artist.isEmpty ? 'Unknown Artist' : artist);

      final rawAlbum = (moreInfo['album'] ?? json['album'] ?? '').toString();
      final album = unescapeHtml(rawAlbum.isNotEmpty ? rawAlbum : title);

      final year = json['year']?.toString();

      // Parse duration
      var durationSeconds = 0;
      final rawDur = moreInfo['duration'] ?? json['duration'];
      if (rawDur is int) {
        durationSeconds = rawDur;
      } else if (rawDur != null) {
        durationSeconds = int.tryParse(rawDur.toString()) ?? 0;
      }

      final imageUrl = upgradeImageUrl(json['image']?.toString());

      final enc = (moreInfo['encrypted_media_url'] ?? json['encrypted_media_url'] ?? '').toString();
      if (enc.isEmpty) return null;

      final targetBitrate = bitrate ?? SettingsService.instance.audioQuality.kbps;
      final streamUrl = DesCipher.decryptMediaUrl(enc, bitrate: targetBitrate);
      if (streamUrl == null || streamUrl.isEmpty) return null;

      return OnlineSong(
        id: id,
        title: title,
        artist: artist,
        album: album,
        year: year,
        duration: Duration(seconds: durationSeconds),
        imageUrl: imageUrl,
        encryptedMediaUrl: enc,
        streamUrl: streamUrl,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'year': year,
        'duration': duration.inSeconds,
        'imageUrl': imageUrl,
        'encryptedMediaUrl': encryptedMediaUrl,
        'streamUrl': streamUrl,
      };

  factory OnlineSong.fromMap(Map<String, dynamic> map) {
    return OnlineSong(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      artist: map['artist']?.toString() ?? '',
      album: map['album']?.toString() ?? '',
      year: map['year']?.toString(),
      duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 0),
      imageUrl: map['imageUrl']?.toString() ?? '',
      encryptedMediaUrl: map['encryptedMediaUrl']?.toString() ?? '',
      streamUrl: map['streamUrl']?.toString() ?? '',
    );
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineSong && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
