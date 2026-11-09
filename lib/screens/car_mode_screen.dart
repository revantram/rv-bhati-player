import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/radio_controller.dart';
import '../widgets/art_box.dart';
import '../widgets/equalizer_sheet.dart';

/// Full-screen, high-contrast, distraction-free Car / Driving Mode.
/// Features extra-large touch targets, high readability, and full-screen swipe gestures.
class CarModeScreen extends StatefulWidget {
  const CarModeScreen({super.key});

  @override
  State<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends State<CarModeScreen> {
  final _ac = AudioController.instance;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _ac.player;
    final radio = RadioController.instance;
    final currentStation = radio.currentStation;
    final isRadio = currentStation != null;
    final accent = isRadio ? currentStation.color : const Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -300) {
              HapticFeedback.mediumImpact();
              if (!isRadio) _ac.next();
            } else if (details.primaryVelocity! > 300) {
              HapticFeedback.mediumImpact();
              if (!isRadio) _ac.previous();
            }
          }
        },
        child: SafeArea(
          child: StreamBuilder<SequenceState?>(
            stream: player.sequenceStateStream,
            builder: (context, seqSnap) {
              final tag = seqSnap.data?.currentSource?.tag;
              final title = (tag is MediaItem)
                  ? tag.title
                  : (isRadio ? currentStation.name : 'No Media Playing');
              final artist = (tag is MediaItem)
                  ? (tag.artist ?? 'RV Bhati Player')
                  : (isRadio ? 'Live FM Radio' : 'RV Bhati Player');

              final queue = _ac.queue;
              final currentIdx = player.currentIndex ?? 0;
              final currentSong =
                  currentIdx < queue.length ? queue[currentIdx] : null;
              final onlineSong = _ac.currentOnlineSong;

              return StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, pSnap) {
                  final playing = pSnap.data?.playing ?? false;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Bar: Exit Car Mode, Status, Equalizer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Exit Car Mode
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'EXIT CAR MODE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Driving Mode Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: accent.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_car_rounded, color: accent, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'DRIVING SAFE',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Equalizer
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                EqualizerSheet.show(context);
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Center: Album Art & Giant Song Info
                        Center(
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: isRadio
                                  ? Container(
                                      color: currentStation.color,
                                      child: const Icon(Icons.radio_rounded, color: Colors.white, size: 56),
                                    )
                                  : onlineSong != null
                                      ? Image.network(
                                          onlineSong.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              ArtBox(seed: title, radius: 0, iconSize: 56),
                                        )
                                      : (currentSong?.embeddedArt != null
                                          ? Image.memory(currentSong!.embeddedArt!, fit: BoxFit.cover)
                                          : ArtBox(seed: title, radius: 0, iconSize: 56)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Giant Track Title
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Artist Name
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Spacer(),

                        // Swipe hint
                        Text(
                          'SWIPE ANYWHERE TO CHANGE TRACK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Extra-Large Driving Controls (Prev, Big Play/Pause, Next)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 10s back
                            _buildCircleButton(
                              icon: Icons.replay_10_rounded,
                              size: 64,
                              iconSize: 32,
                              color: Colors.white.withValues(alpha: 0.12),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final pos = player.position - const Duration(seconds: 10);
                                player.seek(pos < Duration.zero ? Duration.zero : pos);
                              },
                            ),

                            // Previous
                            _buildCircleButton(
                              icon: Icons.skip_previous_rounded,
                              size: 72,
                              iconSize: 42,
                              color: Colors.white.withValues(alpha: 0.18),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                if (!isRadio) _ac.previous();
                              },
                            ),

                            // Giant Play/Pause
                            _buildCircleButton(
                              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 96,
                              iconSize: 56,
                              color: accent,
                              iconColor: Colors.black,
                              hasGlow: true,
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                if (playing) {
                                  player.pause();
                                } else {
                                  player.play();
                                }
                              },
                            ),

                            // Next
                            _buildCircleButton(
                              icon: Icons.skip_next_rounded,
                              size: 72,
                              iconSize: 42,
                              color: Colors.white.withValues(alpha: 0.18),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                if (!isRadio) _ac.next();
                              },
                            ),

                            // 10s forward
                            _buildCircleButton(
                              icon: Icons.forward_10_rounded,
                              size: 64,
                              iconSize: 32,
                              color: Colors.white.withValues(alpha: 0.12),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                player.seek(player.position + const Duration(seconds: 10));
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required Color color,
    Color iconColor = Colors.white,
    bool hasGlow = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: hasGlow
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}
