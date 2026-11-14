import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/online_song.dart';
import 'media_action_service.dart';
import 'yt_audio_resolver.dart';

class DownloadedSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String imageUrl;
  final String localPath;
  final int fileSizeBytes;
  final DateTime downloadedAt;

  const DownloadedSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.imageUrl,
    required this.localPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'imageUrl': imageUrl,
        'localPath': localPath,
        'fileSizeBytes': fileSizeBytes,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory DownloadedSong.fromJson(Map<String, dynamic> json) {
    return DownloadedSong(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Song',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      album: json['album']?.toString() ?? 'RV Player Downloads',
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      imageUrl: json['imageUrl']?.toString() ?? '',
      localPath: json['localPath']?.toString() ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  OnlineSong toOnlineSong() {
    return OnlineSong(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      imageUrl: imageUrl,
      streamUrl: localPath, // Direct local file URI
    );
  }
}

class DownloadService extends ChangeNotifier {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  final List<DownloadedSong> _downloadedSongs = [];
  final Map<String, double> _progress = {}; // songId -> 0.0 .. 1.0
  final Set<String> _activeDownloads = {};

  List<DownloadedSong> get downloadedSongs => List.unmodifiable(_downloadedSongs);
  Map<String, double> get progress => Map.unmodifiable(_progress);

  bool isDownloading(String id) => _activeDownloads.contains(id);
  bool isDownloaded(String id) => _downloadedSongs.any((s) => s.id == id);
  double getProgress(String id) => _progress[id] ?? 0.0;

  DownloadedSong? getSong(String id) {
    final idx = _downloadedSongs.indexWhere((s) => s.id == id);
    return idx != -1 ? _downloadedSongs[idx] : null;
  }

  Future<void> init() async {
    await _loadFromDisk();
  }

  Future<Directory> _getDownloadDirectory() async {
    // 1. Primary Public Download folder (visible to all file managers & media players)
    final dlDir = Directory('/storage/emulated/0/Download/RV-Bhati-Player');
    try {
      if (!dlDir.existsSync()) {
        dlDir.createSync(recursive: true);
      }
      return dlDir;
    } catch (_) {}

    // 2. Secondary Public Music folder
    final musicDir = Directory('/storage/emulated/0/Music/RV-Bhati-Player');
    try {
      if (!musicDir.existsSync()) {
        musicDir.createSync(recursive: true);
      }
      return musicDir;
    } catch (_) {}

    // 3. Standard public Download root
    final rootDl = Directory('/storage/emulated/0/Download');
    try {
      if (rootDl.existsSync()) {
        return rootDl;
      }
    } catch (_) {}

    // 4. Fallback to App internal storage if external cannot be written
    final internalDir = Directory('/data/user/0/com.rvbhati.player/files/Downloads');
    if (!internalDir.existsSync()) {
      internalDir.createSync(recursive: true);
    }
    return internalDir;
  }

  File _getMetadataFile() {
    return File('/data/user/0/com.rvbhati.player/files/downloaded_songs_v2.json');
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = _getMetadataFile();
      if (!file.existsSync()) return;

      final jsonStr = await file.readAsString();
      if (jsonStr.isEmpty) return;

      final list = jsonDecode(jsonStr) as List?;
      if (list == null) return;

      _downloadedSongs.clear();
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final s = DownloadedSong.fromJson(item);
          // Only keep if the local audio file still exists
          if (File(s.localPath).existsSync()) {
            _downloadedSongs.add(s);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[DownloadService] load error: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = _getMetadataFile();
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final data = jsonEncode(_downloadedSongs.map((s) => s.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('[DownloadService] save error: $e');
    }
  }

  Future<bool> downloadSong(OnlineSong song) async {
    if (isDownloading(song.id) || isDownloaded(song.id)) {
      return true;
    }

    _activeDownloads.add(song.id);
    _progress[song.id] = 0.02;
    notifyListeners();

    try {
      // 1. Resolve direct non-HLS stream URL + headers
      String streamUrl = song.getStreamUrlForBitrate(320);
      if (streamUrl.isEmpty) {
        streamUrl = song.streamUrl;
      }
      Map<String, String>? streamHeaders;
      if (streamUrl.isEmpty || song.id.startsWith('yt_')) {
        final ytId = song.id.startsWith('yt_') ? song.id.replaceFirst('yt_', '') : song.id;
        final resolved = await YtAudioResolver.resolveBestForDownload(
          ytId,
          fallbackTitle: song.title,
          fallbackArtist: song.artist,
        );
        if (resolved != null && resolved.url.isNotEmpty) {
          streamUrl = resolved.url;
          streamHeaders = resolved.headers;
        }
      }

      if (streamUrl.isEmpty) {
        throw Exception('Stream URL could not be resolved');
      }

      final dir = await _getDownloadDirectory();
      final cleanTitle = song.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final cleanArtist = song.artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final filename = '${cleanTitle}_$cleanArtist.m4a'.replaceAll(' ', '_');
      final targetFile = File('${dir.path}/$filename');

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      if (streamHeaders != null) {
        request.headers.addAll(streamHeaders);
      }
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw Exception('HTTP error ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _progress[song.id] = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      final downloadedSong = DownloadedSong(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        imageUrl: song.imageUrl,
        localPath: targetFile.path,
        fileSizeBytes: receivedBytes,
        downloadedAt: DateTime.now(),
      );

      _downloadedSongs.insert(0, downloadedSong);
      await _saveToDisk();

      // Trigger MediaScanner so third party music players can immediately find and play it
      await MediaActionService.scanFile(targetFile.path);

      _progress.remove(song.id);
      _activeDownloads.remove(song.id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[DownloadService] download failed: $e');
      _progress.remove(song.id);
      _activeDownloads.remove(song.id);
      notifyListeners();
      return false;
    }
  }

  Future<bool> downloadVideo(OnlineSong song) async {
    if (isDownloading(song.id)) return true;

    _activeDownloads.add(song.id);
    _progress[song.id] = 0.02;
    notifyListeners();

    try {
      final ytId = song.id.startsWith('yt_') ? song.id.replaceFirst('yt_', '') : song.id;
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(ytId);
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      if (muxedStreams.isEmpty) {
        yt.close();
        return downloadSong(song);
      }
      final streamInfo = muxedStreams.last;

      final dir = Directory('/storage/emulated/0/Download/RV-Bhati-Player/Videos');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final cleanTitle = song.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final filename = '${cleanTitle}.mp4'.replaceAll(' ', '_');
      final targetFile = File('${dir.path}/$filename');

      final stream = yt.videos.streamsClient.get(streamInfo);
      final sink = targetFile.openWrite();
      final totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      await for (final chunk in stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _progress[song.id] = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      yt.close();

      await MediaActionService.scanFile(targetFile.path);

      _progress.remove(song.id);
      _activeDownloads.remove(song.id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[DownloadService] video download error: $e');
      _progress.remove(song.id);
      _activeDownloads.remove(song.id);
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteSong(String id) async {
    final idx = _downloadedSongs.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final song = _downloadedSongs.removeAt(idx);
      try {
        final f = File(song.localPath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
      await _saveToDisk();
      notifyListeners();
    }
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
