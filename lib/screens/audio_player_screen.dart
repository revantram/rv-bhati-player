import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'car_mode_screen.dart';

import '../models/media_file.dart';
import '../models/online_song.dart';
import '../models/playlist_item.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/equalizer_service.dart';
import '../services/saavn_api_service.dart';
import '../utils/id3_parser.dart';
import '../utils/lrc_parser.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/art_box.dart';
import '../widgets/artist_songs_sheet.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/glass_bars.dart';
import '../widgets/glass_seek_bar.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/wave_visualizer.dart';

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

    _loadLyricsForIndex(_ac.player.currentIndex ?? widget.startIndex);

    _ac.player.currentIndexStream.listen((idx) {
      if (idx != null && mounted) {
        _loadLyricsForIndex(idx);
        final track = _getCurrentTrack(idx);
        if (track != null) {
          AppState.instance.markPlayed(track.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _lyricsScroll.dispose();
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
          album: song.album.isNotEmpty ? song.album : 'JioSaavn Online',
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

  Future<void> _loadLyricsForIndex(int idx) async {
    final track = _getCurrentTrack(idx);
    if (track == null) return;

    setState(() {
      _loadingLyrics = true;
      _lyrics = [];
      _plainLyrics = null;
    });

    if (track.isOnline) {
      try {
        final lyrics = await SaavnApiService.instance.getLyrics(track.id);
        if (lyrics != null && lyrics.isNotEmpty && mounted) {
          setState(() {
            _plainLyrics = lyrics;
            _loadingLyrics = false;
          });
          return;
        }
      } catch (_) {}
    } else if (track.mediaFile != null) {
      try {
        final path = track.mediaFile!.path;
        final dot = path.lastIndexOf('.');
        if (dot > 0) {
          final base = path.substring(0, dot);
          final candidates = ['$base.lrc', '$base.LRC', '$base.txt'];
          for (final p in candidates) {
            if (File(p).existsSync()) {
              final parsed = await LrcParser.parseFile(p);
              if (parsed.isNotEmpty && mounted) {
                setState(() {
                  _lyrics = parsed;
                  _loadingLyrics = false;
                });
                return;
              }
            }
          }
        }
      } catch (_) {}
    }

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
        return Scaffold(
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
                    // Ambient reflection
                    Positioned.fill(child: _BlurredArt(track: track)),
                    SafeArea(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final artSize = math.max(
                            140.0,
                            math.min(box.maxWidth - 70, box.maxHeight * 0.35),
                          );
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          child: Column(
                            children: [
                              GlassTopBar(
                                title: 'Now Playing',
                                leading: LiquidGlassButton(
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  size: 44,
                                  iconSize: 28,
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                                actions: [
                                  // Equalizer button
                                  LiquidGlassButton(
                                    icon: Icons.tune_rounded,
                                    size: 44,
                                    iconSize: 20,
                                    tint: EqualizerService.instance.isEnabled ? appAccent : null,
                                    onTap: () => EqualizerSheet.show(context),
                                  ),
                                  const SizedBox(width: 6),
                                  // Sleep timer with countdown badge
                                  LiquidGlassButton(
                                    icon: Icons.bedtime_rounded,
                                    size: 44,
                                    iconSize: 20,
                                    tint: AppState.instance.isSleepTimerActive ? appAccent : null,
                                    label: AppState.instance.isSleepTimerActive
                                        ? AppState.instance.sleepTimerFormatted
                                        : null,
                                    onTap: () => SleepTimerSheet.show(context),
                                  ),
                                  const SizedBox(width: 6),
                                  // Add to Custom Playlist
                                  LiquidGlassButton(
                                    icon: Icons.playlist_add_rounded,
                                    size: 44,
                                    iconSize: 22,
                                    onTap: () => _addToPlaylist(context, track),
                                  ),
                                  const SizedBox(width: 6),
                                  // Queue
                                  LiquidGlassButton(
                                    icon: Icons.queue_music_rounded,
                                    size: 44,
                                    iconSize: 20,
                                    onTap: _openQueueSheet,
                                  ),
                                  const SizedBox(width: 6),
                                  // Car Mode / Driving Mode
                                  LiquidGlassButton(
                                    icon: Icons.directions_car_rounded,
                                    size: 44,
                                    iconSize: 20,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CarModeScreen()),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Center Art or Lyrics view
                              if (_showLyrics)
                                SizedBox(
                                  height: artSize + 30,
                                  child: _buildLyricsView(player),
                                )
                              else
                                GestureDetector(
                                  onTap: () => setState(() => _showLyrics = !_showLyrics),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    child: LiquidGlassContainer(
                                      key: ValueKey('${track.id}_${track.imageUrl}_${track.embeddedArt != null}'),
                                      borderRadius: BorderRadius.circular(40),
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: artSize,
                                        height: artSize,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(30),
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
                              const SizedBox(height: 20),
                              // Title and heart row
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
                                            color: AppState.instance.textColor,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w700,
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
                                                    color: AppState.instance.accentColor,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 11,
                                                color: AppState.instance.accentColor.withValues(alpha: 0.8),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  LiquidGlassButton(
                                    icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    size: 44,
                                    iconSize: 24,
                                    tint: isFav ? const Color(0xFFFF2A85) : null,
                                    onTap: () => AppState.instance.toggleFavorite(track.id),
                                  ),
                                  const SizedBox(width: 6),
                                  LiquidGlassButton(
                                    icon: Icons.lyrics_rounded,
                                    size: 44,
                                    iconSize: 22,
                                    tint: _showLyrics ? appAccent : null,
                                    onTap: () => setState(() => _showLyrics = !_showLyrics),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              StreamBuilder<PlayerState>(
                                stream: player.playerStateStream,
                                builder: (context, s) {
                                  final playing = (s.data?.playing ?? false) &&
                                      s.data?.processingState != ProcessingState.completed;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      StreamBuilder<Duration?>(
                                        stream: player.durationStream,
                                        builder: (context, d) => StreamBuilder<Duration>(
                                          stream: player.positionStream,
                                          builder: (context, p) => GlassSeekBar(
                                            position: p.data ?? Duration.zero,
                                            duration: d.data ?? track.duration,
                                            accent: appAccent,
                                            isPlaying: playing,
                                            onSeek: player.seek,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      WaveVisualizer(
                                        barCount: 16,
                                        height: 24,
                                        barWidth: 3,
                                        spacing: 3.5,
                                        isPlaying: playing,
                                        color: appAccent,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              // Shuffle, Repeat, Speed & playback controls
                              StreamBuilder<PlayerState>(
                                stream: player.playerStateStream,
                                builder: (context, s) {
                                  final st = s.data;
                                  final playing = (st?.playing ?? false) &&
                                      st?.processingState != ProcessingState.completed;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Secondary controls: Shuffle, Repeat, Speed
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          StreamBuilder<bool>(
                                            stream: player.shuffleModeEnabledStream,
                                            builder: (context, shuf) {
                                              final isShuf = shuf.data ?? false;
                                              return LiquidGlassButton(
                                                icon: Icons.shuffle_rounded,
                                                size: 40,
                                                iconSize: 20,
                                                tint: isShuf ? appAccent : null,
                                                onTap: () => player.setShuffleModeEnabled(!isShuf),
                                              );
                                            },
                                          ),
                                          StreamBuilder<LoopMode>(
                                            stream: player.loopModeStream,
                                            builder: (context, loop) {
                                              final mode = loop.data ?? LoopMode.off;
                                              final icon = mode == LoopMode.one
                                                  ? Icons.repeat_one_rounded
                                                  : Icons.repeat_rounded;
                                              return LiquidGlassButton(
                                                icon: icon,
                                                size: 40,
                                                iconSize: 20,
                                                tint: mode != LoopMode.off ? appAccent : null,
                                                onTap: () => _cycleRepeat(mode),
                                              );
                                            },
                                          ),
                                          StreamBuilder<double>(
                                            stream: player.speedStream,
                                            builder: (context, spd) {
                                              final speed = spd.data ?? 1.0;
                                              return LiquidGlassButton(
                                                label: '${speed}x',
                                                size: 40,
                                                onTap: _openSpeedSheet,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      // Main Controls
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LiquidGlassButton(
                                              icon: Icons.skip_previous_rounded,
                                              size: 52,
                                              onTap: _previous,
                                            ),
                                            const SizedBox(width: 10),
                                            LiquidGlassButton(
                                              icon: Icons.replay_10_rounded,
                                              size: 56,
                                              onTap: () => _seekBy(-10),
                                            ),
                                            const SizedBox(width: 12),
                                            LiquidGlassButton(
                                              icon: playing
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 78,
                                              iconSize: 40,
                                              tint: appAccent,
                                              onTap: () => _toggle(st),
                                            ),
                                            const SizedBox(width: 12),
                                            LiquidGlassButton(
                                              icon: Icons.forward_10_rounded,
                                              size: 56,
                                              onTap: () => _seekBy(10),
                                            ),
                                            const SizedBox(width: 10),
                                            LiquidGlassButton(
                                              icon: Icons.skip_next_rounded,
                                              size: 52,
                                              onTap: player.hasNext ? player.seekToNext : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
            },
          ),
        );
      },
    );
  }

  int? _lastActiveLyricIdx;

  void _checkAndScrollLyric(int activeIdx) {
    if (activeIdx < 0 || activeIdx == _lastActiveLyricIdx) return;
    _lastActiveLyricIdx = activeIdx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lyricsScroll.hasClients) return;
      final target = (activeIdx * 48.0) - 100.0;
      final clamped = target.clamp(0.0, _lyricsScroll.position.maxScrollExtent);
      _lyricsScroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
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
              time: Duration(milliseconds: i * intervalMs),
              text: rawLines[i],
            ),
        ];
      }
    }

    // Synced scrolling lyrics
    if (displayLyrics.isNotEmpty) {
      return StreamBuilder<Duration>(
        stream: player.positionStream,
        builder: (context, posSnap) {
          final currentPos = posSnap.data ?? Duration.zero;
          final activeIdx = LrcParser.findActiveIndex(displayLyrics, currentPos);
          _checkAndScrollLyric(activeIdx);

          return LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ListView.builder(
              controller: _lyricsScroll,
              physics: const BouncingScrollPhysics(),
              itemCount: displayLyrics.length,
              itemBuilder: (context, i) {
                final line = displayLyrics[i];
                final isActive = i == activeIdx;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    player.seek(line.time);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: isActive ? 21 : 15,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                        color: isActive
                            ? AppState.instance.accentColor
                            : (AppState.instance.isLight
                                ? AppState.instance.secondaryTextColor.withValues(alpha: 0.55)
                                : Colors.white38),
                        shadows: isActive
                            ? [
                                Shadow(
                                  color: AppState.instance.accentColor.withValues(alpha: 0.65),
                                  blurRadius: 12,
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
}

class _BlurredArt extends StatelessWidget {
  const _BlurredArt({required this.track});
  final _AudioTrackInfo track;

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(track.title);
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dynamic album art ambient background
        if (track.imageUrl != null && track.imageUrl!.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.32,
              child: Image.network(
                track.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          )
        else if (track.embeddedArt != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.32,
              child: Image.memory(
                track.embeddedArt!,
                fit: BoxFit.cover,
              ),
            ),
          ),

        // 2. Heavy frosted backdrop blur for liquid ambient glow
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 55, sigmaY: 55),
            child: Container(
              color: Colors.black.withValues(alpha: 0.38),
            ),
          ),
        ),

        // 3. Radial ambient accent halo
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.25),
              radius: 0.95,
              colors: [
                accent.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
