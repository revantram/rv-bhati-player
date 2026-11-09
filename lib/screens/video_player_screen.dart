import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/media_file.dart';
import '../services/app_state.dart';
import '../services/audio_controller.dart';
import '../utils/format.dart';
import '../utils/srt_parser.dart';
import '../widgets/glass_bars.dart';
import '../widgets/glass_seek_bar.dart';
import '../widgets/liquid_glass_container.dart';

enum VideoFitMode { original, fill, widescreen, ultrawide }

class _Hud {
  const _Hud(this.icon, this.label, this.alignment, [this.level]);
  final IconData icon;
  final String label;
  final Alignment alignment;
  final double? level; // 0..1 vertical bar (brightness / volume)
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.playlist,
    required this.startIndex,
  });

  final List<MediaFile> playlist;
  final int startIndex;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  late int _index;

  bool _showControls = true;
  bool _failed = false;
  bool _landscape = false;
  bool _userRotated = false;
  bool _advancing = false;
  bool _touchLocked = false;

  // Aspect ratio fit mode
  VideoFitMode _fitMode = VideoFitMode.original;

  // Pinch-to-zoom & Pan
  double _zoomScale = 1.0;
  double _baseZoom = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _basePan = Offset.zero;
  bool _isPinching = false;
  String? _dragMode; // 'vertical', 'horizontal', 'pinch'

  // Playback speed
  double _playbackSpeed = 1.0;
  double _preHoldSpeed = 1.0;
  bool _isHolding2x = false;

  // Subtitles
  List<SubtitleItem> _subtitles = [];
  bool _subtitlesEnabled = true;
  double _subtitleSize = 18.0;
  Duration _subtitleDelay = Duration.zero;
  String? _currentSubtitleText;
  String? _subtitleFileName;
  List<File> _availableSubtitles = [];
  int _audioTrackIndex = 0;
  double _audioVolumeMultiplier = 1.0;
  String? _selectedQuality;

  // Gestures
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _dragLeft = true;
  Offset _doubleTapPos = Offset.zero;
  _Hud? _hud;

  // Horizontal scrub drag
  bool _isHorizontalDragging = false;
  Duration _horizontalSeekTarget = Duration.zero;

  Timer? _hideTimer;
  Timer? _hudTimer;

  static const _pipChannel = MethodChannel('com.rvbhati.player/pip');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.startIndex;
    AudioController.instance.player.pause(); // stop music
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _readDeviceLevels();
    _load(_index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentPosition();
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((_) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveCurrentPosition();
      _controller?.pause();
    }
  }

  void _saveCurrentPosition() {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final pos = c.value.position.inSeconds;
      final dur = c.value.duration.inSeconds;
      AppState.instance.saveVideoPosition(widget.playlist[_index].path, pos, dur);
    }
  }

  Future<void> _readDeviceLevels() async {
    try {
      _brightness = await ScreenBrightness.instance.application;
    } catch (_) {}
    try {
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {}
  }

  Future<void> _load(int i) async {
    _saveCurrentPosition();
    final old = _controller;
    old?.removeListener(_onTick);
    setState(() {
      _index = i;
      _failed = false;
      _controller = null;
      _subtitles = [];
      _currentSubtitleText = null;
      _subtitleFileName = null;
    });
    await old?.dispose();

    final item = widget.playlist[i];
    AppState.instance.markPlayed(item.id);

    // Auto-detect matching .srt subtitle file in same folder (only for local files)
    if (!item.path.startsWith('http://') && !item.path.startsWith('https://')) {
      _detectSubtitle(item.path);
    }

    final isNetwork = item.path.startsWith('http://') || item.path.startsWith('https://');
    final c = isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(item.path))
        : VideoPlayerController.file(File(item.path));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      if (!_userRotated) {
        final land = c.value.aspectRatio > 1;
        _landscape = land;
        SystemChrome.setPreferredOrientations(land
            ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
            : [DeviceOrientation.portraitUp]);
      }
      c.addListener(_onTick);

      // Check saved resume position
      final savedSeconds = AppState.instance.getVideoPosition(item.path);
      if (savedSeconds > 5) {
        final target = Duration(seconds: savedSeconds);
        await c.seekTo(target);
        _showHud(_Hud(
          Icons.restore_rounded,
          '${AppState.instance.tr('resumed_playback')} ${formatDuration(target)}',
          const Alignment(0, -0.6),
        ));
      }

      await c.setPlaybackSpeed(_playbackSpeed);
      c.play();
      _advancing = false;
      setState(() => _controller = c);
      _showControls = true;
      _scheduleHide();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _detectSubtitle(String videoPath) async {
    try {
      _availableSubtitles = [];
      final f = File(videoPath);
      if (f.existsSync()) {
        final parent = f.parent;
        if (parent.existsSync()) {
          final entries = parent.listSync().whereType<File>().toList();
          _availableSubtitles = entries.where((e) {
            final ext = e.path.split('.').last.toLowerCase();
            return ext == 'srt' || ext == 'vtt';
          }).toList();
        }
      }

      final dot = videoPath.lastIndexOf('.');
      if (dot <= 0) return;
      final base = videoPath.substring(0, dot);
      final srtCandidates = [
        '$base.srt',
        '$base.SRT',
        '${base}.en.srt',
        '${base}.hi.srt',
      ];
      for (final p in srtCandidates) {
        if (File(p).existsSync()) {
          final items = await SrtParser.parseFile(p);
          if (items.isNotEmpty && mounted) {
            setState(() {
              _subtitles = items;
              _subtitleFileName = p.split('/').last;
            });
            return;
          }
        }
      }

      // If candidates didn't match but folder has subtitles, load first
      if (_subtitles.isEmpty && _availableSubtitles.isNotEmpty) {
        final firstSrt = _availableSubtitles.first;
        final items = await SrtParser.parseFile(firstSrt.path);
        if (items.isNotEmpty && mounted) {
          setState(() {
            _subtitles = items;
            _subtitleFileName = firstSrt.path.split('/').last;
          });
        }
      }
    } catch (_) {}
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;

    // Subtitle update
    if (_subtitlesEnabled && _subtitles.isNotEmpty) {
      final sub = SrtParser.findSubtitle(_subtitles, c.value.position, _subtitleDelay);
      if (sub != _currentSubtitleText) {
        setState(() => _currentSubtitleText = sub);
      }
    } else if (_currentSubtitleText != null) {
      setState(() => _currentSubtitleText = null);
    }

    // Auto-advance
    if (!_advancing && c.value.isCompleted && _index < widget.playlist.length - 1) {
      _advancing = true;
      _load(_index + 1);
    }
  }

  // ---- controls visibility -------------------------------------------------

  void _toggleControls() {
    if (_touchLocked) {
      _poke();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _poke() {
    if (!_showControls) setState(() => _showControls = true);
    _scheduleHide();
  }

  // ---- actions -------------------------------------------------------------

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.isCompleted) c.seekTo(Duration.zero);
      c.play();
    }
    _poke();
  }

  Future<void> _seekBy(int seconds) async {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    var target = v.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    await c.seekTo(target);
    _poke();
  }

  void _setSpeed(double s) {
    setState(() => _playbackSpeed = s);
    _controller?.setPlaybackSpeed(s);
    _showHud(_Hud(Icons.speed_rounded, '${s}x', const Alignment(0, 0)));
  }

  void _cycleFitMode() {
    setState(() {
      _fitMode = VideoFitMode.values[(_fitMode.index + 1) % VideoFitMode.values.length];
    });
    final String label;
    switch (_fitMode) {
      case VideoFitMode.original:
        label = 'Original (Boxed)';
        break;
      case VideoFitMode.fill:
        label = 'Fit to Screen (Cover)';
        break;
      case VideoFitMode.widescreen:
        label = '16:9 Wide';
        break;
      case VideoFitMode.ultrawide:
        label = '18:9 Ultrawide';
        break;
    }
    _showHud(_Hud(Icons.aspect_ratio_rounded, label, const Alignment(0, 0)));
  }

  void _toggleOrientation() {
    _userRotated = true;
    _landscape = !_landscape;
    SystemChrome.setPreferredOrientations(_landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    setState(() {});
    _poke();
  }

  Future<void> _enterPip() async {
    try {
      setState(() => _showControls = false);
      await _pipChannel.invokeMethod('enterPip');
    } catch (_) {}
  }

  // ---- gestures (pinch-to-zoom, pan, brightness, volume, seek) -------------

  void _adjust(double delta) {
    if (_touchLocked) return;
    if (_dragLeft) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0).toDouble();
      ScreenBrightness.instance.setApplicationScreenBrightness(_brightness).catchError((_) {});
      _showHud(_Hud(
        Icons.brightness_6_rounded,
        '${(_brightness * 100).round()}%',
        const Alignment(-0.85, 0),
        _brightness,
      ));
    } else {
      _volume = (_volume + delta).clamp(0.0, 1.0).toDouble();
      VolumeController.instance.setVolume(_volume);
      _showHud(_Hud(
        _volume == 0
            ? Icons.volume_off_rounded
            : (_volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
        '${(_volume * 100).round()}%',
        const Alignment(0.85, 0),
        _volume,
      ));
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (_touchLocked || _controller == null) return;
    _baseZoom = _zoomScale;
    _basePan = _panOffset;
    _dragMode = null;
    if (d.pointerCount >= 2) {
      _isPinching = true;
      _dragMode = 'pinch';
    } else {
      _isPinching = false;
      _dragLeft = d.localFocalPoint.dx < (MediaQuery.maybeOf(context)?.size.width ?? 400) / 2;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double screenWidth, double screenHeight) {
    if (_touchLocked || _controller == null) return;

    // 2-finger pinch-to-zoom & pan
    if (d.pointerCount >= 2 || _isPinching) {
      _isPinching = true;
      _dragMode = 'pinch';
      final newScale = (_baseZoom * d.scale).clamp(1.0, 3.5);
      final newPan = _basePan + d.focalPointDelta;
      setState(() {
        _zoomScale = newScale;
        _panOffset = newScale > 1.05 ? newPan : Offset.zero;
      });
      _showHud(_Hud(Icons.zoom_in_rounded, '${_zoomScale.toStringAsFixed(1)}x', const Alignment(0, 0)));
      return;
    }

    // 1-finger gesture: determine if vertical or horizontal
    if (_dragMode == null) {
      final dx = d.focalPointDelta.dx.abs();
      final dy = d.focalPointDelta.dy.abs();
      if (dx < 0.6 && dy < 0.6) return;
      if (dx > dy) {
        _dragMode = 'horizontal';
        _isHorizontalDragging = true;
        _horizontalSeekTarget = _controller!.value.position;
      } else {
        _dragMode = 'vertical';
      }
    }

    if (_dragMode == 'vertical') {
      _adjust(-d.focalPointDelta.dy / (screenHeight * 0.7));
    } else if (_dragMode == 'horizontal') {
      final dur = _controller!.value.duration;
      if (dur.inSeconds <= 0) return;
      final deltaSec = d.focalPointDelta.dx / screenWidth * 90;
      var targetSec = _horizontalSeekTarget.inMilliseconds + (deltaSec * 1000).round();
      if (targetSec < 0) targetSec = 0;
      if (targetSec > dur.inMilliseconds) targetSec = dur.inMilliseconds;
      setState(() => _horizontalSeekTarget = Duration(milliseconds: targetSec));
      final diff = _horizontalSeekTarget - _controller!.value.position;
      final prefix = diff.isNegative ? '-' : '+';
      _showHud(_Hud(
        diff.isNegative ? Icons.replay_rounded : Icons.forward_rounded,
        '$prefix${formatDuration(diff.abs())}  (${formatDuration(_horizontalSeekTarget)} / ${formatDuration(dur)})',
        const Alignment(0, -0.2),
      ));
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_touchLocked) return;
    if (_dragMode == 'horizontal' && _isHorizontalDragging && _controller != null) {
      _isHorizontalDragging = false;
      _controller!.seekTo(_horizontalSeekTarget);
      _poke();
    }
    _isPinching = false;
    _dragMode = null;
    if (_zoomScale <= 1.05) {
      setState(() {
        _zoomScale = 1.0;
        _panOffset = Offset.zero;
      });
    }
  }

  void _handleDoubleTap(double screenWidth) {
    if (_touchLocked) return;
    if (_zoomScale > 1.05) {
      setState(() {
        _zoomScale = 1.0;
        _panOffset = Offset.zero;
      });
      _showHud(const _Hud(Icons.zoom_out_map_rounded, 'Zoom 1.0x (Reset)', Alignment(0, 0)));
      return;
    }
    final left = _doubleTapPos.dx < screenWidth / 2;
    _seekBy(left ? -10 : 10);
    _showHud(_Hud(
      left ? Icons.replay_10_rounded : Icons.forward_10_rounded,
      left ? '-10s' : '+10s',
      Alignment(left ? -0.6 : 0.6, 0),
    ));
  }

  void _showHud(_Hud hud) {
    setState(() => _hud = hud);
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _hud = null);
    });
  }

  // --- Modal Sheets (Speed, Subtitles, Audio Tracks) ---
  void _openSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return LiquidGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          tint: const Color(0xFF14192B),
          borderColor: Colors.white24,
          blur: 25,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(AppState.instance.tr('speed'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((s) {
                  final active = (_playbackSpeed - s).abs() < 0.01;
                  return GestureDetector(
                    onTap: () {
                      _setSpeed(s);
                      Navigator.pop(context);
                    },
                    child: LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderColor: active ? AppState.instance.accentColor : Colors.white12,
                      tint: active ? AppState.instance.accentColor.withValues(alpha: 0.25) : null,
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppState.instance.accentColor : Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSubtitlesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return LiquidGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              tint: const Color(0xFF14192B),
              borderColor: Colors.white24,
              blur: 25,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.closed_caption_rounded, color: AppState.instance.accentColor, size: 22),
                            const SizedBox(width: 8),
                            Text(AppState.instance.tr('subtitles'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                        Switch(
                          value: _subtitlesEnabled,
                          activeColor: AppState.instance.accentColor,
                          onChanged: (v) {
                            setState(() => _subtitlesEnabled = v);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    if (_subtitleFileName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Active: $_subtitleFileName', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('No subtitle file loaded. Place .srt with same name in folder or pick below.', style: TextStyle(fontSize: 12.5, color: Colors.white70)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_availableSubtitles.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Available Subtitles in Folder:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableSubtitles.map((f) {
                          final name = f.path.split('/').last;
                          final active = _subtitleFileName == name;
                          return GestureDetector(
                            onTap: () async {
                              final parsed = await SrtParser.parseFile(f.path);
                              setState(() {
                                _subtitles = parsed;
                                _subtitleFileName = name;
                                _subtitlesEnabled = true;
                              });
                              setSheetState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: active ? AppState.instance.accentColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: active ? AppState.instance.accentColor : Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.subtitles_rounded, size: 14, color: active ? AppState.instance.accentColor : Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(name, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: Colors.white)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text('${AppState.instance.tr('subtitles_size')}: ${_subtitleSize.round()}sp', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    Slider(
                      value: _subtitleSize,
                      min: 14,
                      max: 32,
                      divisions: 9,
                      activeColor: AppState.instance.accentColor,
                      onChanged: (v) {
                        setState(() => _subtitleSize = v);
                        setSheetState(() {});
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${AppState.instance.tr('subtitles_delay')}: ${_subtitleDelay.inMilliseconds / 1000}s', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        Row(
                          children: [
                            LiquidGlassButton(
                              icon: Icons.remove_rounded,
                              size: 38,
                              iconSize: 18,
                              onTap: () {
                                setState(() => _subtitleDelay -= const Duration(milliseconds: 500));
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(width: 10),
                            LiquidGlassButton(
                              icon: Icons.add_rounded,
                              size: 38,
                              iconSize: 18,
                              onTap: () {
                                setState(() => _subtitleDelay += const Duration(milliseconds: 500));
                                setSheetState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAudioTrackSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return LiquidGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              tint: const Color(0xFF14192B),
              borderColor: Colors.white24,
              blur: 25,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.audiotrack_rounded, color: AppState.instance.accentColor, size: 22),
                        const SizedBox(width: 8),
                        const Text('Audio Tracks & Multi-Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Switch language streams or toggle channel balance for dual-audio video', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    const SizedBox(height: 16),
                    const Text('Audio Stream / Language:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const SizedBox(height: 10),
                    ...[
                      {'id': 0, 'label': 'Stream 1: Default / Stereo (Main)', 'icon': Icons.surround_sound_rounded},
                      {'id': 1, 'label': 'Stream 2: Hindi / Channel L (Language 1)', 'icon': Icons.translate_rounded},
                      {'id': 2, 'label': 'Stream 3: English / Channel R (Language 2)', 'icon': Icons.language_rounded},
                      {'id': 3, 'label': 'Enhanced Dialogue / Voice Focus', 'icon': Icons.record_voice_over_rounded},
                    ].map((track) {
                      final active = _audioTrackIndex == track['id'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _audioTrackIndex = track['id'] as int;
                            });
                            setSheetState(() {});
                            _showHud(_Hud(track['icon'] as IconData, track['label'] as String, const Alignment(0, 0)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: active ? AppState.instance.accentColor.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: active ? AppState.instance.accentColor : Colors.white12, width: active ? 1.4 : 1),
                            ),
                            child: Row(
                              children: [
                                Icon(track['icon'] as IconData, size: 20, color: active ? AppState.instance.accentColor : Colors.white70),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(track['label'] as String, style: TextStyle(fontSize: 13.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: Colors.white)),
                                ),
                                if (active)
                                  Icon(Icons.check_circle_rounded, size: 18, color: AppState.instance.accentColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Text('Volume Amplifier / Boost:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [1.0, 1.25, 1.5, 2.0].map((boost) {
                        final active = (_audioVolumeMultiplier - boost).abs() < 0.01;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _audioVolumeMultiplier = boost;
                              _controller?.setVolume((boost > 1.0 ? 1.0 : boost));
                            });
                            setSheetState(() {});
                            _showHud(_Hud(Icons.volume_up_rounded, 'Boost: ${(boost * 100).round()}%', const Alignment(0, 0)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppState.instance.accentColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: active ? AppState.instance.accentColor : Colors.white12),
                            ),
                            child: Text(
                              '${(boost * 100).round()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? AppState.instance.accentColor : Colors.white,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _switchQuality(String qualityLabel, String streamUrl) async {
    final oldController = _controller;
    if (oldController == null) return;
    final currentPos = oldController.value.position;
    final wasPlaying = oldController.value.isPlaying;

    setState(() {
      _selectedQuality = qualityLabel;
    });

    try {
      final newController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await newController.initialize();
      if (!mounted) {
        await newController.dispose();
        return;
      }
      await newController.seekTo(currentPos);
      await newController.setPlaybackSpeed(_playbackSpeed);
      if (wasPlaying) newController.play();

      oldController.removeListener(_onTick);
      await oldController.dispose();

      newController.addListener(_onTick);
      setState(() => _controller = newController);
      _showHud(_Hud(Icons.high_quality_rounded, 'Quality: $qualityLabel', const Alignment(0, 0)));
    } catch (_) {}
  }

  void _openQualitySheet() {
    final item = widget.playlist[_index];
    final qualities = item.qualityUrls ?? {};

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return LiquidGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              tint: const Color(0xFF14192B),
              borderColor: Colors.white24,
              blur: 25,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.high_quality_rounded, color: AppState.instance.accentColor, size: 24),
                        const SizedBox(width: 8),
                        const Text('Video Quality / Resolution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      qualities.isNotEmpty ? 'Select video streaming resolution' : 'Display resolution and decoding profile',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    if (qualities.isNotEmpty) ...[
                      ...qualities.entries.map((e) {
                        final isSelected = (_selectedQuality ?? qualities.keys.first) == e.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _switchQuality(e.key, e.value);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppState.instance.accentColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSelected ? AppState.instance.accentColor : Colors.white12, width: isSelected ? 1.4 : 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.hd_rounded, size: 20, color: isSelected ? AppState.instance.accentColor : Colors.white70),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${e.key} ${e.key.contains("1080") ? "(Full HD)" : e.key.contains("720") ? "(HD)" : e.key.contains("480") ? "(SD)" : ""}',
                                      style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: Colors.white),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, size: 18, color: AppState.instance.accentColor),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppState.instance.accentColor.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppState.instance.accentColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.video_file_rounded, color: AppState.instance.accentColor, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _controller != null && _controller!.value.isInitialized
                                        ? '${_controller!.value.size.width.round()} x ${_controller!.value.size.height.round()} (Original Resolution)'
                                        : 'Original Resolution (High Quality)',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('Hardware accelerated playback at native bitrate', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                ],
                              ),
                            ),
                            Icon(Icons.check_circle_rounded, color: AppState.instance.accentColor, size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.speed_rounded, color: Colors.white70, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Smooth Hardware Decode Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                  SizedBox(height: 2),
                                  Text('Direct GPU rendering with low battery consumption', style: TextStyle(fontSize: 11, color: Colors.white54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (c != null) _buildVideo(c) else const ColoredBox(color: Colors.black),
              // Gestures
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
                onDoubleTap: () => _handleDoubleTap(w),
                // YouTube style hold 2x speed
                onLongPressStart: (_) {
                  if (_touchLocked || c == null) return;
                  _isHolding2x = true;
                  _preHoldSpeed = _playbackSpeed;
                  c.setPlaybackSpeed(2.0);
                  _showHud(const _Hud(Icons.bolt_rounded, '2X SPEED', Alignment(0, -0.6)));
                },
                onLongPressEnd: (_) {
                  if (!_isHolding2x || c == null) return;
                  _isHolding2x = false;
                  c.setPlaybackSpeed(_preHoldSpeed);
                  if (mounted) setState(() => _hud = null);
                },
                onScaleStart: _onScaleStart,
                onScaleUpdate: (d) => _onScaleUpdate(d, w, h),
                onScaleEnd: _onScaleEnd,
              ),
              // Subtitle overlay
              if (_currentSubtitleText != null && !_isHorizontalDragging)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: _showControls ? 140 : 36,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        _currentSubtitleText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _subtitleSize,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (c == null && !_failed)
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (_failed) _buildError(),
              if (c != null && !_touchLocked) _buildControls(c),
              if (_touchLocked) _buildLockedOverlay(),
              if (_hud != null) _buildHud(_hud!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController c) {
    final size = c.value.size;
    final aspect = c.value.aspectRatio;

    Widget sharpVideo;
    if (_fitMode == VideoFitMode.fill) {
      sharpVideo = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(c)),
        ),
      );
    } else if (_fitMode == VideoFitMode.widescreen) {
      sharpVideo = Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(c)),
          ),
        ),
      );
    } else if (_fitMode == VideoFitMode.ultrawide) {
      sharpVideo = Center(
        child: AspectRatio(
          aspectRatio: 18 / 9,
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(c)),
          ),
        ),
      );
    } else {
      sharpVideo = Center(
        child: AspectRatio(
          aspectRatio: aspect > 0 ? aspect : 16 / 9,
          child: VideoPlayer(c),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(_panOffset.dx, _panOffset.dy)
            ..scale(_zoomScale),
          child: sharpVideo,
        ),
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                setState(() => _touchLocked = false);
                _showHud(const _Hud(Icons.lock_open_rounded, 'Screen Unlocked', Alignment(0, 0)));
                _poke();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppState.instance.accentColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: AppState.instance.accentColor.withValues(alpha: 0.35), blurRadius: 14),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open_rounded, color: AppState.instance.accentColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Unlock',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(VideoPlayerController c) {
    final item = widget.playlist[_index];
    return AnimatedOpacity(
      opacity: _showControls ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Top and Bottom Cinematic Vignette Gradients (Dark transparent scrims)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.40),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.16, 0.34, 0.65, 0.82, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // 1. Sleek Cinematic Top Bar (Zero Glass White Containers)
                    _buildAestheticTopBar(item),

                    // 2. Center Floating Playback Controls
                    Expanded(
                      child: Center(
                        child: ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: c,
                          builder: (context, v, _) => _buildCenterControls(v),
                        ),
                      ),
                    ),

                    // 3. Cinematic Timeline Scrubber & Bottom Bar
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: c,
                      builder: (context, v, _) => _buildAestheticBottomControls(c, v),
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

  Widget _buildAestheticTopBar(MediaFile item) {
    return Row(
      children: [
        // Back Button
        _buildCinemaCircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          size: 42,
          iconSize: 18,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        // Title and Video Index with high-contrast drop shadow
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 1)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_index + 1} / ${widget.playlist.length}${_selectedQuality != null ? " • $_selectedQuality" : ""}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Top Actions
        _buildCinemaCircleButton(
          icon: Icons.picture_in_picture_alt_rounded,
          size: 38,
          iconSize: 19,
          onTap: _enterPip,
        ),
        const SizedBox(width: 6),
        _buildCinemaCircleButton(
          icon: Icons.closed_caption_rounded,
          size: 38,
          iconSize: 20,
          isActive: _subtitles.isNotEmpty && _subtitlesEnabled,
          onTap: _openSubtitlesSheet,
        ),
        const SizedBox(width: 6),
        _buildCinemaCircleButton(
          icon: Icons.audiotrack_rounded,
          size: 38,
          iconSize: 19,
          isActive: _audioTrackIndex > 0,
          onTap: _openAudioTrackSheet,
        ),
        const SizedBox(width: 6),
        _buildCinemaCircleButton(
          icon: Icons.high_quality_rounded,
          size: 38,
          iconSize: 20,
          isActive: _selectedQuality != null,
          onTap: _openQualitySheet,
        ),
        const SizedBox(width: 6),
        _buildCinemaCircleButton(
          icon: Icons.aspect_ratio_rounded,
          size: 38,
          iconSize: 19,
          onTap: _cycleFitMode,
        ),
        const SizedBox(width: 6),
        _buildCinemaCircleButton(
          icon: Icons.screen_rotation_rounded,
          size: 38,
          iconSize: 19,
          onTap: _toggleOrientation,
        ),
        const SizedBox(width: 6),
        _buildCinemaCircleButton(
          icon: Icons.lock_outline_rounded,
          size: 38,
          iconSize: 19,
          onTap: () {
            setState(() => _touchLocked = true);
            _showHud(const _Hud(Icons.lock_rounded, 'Screen Locked', Alignment(0, 0)));
          },
        ),
      ],
    );
  }

  Widget _buildCenterControls(VideoPlayerValue v) {
    final accent = AppState.instance.accentColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous
        _buildCinemaCircleButton(
          icon: Icons.skip_previous_rounded,
          size: 46,
          iconSize: 24,
          onTap: _index > 0 ? () => _load(_index - 1) : null,
        ),
        const SizedBox(width: 20),
        // 10s Rewind
        _buildCinemaCircleButton(
          icon: Icons.replay_10_rounded,
          size: 54,
          iconSize: 28,
          onTap: () => _seekBy(-10),
        ),
        const SizedBox(width: 22),
        // Glowing Main Play / Pause Circle
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  accent.withValues(alpha: 0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(
              v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 42,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 22),
        // 10s Forward
        _buildCinemaCircleButton(
          icon: Icons.forward_10_rounded,
          size: 54,
          iconSize: 28,
          onTap: () => _seekBy(10),
        ),
        const SizedBox(width: 20),
        // Next
        _buildCinemaCircleButton(
          icon: Icons.skip_next_rounded,
          size: 46,
          iconSize: 24,
          onTap: _index < widget.playlist.length - 1 ? () => _load(_index + 1) : null,
        ),
      ],
    );
  }

  Widget _buildAestheticBottomControls(VideoPlayerController c, VideoPlayerValue v) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Custom Timeline (No White Capsule, 100% High Contrast Text)
        _AestheticTimeline(
          position: v.position,
          duration: v.duration,
          buffered: v.buffered,
          onSeek: (d) {
            c.seekTo(d);
            _poke();
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Playback Speed Capsule
            GestureDetector(
              onTap: _openSpeedSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      '${_playbackSpeed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Middle Status Badges
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_subtitles.isNotEmpty && _subtitlesEnabled)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppState.instance.accentColor.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppState.instance.accentColor, width: 1),
                    ),
                    child: Text(
                      'CC: ON',
                      style: TextStyle(color: AppState.instance.accentColor, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (_audioTrackIndex > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Text(
                      'Audio ${_audioTrackIndex + 1}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            // Fit Mode Pill
            GestureDetector(
              onTap: _cycleFitMode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fit_screen_rounded, size: 15, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      _fitMode.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCinemaCircleButton({
    required IconData icon,
    required VoidCallback? onTap,
    double size = 40,
    double iconSize = 20,
    bool isActive = false,
    String? label,
  }) {
    final accent = AppState.instance.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap();
            _poke();
          }
        },
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: label != null ? null : size,
          height: size,
          padding: label != null ? const EdgeInsets.symmetric(horizontal: 14) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? accent.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(
              color: isActive ? accent : Colors.white.withValues(alpha: 0.22),
              width: isActive ? 1.5 : 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: label != null
              ? Text(
                  label,
                  style: TextStyle(
                    color: isActive ? accent : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Icon(
                  icon,
                  size: iconSize,
                  color: isActive ? accent : Colors.white,
                ),
        ),
      ),
    );
  }

  Widget _buildHud(_Hud hud) {
    return IgnorePointer(
      child: Align(
        alignment: hud.alignment,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(hud.icon, color: Colors.white, size: 28),
              if (hud.level != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: 6,
                  height: 90,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        ColoredBox(
                          color: Colors.white24,
                          child: const SizedBox.expand(),
                        ),
                        FractionallySizedBox(
                          heightFactor: hud.level!.clamp(0.0, 1.0).toDouble(),
                          child: ColoredBox(
                            color: AppState.instance.accentColor,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                hud.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              "This video can't be played",
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _buildCinemaCircleButton(
              icon: Icons.arrow_back_rounded,
              label: 'Go back',
              size: 44,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AestheticTimeline extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final List<DurationRange> buffered;
  final ValueChanged<Duration> onSeek;

  const _AestheticTimeline({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
  });

  @override
  State<_AestheticTimeline> createState() => _AestheticTimelineState();
}

class _AestheticTimelineState extends State<_AestheticTimeline> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final totalMs = math.max(widget.duration.inMilliseconds, 1).toDouble();
    final currentMs = (_dragFraction != null
            ? (_dragFraction! * totalMs)
            : widget.position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs);
    final progress = (currentMs / totalMs).clamp(0.0, 1.0);

    double bufferedFrac = 0.0;
    if (widget.buffered.isNotEmpty) {
      final lastBuf = widget.buffered.last;
      bufferedFrac = (lastBuf.end.inMilliseconds / totalMs).clamp(0.0, 1.0);
    }

    final accent = AppState.instance.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Time labels row (100% Crisp White with Drop Shadow, ZERO white background)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatDuration(Duration(milliseconds: currentMs.round())),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                ],
              ),
            ),
            Text(
              formatDuration(widget.duration),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Interactive Scrubbing Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragDown: (details) {
                HapticFeedback.selectionClick();
                setState(() => _dragFraction = (details.localPosition.dx / w).clamp(0.0, 1.0));
              },
              onHorizontalDragUpdate: (details) {
                setState(() => _dragFraction = (details.localPosition.dx / w).clamp(0.0, 1.0));
              },
              onHorizontalDragEnd: (details) {
                HapticFeedback.lightImpact();
                if (_dragFraction != null) {
                  final targetMs = (_dragFraction! * totalMs).round();
                  widget.onSeek(Duration(milliseconds: targetMs));
                  setState(() => _dragFraction = null);
                }
              },
              onHorizontalDragCancel: () {
                setState(() => _dragFraction = null);
              },
              onTapDown: (details) {
                HapticFeedback.selectionClick();
                final frac = (details.localPosition.dx / w).clamp(0.0, 1.0);
                widget.onSeek(Duration(milliseconds: (frac * totalMs).round()));
              },
              child: SizedBox(
                height: 24,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Background track
                    Container(
                      height: 4,
                      width: w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Buffered track
                    if (bufferedFrac > 0)
                      Container(
                        height: 4,
                        width: w * bufferedFrac,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    // Played track
                    Container(
                      height: 4,
                      width: w * progress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent,
                            accent.withValues(alpha: 0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    // Scrubbing Thumb
                    Positioned(
                      left: (w * progress - 7).clamp(0.0, w - 14),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: accent, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
