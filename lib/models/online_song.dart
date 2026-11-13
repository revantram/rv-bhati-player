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
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static String upgradeImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll('http://', 'https://')
        .replaceAll('w120-h120', 'w544-h544')
        .replaceAll('w60-h60', 'w544-h544')
        .replaceAll('=s120', '=s544')
        .replaceAll('=s60', '=s544');
  }

  String getStreamUrlForBitrate(int kbps) => streamUrl;

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
      title: unescapeHtml(map['title']?.toString() ?? ''),
      artist: unescapeHtml(map['artist']?.toString() ?? 'Unknown Artist'),
      album: unescapeHtml(map['album']?.toString() ?? 'BitMusic'),
      year: map['year']?.toString(),
      duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 0),
      imageUrl: upgradeImageUrl(map['imageUrl']?.toString()),
      encryptedMediaUrl: map['encryptedMediaUrl']?.toString() ?? '',
      streamUrl: map['streamUrl']?.toString() ?? '',
    );
  }

  OnlineSong copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? year,
    Duration? duration,
    String? imageUrl,
    String? streamUrl,
  }) {
    return OnlineSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      imageUrl: imageUrl ?? this.imageUrl,
      encryptedMediaUrl: encryptedMediaUrl,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineSong && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
