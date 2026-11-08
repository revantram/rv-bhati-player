import 'dart:ui' show ImageFilter;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_file.dart';
import '../services/audio_controller.dart';
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

  /// false when re-opening the screen from the mini player (don't restart).
  final bool startPlayback;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final _ac = AudioController.instance;

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

  @override
  Widget build(BuildContext context) {
    final player = _ac.player;
    return Scaffold(
      body: StreamBuilder<int?>(
        stream: player.currentIndexStream,
        builder: (context, snap) {
          final queue = _ac.queue;
          if (queue.isEmpty) return const SizedBox.shrink();
          final idx = (snap.data ?? widget.startIndex).clamp(0, queue.length - 1).toInt();
          final item = queue[idx];
          final accent = accentFor(item.displayTitle);

          return Stack(
            children: [
              Positioned.fill(child: LiquidBackground(accent: accent)),
              // Album-art "reflection": the cover, scaled up and heavily blurred.
              Positioned.fill(child: _BlurredArt(seed: item.displayTitle)),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final artSize = math.max(
                      120.0,
                      math.min(box.maxWidth - 80, box.maxHeight * 0.38),
                    );
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: IntrinsicHeight(
                          child: Padding(
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
                                    Padding(
                                      padding: const EdgeInsets.only(right: 14),
                                      child: Text(
                                        '${idx + 1} / ${queue.length}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // iOS style music card
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  child: LiquidGlassContainer(
                                    key: ValueKey(item.id),
                                    borderRadius: BorderRadius.circular(40),
                                    padding: const EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: artSize,
                                      height: artSize,
                                      child: ArtBox(
                                        seed: item.displayTitle,
                                        radius: 30,
                                        iconSize: artSize * 0.35,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Text(
                                  item.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Local Music  -  ${item.extension}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                StreamBuilder<Duration?>(
                                  stream: player.durationStream,
                                  builder: (context, d) => StreamBuilder<Duration>(
                                    stream: player.positionStream,
                                    builder: (context, p) => GlassSeekBar(
                                      position: p.data ?? Duration.zero,
                                      duration: d.data ?? item.duration,
                                      accent: accent,
                                      onSeek: player.seek,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                StreamBuilder<PlayerState>(
                                  stream: player.playerStateStream,
                                  builder: (context, s) {
                                    final st = s.data;
                                    final playing = (st?.playing ?? false) &&
                                        st?.processingState != ProcessingState.completed;
                                    return FittedBox(
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
                                            tint: accent,
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
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
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
  }
}

class _BlurredArt extends StatelessWidget {
  const _BlurredArt({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: KeyedSubtree(
        key: ValueKey(seed),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Opacity(
            opacity: 0.5,
            child: Transform.scale(
              scale: 1.6,
              child: ArtBox(seed: seed, radius: 0, iconSize: 220),
            ),
          ),
        ),
      ),
    );
  }
}
