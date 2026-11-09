import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/update_dialog.dart';

class UpdateInfo {
  final String version;
  final String title;
  final String changelog;
  final String apkUrl;
  final int apkSize;

  UpdateInfo({
    required this.version,
    required this.title,
    required this.changelog,
    required this.apkUrl,
    required this.apkSize,
  });
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String currentVersion = '1.2.6';
  static const int currentBuildNumber = 18;

  static const String _releasesUrl =
      'https://api.github.com/repos/revantram/rv-bhati-player/releases/latest';
  static const MethodChannel _updaterChannel =
      MethodChannel('com.rvbhati.player/updater');

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// Check GitHub Releases for newer version
  Future<UpdateInfo?> checkForUpdate() async {
    _isChecking = true;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.getUrl(Uri.parse(_releasesUrl));
      request.headers.set('User-Agent', 'RV-Bhati-Player/$currentVersion');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = json.decode(body) as Map<String, dynamic>;

      final tagName = (data['tag_name'] as String? ?? '').trim();
      final releaseName = (data['name'] as String? ?? 'New Update').trim();
      final changelog = (data['body'] as String? ?? '').trim();
      final assets = (data['assets'] as List<dynamic>? ?? []);

      // Find APK asset (prefer RV-Bhati-Player.apk or arm64)
      String? apkUrl;
      int apkSize = 0;

      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name == 'rv-bhati-player.apk' || name.contains('arm64')) {
          apkUrl = a['browser_download_url'] as String?;
          apkSize = (a['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }

      if (apkUrl == null && assets.isNotEmpty) {
        for (final a in assets) {
          final name = (a['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkUrl = a['browser_download_url'] as String?;
            apkSize = (a['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }

      if (tagName.isEmpty || apkUrl == null) {
        return null;
      }

      final cleanLatest = tagName.replaceAll(RegExp(r'^v'), '').split('+')[0];
      if (_isNewer(cleanLatest, currentVersion)) {
        return UpdateInfo(
          version: tagName.startsWith('v') ? tagName : 'v$tagName',
          title: releaseName,
          changelog: changelog,
          apkUrl: apkUrl,
          apkSize: apkSize,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    } finally {
      client.close();
      _isChecking = false;
    }
  }

  /// Compare two semantic version strings e.g. "1.1.7" vs "1.1.6"
  bool _isNewer(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (lParts.length < 3) lParts.add(0);
      while (cParts.length < 3) cParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (lParts[i] > cParts[i]) return true;
        if (lParts[i] < cParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Download APK to storage and invoke native package installer
  Future<File?> downloadApk(
    String url, {
    required void Function(double progress, int received, int total) onProgress,
  }) async {
    final client = HttpClient();
    client.autoUncompress = true;

    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 8;
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }

      Directory targetDir = Directory('/storage/emulated/0/Download');
      if (!await targetDir.exists()) {
        targetDir = Directory('/sdcard/Download');
        if (!await targetDir.exists()) {
          targetDir = Directory.systemTemp;
        }
      }

      final targetFile = File('${targetDir.path}/RV-Bhati-Player-update.apk');
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      final total = response.contentLength;
      int received = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress(received / total, received, total);
        }
      }

      await sink.flush();
      await sink.close();
      return targetFile;
    } finally {
      client.close();
    }
  }

  /// Trigger native Android package installer
  Future<bool> installApk(String filePath) async {
    try {
      final res = await _updaterChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return res ?? false;
    } catch (e) {
      debugPrint('Install error: $e');
      return false;
    }
  }

  /// Automatically check on app startup or manual check in settings
  Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool showUpToDate = false,
  }) async {
    final info = await checkForUpdate();
    if (!context.mounted) return;

    if (info != null) {
      UpdateDialog.show(context, info);
    } else if (showUpToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aapka RV Bhati Player latest version (v$currentVersion) par hai! ✅',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
