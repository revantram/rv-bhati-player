import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/update_service.dart';
import '../utils/format.dart';
import 'ios_bounce_button.dart';
import 'liquid_glass_container.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.info.apkSize;
    });

    try {
      final file = await UpdateService.instance.downloadApk(
        widget.info.apkUrl,
        onProgress: (p, rec, tot) {
          if (mounted) {
            setState(() {
              _progress = p;
              _receivedBytes = rec;
              _totalBytes = tot;
            });
          }
        },
      );

      if (file == null || !await file.exists()) {
        throw Exception('Download failed or file not found.');
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = true;
        });
      }

      final success = await UpdateService.instance.installApk(file.path);
      if (!success && mounted) {
        setState(() {
          _isInstalling = false;
          _errorMessage = 'Installation intent failed to launch.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
          _errorMessage = 'Update error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isLight = app.isLight;
    final textColor = app.textColor;
    final secondaryTextColor = app.secondaryTextColor;
    final accent = app.accentColor;

    return PopScope(
      canPop: !_isDownloading && !_isInstalling,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(24),
            blur: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Icon & Badge
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, const Color(0xFF00D2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Center(
                  child: Text(
                    'नया अपडेट उपलब्ध है!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Version Tag Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'v${UpdateService.currentVersion}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: accent,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${widget.info.version} (NEW)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Release Title & Changelog Box
                if (widget.info.changelog.isNotEmpty) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        widget.info.changelog,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Error Message if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF5252),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // Progress Bar while downloading
                if (_isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: isLight ? Colors.black12 : Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'डाउनलोड हो रहा है... ${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (_totalBytes > 0)
                        Text(
                          '${formatBytes(_receivedBytes)} / ${formatBytes(_totalBytes)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else if (_isInstalling) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'पैकेज इंस्टालर ओपन हो रहा है...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                if (!_isDownloading && !_isInstalling) ...[
                  iOSBounceButton(
                    onTap: _startUpdate,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, const Color(0xFF00D2FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.info.apkSize > 0
                                  ? 'अभी अपडेट करें (${formatBytes(widget.info.apkSize)})'
                                  : 'अभी अपडेट करें',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'बाद में',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
