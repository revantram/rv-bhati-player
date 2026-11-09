import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/radio_controller.dart';
import 'art_box.dart';
import 'liquid_glass_container.dart';

/// iPhone-style floating Dynamic Island player at the top of the screen.
/// Automatically appears when music plays and smoothly slides away when stopped.
class DynamicIslandPlayer extends StatefulWidget {
  const DynamicIslandPlayer({
    super.key,
    required this.onOpen,
    this.onOpenRadio,
    this.onOpenOnline,
  });

  final VoidCallback onOpen;
  final VoidCallback? onOpenRadio;
  final VoidCallback? onOpenOnline;

  @override
  State<DynamicIslandPlayer> createState() => _DynamicIslandPlayerState();
}

class _DynamicIslandPlayerState extends State<DynamicIslandPlayer>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioController.instance.player;
    final radio = RadioController.instance;
    final app = AppState.instance;

    return ListenableBuilder(
      listenable: radio,
      builder: (context, _) {
        return StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, seqSnap) {
            final tag = seqSnap.data?.currentSource?.tag;
            final hasTrack = tag is MediaItem;

            return StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, playerSnap) {
                final playing = playerSnap.data?.playing ?? false;
                final processingState = playerSnap.data?.processingState;
                final isCompleted = processingState == ProcessingState.completed;
                final isIdle = processingState == ProcessingState.idle;

                // Dynamic Island is visible when a track is loaded and either playing or paused (not idle/completed)
                final shouldShow = hasTrack && !isCompleted && !isIdle;

                if (playing) {
                  if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
                  if (!_waveCtrl.isAnimating) _waveCtrl.repeat(reverse: true);
                } else {
                  if (_spinCtrl.isAnimating) _spinCtrl.stop();
                  if (_waveCtrl.isAnimating) _waveCtrl.stop();
                }

                if (!shouldShow) {
                  return const SizedBox.shrink();
                }

                final queue = AudioController.instance.queue;
                final currentIdx = player.currentIndex ?? 0;
                final currentSong =
                    currentIdx < queue.length ? queue[currentIdx] : null;
                final currentStation = radio.currentStation;
                final isRadio = currentStation != null;
                final onlineSong = AudioController.instance.currentOnlineSong;
                final isOnline = AudioController.instance.isPlayingOnline;

                VoidCallback? onTapAction;
                if (isRadio) {
                  onTapAction = widget.onOpenRadio;
                } else if (isOnline) {
                  onTapAction = widget.onOpenOnline;
                } else {
                  onTapAction = widget.onOpen;
                }

                final accent = isRadio ? currentStation.color : app.accentColor;

                return AnimatedSlide(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  offset: shouldShow ? Offset.zero : const Offset(0, -1.2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: shouldShow ? 1.0 : 0.0,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onTapAction?.call();
                        },
                        child: Container(
                          height: 48,
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 18,
                                spreadRadius: 1,
                                offset: const Offset(0, 5),
                              ),
                              BoxShadow(
                                color: accent.withValues(alpha: 0.22),
                                blurRadius: 14,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // 1. Spinning Album Artwork / Icon
                              RotationTransition(
                                turns: _spinCtrl,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.6),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: isRadio
                                        ? Container(
                                            color: currentStation.color,
                                            child: const Icon(
                                              Icons.radio_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          )
                                        : isOnline && onlineSong != null
                                            ? Image.network(
                                                onlineSong.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    ArtBox(
                                                  seed: tag.title,
                                                  radius: 0,
                                                  iconSize: 18,
                                                ),
                                              )
                                            : (currentSong?.embeddedArt != null
                                                ? Image.memory(
                                                    currentSong!.embeddedArt!,
                                                    fit: BoxFit.cover,
                                                  )
                                                : ArtBox(
                                                    seed: tag.title,
                                                    radius: 0,
                                                    iconSize: 18,
                                                  )),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),

                              // 2. Track Title & Artist Info + Mini Equalizer
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tag.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            tag.artist ??
                                                (isRadio
                                                    ? 'Live Radio'
                                                    : 'RV Bhati Player'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.65),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // Mini 3-bar animated equalizer wave
                                    if (playing)
                                      AnimatedBuilder(
                                        animation: _waveCtrl,
                                        builder: (context, _) {
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildWaveBar(14.0 * (0.3 + 0.7 * _waveCtrl.value), accent),
                                              const SizedBox(width: 2.2),
                                              _buildWaveBar(14.0 * (0.9 - 0.6 * _waveCtrl.value), accent),
                                              const SizedBox(width: 2.2),
                                              _buildWaveBar(14.0 * (0.5 + 0.5 * _waveCtrl.value), accent),
                                            ],
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),

                              // 3. iPhone-style Controls: Previous, Play/Pause, Next
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Previous Song
                                  _buildIslandButton(
                                    icon: Icons.skip_previous_rounded,
                                    size: 19,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      if (!isRadio) AudioController.instance.previous();
                                    },
                                  ),
                                  const SizedBox(width: 4),

                                  // Play / Pause Button
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      if (playing) {
                                        player.pause();
                                      } else {
                                        player.play();
                                      }
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(alpha: 0.45),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Next Song
                                  _buildIslandButton(
                                    icon: Icons.skip_next_rounded,
                                    size: 19,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      if (!isRadio) AudioController.instance.next();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWaveBar(double height, Color color) {
    return Container(
      width: 2.8,
      height: height.clamp(4.0, 15.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildIslandButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: size,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}
