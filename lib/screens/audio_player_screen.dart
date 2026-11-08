import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../utils/id3_parser.dart';
import '../utils/lrc_parser.dart';
import '../widgets/art_box.dart';
import '../widgets/glass_bars.dart';
import '../widgets/glass_seek_bar.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({
    super.key,
    required this.queue,
    required this.startIndex,
    this.startPlayback = true,
  });

  final List<MediaFile> queue;
  final int startIndex;
  final bool startPlayback;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final _ac = AudioController.instance;

  bool _showLyrics = false;
  List<LrcLine> _lyrics = [];
  String? _lyricsFile;
  final ScrollController _lyricsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.startPlayback) {
      _ac.playQueue(widget.queue, widget.startIndex).catchError((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Can't play this file")),
          );
        }
      });
    }

    _loadLyricsForIndex(widget.startIndex);

    _ac.player.currentIndexStream.listen((idx) {
      if (idx != null && mounted) {
        _loadLyricsForIndex(idx);
        if (idx >= 0 && idx < _ac.queue.length) {
          AppState.instance.markPlayed(_ac.queue[idx].id);
        }
      }
    });
  }

  @override
  void dispose() {
    _lyricsScroll.dispose();
    super.dispose();
  }

  Future<void> _loadLyricsForIndex(int idx) async {
    final queue = _ac.queue;
    if (idx < 0 || idx >= queue.length) return;
    final item = queue[idx];

    try {
      final dot = item.path.lastIndexOf('.');
      if (dot > 0) {
        final base = item.path.substring(0, dot);
        final candidates = ['$base.lrc', '$base.LRC', '$base.txt'];
        for (final p in candidates) {
          if (File(p).existsSync()) {
            final parsed = await LrcParser.parseFile(p);
            if (parsed.isNotEmpty && mounted) {
              setState(() {
                _lyrics = parsed;
                _lyricsFile = p.split('/').last;
              });
              return;
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _lyrics = [];
        _lyricsFile = null;
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

  void _openSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(AppState.instance.tr('sleep_timer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _timerPill('15 min', 15),
                  _timerPill('30 min', 30),
                  _timerPill('45 min', 45),
                  _timerPill('60 min', 60),
                  _timerPill(AppState.instance.tr('timer_off'), 0),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timerPill(String label, int minutes) {
    final active = AppState.instance.sleepMinutesRemaining == minutes && minutes > 0;
    return GestureDetector(
      onTap: () {
        AppState.instance.setSleepTimer(minutes, () {
          _ac.player.pause();
        });
        Navigator.pop(context);
      },
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        borderColor: active ? AppState.instance.accentColor : Colors.white12,
        tint: active ? AppState.instance.accentColor.withValues(alpha: 0.25) : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppState.instance.accentColor : Colors.white,
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
            final queue = _ac.queue;
            final currentIdx = _ac.player.currentIndex ?? 0;
            return LiquidGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppState.instance.tr('queue'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('${queue.length} songs', style: const TextStyle(fontSize: 13, color: Colors.white54)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: queue.length,
                      itemBuilder: (context, i) {
                        final song = queue[i];
                        final isPlaying = i == currentIdx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
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
                                      child: song.embeddedArt != null
                                          ? Image.memory(song.embeddedArt!, fit: BoxFit.cover)
                                          : ArtBox(seed: song.displayTitle, radius: 0, iconSize: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.displayTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                                            color: isPlaying ? AppState.instance.accentColor : Colors.white,
                                          ),
                                        ),
                                        Text(
                                          song.artist ?? 'Local Music',
                                          maxLines: 1,
                                          style: const TextStyle(fontSize: 12, color: Colors.white54),
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(AppState.instance.tr('speed'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                  final active = (currentSpeed - s).abs() < 0.01;
                  return GestureDetector(
                    onTap: () {
                      _ac.player.setSpeed(s);
                      Navigator.pop(context);
                    },
                    child: LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderColor: active ? AppState.instance.accentColor : Colors.white12,
                      tint: active ? AppState.instance.accentColor.withValues(alpha: 0.25) : null,
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppState.instance.accentColor : Colors.white,
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
              final queue = _ac.queue;
              if (queue.isEmpty) return const SizedBox.shrink();
              final idx = (snap.data ?? widget.startIndex).clamp(0, queue.length - 1).toInt();
              final item = queue[idx];
              final isFav = AppState.instance.isFavorite(item.id);

              return Stack(
                children: [
                  Positioned.fill(child: LiquidBackground(accent: appAccent)),
                  // Blurred album art reflection
                  Positioned.fill(child: _BlurredArt(item: item)),
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final artSize = math.max(
                          130.0,
                          math.min(box.maxWidth - 80, box.maxHeight * 0.36),
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
                                  // Sleep timer
                                  LiquidGlassButton(
                                    icon: Icons.timer_outlined,
                                    size: 44,
                                    iconSize: 22,
                                    tint: AppState.instance.isSleepTimerActive ? appAccent : null,
                                    onTap: _openSleepTimerSheet,
                                  ),
                                  const SizedBox(width: 6),
                                  // Queue
                                  LiquidGlassButton(
                                    icon: Icons.queue_music_rounded,
                                    size: 44,
                                    iconSize: 22,
                                    onTap: _openQueueSheet,
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
                                    duration: const Duration(milliseconds: 400),
                                    child: LiquidGlassContainer(
                                      key: ValueKey('${item.id}_${item.embeddedArt != null}'),
                                      borderRadius: BorderRadius.circular(40),
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: artSize,
                                        height: artSize,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(30),
                                          child: item.embeddedArt != null
                                              ? Image.memory(item.embeddedArt!, fit: BoxFit.cover)
                                              : ArtBox(
                                                  seed: item.displayTitle,
                                                  radius: 0,
                                                  iconSize: artSize * 0.35,
                                                ),
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
                                          item.displayTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.artist ?? (item.album ?? 'Local Music'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.65),
                                            fontSize: 14,
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
                                    onTap: () => AppState.instance.toggleFavorite(item.id),
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
                              StreamBuilder<Duration?>(
                                stream: player.durationStream,
                                builder: (context, d) => StreamBuilder<Duration>(
                                  stream: player.positionStream,
                                  builder: (context, p) => GlassSeekBar(
                                    position: p.data ?? Duration.zero,
                                    duration: d.data ?? item.duration,
                                    accent: appAccent,
                                    onSeek: player.seek,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
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
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLyricsView(AudioPlayer player) {
    if (_lyrics.isEmpty) {
      return Center(
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded, color: Colors.white54, size: 36),
              const SizedBox(height: 8),
              Text(
                AppState.instance.tr('no_lyrics'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, posSnap) {
        final currentPos = posSnap.data ?? Duration.zero;
        final activeIdx = LrcParser.findActiveIndex(_lyrics, currentPos);

        return ListView.builder(
          controller: _lyricsScroll,
          itemCount: _lyrics.length,
          itemBuilder: (context, i) {
            final line = _lyrics[i];
            final isActive = i == activeIdx;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isActive ? 20 : 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AppState.instance.accentColor : Colors.white38,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BlurredArt extends StatelessWidget {
  const _BlurredArt({required this.item});
  final MediaFile item;

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(item.displayTitle);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 0.9,
          colors: [
            accent.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
