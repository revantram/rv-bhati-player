import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../services/equalizer_service.dart';
import 'liquid_glass_container.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const EqualizerSheet(),
    );
  }

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  final _eq = EqualizerService.instance;
  AppState get app => AppState.instance;

  @override
  void initState() {
    super.initState();
    _eq.addListener(_onEqChanged);
  }

  @override
  void dispose() {
    _eq.removeListener(_onEqChanged);
    AppState.instance.saveEqualizer();
    super.dispose();
  }

  void _onEqChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final accent = app.accentColor;
    final bands = _eq.bands;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 14,
        right: 14,
        top: 20,
      ),
      child: LiquidGlassContainer(
        borderRadius: const BorderRadius.all(Radius.circular(32)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: app.isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row: Title, Power toggle, Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.tune_rounded, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.tr('equalizer'),
                        style: TextStyle(
                          color: app.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        _eq.isEnabled ? _eq.currentPreset : 'Disabled',
                        style: TextStyle(
                          color: _eq.isEnabled
                              ? accent
                              : app.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Power Toggle
                PressableScale(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _eq.setEnabled(!_eq.isEnabled);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _eq.isEnabled
                          ? accent.withValues(alpha: 0.25)
                          : (app.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _eq.isEnabled
                            ? accent.withValues(alpha: 0.6)
                            : (app.isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          size: 14,
                          color: _eq.isEnabled ? accent : app.secondaryTextColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _eq.isEnabled ? 'ON' : 'OFF',
                          style: TextStyle(
                            color: _eq.isEnabled ? Colors.white : app.secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Close button
                PressableScale(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: app.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: app.secondaryTextColor, size: 18),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Presets Horizontal Carousel
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: EqualizerService.presets.keys.map((presetName) {
                  final isSelected = _eq.isEnabled && _eq.currentPreset == presetName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PressableScale(
                      onTap: _eq.isEnabled
                          ? () {
                              HapticFeedback.lightImpact();
                              _eq.selectPreset(presetName);
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [accent, accent.withValues(alpha: 0.75)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isSelected ? null : (app.isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.07)),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.4)
                                : (app.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            presetName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : app.textColor,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 22),

            // 5 Band iOS Vertical Sliders
            Opacity(
              opacity: _eq.isEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !_eq.isEnabled,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final level = bands.length > index ? bands[index] : 0;
                    final label = EqualizerService.bandLabels[index];
                    return _IosBandSlider(
                      index: index,
                      label: label,
                      level: level,
                      accent: accent,
                      onChanged: (newLevel) => _eq.setBandLevel(index, newLevel),
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Bass Boost & 3D Surround Control Cards
            Opacity(
              opacity: _eq.isEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !_eq.isEnabled,
                child: Row(
                  children: [
                    // Bass Booster
                    Expanded(
                      child: _EffectCard(
                        title: AppState.instance.tr('bass_boost'),
                        valueText: '${(_eq.bassStrength / 10).round()}%',
                        icon: Icons.speaker_group_rounded,
                        accent: accent,
                        valueFraction: _eq.bassStrength / 1000.0,
                        onChanged: (fraction) {
                          _eq.setBassStrength((fraction * 1000).round());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 3D Surround
                    Expanded(
                      child: _SurroundCard(
                        title: AppState.instance.tr('virtualizer'),
                        isActive: _eq.surround3D,
                        strengthFraction: _eq.virtualizerStrength / 1000.0,
                        accent: accent,
                        onToggle: (active) => _eq.toggleSurround(active),
                        onStrengthChanged: (fraction) {
                          _eq.setVirtualizerStrength((fraction * 1000).round());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS Control Center style vertical capsule slider
class _IosBandSlider extends StatelessWidget {
  const _IosBandSlider({
    required this.index,
    required this.label,
    required this.level, // -1000 to +1000
    required this.accent,
    required this.onChanged,
  });

  final int index;
  final String label;
  final int level;
  final Color accent;
  final ValueChanged<int> onChanged;

  void _handleDrag(Offset localPos, double height) {
    // 0 is at bottom (level -1000), height is at top (level +1000)
    final clampedY = localPos.dy.clamp(0.0, height);
    final fraction = 1.0 - (clampedY / height); // 0.0 at bottom to 1.0 at top
    final newLevel = ((fraction * 2000) - 1000).round().clamp(-1000, 1000);
    onChanged(newLevel);
  }

  @override
  Widget build(BuildContext context) {
    // Convert -1000..1000 to 0.0..1.0
    final fillFraction = ((level + 1000) / 2000.0).clamp(0.0, 1.0);
    final db = (level / 100).round();
    final dbStr = db > 0 ? '+$db' : '$db';

    return LayoutBuilder(
      builder: (context, constraints) {
        const double sliderHeight = 140.0;
        const double sliderWidth = 52.0;
        final app = AppState.instance;

        return Column(
          children: [
            // dB label
            Text(
              '${dbStr}dB',
              style: TextStyle(
                color: app.secondaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),

            // Vertical capsule
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                _handleDrag(details.localPosition, sliderHeight);
              },
              onTapDown: (details) {
                HapticFeedback.selectionClick();
                _handleDrag(details.localPosition, sliderHeight);
              },
              child: Container(
                width: sliderWidth,
                height: sliderHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: app.isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: app.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Active fill from bottom
                      FractionallySizedBox(
                        heightFactor: fillFraction,
                        widthFactor: 1.0,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                accent.withValues(alpha: 0.85),
                                accent.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Center 0dB indicator tick
                      Positioned(
                        top: sliderHeight / 2 - 0.5,
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 1,
                          color: app.isLight ? Colors.black26 : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Frequency label
            Text(
              label,
              style: TextStyle(
                color: app.textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.title,
    required this.valueText,
    required this.icon,
    required this.accent,
    required this.valueFraction,
    required this.onChanged,
  });

  final String title;
  final String valueText;
  final IconData icon;
  final Color accent;
  final double valueFraction;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: app.isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: app.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: app.textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Horizontal liquid slider
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final pos = details.localPosition.dx / (box.size.width - 24);
                onChanged(pos.clamp(0.0, 1.0));
              }
            },
            onTapDown: (details) {
              HapticFeedback.selectionClick();
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final pos = details.localPosition.dx / (box.size.width - 24);
                onChanged(pos.clamp(0.0, 1.0));
              }
            },
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: app.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FractionallySizedBox(
                  widthFactor: valueFraction.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: 0.7), accent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurroundCard extends StatelessWidget {
  const _SurroundCard({
    required this.title,
    required this.isActive,
    required this.strengthFraction,
    required this.accent,
    required this.onToggle,
    required this.onStrengthChanged,
  });

  final String title;
  final bool isActive;
  final double strengthFraction;
  final Color accent;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onStrengthChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: app.isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.3)
              : (app.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.surround_sound_rounded,
                color: isActive ? accent : app.secondaryTextColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: app.textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PressableScale(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggle(!isActive);
                },
                child: Container(
                  width: 32,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isActive ? accent : (app.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15)),
                  ),
                  alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Horizontal slider for 3D surround strength
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: isActive
                ? (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final pos = details.localPosition.dx / (box.size.width - 24);
                      onStrengthChanged(pos.clamp(0.0, 1.0));
                    }
                  }
                : null,
            onTapDown: isActive
                ? (details) {
                    HapticFeedback.selectionClick();
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final pos = details.localPosition.dx / (box.size.width - 24);
                      onStrengthChanged(pos.clamp(0.0, 1.0));
                    }
                  }
                : null,
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: app.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FractionallySizedBox(
                  widthFactor: (isActive ? strengthFraction : 0.0).clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: 0.7), accent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
