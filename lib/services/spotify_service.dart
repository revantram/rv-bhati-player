import '../models/online_song.dart';
import 'yt_music_service.dart';

class SpotifyTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String imageUrl;

  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.imageUrl,
  });
}

class SpotifyService {
  SpotifyService._();
  static final SpotifyService instance = SpotifyService._();

  final Map<String, List<OnlineSong>> _cachedPlaylists = {};

  static const List<Map<String, String>> spotifyPlaylists = [
    {
      'id': 'top_hits',
      'title': "Today's Top Hits",
      'subtitle': 'Most viral & played tracks worldwide',
      'icon': '🔥',
      'query': 'Top Global Hits 2025 Audio',
      'gradientStart': '0xFFFA2D48',
      'gradientEnd': '0xFFFF5E3A',
    },
    {
      'id': 'india_50',
      'title': 'Hot Hits Hindi',
      'subtitle': 'Bollywood chartbusters',
      'icon': '🇮🇳',
      'query': 'Hot Hits Hindi 2025 Audio',
      'gradientStart': '0xFFFF4B2B',
      'gradientEnd': '0xFFFF416C',
    },
    {
      'id': 'viral_50',
      'title': 'Viral Hits India',
      'subtitle': 'Trending reels & social media anthems',
      'icon': '🚀',
      'query': 'Viral Hits India Songs',
      'gradientStart': '0xFF8E2DE2',
      'gradientEnd': '0xFF4A00E0',
    },
    {
      'id': 'lofi_chill',
      'title': 'Lo-Fi Chill & Sleep',
      'subtitle': 'Soft beats, study vibes & peace',
      'icon': '🎧',
      'query': 'Lo-Fi Hindi Chill Beats',
      'gradientStart': '0xFF3A1C71',
      'gradientEnd': '0xFFD76D77',
    },
    {
      'id': 'punjabi_100',
      'title': 'Punjabi 101',
      'subtitle': 'Sidhu, Karan Aujla, Diljit & AP Dhillon',
      'icon': '⚡',
      'query': 'Punjabi Top Hits Audio',
      'gradientStart': '0xFFF7971E',
      'gradientEnd': '0xFFFFD200',
    },
    {
      'id': 'romantic_vibes',
      'title': 'Romantic Beats',
      'subtitle': 'Arijit, Shreya & timeless love tracks',
      'icon': '❤️',
      'query': 'Bollywood Romantic Hits Audio',
      'gradientStart': '0xFFED213A',
      'gradientEnd': '0xFF93291E',
    },
  ];

  /// Fetch playlist songs via BitMusic (YtMusicService)
  Future<List<OnlineSong>> getSpotifyPlaylist(String categoryId, {int limit = 30}) async {
    if (_cachedPlaylists.containsKey(categoryId)) {
      return _cachedPlaylists[categoryId]!;
    }

    final cat = spotifyPlaylists.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => spotifyPlaylists.first,
    );
    final query = cat['query'] ?? 'Top Hits Audio';

    final songs = await YtMusicService.instance.search(query);
    if (songs.isNotEmpty) {
      _cachedPlaylists[categoryId] = songs.take(limit).toList();
      return _cachedPlaylists[categoryId]!;
    }
    return const [];
  }

  /// Search via BitMusic
  Future<List<OnlineSong>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final songs = await YtMusicService.instance.search(clean);
    return songs.take(30).toList();
  }
}
