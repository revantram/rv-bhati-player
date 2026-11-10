import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio_trimmer_screen.dart';
import 'car_mode_screen.dart';
import '../models/radio_station.dart';
import '../services/app_state.dart';
import '../services/media_scanner.dart';
import '../services/saavn_api_service.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/ios_bounce_button.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import 'albums_browser_screen.dart';
import 'artists_hub_screen.dart';
import 'downloads_screen.dart';
import 'liked_songs_screen.dart';
import 'playlists_manager_screen.dart';
import 'shows_hub_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  final _app = AppState.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
    _app.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    _app.removeListener(_onChanged);
    super.dispose();
  }

  bool _isCheckingUpdate = false;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    HapticFeedback.lightImpact();
    await UpdateService.instance.checkAndPromptUpdate(context, showUpToDate: true);
    if (mounted) {
      setState(() => _isCheckingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = _app.isLight;
    final textColor = _app.textColor;
    final secondaryTextColor = _app.secondaryTextColor;
    final accent = _app.accentColor;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LiquidBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    iOSBounceButton(
                      onTap: () => Navigator.pop(context),
                      child: LiquidGlassContainer(
                        borderRadius: BorderRadius.circular(20),
                        padding: const EdgeInsets.all(10),
                        blur: 16,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: textColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      AppState.translate('settings'),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Grouped Settings List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                  children: [
                    // My Library Hub
                    _buildMyLibrarySection(context, textColor, secondaryTextColor, accent, isLight),

                    // Section: Online Search & Music Engine
                    _buildSectionHeader('ONLINE SEARCH & MUSIC ENGINE', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      blur: 14,
                      child: Column(
                        children: [
                          for (final engine in MusicEngine.values) ...[
                            _buildEngineTile(engine, textColor, secondaryTextColor, accent),
                            if (engine != MusicEngine.values.last)
                              _buildDivider(isLight),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 1: Streaming Quality
                    _buildSectionHeader('AUDIO STREAMING QUALITY', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      blur: 14,
                      child: Column(
                        children: [
                          for (final q in AudioQuality.values) ...[
                            _buildQualityTile(q, textColor, secondaryTextColor, accent),
                            if (q != AudioQuality.values.last)
                              _buildDivider(isLight),
                          ],
                          _buildDivider(isLight),
                          _buildSwitchTile(
                            title: AppState.translate('auto_quality'),
                            subtitle: '320 kbps on Wi-Fi • 160 kbps on Mobile Data',
                            value: _settings.autoQuality,
                            onChanged: _settings.setAutoQuality,
                            icon: Icons.wifi_tethering_rounded,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 2: Audio & Playback Enhancements
                    _buildSectionHeader('AUDIO & PLAYBACK', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      blur: 14,
                      child: Column(
                        children: [
                          _buildNavTile(
                            icon: Icons.equalizer_rounded,
                            title: 'Built-in Equalizer & Bass Boost',
                            subtitle: '5-Band EQ, 3D Surround & Bass presets',
                            onTap: () => EqualizerSheet.show(context),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                          _buildDivider(isLight),
                          _buildNavTile(
                            icon: Icons.content_cut_rounded,
                            title: 'Ringtone Cutter & Audio Trimmer',
                            subtitle: 'Trim any song & set as custom ringtone',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AudioTrimmerScreen(
                                  availableTracks: MediaScanner.lastScannedAudios,
                                ),
                              ),
                            ),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                          _buildDivider(isLight),
                          _buildSwitchTile(
                            title: AppState.translate('sleep_fade_out'),
                            subtitle: 'Smoothly fade out volume over last 10s',
                            value: _settings.sleepFadeOut,
                            onChanged: _settings.setSleepFadeOut,
                            icon: Icons.bedtime_rounded,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                          _buildDivider(isLight),
                          _buildCrossfadeTile(textColor, secondaryTextColor, accent),
                          _buildDivider(isLight),
                          _buildNavTile(
                            icon: Icons.directions_car_rounded,
                            title: 'Car Mode / Driving Mode',
                            subtitle: 'Extra-large touch controls for safe driving',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CarModeScreen()),
                            ),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 3: Appearance & Language
                    _buildSectionHeader('APPEARANCE & LANGUAGE', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.all(16),
                      blur: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Theme Switcher Pills
                          Text(
                            AppState.translate('theme_style'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: AppThemeMode.values.map((mode) {
                              final active = _settings.themeMode == mode;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: iOSBounceButton(
                                    onTap: () => _settings.setThemeMode(mode),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? accent.withValues(alpha: 0.18)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: active
                                              ? accent
                                              : (isLight
                                                  ? Colors.black.withValues(alpha: 0.08)
                                                  : Colors.white.withValues(alpha: 0.12)),
                                          width: active ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          mode == AppThemeMode.light
                                              ? 'Light'
                                              : mode == AppThemeMode.dark
                                                  ? 'Dark'
                                                  : 'System',
                                          style: TextStyle(
                                            color: active ? accent : textColor,
                                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 18),
                          Divider(color: isLight ? Colors.black12 : Colors.white12, height: 1),
                          const SizedBox(height: 16),

                          // Language Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'App Language / भाषा',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _app.language == AppLanguage.en ? 'English' : 'हिंदी (Hindi)',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              iOSBounceButton(
                                onTap: () => _app.setLanguage(
                                  _app.language == AppLanguage.en ? AppLanguage.hi : AppLanguage.en,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    _app.language == AppLanguage.en ? 'हिंदी में बदलें' : 'Switch to English',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 4: Software Updates
                    _buildSectionHeader('APP UPDATES / ऐप अपडेट', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      blur: 14,
                      child: _buildNavTile(
                        icon: Icons.system_update_rounded,
                        title: 'Check for Updates / नया अपडेट देखें',
                        subtitle: 'Current: v${UpdateService.currentVersion} • GitHub Direct Update',
                        onTap: _isCheckingUpdate ? null : _checkUpdate,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        accent: accent,
                        trailing: _isCheckingUpdate
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Check',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 5: Developer Options
                    _buildSectionHeader('DEVELOPER OPTIONS', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(24),
                      padding: const EdgeInsets.all(20),
                      blur: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accent,
                                      const Color(0xFF00E5FF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.45),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'RB',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Revant Ram Bhati',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.verified_rounded,
                                          color: accent,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Lead Developer & Creator',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'RV Bhati Player • v${UpdateService.currentVersion}',
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Email Tile
                          _buildDevContactTile(
                            icon: Icons.alternate_email_rounded,
                            label: 'Official Email',
                            value: 'revantrambhati@gmail.com',
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: 'revantrambhati@gmail.com'));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email copied: revantrambhati@gmail.com'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          // Phone Tile
                          _buildDevContactTile(
                            icon: Icons.phone_android_rounded,
                            label: 'Mobile / WhatsApp',
                            value: '+91 8696663615',
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: '8696663615'));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Phone number copied: 8696663615'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: iOSBounceButton(
                                  onTap: () {
                                    Clipboard.setData(const ClipboardData(text: 'revantrambhati@gmail.com'));
                                    HapticFeedback.selectionClick();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied email: revantrambhati@gmail.com'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.mail_outline_rounded, size: 16, color: accent),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Send Email',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: iOSBounceButton(
                                  onTap: () {
                                    Clipboard.setData(const ClipboardData(text: '8696663615'));
                                    HapticFeedback.selectionClick();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied mobile: +91 8696663615'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.call_rounded, size: 16, color: textColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Call / WhatsApp',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionHeader(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.55),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isLight) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 52,
      endIndent: 16,
      color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildQualityTile(
    AudioQuality q,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
  ) {
    final selected = _settings.audioQuality == q;

    return iOSBounceButton(
      onTap: () => _settings.setAudioQuality(q),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : secondaryTextColor.withValues(alpha: 0.4),
                  width: 2,
                ),
                color: selected ? accent : Colors.transparent,
              ),
              child: selected
                  ? const Center(
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    q.description,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color textColor,
    required Color secondaryTextColor,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color textColor,
    required Color secondaryTextColor,
    required Color accent,
    Widget? trailing,
  }) {
    return iOSBounceButton(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: secondaryTextColor.withValues(alpha: 0.5),
                  size: 14,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossfadeTile(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
  ) {
    final secs = _settings.crossfadeSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  AppState.translate('crossfade'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                secs == 0 ? 'Off' : '${secs}s',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: secondaryTextColor.withValues(alpha: 0.2),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.15),
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: secs.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                _settings.setCrossfadeSeconds(v.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevContactTile({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color secondaryTextColor,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppState.instance.isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppState.instance.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 16, color: secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineTile(
    MusicEngine engine,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
  ) {
    final selected = _settings.musicEngine == engine;
    final isYt = engine == MusicEngine.youtube;

    return iOSBounceButton(
      onTap: () => _settings.setMusicEngine(engine),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isYt
                    ? const Color(0xFFFF0000).withValues(alpha: 0.15)
                    : accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isYt ? Icons.play_circle_fill_rounded : Icons.graphic_eq_rounded,
                color: isYt ? const Color(0xFFFF0000) : accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    engine.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    engine.description,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : secondaryTextColor.withValues(alpha: 0.4),
                  width: 2,
                ),
                color: selected ? accent : Colors.transparent,
              ),
              child: selected
                  ? const Center(
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyLibrarySection(
    BuildContext context,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final rawName = _app.userName.trim();
    final initials = rawName.isNotEmpty
        ? rawName.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
        : 'RR';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('MY LIBRARY', textColor),
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(16),
          blur: 14,
          child: Column(
            children: [
              // User Profile Row
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.65)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _app.userName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personal Audio Space',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  iOSBounceButton(
                    onTap: () => _showEditNameDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, size: 14, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDivider(isLight),

              // Items
              ListenableBuilder(
                listenable: _app,
                builder: (context, _) => _buildLibraryTile(
                  icon: Icons.music_note_rounded,
                  title: 'Liked Songs',
                  count: '${_app.favorites.length}',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  accent: accent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                    );
                  },
                ),
              ),
              _buildDivider(isLight),
              ListenableBuilder(
                listenable: _app,
                builder: (context, _) => _buildLibraryTile(
                  icon: Icons.album_outlined,
                  title: 'Albums',
                  count: '${MediaScanner.lastScannedAudios.map((a) => a.album ?? "").where((s) => s.trim().isNotEmpty).toSet().length}',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  accent: accent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlbumsBrowserScreen()),
                    );
                  },
                ),
              ),
              _buildDivider(isLight),
              _buildLibraryTile(
                icon: Icons.mic_none_rounded,
                title: 'Artists',
                count: '${SaavnApiService.curatedArtists.length}',
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                accent: accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ArtistsHubScreen()),
                  );
                },
              ),
              _buildDivider(isLight),
              _buildLibraryTile(
                icon: Icons.podcasts_rounded,
                title: 'Shows',
                count: '15+ Shows',
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                accent: accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShowsHubScreen()),
                  );
                },
              ),
              _buildDivider(isLight),
              ListenableBuilder(
                listenable: DownloadService.instance,
                builder: (context, _) => _buildLibraryTile(
                  icon: Icons.download_outlined,
                  title: 'Downloads',
                  count: '${DownloadService.instance.downloadedSongs.length}',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  accent: accent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                    );
                  },
                ),
              ),
              _buildDivider(isLight),
              ListenableBuilder(
                listenable: _app,
                builder: (context, _) => _buildLibraryTile(
                  icon: Icons.queue_music_rounded,
                  title: 'Playlists',
                  count: '${_app.playlists.length + _app.customPlaylists.length}',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  accent: accent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlaylistsManagerScreen()),
                    );
                  },
                ),
              ),

            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildLibraryTile({
    required IconData icon,
    required String title,
    required String count,
    required Color textColor,
    required Color secondaryTextColor,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppState.instance.isLight
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: secondaryTextColor.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: _app.userName);
    final isLight = _app.isLight;
    final textColor = _app.textColor;
    final accent = _app.accentColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLight
            ? Colors.white.withValues(alpha: 0.95)
            : const Color(0xFF1E1E22).withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Profile Name',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
            filled: true,
            fillColor: isLight
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: textColor.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _app.setUserName(newName);
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

