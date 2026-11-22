import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio_trimmer_screen.dart';
import 'car_mode_screen.dart';
import '../models/radio_station.dart';
import '../services/app_state.dart';
import '../services/backup_restore_service.dart';
import '../services/cache_service.dart';
import '../services/media_action_service.dart';
import '../services/media_scanner.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../utils/format.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/ios_bounce_button.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/jiosaavn_login_sheet.dart';
import '../services/jiosaavn_auth_service.dart';
import 'albums_browser_screen.dart';
import 'artists_hub_screen.dart';
import 'downloads_screen.dart';
import 'liked_songs_screen.dart';
import 'local_storage_music_screen.dart';
import 'playlists_manager_screen.dart';
import 'shows_hub_screen.dart';


class SettingsScreen extends StatefulWidget {
  final bool isTab;
  final double? bottomOffset;
  const SettingsScreen({
    super.key,
    this.isTab = false,
    this.bottomOffset,
  });

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
                    if (!widget.isTab) ...[
                      iOSBounceButton(
                        onTap: () => Navigator.pop(context),
                        child: LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(20),
                          padding: const EdgeInsets.all(10),
                          blur: 0,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: textColor,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.settings_rounded, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                    ],
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 6, 16, (widget.bottomOffset ?? 120) + 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // My Library Hub
                      _buildMyLibrarySection(context, textColor, secondaryTextColor, accent, isLight),

                    // Section 1: Streaming Quality
                    _buildSectionHeader('AUDIO STREAMING QUALITY', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      blur: 0,
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
                      blur: 0,
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
                          _buildNavTile(
                            icon: Icons.timer_rounded,
                            title: 'Sleep Timer / स्लीप टाइमर',
                            subtitle: _app.isSleepTimerActive
                                ? 'Active: ${_app.sleepTimerFormatted}'
                                : 'Set auto-pause countdown or end of track',
                            onTap: () => SleepTimerSheet.show(context),
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
                          _buildSwitchTile(
                            title: 'Skip Silence',
                            subtitle: 'Automatically trim silent gaps between audio',
                            value: _settings.skipSilence,
                            onChanged: _settings.setSkipSilence,
                            icon: Icons.fast_forward_rounded,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                          _buildDivider(isLight),
                          _buildCrossfadeTile(textColor, secondaryTextColor, accent),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 3: BitChord Appearance & Language
                    _buildSectionHeader('BITCHORD APPEARANCE & THEME', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.all(16),
                      blur: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Theme Mode Switcher Pills
                          Text(
                            AppState.translate('theme_style'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildThemeTile(AppThemeMode.oled, accent, textColor)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildThemeTile(AppThemeMode.royalGold, accent, textColor)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildThemeTile(AppThemeMode.iosLiquid, accent, textColor)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildThemeTile(AppThemeMode.light, accent, textColor)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildThemeTile(AppThemeMode.dark, accent, textColor)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildThemeTile(AppThemeMode.system, accent, textColor)),
                            ],
                          ),

                          const SizedBox(height: 18),
                          Divider(color: _app.dividerColor, height: 1),
                          const SizedBox(height: 16),

                          // Now Playing Player Theme Style (BitChord)
                          Text(
                            'Now Playing Player Style',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: PlayerThemeStyle.values.map((style) {
                              final active = _settings.playerThemeStyle == style;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: iOSBounceButton(
                                    onTap: () => _settings.setPlayerThemeStyle(style),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? accent.withValues(alpha: 0.18)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: active ? accent : _app.cardBorderColor,
                                          width: active ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          style == PlayerThemeStyle.frosted
                                              ? 'Frosted'
                                              : style == PlayerThemeStyle.vibrant
                                                  ? 'Vibrant'
                                                  : 'Minimal',
                                          style: TextStyle(
                                            color: active ? accent : textColor,
                                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),
                          Divider(color: _app.dividerColor, height: 1),
                          const SizedBox(height: 14),

                          // BitChord Accent Color Swatches
                          Text(
                            'BitChord Accent Color',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 11,
                            runSpacing: 11,
                            children: AppState.accentOptions.map((c) {
                              final selected = _app.staticAccentColor == c;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _app.setAccentColor(c);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? (isLight ? Colors.black87 : Colors.white)
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: c.withValues(alpha: 0.55),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),
                          Divider(color: _app.dividerColor, height: 1),
                          const SizedBox(height: 6),

                          _buildSwitchTile(
                            title: 'Frosted Glass Cards',
                            subtitle: 'Translucent Apple Music blur across bars & panels',
                            value: _settings.glassBlurEnabled,
                            onChanged: _settings.setGlassBlurEnabled,
                            icon: Icons.blur_on_rounded,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                          _buildDivider(isLight),
                          _buildSwitchTile(
                            title: 'Dynamic Artwork Glow',
                            subtitle: 'Adapt accent glow to album cover colors',
                            value: _settings.dynamicArtworkColors,
                            onChanged: _settings.setDynamicArtworkColors,
                            icon: Icons.palette_rounded,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),

                          Divider(color: _app.dividerColor, height: 1),
                          const SizedBox(height: 14),

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

                    // Section: Storage & App Data Management
                    _buildSectionHeader('STORAGE & APP DATA MANAGEMENT', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      blur: 0,
                      child: Column(
                        children: [
                          _buildNavTile(
                            icon: Icons.backup_rounded,
                            title: 'App Data Backup & Restore',
                            subtitle: 'Local JSON Export • Playlists, Favorites & Preferences',
                            onTap: () => _showBackupRestoreSheet(context, textColor, secondaryTextColor, accent, isLight),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                          _buildDivider(isLight),
                          _buildNavTile(
                            icon: Icons.cleaning_services_rounded,
                            title: 'Safe Cache / Temp Cleanup',
                            subtitle: 'Clear buffer & temporary image cache safely',
                            onTap: () => _showCacheCleanupSheet(context, textColor, secondaryTextColor, accent, isLight),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section: Share App
                    _buildSectionHeader('SHARE RV BHATI PLAYER / ऐप शेयर करें', textColor),
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      blur: 0,
                      child: Column(
                        children: [
                          _buildNavTile(
                            icon: Icons.android_rounded,
                            title: 'Share APK File (सीधी ऐप फाइल शेयर करें)',
                            subtitle: 'Send full APK file via WhatsApp, Bluetooth, Nearby Share',
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final ok = await MediaActionService.shareAppApk();
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open APK share sheet')),
                                );
                              }
                            },
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
                          ),
                          _buildDivider(isLight),
                          _buildNavTile(
                            icon: Icons.share_rounded,
                            title: 'Share Download Link (डाउनलोड लिंक शेयर करें)',
                            subtitle: 'Share official GitHub download link with friends',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              MediaActionService.shareText(
                                '🎵 RV Bhati Player - Android 4K Video, Music & FM Radio Player\n\n'
                                '✨ iOS 18 Liquid Glass Design\n'
                                '✨ JioSaavn, Spotify, FM Radio & Shows\n'
                                '✨ 4K HDR Video with background PiP\n\n'
                                'Download latest APK directly: https://github.com/revantram/rv-bhati-player/releases/latest',
                                subject: 'Download RV Bhati Player',
                              );
                            },
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: accent,
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
                      blur: 0,
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
                      blur: 0,
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
            ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildThemeTile(AppThemeMode mode, Color accent, Color textColor) {
    final active = _settings.themeMode == mode;
    final themeAccent = AppState.recommendedAccent(mode);
    return iOSBounceButton(
      onTap: () {
        _settings.setThemeMode(mode);
        _app.setAccentColor(themeAccent);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.18)
              : _app.surfaceColorSecondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent : _app.cardBorderColor,
            width: active ? 1.6 : 1.0,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _buildThemeIndicator(mode),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mode.label,
                style: TextStyle(
                  color: active ? accent : textColor,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, color: accent, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThemeIndicator(AppThemeMode mode) {
    final Decoration decoration;
    switch (mode) {
      case AppThemeMode.cyberpunk:
        decoration = const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF00F0FF), Color(0xFFFF007F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
        break;
      case AppThemeMode.royalGold:
        decoration = const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
        break;
      case AppThemeMode.aurora:
        decoration = const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFA855F7), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
        break;
      case AppThemeMode.sunsetBliss:
        decoration = const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFF5E62), Color(0xFFFFA07A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
        break;
      case AppThemeMode.iosLiquid:
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0088FF), Color(0xFF60A5FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF0088FF), width: 1.5),
        );
        break;
      case AppThemeMode.oled:
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF000000),
          border: Border.all(color: const Color(0xFFFA2D48), width: 1.8),
        );
        break;
      case AppThemeMode.dark:
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E2230),
          border: Border.all(color: const Color(0xFF64748B), width: 1.4),
        );
        break;
      case AppThemeMode.light:
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
        );
        break;
      case AppThemeMode.system:
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1E2230), Color(0xFFF1F5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
        );
        break;
    }
    return Container(
      width: 15,
      height: 15,
      decoration: decoration,
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

  Widget _buildEngineTile(
    MusicEngine engine,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
  ) {
    final isSelected = SettingsService.instance.musicEngine == engine;
    Color engineColor;
    IconData engineIcon;
    if (engine == MusicEngine.spotify) {
      engineColor = const Color(0xFF1DB954);
      engineIcon = Icons.graphic_eq_rounded;
    } else {
      engineColor = const Color(0xFF10B981);
      engineIcon = Icons.music_note_rounded;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        SettingsService.instance.setMusicEngine(engine);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: engineColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(engineIcon, color: engineColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        engine.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: engineColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: engineColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    engine.description,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                ],
              ),
            ),
            Radio<MusicEngine>(
              value: engine,
              groupValue: SettingsService.instance.musicEngine,
              activeColor: engineColor,
              onChanged: (val) {
                if (val != null) {
                  HapticFeedback.selectionClick();
                  SettingsService.instance.setMusicEngine(val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJioSaavnAccountSection(
    BuildContext context,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    final auth = JioSaavnAuthService.instance;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('JIOSAAVN ACCOUNT / जियोसावन खाता (OTP)', textColor),
            LiquidGlassContainer(
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              blur: 0,
              child: auth.isLoggedIn
                  ? Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF2EA043),
                            backgroundImage: (auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty)
                                ? NetworkImage(auth.avatarUrl!)
                                : null,
                            child: (auth.avatarUrl == null || auth.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person_rounded, color: Colors.white)
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  auth.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF2EA043), size: 16),
                            ],
                          ),
                          subtitle: Text(
                            auth.isSyncing
                                ? 'Syncing playlists & liked songs...'
                                : (auth.lastSyncMessage ?? '100% Ad-Free • Lossless FLAC / 320kbps'),
                            style: TextStyle(
                              fontSize: 12,
                              color: auth.isSyncing ? const Color(0xFF2EA043) : secondaryTextColor,
                            ),
                          ),
                          trailing: auth.isSyncing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2EA043)),
                                )
                              : iOSBounceButton(
                                  onTap: () => auth.syncUserLibrary(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2EA043).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF2EA043).withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sync_rounded, size: 16, color: Color(0xFF2EA043)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Sync',
                                          style: TextStyle(
                                            color: Color(0xFF2EA043),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        _buildDivider(isLight),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                          title: const Text(
                            'Disconnect JioSaavn',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Logout from current session',
                            style: TextStyle(fontSize: 11, color: secondaryTextColor),
                          ),
                          onTap: () => auth.logout(),
                        ),
                      ],
                    )
                  : ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2EA043).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phone_android_rounded,
                          color: Color(0xFF2EA043),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        'Login with JioSaavn (Mobile OTP)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        'Mobile Number + SMS OTP • Sync Liked Songs & Playlists (Ad-Free)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryTextColor,
                        ),
                      ),
                      trailing: iOSBounceButton(
                        onTap: () => JioSaavnLoginSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2EA043), Color(0xFF238636)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2EA043).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Connect',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
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
    return iOSBounceButton(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Padding(
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
            ExcludeFocus(
              excluding: true,
              child: Switch.adaptive(
                value: value,
                activeColor: accent,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppState.translate('crossfade'),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secs == 0
                          ? 'Off (Gapless direct transition)'
                          : '${secs}s seamless BitChord AutoMix transition',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  secs == 0 ? 'Off' : '${secs}s',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: secondaryTextColor.withValues(alpha: 0.2),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: secs.toDouble(),
              min: 0,
              max: 12,
              divisions: 12,
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
    return iOSBounceButton(
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
          blur: 0,
          child: Column(
            children: [
              // User Profile Row
              iOSBounceButton(
                onTap: () => _showEditNameDialog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
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
                              _app.userPhone.isNotEmpty
                                  ? '${_app.userPhone} • Personal Space'
                                  : 'Personal Audio Space (Click to edit)',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ExcludeFocus(
                        excluding: true,
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
                ),
              ),
              const SizedBox(height: 16),
              _buildDivider(isLight),

              // Items
              // 1. Local Storage Music
              _buildLibraryTile(
                icon: Icons.folder_open_rounded,
                title: 'Local Storage Music (लोकल संगीत)',
                count: '${MediaScanner.lastScannedAudios.length} Tracks',
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                accent: accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocalStorageMusicScreen()),
                  );
                },
              ),
              _buildDivider(isLight),

              // 2. Liked Songs
              ListenableBuilder(
                listenable: _app,
                builder: (context, _) => _buildLibraryTile(
                  icon: Icons.favorite_rounded,
                  title: 'Liked Songs (पसंदीदा गाने)',
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

              // 3. Downloads
              ListenableBuilder(
                listenable: DownloadService.instance,
                builder: (context, _) => _buildLibraryTile(
                  icon: Icons.download_rounded,
                  title: 'Downloads (डाउनलोड)',
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

              // 4. Playlists
              ListenableBuilder(
                listenable: _app,
                builder: (context, _) => _buildLibraryTile(
                  icon: Icons.queue_music_rounded,
                  title: 'Playlists (प्लेलिस्ट)',
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
    return iOSBounceButton(
      onTap: onTap,
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
    final phoneController = TextEditingController(text: _app.userPhone);
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
          'Edit Profile',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _app.secondaryTextColor)),
            const SizedBox(height: 6),
            TextField(
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
            const SizedBox(height: 14),
            Text('Mobile Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _app.secondaryTextColor)),
            const SizedBox(height: 6),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter mobile number (e.g. +91 98765 43210)',
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
          ],
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
              }
              _app.setUserPhone(phoneController.text.trim());
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBackupRestoreSheet(
    BuildContext context,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF141926).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.backup_rounded, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Data Backup & Restore',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Local JSON archive • 100% Offline & Private',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              iOSBounceButton(
                onTap: () async {
                  Navigator.pop(sheetContext);
                  HapticFeedback.mediumImpact();
                  try {
                    final summary = await BackupRestoreService.instance.exportBackup();
                    if (!context.mounted) return;
                    _showBackupSummaryDialog(context, summary, isExport: true, textColor: textColor, secondaryTextColor: secondaryTextColor, accent: accent, isLight: isLight);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Backup failed: $e'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.file_upload_rounded, color: accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Export Backup (Save to Device)',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              'Saves playlists, favorites, radio & resume positions as JSON',
                              style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<File>>(
                future: BackupRestoreService.instance.listBackups(),
                builder: (context, snapshot) {
                  final files = snapshot.data ?? [];
                  if (files.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: secondaryTextColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No existing backups found. Export a backup first to restore later.',
                              style: TextStyle(color: secondaryTextColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESTORE FROM EXISTING BACKUP',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: files.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final file = files[i];
                            final name = file.path.split('/').last;
                            final date = file.lastModifiedSync();
                            final size = formatBytes(file.lengthSync());
                            return iOSBounceButton(
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                HapticFeedback.mediumImpact();
                                _confirmAndRestore(context, file, textColor, secondaryTextColor, accent, isLight);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.settings_backup_restore_rounded, color: accent, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')} • $size',
                                            style: TextStyle(color: secondaryTextColor, fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Restore',
                                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
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
            ],
          ),
        );
      },
    );
  }

  void _confirmAndRestore(
    BuildContext context,
    File file,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          backgroundColor: isLight ? Colors.white : const Color(0xFF1E2433),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Restore Backup?', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
          content: Text(
            'This will safely merge and restore your saved playlists, favorite songs, radio stations, and resume positions from "${file.path.split('/').last}".',
            style: TextStyle(color: secondaryTextColor, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(dlgContext);
                try {
                  final summary = await BackupRestoreService.instance.restoreBackup(file);
                  if (!context.mounted) return;
                  _showBackupSummaryDialog(context, summary, isExport: false, textColor: textColor, secondaryTextColor: secondaryTextColor, accent: accent, isLight: isLight);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Restore error: $e'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Restore Now'),
            ),
          ],
        );
      },
    );
  }

  void _showBackupSummaryDialog(
    BuildContext context,
    BackupSummary summary, {
    required bool isExport,
    required Color textColor,
    required Color secondaryTextColor,
    required Color accent,
    required bool isLight,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF161C2C),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExport ? Icons.check_circle_rounded : Icons.cloud_done_rounded,
                        color: accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExport ? 'Backup Export Complete! ✅' : 'Restore Successful! 🎉',
                            style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            summary.formattedDate,
                            style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('🎵 Playlists', '${summary.playlistsCount + summary.customPlaylistsCount}', textColor, secondaryTextColor),
                      const SizedBox(height: 6),
                      _buildSummaryRow('⭐ Favorite Songs', '${summary.favoriteSongsCount}', textColor, secondaryTextColor),
                      const SizedBox(height: 6),
                      _buildSummaryRow('📻 Favorite Radio Stations', '${summary.favoriteStationsCount}', textColor, secondaryTextColor),
                      const SizedBox(height: 6),
                      _buildSummaryRow('🎬 Video & Episode Resumes', '${summary.videoPositionsCount + summary.episodePositionsCount}', textColor, secondaryTextColor),
                      const SizedBox(height: 6),
                      _buildSummaryRow('🔍 Search Queries Saved', '${summary.searchHistoryCount}', textColor, secondaryTextColor),
                      const SizedBox(height: 6),
                      _buildSummaryRow('🎨 Active Theme', summary.themeMode, textColor, secondaryTextColor),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Saved to: ${summary.filePath.split('/').last}',
                  style: TextStyle(color: secondaryTextColor, fontSize: 11, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, Color textColor, Color secondaryTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 12.5)),
        Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  void _showCacheCleanupSheet(
    BuildContext context,
    Color textColor,
    Color secondaryTextColor,
    Color accent,
    bool isLight,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FutureBuilder<CacheInfo>(
          future: CacheService.instance.getCacheSize(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final sizeStr = info != null ? info.formattedSize : 'Calculating...';

            return Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isLight ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF141926).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.cleaning_services_rounded, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Safe Cache / Temp Cleanup',
                              style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Current Cache: $sizeStr',
                              style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security_rounded, color: Colors.greenAccent.shade700, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Strict Safety Guarantee',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Clears ONLY temporary network buffer images and stream temp files. Your playlists, favorites, offline downloads, backups, and resume timestamps will be strictly preserved.',
                          style: TextStyle(color: secondaryTextColor, fontSize: 12, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    label: Text(
                      'Clear Temporary Cache ($sizeStr)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      HapticFeedback.mediumImpact();
                      final freed = await CacheService.instance.clearSafeCache();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Freed ${freed.formattedSize} temporary cache safely! ✅'),
                          backgroundColor: Colors.green.shade700,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

