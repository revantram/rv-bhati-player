import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'car_mode_screen.dart';

import '../models/media_file.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/equalizer_service.dart';
import '../services/lyrics_service.dart';
import '../services/settings_service.dart';
import '../utils/format.dart';
import '../utils/lrc_parser.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/art_box.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/sleep_timer_sheet.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({
    super.key,
    this.queue = const [],
    this.startIndex = 0,
    this.startPlayback = true,
  });

  final List<MediaFile> queue;
  final int startIndex;
  final bool startPlayback;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioTrackInfo {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Uint8List? embeddedArt;
  final String? imageUrl;
  final bool isOnline;
  final MediaFile? mediaFile;
  final OnlineSong? onlineSong;
  final PlaylistItem? playlistItem;

  const _AudioTrackInfo({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.embeddedArt,
    this.imageUrl,
    required this.isOnline,
    this.mediaFile,
    this.onlineSong,
    this.playlistItem,
  });
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final _ac = AudioController.instance;
  AppState get app => AppState.instance;

  bool _showLyrics = false;
  List<LrcLine> _lyrics = [];
  String? _plainLyrics;
  bool _loadingLyrics = false;
  final ScrollController _lyricsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.startPlayback && widget.queue.isNotEmpty) {
      _ac.playQueue(widget.queue, widget.startIndex).catchError((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Can't play this file")),
          );
        }
      });
    }

    final initialIdx = _ac.player.currentIndex ?? widget.startIndex;
    _handleTrackChange(initialIdx);

    _ac.player.currentIndexStream.listen((idx) {
      if (idx != null && mounted) {
        _handleTrackChange(idx);
      }
    });
  }

  @override
  void dispose() {
    _lyricsScroll.dispose();
    _userLyricsTimer?.cancel();
    super.dispose();
  }

  _AudioTrackInfo? _getCurrentTrack(int idx) {
    if (_ac.isPlayingHybrid) {
      final hq = _ac.hybridQueue;
      if (idx >= 0 && idx < hq.length) {
        final item = hq[idx];
        return _AudioTrackInfo(
          id: item.id,
          title: item.title,
          artist: item.artist,
          album: item.album ?? 'Custom Playlist',
          duration: item.duration,
          imageUrl: item.imageUrl,
          isOnline: item.isOnline,
          playlistItem: item,
        );
      }
    } else if (_ac.isPlayingOnline) {
      final oq = _ac.onlineQueue;
      if (idx >= 0 && idx < oq.length) {
        final song = oq[idx];
        return _AudioTrackInfo(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album.isNotEmpty ? song.album : 'BitMusic Stream',
          duration: song.duration,
          imageUrl: song.imageUrl,
          isOnline: true,
          onlineSong: song,
        );
      }
    } else {
      final lq = _ac.queue;
      if (idx >= 0 && idx < lq.length) {
        final file = lq[idx];
        return _AudioTrackInfo(
          id: file.id,
          title: file.displayTitle,
          artist: file.artist ?? 'Local Music',
          album: file.album ?? 'RV Bhati Player',
          duration: file.duration,
          embeddedArt: file.embeddedArt,
          isOnline: false,
          mediaFile: file,
        );
      }
    }
    return null;
  }

  void _handleTrackChange(int idx) {
    _loadLyricsForIndex(idx);
    final track = _getCurrentTrack(idx);
    if (track != null) {
      AppState.instance.markPlayed(track.id);
      _extractAndApplyThemeColor(track);
    }
  }

  Future<void> _extractAndApplyThemeColor(_AudioTrackInfo track) async {
    try {
      Uint8List? imageBytes;
      if (track.embeddedArt != null && track.embeddedArt!.isNotEmpty) {
        imageBytes = track.embeddedArt;
      } else if (track.isOnline && track.imageUrl != null && track.imageUrl!.isNotEmpty) {
        final res = await http.get(Uri.parse(track.imageUrl!)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          imageBytes = res.bodyBytes;
        }
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 24, targetHeight: 24);
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          int bestR = 124, bestG = 108, bestB = 255;
          double maxScore = -1;

          for (int i = 0; i < bytes.length; i += 4) {
            final r = bytes[i];
            final g = bytes[i + 1];
            final b = bytes[i + 2];
            final a = bytes[i + 3];
            if (a < 128) continue;

            final maxVal = math.max(r, math.max(g, b));
            final minVal = math.min(r, math.min(g, b));
            final delta = maxVal - minVal;
            if (delta < 20 || maxVal < 40 || minVal > 220) continue;

            final saturation = delta / maxVal;
            final brightness = maxVal / 255.0;
            final score = saturation * 1.5 + (1.0 - (brightness - 0.65).abs());
            if (score > maxScore) {
              maxScore = score;
              bestR = r;
              bestG = g;
              bestB = b;
            }
          }

          if (maxScore > 0 && mounted) {
            final vibrant = Color.fromARGB(255, bestR, bestG, bestB);
            AppState.instance.setDynamicAccentColor(vibrant);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLyricsForIndex(int idx) async {
    final track = _getCurrentTrack(idx);
    if (track == null) return;

    _userLyricsTimer?.cancel();
    setState(() {
      _loadingLyrics = true;
      _lyrics = [];
      _plainLyrics = null;
      _lastActiveLyricIdx = null;
      _lyricKeys.clear();
      _userInteractingWithLyrics = false;
    });

    try {
      final result = await LyricsService.instance.fetchLyrics(
        id: track.id,
        title: track.title,
        artist: track.artist,
        duration: track.duration,
        localPath: track.mediaFile?.path,
      );

      if (mounted) {
        setState(() {
          _lyrics = result.synced;
          _plainLyrics = result.plain;
          _loadingLyrics = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _lyrics = [];
        _plainLyrics = null;
        _loadingLyrics = false;
      });
    }
  }

  void _toggle(PlayerState? st) {
    final p = _ac.player;
    if (st?.processingState == ProcessingState.completed) {
      p.seek(Duration.zero, index: 0);
      p.play();
    } else if (p.playing) {
      p.pause();
    } else {
      p.play();
    }
  }

  void _seekBy(int seconds) {
    final p = _ac.player;
    final dur = p.duration ?? Duration.zero;
    var t = p.position + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (dur > Duration.zero && t > dur) t = dur;
    p.seek(t);
  }

  void _previous() {
    final p = _ac.player;
    if (p.position > const Duration(seconds: 3) || !p.hasPrevious) {
      p.seek(Duration.zero);
    } else {
      p.seekToPrevious();
    }
  }

  void _cycleRepeat(LoopMode current) {
    final next = current == LoopMode.off
        ? LoopMode.all
        : (current == LoopMode.all ? LoopMode.one : LoopMode.off);
    _ac.player.setLoopMode(next);
  }

  void _openMoreOptionsSheet(BuildContext context, _AudioTrackInfo track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: AppState.instance,
          builder: (context, _) {
            final app = AppState.instance;
            final isLight = app.isLight;
            final textColor = app.textColor;
            final secondaryTextColor = app.secondaryTextColor;
            final appAccent = app.accentColor;

            return LiquidGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              blur: 30,
              opacity: 0.16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.black26 : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: track.imageUrl != null && track.imageUrl!.isNotEmpty
                              ? Image.network(
                                  track.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => ArtBox(
                                    seed: track.title,
                                    radius: 0,
                                    iconSize: 22,
                                  ),
                                )
                              : (track.embeddedArt != null
                                  ? Image.memory(track.embeddedArt!, fit: BoxFit.cover)
                                  : ArtBox(
                                      seed: track.title,
                                      radius: 0,
                                      iconSize: 22,
                                    )),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white12,
                    height: 1,
                  ),
                  const SizedBox(height: 8),
                  _sheetActionTile(
                    icon: Icons.bedtime_rounded,
                    title: app.tr('sleep_timer'),
                    subtitle: app.isSleepTimerActive
                        ? app.sleepTimerFormatted
                        : null,
                    accentColor: appAccent,
                    isActive: app.isSleepTimerActive,
                    onTap: () {
                      Navigator.pop(context);
                      SleepTimerSheet.show(context);
                    },
                  ),
                  _sheetActionTile(
                    icon: Icons.tune_rounded,
                    title: app.tr('equalizer'),
                    subtitle: EqualizerService.instance.isEnabled ? 'Active' : 'Off',
                    accentColor: appAccent,
                    isActive: EqualizerService.instance.isEnabled,
                    onTap: () {
                      Navigator.pop(context);
                      EqualizerSheet.show(context);
                    },
                  ),
                  _sheetActionTile(
                    icon: Icons.directions_car_rounded,
                    title: 'Driving Mode',
                    subtitle: 'Clean car dashboard',
                    accentColor: appAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CarModeScreen()),
                      );
                    },
                  ),
                  _sheetActionTile(
                    icon: Icons.playlist_add_rounded,
                    title: 'Add to Playlist',
                    accentColor: appAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _addToPlaylist(context, track);
                    },
                  ),
                  _sheetActionTile(
                    icon: Icons.queue_music_rounded,
                    title: app.tr('queue'),
                    accentColor: appAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _openQueueSheet();
                    },
                  ),
                  _sheetActionTile(
                    icon: Icons.speed_rounded,
                    title: app.tr('speed'),
                    subtitle: '${_ac.player.speed}x',
                    accentColor: appAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _openSpeedSheet();
                    },
                  ),
                  if (track.artist.isNotEmpty && track.artist != 'Unknown')
                    _sheetActionTile(
                      icon: Icons.person_search_rounded,
                      title: 'Songs by ${track.artist}',
                      accentColor: appAccent,
                      onTap: () {
                        Navigator.pop(context);
                        ArtistSongsSheet.show(context, artistName: track.artist);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color accentColor,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    final isLight = AppState.instance.isLight;
    final textColor = AppState.instance.textColor;
    final secondaryTextColor = AppState.instance.secondaryTextColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isActive
                ? accentColor.withValues(alpha: isLight ? 0.12 : 0.18)
                : (isLight
                    ? Colors.black.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? accentColor.withValues(alpha: isLight ? 0.35 : 0.45)
                  : (isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.10)),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive
                    ? accentColor
                    : (isLight ? const Color(0xFF334155) : Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? accentColor
                        : (isLight ? const Color(0xFF0F172A) : Colors.white),
                  ),
                ),
              ),
              if (subtitle != null) ...[
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? accentColor
                        : (isLight
                            ? const Color(0xFF64748B)
                            : Colors.white.withValues(alpha: 0.6)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isLight ? Colors.black26 : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollCtrl) {
            final currentIdx = _ac.player.currentIndex ?? 0;
            final count = _ac.isPlayingHybrid
                ? _ac.hybridQueue.length
                : (_ac.isPlayingOnline ? _ac.onlineQueue.length : _ac.queue.length);

            return LiquidGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppState.instance.isLight ? Colors.black12 : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppState.instance.tr('queue'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppState.instance.textColor,
                        ),
                      ),
                      Text(
                        '$count tracks',
                        style: TextStyle(fontSize: 13, color: AppState.instance.secondaryTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: count,
                      itemBuilder: (context, i) {
                        final track = _getCurrentTrack(i);
                        if (track == null) return const SizedBox.shrink();
                        final isPlaying = i == currentIdx;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PressableScale(
                            onTap: () {
                              _ac.player.seek(Duration.zero, index: i);
                              Navigator.pop(context);
                            },
                            child: LiquidGlassContainer(
                              borderRadius: BorderRadius.circular(18),
                              padding: const EdgeInsets.all(8),
                              borderColor: isPlaying ? AppState.instance.accentColor : Colors.transparent,
                              tint: isPlaying ? AppState.instance.accentColor.withValues(alpha: 0.2) : null,
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: track.imageUrl != null && track.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              track.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => ArtBox(
                                                seed: track.title,
                                                radius: 0,
                                                iconSize: 20,
                                              ),
                                            )
                                          : (track.embeddedArt != null
                                              ? Image.memory(track.embeddedArt!, fit: BoxFit.cover)
                                              : ArtBox(
                                                  seed: track.title,
                                                  radius: 0,
                                                  iconSize: 20,
                                                )),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                                            color: isPlaying ? AppState.instance.accentColor : AppState.instance.textColor,
                                          ),
                                        ),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            if (track.artist.isNotEmpty && track.artist != 'Unknown') {
                                              Navigator.pop(context);
                                              ArtistSongsSheet.show(context, artistName: track.artist);
                                            }
                                          },
                                          child: Text(
                                            track.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: AppState.instance.accentColor, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isPlaying)
                                    Icon(Icons.equalizer_rounded, color: AppState.instance.accentColor, size: 22),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentSpeed = _ac.player.speed;
        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppState.instance.isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppState.instance.tr('speed'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppState.instance.textColor,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                  final active = (currentSpeed - s).abs() < 0.01;
                  return PressableScale(
                    onTap: () {
                      _ac.player.setSpeed(s);
                      Navigator.pop(context);
                    },
                    child: LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderColor: active
                          ? AppState.instance.accentColor
                          : (AppState.instance.isLight
                              ? Colors.black.withValues(alpha: 0.1)
                              : Colors.white12),
                      tint: active ? AppState.instance.accentColor.withValues(alpha: 0.25) : null,
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppState.instance.accentColor : AppState.instance.textColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addToPlaylist(BuildContext context, _AudioTrackInfo track) {
    if (track.playlistItem != null) {
      AddToPlaylistDialog.showForItem(context, track.playlistItem!);
    } else if (track.onlineSong != null) {
      AddToPlaylistDialog.showForOnline(context, track.onlineSong!);
    } else if (track.mediaFile != null) {
      AddToPlaylistDialog.showForMedia(context, track.mediaFile!);
    } else {
      final item = PlaylistItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        isOnline: track.isOnline,
        imageUrl: track.imageUrl,
      );
      AddToPlaylistDialog.showForItem(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _ac.player;
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final appAccent = AppState.instance.accentColor;
        return PopScope(
          canPop: true,
          child: Scaffold(
            body: StreamBuilder<int?>(
            stream: player.currentIndexStream,
            builder: (context, snap) {
              final idx = (snap.data ?? widget.startIndex);
              final track = _getCurrentTrack(idx);
              if (track == null) {
                return Stack(
                  children: [
                    Positioned.fill(child: LiquidBackground(accent: appAccent)),
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ],
                );
              }

              final isFav = AppState.instance.isFavorite(track.id);
              final isLight = app.isLight;

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                    Navigator.of(context).maybePop();
                  }
                },
                child: Stack(
                  children: [
                    Positioned.fill(child: LiquidBackground(accent: appAccent)),
                    // 1. DYNAMIC COLOR-MATCHED BLURRED BACKGROUND
                    Positioned.fill(child: _BlurredArt(track: track)),
                    SafeArea(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final artSize = math.max(
                            150.0,
                            math.min(box.maxWidth - 56, box.maxHeight * 0.38),
                          );
                          return StreamBuilder<PlayerState>(
                            stream: player.playerStateStream,
                            builder: (context, playerStateSnap) {
                              final st = playerStateSnap.data;
                              final isPlaying = (st?.playing ?? false) &&
                                  st?.processingState != ProcessingState.completed;

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                                child: Column(
                                  children: [
                                    // 3. MINIMAL TOP BAR
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Left: Studio down-chevron icon
                                        LiquidGlassButton(
                                          icon: Icons.keyboard_arrow_down_rounded,
                                          size: 44,
                                          iconSize: 28,
                                          onTap: () => Navigator.of(context).maybePop(),
                                        ),
                                        // Center: BitChord 'Now Playing' pill badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: app.surfaceColor,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: app.cardBorderColor,
                                              width: 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.graphic_eq_rounded, size: 14, color: appAccent),
                                              const SizedBox(width: 6),
                                              Text(
                                                track.isOnline ? 'BITMUSIC • NOW PLAYING' : 'NOW PLAYING',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  letterSpacing: 1.1,
                                                  fontWeight: FontWeight.w700,
                                                  color: app.textColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right: Single glass Three-Dot action button
                                        LiquidGlassButton(
                                          icon: Icons.more_horiz_rounded,
                                          size: 44,
                                          iconSize: 22,
                                          onTap: () => _openMoreOptionsSheet(context, track),
                                        ),
                                      ],
                                    ),
                                    const Spacer(flex: 1),

                                    // 2. FLOATING 3D VINYL / ALBUM CARD OR SYNCHRONIZED LYRICS
                                    if (_showLyrics)
                                      SizedBox(
                                        height: artSize + 20,
                                        child: _buildLyricsView(player),
                                      )
                                    else
                                      AnimatedScale(
                                        scale: isPlaying ? 1.0 : 0.92,
                                        duration: const Duration(milliseconds: 400),
                                        curve: Curves.easeOutBack,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => _showLyrics = !_showLyrics);
                                            if (_showLyrics) {
                                              _lastActiveLyricIdx = null;
                                              _userInteractingWithLyrics = false;
                                            }
                                          },
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 350),
                                            child: Container(
                                              key: ValueKey('${track.id}_${track.imageUrl}_${track.embeddedArt != null}'),
                                              width: artSize,
                                              height: artSize,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(28),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.22),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: appAccent.withValues(alpha: isPlaying ? 0.45 : 0.22),
                                                    blurRadius: 35,
                                                    spreadRadius: -5,
                                                    offset: const Offset(0, 16),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.40),
                                                    blurRadius: 22,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(26),
                                                child: track.imageUrl != null && track.imageUrl!.isNotEmpty
                                                    ? Image.network(
                                                        track.imageUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => ArtBox(
                                                          seed: track.title,
                                                          radius: 0,
                                                          iconSize: artSize * 0.35,
                                                        ),
                                                      )
                                                    : (track.embeddedArt != null
                                                        ? Image.memory(track.embeddedArt!, fit: BoxFit.cover)
                                                        : ArtBox(
                                                            seed: track.title,
                                                            radius: 0,
                                                            iconSize: artSize * 0.35,
                                                          )),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    const Spacer(flex: 1),

                                    // 4. MODERN TRACK INFO & SEEKBAR
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () {
                                                  if (track.artist.isNotEmpty && track.artist != 'Unknown') {
                                                    ArtistSongsSheet.show(context, artistName: track.artist);
                                                  }
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        track.artist,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: isLight ? const Color(0xFF475569) : Colors.white.withValues(alpha: 0.72),
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    if (track.artist.isNotEmpty && track.artist != 'Unknown') ...[
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.arrow_forward_ios_rounded,
                                                        size: 11,
                                                        color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.5),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (track.isOnline) ...[
                                          ListenableBuilder(
                                            listenable: DownloadService.instance,
                                            builder: (context, _) {
                                              final isDl = DownloadService.instance.isDownloaded(track.id);
                                              final isDownloading = DownloadService.instance.isDownloading(track.id);

                                              return LiquidGlassButton(
                                                icon: isDownloading
                                                    ? Icons.hourglass_top_rounded
                                                    : (isDl ? Icons.download_done_rounded : Icons.download_rounded),
                                                size: 44,
                                                iconSize: 22,
                                                tint: isDl ? Colors.green : null,
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  final os = AudioController.instance.currentOnlineSong;
                                                  if (os != null && !isDl && !isDownloading) {
                                                    DownloadService.instance.downloadSong(os);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Downloading "${os.title}"...')),
                                                    );
                                                  } else if (isDl) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('"${track.title}" is saved for offline play.')),
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        LiquidGlassButton(
                                          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          size: 44,
                                          iconSize: 24,
                                          tint: isFav ? const Color(0xFFFF2D55) : null,
                                          onTap: () {
                                            final item = PlaylistItem(
                                              id: track.id,
                                              title: track.title,
                                              artist: track.artist,
                                              album: track.album,
                                              duration: track.duration,
                                              isOnline: track.isOnline,
                                              localPath: track.mediaFile?.path,
                                              streamUrl: track.isOnline ? (AudioController.instance.currentOnlineSong?.streamUrl) : null,
                                              imageUrl: track.imageUrl,
                                            );
                                            AppState.instance.toggleFavorite(track.id, item: item);
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Smooth Interactive Capsule Slider
                                    StreamBuilder<Duration?>(
                                      stream: player.durationStream,
                                      builder: (context, d) => StreamBuilder<Duration>(
                                        stream: player.positionStream,
                                        builder: (context, p) => _IOSCapsuleSlider(
                                          position: p.data ?? Duration.zero,
                                          duration: d.data ?? track.duration,
                                          accent: appAccent,
                                          onSeek: player.seek,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Secondary Controls: Replay 10s, Speed, Lyrics, Queue, Forward 10s
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        PressableScale(
                                          onTap: () => _seekBy(-10),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.replay_10_rounded,
                                              size: 24,
                                              color: app.secondaryTextColor,
                                            ),
                                          ),
                                        ),
                                        StreamBuilder<double>(
                                          stream: player.speedStream,
                                          builder: (context, spd) {
                                            final speed = spd.data ?? 1.0;
                                            return PressableScale(
                                              onTap: _openSpeedSheet,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: app.surfaceColorSecondary,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: app.cardBorderColor),
                                                ),
                                                child: Text(
                                                  '${speed}x',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: app.textColor,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        PressableScale(
                                          onTap: () {
                                            setState(() => _showLyrics = !_showLyrics);
                                            if (_showLyrics) {
                                              _lastActiveLyricIdx = null;
                                              _userInteractingWithLyrics = false;
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.lyrics_rounded,
                                              size: 24,
                                              color: _showLyrics ? appAccent : (isLight ? app.secondaryTextColor : Colors.white.withValues(alpha: 0.65)),
                                            ),
                                          ),
                                        ),
                                        PressableScale(
                                          onTap: _openQueueSheet,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.queue_music_rounded,
                                              size: 24,
                                              color: app.secondaryTextColor,
                                            ),
                                          ),
                                        ),
                                        PressableScale(
                                          onTap: () => _seekBy(10),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.forward_10_rounded,
                                              size: 24,
                                              color: app.secondaryTextColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // 5. BITCHORD STUDIO CONTROL DOCK
                                    LiquidGlassContainer(
                                      borderRadius: BorderRadius.circular(36),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      blur: SettingsService.instance.playerThemeStyle == PlayerThemeStyle.frosted ? 26 : 0,
                                      opacity: SettingsService.instance.playerThemeStyle == PlayerThemeStyle.frosted ? 0.14 : 0.85,
                                      tint: SettingsService.instance.playerThemeStyle == PlayerThemeStyle.minimal
                                          ? app.backgroundColor
                                          : app.surfaceColor,
                                      borderColor: app.cardBorderColor,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Shuffle
                                          StreamBuilder<bool>(
                                            stream: player.shuffleModeEnabledStream,
                                            builder: (context, shuf) {
                                              final isShuf = shuf.data ?? false;
                                              return PressableScale(
                                                onTap: () => player.setShuffleModeEnabled(!isShuf),
                                                child: Container(
                                                  padding: const EdgeInsets.all(10),
                                                  child: Icon(
                                                    Icons.shuffle_rounded,
                                                    size: 22,
                                                    color: isShuf ? appAccent : app.secondaryTextColor,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),

                                          // Previous
                                          PressableScale(
                                            onTap: _previous,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.skip_previous_rounded,
                                                size: 34,
                                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                              ),
                                            ),
                                          ),

                                          // Center Play/Pause button: 68px vibrant accent gradient disc
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              HapticFeedback.mediumImpact();
                                              _toggle(st);
                                            },
                                            child: Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    appAccent,
                                                    appAccent.withValues(alpha: 0.85),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: appAccent.withValues(alpha: 0.55),
                                                    blurRadius: 22,
                                                    spreadRadius: 2,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                  size: 36,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Next
                                          PressableScale(
                                            onTap: player.hasNext ? player.seekToNext : null,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.skip_next_rounded,
                                                size: 34,
                                                color: player.hasNext ? app.textColor : app.secondaryTextColor.withValues(alpha: 0.35),
                                              ),
                                            ),
                                          ),

                                          // Repeat
                                          StreamBuilder<LoopMode>(
                                            stream: player.loopModeStream,
                                            builder: (context, loop) {
                                              final mode = loop.data ?? LoopMode.off;
                                              final isLoop = mode != LoopMode.off;
                                              return PressableScale(
                                                onTap: () => _cycleRepeat(mode),
                                                child: Container(
                                                  padding: const EdgeInsets.all(10),
                                                  child: Icon(
                                                    mode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                                    size: 22,
                                                    color: isLoop ? appAccent : app.secondaryTextColor,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
    );
  }

  final Map<int, GlobalKey> _lyricKeys = {};
  int? _lastActiveLyricIdx;
  bool _userInteractingWithLyrics = false;
  Timer? _userLyricsTimer;

  void _checkAndScrollLyric(int activeIdx, {bool force = false}) {
    if (activeIdx < 0) return;
    if (!force && activeIdx == _lastActiveLyricIdx) return;
    _lastActiveLyricIdx = activeIdx;

    if (!force && _userInteractingWithLyrics) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lyricsScroll.hasClients) return;
      _scrollToLyric(activeIdx);
    });
  }

  void _scrollToLyric(int activeIdx) {
    final key = _lyricKeys[activeIdx];
    final itemContext = key?.currentContext;
    if (itemContext != null && itemContext.mounted) {
      Scrollable.ensureVisible(
        itemContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      final target = activeIdx * 52.0;
      final clamped = target.clamp(0.0, _lyricsScroll.position.maxScrollExtent);
      _lyricsScroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildLyricsView(AudioPlayer player) {
    if (_loadingLyrics) {
      return Center(
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(20),
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Convert plain lyrics to synced lines if standard LRC is empty
    List<LrcLine> displayLyrics = _lyrics;
    if (displayLyrics.isEmpty && _plainLyrics != null && _plainLyrics!.isNotEmpty) {
      final rawLines = _plainLyrics!.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (rawLines.isNotEmpty) {
        final totalDurationMs = math.max(player.duration?.inMilliseconds ?? 180000, 30000);
        final intervalMs = (totalDurationMs / rawLines.length).round();
        displayLyrics = [
          for (int i = 0; i < rawLines.length; i++)
            LrcLine(
              Duration(milliseconds: i * intervalMs),
              rawLines[i],
            ),
        ];
      }
    }

    // Synced scrolling lyrics with exact centering
    if (displayLyrics.isNotEmpty) {
      return StreamBuilder<Duration>(
        stream: player.positionStream,
        builder: (context, posSnap) {
          final currentPos = posSnap.data ?? Duration.zero;
          final activeIdx = LrcParser.findActiveIndex(displayLyrics, currentPos);
          _checkAndScrollLyric(activeIdx);

          return LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final vHeight = constraints.maxHeight;
                // Vertical padding allows any line (including first and last) to reach the exact vertical center
                final verticalPadding = math.max(40.0, (vHeight / 2) - 30.0);

                return NotificationListener<ScrollNotification>(
                  onNotification: (notif) {
                    if (notif is UserScrollNotification) {
                      if (notif.direction != ScrollDirection.idle) {
                        _userInteractingWithLyrics = true;
                        _userLyricsTimer?.cancel();
                        _userLyricsTimer = Timer(const Duration(seconds: 3), () {
                          if (mounted) {
                            setState(() {
                              _userInteractingWithLyrics = false;
                            });
                            if (_lastActiveLyricIdx != null) {
                              _scrollToLyric(_lastActiveLyricIdx!);
                            }
                          }
                        });
                      }
                    }
                    return false;
                  },
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.12, 0.88, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: SingleChildScrollView(
                      controller: _lyricsScroll,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        vertical: verticalPadding,
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < displayLyrics.length; i++)
                            _buildLyricLine(
                              displayLyrics[i],
                              i,
                              isActive: i == activeIdx,
                              player: player,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    return Center(
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, color: AppState.instance.secondaryTextColor, size: 36),
            const SizedBox(height: 8),
            Text(
              AppState.instance.tr('no_lyrics'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppState.instance.secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricLine(
    LrcLine line,
    int index, {
    required bool isActive,
    required AudioPlayer player,
  }) {
    final key = _lyricKeys.putIfAbsent(index, () => GlobalKey());
    final isLight = AppState.instance.isLight;
    final accent = AppState.instance.accentColor;

    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        player.seek(line.time);
        _userInteractingWithLyrics = false;
        _userLyricsTimer?.cancel();
        _checkAndScrollLyric(index, force: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(
          vertical: isActive ? 8 : 6,
          horizontal: 10,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: isActive ? 22 : 16,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            height: 1.35,
            color: isActive
                ? accent
                : (isLight
                    ? AppState.instance.textColor.withValues(alpha: 0.38)
                    : Colors.white.withValues(alpha: 0.35)),
            shadows: isActive
                ? [
                    Shadow(
                      color: accent.withValues(alpha: 0.70),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Text(
            line.text,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// 4. Modern interactive iOS capsule seek bar
class _IOSCapsuleSlider extends StatefulWidget {
  const _IOSCapsuleSlider({
    required this.position,
    required this.duration,
    required this.accent,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final Color accent;
  final ValueChanged<Duration> onSeek;

  @override
  State<_IOSCapsuleSlider> createState() => _IOSCapsuleSliderState();
}

class _IOSCapsuleSliderState extends State<_IOSCapsuleSlider> {
  double? _dragFraction;

  void _onSeekFromOffset(double localDx, double width) {
    if (width <= 0) return;
    final frac = (localDx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = frac);
  }

  void _finalizeSeek(double width) {
    if (_dragFraction != null) {
      final totalMs = math.max(widget.duration.inMilliseconds, 1);
      final targetMs = (_dragFraction! * totalMs).round();
      widget.onSeek(Duration(milliseconds: targetMs));
      HapticFeedback.selectionClick();
      setState(() => _dragFraction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final totalMs = math.max(widget.duration.inMilliseconds, 1);
    final curMs = widget.position.inMilliseconds.clamp(0, totalMs);
    final currentFraction = _dragFraction ?? (curMs / totalMs).clamp(0.0, 1.0);
    final isDragging = _dragFraction != null;

    final displayPos = _dragFraction != null
        ? Duration(milliseconds: (_dragFraction! * totalMs).round())
        : widget.position;
    final remaining = widget.duration > displayPos
        ? widget.duration - displayPos
        : Duration.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragDown: (d) => _onSeekFromOffset(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _onSeekFromOffset(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => _finalizeSeek(width),
              onHorizontalDragCancel: () => setState(() => _dragFraction = null),
              onTapUp: (d) {
                _onSeekFromOffset(d.localPosition.dx, width);
                _finalizeSeek(width);
              },
              child: Container(
                height: 28,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Base background capsule
                    Container(
                      height: 6,
                      width: width,
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Active glowing progress track
                    Container(
                      height: 6,
                      width: width * currentFraction,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [
                            widget.accent,
                            widget.accent.withValues(alpha: 0.85),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                    // Sleek thumb
                    Positioned(
                      left: (width * currentFraction - (isDragging ? 9 : 7))
                          .clamp(0.0, width - (isDragging ? 18 : 14)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isDragging ? 18 : 14,
                        height: isDragging ? 18 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: widget.accent.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatDuration(displayPos),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: app.secondaryTextColor,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '-${formatDuration(remaining)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: app.secondaryTextColor,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 1. Dynamic BitChord ambient mesh background supporting Frosted / Vibrant / Minimal OLED
class _BlurredArt extends StatelessWidget {
  const _BlurredArt({required this.track});
  final _AudioTrackInfo track;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final settings = SettingsService.instance;
    final isLight = app.isLight;
    final accent = app.accentColor;
    final style = settings.playerThemeStyle;

    final topAlpha = style == PlayerThemeStyle.minimal
        ? 0.04
        : (style == PlayerThemeStyle.vibrant
            ? (isLight ? 0.22 : 0.42)
            : (isLight ? 0.14 : 0.26));
    final bottomAlpha = style == PlayerThemeStyle.minimal
        ? 0.02
        : (style == PlayerThemeStyle.vibrant
            ? (isLight ? 0.16 : 0.28)
            : (isLight ? 0.09 : 0.18));

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: app.backgroundColor),
        if (style == PlayerThemeStyle.frosted &&
            settings.glassBlurEnabled &&
            track.imageUrl != null &&
            track.imageUrl!.isNotEmpty)
          Opacity(
            opacity: isLight ? 0.14 : 0.20,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 42, sigmaY: 42),
              child: Image.network(
                track.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          )
        else if (style == PlayerThemeStyle.frosted &&
            settings.glassBlurEnabled &&
            track.embeddedArt != null)
          Opacity(
            opacity: isLight ? 0.14 : 0.20,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 42, sigmaY: 42),
              child: Image.memory(track.embeddedArt!, fit: BoxFit.cover),
            ),
          ),
        Positioned(
          top: -100,
          left: -50,
          right: -50,
          height: 380,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.0,
                colors: [
                  accent.withValues(alpha: topAlpha),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -60,
          width: 320,
          height: 320,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: bottomAlpha),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
