import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/yt_music_service.dart';
import '../utils/format.dart';
import 'add_to_playlist_dialog.dart';
import 'liquid_glass_container.dart';

class ArtistSongsSheet extends StatefulWidget {
  final String artistName;
  final String? avatarUrl;
  final String? subtitle;
  final BitArtist? artist;

  const ArtistSongsSheet({
    super.key,
    required this.artistName,
    this.avatarUrl,
    this.subtitle,
    this.artist,
  });

  static Future<void> show(
    BuildContext context, {
    required String artistName,
    String? avatarUrl,
    String? subtitle,
    BitArtist? artist,
  }) {
    final cleanArtistName = artistName.contains(',')
        ? artistName.split(',').first.trim()
        : (artistName.contains('&') ? artistName.split('&').first.trim() : artistName.trim());

    final matched = artist ?? YtMusicService.findCuratedArtist(cleanArtistName);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArtistSongsSheet(
        artistName: cleanArtistName.isNotEmpty ? cleanArtistName : artistName,
        avatarUrl: avatarUrl ?? matched?.avatarUrl,
        subtitle: subtitle ?? matched?.subtitle,
        artist: matched,
      ),
    );
  }

  @override
  State<ArtistSongsSheet> createState() => _ArtistSongsSheetState();
}

class _ArtistSongsSheetState extends State<ArtistSongsSheet> {
  bool _loading = true;
  List<OnlineSong> _songs = [];
  String? _fallbackAvatarUrl;

  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final songs = await YtMusicService.instance.getArtistSongs(widget.artistName, limit: 40);
    if (mounted) {
      setState(() {
        _songs = songs;
        _loading = false;
        if (widget.avatarUrl == null && songs.isNotEmpty) {
          _fallbackAvatarUrl = songs.first.imageUrl;
        }
      });
    }
  }

  void _playSong(int index) {
    if (_songs.isEmpty) return;
    AudioController.instance.playOnlineQueue(_songs, index);
  }

  void _playAll({bool shuffle = false}) {
    if (_songs.isEmpty) return;
    final list = List<OnlineSong>.from(_songs);
    if (shuffle) list.shuffle();
    AudioController.instance.playOnlineQueue(list, 0);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;

    final avatar = widget.avatarUrl ?? _fallbackAvatarUrl;

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: BoxDecoration(
        color: app.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: app.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isLight ? Colors.black12 : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header Bar with Back/Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_downward_rounded, color: textColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Artist Hub / कलाकार संग्रह',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (_songs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${_songs.length} Tracks',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Artist Profile Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatar != null && avatar.isNotEmpty
                        ? Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackAvatar(accent),
                          )
                        : _buildFallbackAvatar(accent),
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: const Color(0xFF00D2FF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle ?? 'Top verified hits & discography',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Play All & Shuffle Buttons
          if (!_loading && _songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: PressableScale(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _playAll(shuffle: false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Play All / सभी बजाएं',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PressableScale(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _playAll(shuffle: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shuffle_rounded, color: textColor, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Shuffle',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
          Divider(color: isLight ? Colors.black12 : Colors.white12, height: 1),

          // Songs List
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: accent),
                        const SizedBox(height: 14),
                        Text(
                          'Loading ${widget.artistName} hits...',
                          style: TextStyle(color: secondaryTextColor, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : _songs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_off_rounded, size: 48, color: secondaryTextColor.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No songs found for this artist',
                                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Check your network connection or try searching another singer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: secondaryTextColor, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                        itemCount: _songs.length,
                        itemBuilder: (context, i) {
                          final song = _songs[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ArtistSongTile(
                              song: song,
                              onTap: () => _playSong(i),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          widget.artistName.isNotEmpty ? widget.artistName[0].toUpperCase() : 'A',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent),
        ),
      ),
    );
  }
}

class _ArtistSongTile extends StatelessWidget {
  final OnlineSong song;
  final VoidCallback onTap;

  const _ArtistSongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isFav = app.isFavorite(song.id);

    final currentOnline = AudioController.instance.currentOnlineSong;
    final isCurrent = currentOnline?.id == song.id;

    return PressableScale(
      hapticOnDown: false,
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(8),
        borderColor: isCurrent ? app.accentColor.withValues(alpha: 0.6) : null,
        tint: isCurrent ? app.accentColor.withValues(alpha: 0.12) : null,
        blur: 0,
        glow: false,
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      song.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white10,
                        child: Icon(Icons.music_note_rounded,
                            color: app.secondaryTextColor, size: 24),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Icon(Icons.equalizer_rounded,
                              color: app.accentColor, size: 24),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Song Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? app.accentColor : app.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: app.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: app.isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '320 kbps',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF00D2FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDuration(song.duration),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: app.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Download button
            ListenableBuilder(
              listenable: DownloadService.instance,
              builder: (context, _) {
                final isDl = DownloadService.instance.isDownloaded(song.id);
                final isDownloading = DownloadService.instance.isDownloading(song.id);

                return IconButton(
                  icon: isDownloading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: app.accentColor,
                          ),
                        )
                      : Icon(
                          isDl ? Icons.download_done_rounded : Icons.download_rounded,
                          color: isDl ? Colors.green : app.secondaryTextColor.withValues(alpha: 0.6),
                          size: 19,
                        ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (!isDl && !isDownloading) {
                      DownloadService.instance.downloadSong(song);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloading "${song.title}"...'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else if (isDl) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${song.title}" is saved offline.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),

            // Favourite button
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFFF2A85) : app.secondaryTextColor.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () => app.toggleFavorite(song.id, item: PlaylistItem.fromOnlineSong(song)),
            ),

            // Three-dot menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: app.secondaryTextColor, size: 18),
              color: app.isLight ? Colors.white : const Color(0xFF14192B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'play_now') {
                  onTap();
                } else if (val == 'download') {
                  DownloadService.instance.downloadSong(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading "${song.title}"...')),
                  );
                } else if (val == 'play_next') {
                  AudioController.instance.playOnlineNext(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Playing next: ${song.title}')),
                  );
                } else if (val == 'add_queue') {
                  AudioController.instance.addOnlineToQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to queue: ${song.title}')),
                  );
                } else if (val == 'add_playlist') {
                  AddToPlaylistDialog.showForOnline(context, song);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'play_now',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Play Now', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Download Offline', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_play_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Play Next', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Add to Queue', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: app.secondaryTextColor, size: 18),
                      const SizedBox(width: 10),
                      Text('Add to Playlist', style: TextStyle(color: app.textColor)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
