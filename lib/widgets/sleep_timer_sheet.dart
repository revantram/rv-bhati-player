import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/radio_controller.dart';
import 'liquid_glass_container.dart';

/// iOS 18 Liquid Glass Sleep Timer Sheet with quick one-tap presets and live countdown
class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  static void _triggerSleep() {
    try {
      AudioController.instance.player.pause();
    } catch (_) {}
    try {
      RadioController.instance.stop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final accent = app.accentColor;
    final textColor = app.textColor;
    final secondaryText = app.secondaryTextColor;

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final isActive = app.isSleepTimerActive;
        final isEndOfSong = app.isSleepEndOfSong;
        final timeStr = app.sleepTimerFormatted;

        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.bedtime_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sleep Timer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          isActive
                              ? (isEndOfSong
                                  ? 'Pauses after current track finishes'
                                  : 'Active: $timeStr remaining')
                              : 'Automatically stops music, radio & shows',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isActive ? accent : secondaryText,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    PressableScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        app.cancelSleepTimer();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                        ),
                        child: const Text(
                          'Turn Off',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick Presets Row
              Text(
                'QUICK PRESETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: secondaryText.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _presetPill(context, app, 15, '15 min', accent, textColor),
                  const SizedBox(width: 8),
                  _presetPill(context, app, 30, '30 min', accent, textColor),
                  const SizedBox(width: 8),
                  _presetPill(context, app, 45, '45 min', accent, textColor),
                  const SizedBox(width: 8),
                  _presetPill(context, app, 60, '60 min', accent, textColor),
                ],
              ),

              const SizedBox(height: 12),

              // End of track preset
              PressableScale(
                onTap: () {
                  HapticFeedback.lightImpact();
                  app.setSleepTimer(0, _triggerSleep, endOfSong: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isEndOfSong
                        ? accent.withValues(alpha: 0.18)
                        : (isLight
                            ? Colors.black.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.06)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isEndOfSong ? accent : app.cardBorderColor,
                      width: isEndOfSong ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_off_rounded,
                        color: isEndOfSong ? accent : textColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'End of Current Track / गीत समाप्ति पर बंद करें',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isEndOfSong ? FontWeight.w700 : FontWeight.w500,
                            color: isEndOfSong ? accent : textColor,
                          ),
                        ),
                      ),
                      if (isEndOfSong)
                        Icon(Icons.check_circle_rounded, color: accent, size: 18),
                    ],
                  ),
                ),
              ),

              // Active Timer Controls: Extend buttons
              if (isActive && !isEndOfSong) ...[
                const SizedBox(height: 18),
                Divider(color: app.dividerColor, height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _extendButton(app, 5, '+5 min', accent, textColor),
                    const SizedBox(width: 12),
                    _extendButton(app, 15, '+15 min', accent, textColor),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _presetPill(
    BuildContext context,
    AppState app,
    int minutes,
    String label,
    Color accent,
    Color textColor,
  ) {
    final isSelected = app.isSleepTimerActive &&
        !app.isSleepEndOfSong &&
        app.sleepMinutesRemaining == minutes;

    return Expanded(
      child: PressableScale(
        onTap: () {
          HapticFeedback.lightImpact();
          app.setSleepTimer(minutes, _triggerSleep);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.18)
                : app.surfaceColorSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accent : app.cardBorderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? accent : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _extendButton(
    AppState app,
    int extraMinutes,
    String label,
    Color accent,
    Color textColor,
  ) {
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        final currentMins = app.sleepMinutesRemaining;
        app.setSleepTimer(currentMins + extraMinutes, _triggerSleep);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
