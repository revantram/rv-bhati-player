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

  static const String currentVersion = '1.4.34';
  static const int currentBuildNumber = 99;

  static const String _releasesListUrl =
      'https://api.github.com/repos/revantram/rv-bhati-player/releases?per_page=10';
  static const String _rawPubspecUrl =
      'https://raw.githubusercontent.com/revantram/rv-bhati-player/main/pubspec.yaml';
  static const MethodChannel _updaterChannel =
      MethodChannel('com.rvbhati.player/updater');

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// Check GitHub Releases and raw repository for newer version
  Future<UpdateInfo?> checkForUpdate() async {
    _isChecking = true;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      // 1. First try GitHub Releases List API
      try {
        final request = await client.getUrl(Uri.parse(_releasesListUrl));
        request.headers.set('User-Agent', 'RV-Bhati-Player/$currentVersion');
        request.headers.set('Accept', 'application/vnd.github.v3+json');

        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = json.decode(body);
          if (data is List && data.isNotEmpty) {
            for (final rel in data) {
              if (rel is! Map<String, dynamic>) continue;
              final tagName = (rel['tag_name'] as String? ?? '').trim();
              final releaseName = (rel['name'] as String? ?? '').trim();
              final changelog = (rel['body'] as String? ?? '').trim();
              final assets = (rel['assets'] as List<dynamic>? ?? []);

              // Extract semantic version from tag or title
              final verMatch = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(tagName) ??
                  RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(releaseName);
              if (verMatch != null) {
                final foundVer = verMatch.group(1)!;
                if (_isNewer(foundVer, currentVersion)) {
                  String? apkUrl;
                  int apkSize = 0;
                  for (final a in assets) {
                    final name = (a['name'] as String? ?? '').toLowerCase();
                    if (name.contains('arm64') || name == 'rv-bhati-player.apk') {
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
                  if (apkUrl != null) {
                    return UpdateInfo(
                      version: 'v$foundVer',
                      title: releaseName.isNotEmpty ? releaseName : 'RV Bhati Player v$foundVer',
                      changelog: changelog.isNotEmpty ? changelog : 'New features, improved performance, and bug fixes.',
                      apkUrl: apkUrl,
                      apkSize: apkSize,
                    );
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[UpdateService] releases list check error: $e');
      }

      // 2. High-reliability fallback: Check raw pubspec.yaml on GitHub main branch (never rate-limited)
      try {
        final rawReq = await client.getUrl(Uri.parse(_rawPubspecUrl));
        rawReq.headers.set('User-Agent', 'RV-Bhati-Player/$currentVersion');
        final rawResp = await rawReq.close();
        if (rawResp.statusCode == 200) {
          final yamlText = await rawResp.transform(utf8.decoder).join();
          final m = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(yamlText);
          if (m != null) {
            final remoteVer = m.group(1)!;
            if (_isNewer(remoteVer, currentVersion)) {
              return UpdateInfo(
                version: 'v$remoteVer',
                title: 'RV Bhati Player v$remoteVer (Latest Update)',
                changelog: 'Latest stable release with performance upgrades, stream reliability, and iOS 18 Liquid Glass polish.',
                apkUrl: 'https://github.com/revantram/rv-bhati-player/releases/latest/download/RV-Bhati-Player-arm64.apk',
                apkSize: 24000000,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[UpdateService] raw pubspec fallback error: $e');
      }

      return null;
    } catch (e) {
      debugPrint('[UpdateService] Update check error: $e');
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
      request.headers.set('Connection', 'close');
      request.headers.set('User-Agent', 'RV-Bhati-Player/$currentVersion');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }

      Directory targetDir = Directory('/data/user/0/com.rvbhati.player/cache');
      if (!await targetDir.exists()) {
        targetDir = Directory.systemTemp;
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
          if (received >= total) {
            break;
          }
        }
      }

      await sink.flush();
      await sink.close();

      // Also copy to Download folder as convenient backup for user
      try {
        final dlDir = Directory('/storage/emulated/0/Download');
        if (await dlDir.exists()) {
          await targetFile.copy('${dlDir.path}/RV-Bhati-Player.apk');
        }
      } catch (_) {}

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
      UpdateDialog.showUpToDateSheet(context);
    }
  }
}
