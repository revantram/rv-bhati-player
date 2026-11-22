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
import '../widgets/liquid_glass_play_pause_button.dart';

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
    final app = AppState.instance;
    final isLight = app.isLight;
    final player = _ac.player;
    final radio = RadioController.instance;
    final currentStation = radio.currentStation;
    final isRadio = currentStation != null;
    final rawAccent = isRadio ? currentStation.color : const Color(0xFF00E5FF);
    final accent = isLight
        ? (rawAccent.computeLuminance() > 0.55 ? const Color(0xFF0284C7) : rawAccent)
        : rawAccent;

    final textColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final secondaryTextColor = isLight ? const Color(0xFF334155) : Colors.white.withValues(alpha: 0.75);
    final hintColor = isLight ? const Color(0xFF475569) : Colors.white.withValues(alpha: 0.45);

    final exitBg = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.12);
    final exitBorder = isLight ? const Color(0xFFCBD5E1) : Colors.white24;
    final exitText = isLight ? const Color(0xFF0F172A) : Colors.white;

    final mainBtnBg = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.18);
    final mainBtnBorder = isLight ? const Color(0xFFCBD5E1) : Colors.white24;
    final mainBtnIcon = isLight ? const Color(0xFF0F172A) : Colors.white;

    final secBtnBg = isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.12);
    final secBtnBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white12;
    final secBtnIcon = isLight ? const Color(0xFF334155) : Colors.white;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: isLight ? const Color(0xFFEDF2F7) : Colors.black,
        body: StreamBuilder<SequenceState?>(
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
            final currentSong = currentIdx < queue.length ? queue[currentIdx] : null;
            final onlineSong = _ac.currentOnlineSong;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Atmospheric Ambient Backdrop with subtle art blur
                if (onlineSong != null && onlineSong.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: isLight ? 0.18 : 0.22,
                      child: Image.network(
                        onlineSong.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  )
                else if (currentSong?.embeddedArt != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: isLight ? 0.18 : 0.22,
                      child: Image.memory(
                        currentSong!.embeddedArt!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                // 2. High-contrast Frosted Backdrop Gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isLight
                            ? [
                                Colors.white.withValues(alpha: 0.82),
                                const Color(0xFFE2E8F0).withValues(alpha: 0.88),
                                const Color(0xFFCBD5E1).withValues(alpha: 0.94),
                              ]
                            : [
                                Colors.black.withValues(alpha: 0.70),
                                const Color(0xFF0F121C).withValues(alpha: 0.85),
                                Colors.black.withValues(alpha: 0.95),
                              ],
                      ),
                    ),
                  ),
                ),

                // 3. Foreground Content
                SafeArea(
                  child: GestureDetector(
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
                    child: StreamBuilder<PlayerState>(
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
                                  // Exit Car Mode Button
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: exitBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: exitBorder, width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.close_rounded, color: exitText, size: 20),
                                          const SizedBox(width: 6),
                                          Text(
                                            'EXIT CAR MODE',
                                            style: TextStyle(
                                              color: exitText,
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
                                      color: accent.withValues(alpha: isLight ? 0.16 : 0.20),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: accent.withValues(alpha: isLight ? 0.55 : 0.50),
                                        width: 1.2,
                                      ),
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

                                  // Equalizer Button
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      EqualizerSheet.show(context);
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: exitBg,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: exitBorder, width: 1.2),
                                      ),
                                      child: Icon(Icons.tune_rounded, color: exitText, size: 22),
                                    ),
                                  ),
                                ],
                              ),

                              const Spacer(),

                              // Center: Album Art & Giant Song Info
                              Center(
                                child: Container(
                                  width: 156,
                                  height: 156,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(34),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: isLight ? 0.25 : 0.35),
                                        blurRadius: 26,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.40),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(34),
                                    child: isRadio
                                        ? Container(
                                            color: currentStation.color,
                                            child: const Icon(Icons.radio_rounded, color: Colors.white, size: 64),
                                          )
                                        : onlineSong != null
                                            ? Image.network(
                                                onlineSong.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    ArtBox(seed: title, radius: 0, iconSize: 64),
                                              )
                                            : (currentSong?.embeddedArt != null
                                                ? Image.memory(currentSong!.embeddedArt!, fit: BoxFit.cover)
                                                : ArtBox(seed: title, radius: 0, iconSize: 64)),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Giant High-Contrast Track Title
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 27,
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
                                  color: secondaryTextColor,
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
                                  color: hintColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Extra-Large Driving Controls (Prev, Big Play/Pause, Next)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 10s back
                                      _buildCircleButton(
                                        icon: Icons.replay_10_rounded,
                                        size: 60,
                                        iconSize: 30,
                                        color: secBtnBg,
                                        borderColor: secBtnBorder,
                                        iconColor: secBtnIcon,
                                        isLight: isLight,
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          final pos = player.position - const Duration(seconds: 10);
                                          player.seek(pos < Duration.zero ? Duration.zero : pos);
                                        },
                                      ),
                                      const SizedBox(width: 14),

                                      // Previous: Enlarged 80px touch target
                                      _buildCircleButton(
                                        icon: Icons.skip_previous_rounded,
                                        size: 80,
                                        iconSize: 46,
                                        color: mainBtnBg,
                                        borderColor: mainBtnBorder,
                                        iconColor: mainBtnIcon,
                                        isLight: isLight,
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          if (!isRadio) _ac.previous();
                                        },
                                      ),
                                      const SizedBox(width: 16),

                                      // Giant Play/Pause: Enlarged 106px disc for effortless car driving access
                                      LiquidGlassPlayPauseButton(
                                        isPlaying: playing,
                                        size: 106,
                                        iconSize: 60,
                                        color: accent,
                                        iconColor: Colors.white,
                                        onToggle: () {
                                          if (playing) {
                                            player.pause();
                                          } else {
                                            player.play();
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 16),

                                      // Next: Enlarged 80px touch target
                                      _buildCircleButton(
                                        icon: Icons.skip_next_rounded,
                                        size: 80,
                                        iconSize: 46,
                                        color: mainBtnBg,
                                        borderColor: mainBtnBorder,
                                        iconColor: mainBtnIcon,
                                        isLight: isLight,
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          if (!isRadio) _ac.next();
                                        },
                                      ),
                                      const SizedBox(width: 14),

                                      // 10s forward
                                      _buildCircleButton(
                                        icon: Icons.forward_10_rounded,
                                        size: 60,
                                        iconSize: 30,
                                        color: secBtnBg,
                                        borderColor: secBtnBorder,
                                        iconColor: secBtnIcon,
                                        isLight: isLight,
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          player.seek(player.position + const Duration(seconds: 10));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
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
    Color? borderColor,
    bool hasGlow = false,
    bool isLight = false,
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
          border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            if (hasGlow)
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(child: Icon(icon, color: iconColor, size: iconSize)),
      ),
    );
  }
}
