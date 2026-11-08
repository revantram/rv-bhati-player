import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/media_file.dart';
import '../services/audio_controller.dart';
import '../widgets/glass_bars.dart';
import '../widgets/glass_seek_bar.dart';
import '../widgets/liquid_glass_container.dart';

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

  Timer? _hideTimer;
  Timer? _hudTimer;

  double _brightness = 0.5;
  double _volume = 0.5;
  bool _dragLeft = true;
  Offset _doubleTapPos = Offset.zero;
  _Hud? _hud;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.startIndex;
    AudioController.instance.player.pause(); // one thing plays at a time
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _readDeviceLevels();
    _load(_index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (state == AppLifecycleState.paused) _controller?.pause();
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
    final old = _controller;
    old?.removeListener(_onTick);
    setState(() {
      _index = i;
      _failed = false;
      _controller = null;
    });
    await old?.dispose();

    final c = VideoPlayerController.file(File(widget.playlist[i].path));
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

  /// Auto-play next video when the current one ends.
  void _onTick() {
    final c = _controller;
    if (c == null || _advancing) return;
    if (c.value.isCompleted && _index < widget.playlist.length - 1) {
      _advancing = true;
      _load(_index + 1);
    }
  }

  // ---- controls visibility -------------------------------------------------

  void _toggleControls() {
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

  void _toggleOrientation() {
    _userRotated = true;
    _landscape = !_landscape;
    SystemChrome.setPreferredOrientations(_landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    setState(() {});
    _poke();
  }

  // ---- gestures: left side = brightness, right side = volume -----------------

  void _adjust(double delta) {
    if (_dragLeft) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0).toDouble();
      ScreenBrightness.instance
          .setApplicationScreenBrightness(_brightness)
          .catchError((_) {});
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

  void _showHud(_Hud hud) {
    setState(() => _hud = hud);
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _hud = null);
    });
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
              // Gesture layer (tap / double-tap / vertical swipes)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
                onDoubleTap: () {
                  final left = _doubleTapPos.dx < w / 2;
                  _seekBy(left ? -10 : 10);
                  _showHud(_Hud(
                    left ? Icons.replay_10_rounded : Icons.forward_10_rounded,
                    left ? '-10s' : '+10s',
                    Alignment(left ? -0.6 : 0.6, 0),
                  ));
                },
                onVerticalDragStart: (d) => _dragLeft = d.localPosition.dx < w / 2,
                onVerticalDragUpdate: (d) => _adjust(-d.delta.dy / (h * 0.7)),
              ),
              if (c == null && !_failed)
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (_failed) _buildError(),
              if (c != null) _buildControls(c),
              if (_hud != null) _buildHud(_hud!),
            ],
          );
        },
      ),
    );
  }

  /// Sharp video in front + a heavily blurred copy behind it: the letterbox
  /// area "reflects" the playing video like frosted glass.
  Widget _buildVideo(VideoPlayerController c) {
    final size = c.value.size;
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Opacity(
            opacity: 0.55,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(c),
              ),
            ),
          ),
        ),
        Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        ),
      ],
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
            // Legibility gradient (must not swallow taps)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0, 0.25, 0.6, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: [
                    GlassTopBar(
                      title: item.displayTitle,
                      subtitle: '${_index + 1} / ${widget.playlist.length}',
                      leading: LiquidGlassButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 44,
                        iconSize: 20,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      actions: [
                        LiquidGlassButton(
                          icon: Icons.screen_rotation_rounded,
                          size: 44,
                          iconSize: 22,
                          onTap: _toggleOrientation,
                        ),
                      ],
                    ),
                    const Spacer(),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: c,
                      builder: (context, v, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlassSeekBar(
                            position: v.position,
                            duration: v.duration,
                            onSeek: (d) {
                              c.seekTo(d);
                              _poke();
                            },
                          ),
                          const SizedBox(height: 14),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LiquidGlassButton(
                                  icon: Icons.skip_previous_rounded,
                                  size: 48,
                                  onTap: _index > 0 ? () => _load(_index - 1) : null,
                                ),
                                const SizedBox(width: 10),
                                LiquidGlassButton(
                                  icon: Icons.replay_10_rounded,
                                  size: 54,
                                  onTap: () => _seekBy(-10),
                                ),
                                const SizedBox(width: 12),
                                LiquidGlassButton(
                                  icon: v.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 74,
                                  iconSize: 38,
                                  tint: const Color(0xFF7C6CFF),
                                  onTap: _togglePlay,
                                ),
                                const SizedBox(width: 12),
                                LiquidGlassButton(
                                  icon: Icons.forward_10_rounded,
                                  size: 54,
                                  onTap: () => _seekBy(10),
                                ),
                                const SizedBox(width: 10),
                                LiquidGlassButton(
                                  icon: Icons.skip_next_rounded,
                                  size: 48,
                                  onTap: _index < widget.playlist.length - 1
                                      ? () => _load(_index + 1)
                                      : null,
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
          ],
        ),
      ),
    );
  }

  Widget _buildHud(_Hud hud) {
    return IgnorePointer(
      child: Align(
        alignment: hud.alignment,
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(hud.icon, color: Colors.white, size: 26),
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
                          color: Colors.white.withValues(alpha: 0.22),
                          child: const SizedBox.expand(),
                        ),
                        FractionallySizedBox(
                          heightFactor: hud.level!.clamp(0.0, 1.0).toDouble(),
                          child: const ColoredBox(
                            color: Colors.white,
                            child: SizedBox.expand(),
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
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(32),
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
            LiquidGlassButton(
              icon: Icons.arrow_back_rounded,
              label: 'Go back',
              size: 48,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
