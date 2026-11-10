import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../services/media_scanner.dart';
import '../utils/format.dart';
import '../widgets/art_box.dart';
import '../widgets/glass_bars.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';

class AudioTrimmerScreen extends StatefulWidget {
  const AudioTrimmerScreen({
    super.key,
    this.initialTrack,
    this.availableTracks = const [],
  });

  final MediaFile? initialTrack;
  final List<MediaFile> availableTracks;

  @override
  State<AudioTrimmerScreen> createState() => _AudioTrimmerScreenState();
}

class _AudioTrimmerScreenState extends State<AudioTrimmerScreen> {
  final AudioPlayer _player = AudioPlayer();
  MediaFile? _selectedTrack;
  List<MediaFile> _allAudios = [];

  double _totalDurationSec = 60.0;
  double _startSec = 0.0;
  double _endSec = 30.0;
  double _currentPosSec = 0.0;
  bool _isPlaying = false;
  bool _isProcessing = false;
  String? _savedPath;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  bool _isLoadingAudios = false;

  @override
  void initState() {
    super.initState();
    _allAudios = List<MediaFile>.from(
      widget.availableTracks.isNotEmpty
          ? widget.availableTracks
          : (MediaScanner.lastScannedAudios.isNotEmpty
              ? MediaScanner.lastScannedAudios
              : AudioController.instance.queue),
    );

    _selectedTrack = widget.initialTrack ??
        (_allAudios.isNotEmpty ? _allAudios.first : null);

    _posSub = _player.positionStream.listen((pos) {
      if (!mounted) return;
      final cur = pos.inMilliseconds / 1000.0;
      setState(() => _currentPosSec = cur);

      // Loop or stop if reaching end of trimmed selection
      if (cur >= _endSec && _isPlaying) {
        _player.seek(Duration(milliseconds: (_startSec * 1000).round()));
      }
    });

    _stateSub = _player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _isPlaying = st.playing);
    });

    if (_selectedTrack != null) {
      _loadTrack(_selectedTrack!);
    } else {
      _loadDeviceAudioTracks();
    }
  }

  Future<void> _loadDeviceAudioTracks() async {
    setState(() => _isLoadingAudios = true);
    try {
      final tracks = await MediaScanner.scan(MediaKind.audio);
      if (mounted && tracks.isNotEmpty) {
        setState(() {
          _allAudios = tracks;
          _isLoadingAudios = false;
          if (_selectedTrack == null) {
            _selectedTrack = tracks.first;
            _loadTrack(_selectedTrack!);
          }
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingAudios = false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadTrack(MediaFile track) async {
    try {
      await _player.pause();
      setState(() {
        _selectedTrack = track;
        _savedPath = null;
      });

      if (File(track.path).existsSync()) {
        final dur = await _player.setFilePath(track.path);
        final total = (dur?.inMilliseconds ?? 60000) / 1000.0;
        setState(() {
          _totalDurationSec = math.max(total, 5.0);
          _startSec = 0.0;
          _endSec = math.min(30.0, _totalDurationSec);
          _currentPosSec = 0.0;
        });
      }
    } catch (_) {}
  }

  void _togglePreview() {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      _player.pause();
    } else {
      if (_currentPosSec < _startSec || _currentPosSec >= _endSec) {
        _player.seek(Duration(milliseconds: (_startSec * 1000).round()));
      }
      _player.play();
    }
  }

  void _setPresetDuration(double seconds) {
    HapticFeedback.selectionClick();
    setState(() {
      final available = _totalDurationSec - _startSec;
      _endSec = _startSec + math.min(seconds, available);
      if (_endSec <= _startSec) {
        _startSec = math.max(0.0, _totalDurationSec - seconds);
        _endSec = _totalDurationSec;
      }
    });
    _player.seek(Duration(milliseconds: (_startSec * 1000).round()));
  }

  Future<void> _trimAndSave() async {
    final track = _selectedTrack;
    if (track == null) return;

    setState(() => _isProcessing = true);
    await _player.pause();

    try {
      final sourceFile = File(track.path);
      if (!sourceFile.existsSync()) {
        throw Exception('Audio file not found on disk');
      }

      final fileBytes = await sourceFile.readAsBytes();
      final totalLen = fileBytes.length;

      // Calculate byte offsets
      final startRatio = (_startSec / _totalDurationSec).clamp(0.0, 1.0);
      final endRatio = (_endSec / _totalDurationSec).clamp(0.0, 1.0);

      int startByte = (totalLen * startRatio).round();
      int endByte = (totalLen * endRatio).round();

      // Search for MPEG frame sync boundary (0xFF 0xFA or 0xFF 0xFB) within 4KB
      if (startByte > 0 && startByte < totalLen - 2) {
        for (int i = startByte; i < math.min(startByte + 4096, totalLen - 1); i++) {
          if (fileBytes[i] == 0xFF && (fileBytes[i + 1] & 0xE0) == 0xE0) {
            startByte = i;
            break;
          }
        }
      }

      if (endByte <= startByte) {
        endByte = math.min(startByte + 1024 * 500, totalLen);
      }

      final trimmedBytes = fileBytes.sublist(startByte, endByte);

      // Determine destination directory
      Directory destDir = Directory('/storage/emulated/0/Ringtones');
      if (!destDir.existsSync()) {
        try {
          destDir.createSync(recursive: true);
        } catch (_) {
          destDir = Directory('/data/user/0/com.rvbhati.player/files/Ringtones');
          if (!destDir.existsSync()) destDir.createSync(recursive: true);
        }
      }

      final cleanName = track.title.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      final targetName = '${cleanName.isNotEmpty ? cleanName : 'Ringtone'}_${DateTime.now().millisecondsSinceEpoch % 10000}.mp3';
      final targetFile = File('${destDir.path}/$targetName');
      await targetFile.writeAsBytes(trimmedBytes);

      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _savedPath = targetFile.path;
        });
        _showSuccessDialog(targetFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ringtone: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showTrackPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            return LiquidGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              tint: const Color(0xFF14192B),
              borderColor: Colors.white24,
              blur: 25,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 14),
                  const Text('Select Track to Trim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 12),
                  if (_isLoadingAudios)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppState.instance.accentColor),
                            const SizedBox(height: 12),
                            const Text('Scanning audio files...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  else if (_allAudios.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_off_rounded, color: Colors.white38, size: 52),
                            const SizedBox(height: 12),
                            const Text(
                              'No local audio tracks found yet',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Scan your storage to load device music',
                              style: TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 18),
                            LiquidGlassButton(
                              icon: Icons.refresh_rounded,
                              label: 'Scan Storage Now',
                              tint: AppState.instance.accentColor,
                              size: 42,
                              onTap: () async {
                                setPickerState(() => _isLoadingAudios = true);
                                final tracks = await MediaScanner.scan(MediaKind.audio);
                                if (mounted) {
                                  setState(() {
                                    _allAudios = tracks;
                                    _isLoadingAudios = false;
                                    if (_selectedTrack == null && tracks.isNotEmpty) {
                                      _selectedTrack = tracks.first;
                                      _loadTrack(_selectedTrack!);
                                    }
                                  });
                                  setPickerState(() => _isLoadingAudios = false);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _allAudios.length,
                        itemBuilder: (context, i) {
                          final item = _allAudios[i];
                          final isSel = _selectedTrack?.id == item.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _loadTrack(item);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppState.instance.accentColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSel ? AppState.instance.accentColor : Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: item.embeddedArt != null
                                            ? Image.memory(item.embeddedArt!, fit: BoxFit.cover)
                                            : ArtBox(seed: item.title, radius: 10, iconSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                          const SizedBox(height: 2),
                                          Text(item.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                                        ],
                                      ),
                                    ),
                                    if (isSel)
                                      Icon(Icons.check_circle_rounded, color: AppState.instance.accentColor, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (context) {
        final accent = AppState.instance.accentColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(24),
            tint: const Color(0xFF14192B),
            borderColor: Colors.white24,
            blur: 25,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  ),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 34),
                ),
                const SizedBox(height: 16),
                const Text('Ringtone Saved Successfully!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                Text('File saved to:\n$path', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: path));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File path copied! Set in Sound Settings.')),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.8)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Copy File Path & Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final accent = app.accentColor;
    final track = _selectedTrack;
    final selectionDur = (_endSec - _startSec).clamp(0.0, _totalDurationSec);

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: GlassTopBar(
                  title: 'Ringtone Cutter',
                  subtitle: 'Trim & Create Custom Tones',
                  leading: LiquidGlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 44,
                    iconSize: 20,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  actions: [
                    LiquidGlassButton(
                      icon: Icons.library_music_rounded,
                      size: 44,
                      iconSize: 22,
                      tint: accent,
                      onTap: _showTrackPicker,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: track == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_off_rounded, size: 50, color: Colors.white54),
                            const SizedBox(height: 12),
                            const Text('No audio file selected', style: TextStyle(color: Colors.white70, fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _showTrackPicker, child: const Text('Select Track')),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Column(
                          children: [
                            // 1. Artwork & Info Card
                            LiquidGlassContainer(
                              borderRadius: BorderRadius.circular(26),
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: track.embeddedArt != null
                                          ? Image.memory(track.embeddedArt!, fit: BoxFit.cover)
                                          : ArtBox(seed: track.title, radius: 16, iconSize: 28),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: app.textColor)),
                                        const SizedBox(height: 4),
                                        Text(track.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: app.secondaryTextColor)),
                                        const SizedBox(height: 4),
                                        Text('Total: ${formatDuration(Duration(seconds: _totalDurationSec.round()))}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.swap_horiz_rounded),
                                    color: accent,
                                    onPressed: _showTrackPicker,
                                    tooltip: 'Change Song',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 2. Waveform & Range Slider Card
                            LiquidGlassContainer(
                              borderRadius: BorderRadius.circular(26),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Selection Length:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: app.textColor)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: accent),
                                        ),
                                        child: Text(
                                          '${selectionDur.toStringAsFixed(1)}s',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Visual Trim Range Slider
                                  RangeSlider(
                                    values: RangeValues(_startSec, _endSec),
                                    min: 0.0,
                                    max: _totalDurationSec,
                                    activeColor: accent,
                                    inactiveColor: Colors.white24,
                                    onChanged: (vals) {
                                      setState(() {
                                        _startSec = vals.start;
                                        _endSec = vals.end;
                                      });
                                    },
                                    onChangeEnd: (vals) {
                                      _player.seek(Duration(milliseconds: (vals.start * 1000).round()));
                                    },
                                  ),

                                  // Start & End Timestamps
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Start Point', style: TextStyle(fontSize: 11, color: app.secondaryTextColor)),
                                          Text(formatDuration(Duration(seconds: _startSec.round())), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: app.textColor)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('End Point', style: TextStyle(fontSize: 11, color: app.secondaryTextColor)),
                                          Text(formatDuration(Duration(seconds: _endSec.round())), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: app.textColor)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // Quick Preset Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _presetButton('15s', 15.0),
                                      _presetButton('30s (Default)', 30.0),
                                      _presetButton('45s', 45.0),
                                      _presetButton('Full', _totalDurationSec),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 3. Play Preview Control
                            Center(
                              child: GestureDetector(
                                onTap: _togglePreview,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [accent, accent.withValues(alpha: 0.75)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.4),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isPlaying ? 'Playing Preview Segment...' : 'Tap to Preview Trimmed Clip',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: app.secondaryTextColor),
                            ),
                            const SizedBox(height: 24),

                            // 4. Save Ringtone Button
                            GestureDetector(
                              onTap: _isProcessing ? null : _trimAndSave,
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [accent, accent.withValues(alpha: 0.85)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: _isProcessing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.content_cut_rounded, color: Colors.white, size: 22),
                                          SizedBox(width: 10),
                                          Text('Trim & Save as Ringtone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                        ],
                                      ),
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

  Widget _presetButton(String label, double seconds) {
    return GestureDetector(
      onTap: () => _setPresetDuration(seconds),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppState.instance.textColor),
        ),
      ),
    );
  }
}
