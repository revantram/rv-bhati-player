import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/radio_controller.dart';
import 'liquid_glass_container.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  final _appState = AppState.instance;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _setTimer(int minutes, {bool endOfSong = false}) {
    HapticFeedback.mediumImpact();
    _appState.setSleepTimer(
      minutes,
      () {
        AudioController.instance.player.pause();
        RadioController.instance.stop();
      },
      endOfSong: endOfSong,
    );
    Navigator.of(context).pop();
  }

  void _cancelTimer() {
    HapticFeedback.lightImpact();
    _appState.cancelSleepTimer();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _appState.accentColor;
    final isActive = _appState.isSleepTimerActive;
    final formatted = _appState.sleepTimerFormatted;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 14,
        right: 14,
        top: 20,
      ),
      child: LiquidGlassContainer(
        borderRadius: const BorderRadius.all(Radius.circular(32)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bedtime_rounded, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _appState.tr('sleep_timer'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isActive
                            ? 'Active: $formatted remaining'
                            : 'Music & radio will auto-pause',
                        style: TextStyle(
                          color: isActive ? accent : Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                PressableScale(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Timer options
            _TimerOptionTile(
              label: '15 Minutes',
              icon: Icons.timer_outlined,
              isSelected: !isActive ? false : (!_appState.isSleepEndOfSong && _appState.sleepMinutesRemaining > 0 && _appState.sleepMinutesRemaining <= 15),
              accent: accent,
              onTap: () => _setTimer(15),
            ),
            const SizedBox(height: 8),

            _TimerOptionTile(
              label: '30 Minutes',
              icon: Icons.timer_outlined,
              isSelected: !isActive ? false : (!_appState.isSleepEndOfSong && _appState.sleepMinutesRemaining > 15 && _appState.sleepMinutesRemaining <= 30),
              accent: accent,
              onTap: () => _setTimer(30),
            ),
            const SizedBox(height: 8),

            _TimerOptionTile(
              label: '45 Minutes',
              icon: Icons.timer_outlined,
              isSelected: !isActive ? false : (!_appState.isSleepEndOfSong && _appState.sleepMinutesRemaining > 30 && _appState.sleepMinutesRemaining <= 45),
              accent: accent,
              onTap: () => _setTimer(45),
            ),
            const SizedBox(height: 8),

            _TimerOptionTile(
              label: '60 Minutes (1 Hour)',
              icon: Icons.timer_outlined,
              isSelected: !isActive ? false : (!_appState.isSleepEndOfSong && _appState.sleepMinutesRemaining > 45 && _appState.sleepMinutesRemaining <= 60),
              accent: accent,
              onTap: () => _setTimer(60),
            ),
            const SizedBox(height: 8),

            _TimerOptionTile(
              label: _appState.tr('end_of_song'),
              icon: Icons.music_off_rounded,
              isSelected: _appState.isSleepEndOfSong,
              accent: accent,
              onTap: () => _setTimer(0, endOfSong: true),
            ),

            if (isActive) ...[
              const SizedBox(height: 18),
              PressableScale(
                onTap: _cancelTimer,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _appState.tr('timer_off'),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimerOptionTile extends StatelessWidget {
  const _TimerOptionTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? accent : Colors.white70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}
