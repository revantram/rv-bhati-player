import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';
import '../services/audio_controller.dart';
import '../services/media_scanner.dart';
import '../utils/format.dart';
import '../widgets/art_box.dart';
import '../widgets/glass_bars.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0; // 0 = videos, 1 = music
  bool _loading = true;
  bool _denied = false;
  String? _error;
  List<MediaFile> _videos = const [];
  List<MediaFile> _audios = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User may come back from system Settings after granting permission.
    if (state == AppLifecycleState.resumed && _denied) _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _denied = false;
      _error = null;
    });
    try {
      final granted = await MediaScanner.requestPermissions();
      if (!granted) {
        if (mounted) setState(() {
          _denied = true;
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        MediaScanner.scan(MediaKind.video),
        MediaScanner.scan(MediaKind.audio),
      ]);
      if (!mounted) return;
      setState(() {
        _videos = results[0];
        _audios = results[1];
        _loading = false;
      });
      // Needed on Android 13+ to show the background-playback notification.
      Permission.notification.request();
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _open(List<MediaFile> items, int i) {
    final page = _tab == 0
        ? VideoPlayerScreen(playlist: items, startIndex: i)
        : AudioPlayerScreen(queue: items, startIndex: i);
    Navigator.of(context).push(glassRoute(page));
  }

  void _openNowPlaying() {
    final ac = AudioController.instance;
    Navigator.of(context).push(glassRoute(AudioPlayerScreen(
      queue: ac.queue,
      startIndex: ac.player.currentIndex ?? 0,
      startPlayback: false,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidBackground()),
          Positioned.fill(child: _buildContent(pad)),
          Positioned(
            top: pad.top + 10,
            left: 16,
            right: 16,
            child: GlassTopBar(
              title: 'RV Bhati Player',
              subtitle: _loading
                  ? 'Scanning your media...'
                  : '${_videos.length} videos  -  ${_audios.length} songs',
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C6CFF), Color(0xFF00D2FF)],
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
              actions: [
                LiquidGlassButton(icon: Icons.refresh_rounded, size: 44, onTap: _init),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: pad.bottom + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniPlayer(onOpen: _openNowPlaying),
                GlassBottomNav(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                  items: const [
                    GlassNavItem(Icons.movie_filter_rounded, 'Videos'),
                    GlassNavItem(Icons.library_music_rounded, 'Music'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(EdgeInsets pad) {
    if (_loading) {
      return const Center(
        child: _GlassMessage(
          icon: Icons.hourglass_top_rounded,
          title: 'Scanning storage',
          body: 'Finding your .mp4, .mkv and .mp3 files...',
          showSpinner: true,
        ),
      );
    }
    if (_denied) {
      return Center(
        child: _GlassMessage(
          icon: Icons.lock_outline_rounded,
          title: 'Allow media access',
          body: 'RV Bhati Player needs permission to read videos and audio on this device.',
          actions: [
            LiquidGlassButton(icon: Icons.check_rounded, label: 'Allow', size: 48, tint: const Color(0xFF7C6CFF), onTap: _init),
            const SizedBox(height: 10),
            LiquidGlassButton(icon: Icons.settings_rounded, label: 'Open Settings', size: 48, onTap: openAppSettings),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: _GlassMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not scan media',
          body: _error!,
          actions: [LiquidGlassButton(icon: Icons.refresh_rounded, label: 'Retry', size: 48, onTap: _init)],
        ),
      );
    }

    final isVideo = _tab == 0;
    final items = isVideo ? _videos : _audios;
    final Widget body;
    if (items.isEmpty) {
      body = Center(
        child: _GlassMessage(
          icon: isVideo ? Icons.movie_outlined : Icons.music_off_rounded,
          title: isVideo ? 'No videos found' : 'No songs found',
          body: isVideo ? 'No .mp4 or .mkv files on this device.' : 'No .mp3 files on this device.',
        ),
      );
    } else {
      body = ListView.builder(
        padding: EdgeInsets.fromLTRB(16, pad.top + 86, 16, pad.bottom + 170),
        itemCount: items.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _MediaCard(item: items[i], onTap: () => _open(items, i)),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(_tab), child: body),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item, required this.onTap});

  final MediaFile item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.kind == MediaKind.video;
    return PressableScale(
      hapticOnDown: false,
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(26),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 76,
                height: 76,
                child: isVideo
                    ? _VideoThumb(entity: item.entity)
                    : ArtBox(seed: item.displayTitle, radius: 0, iconSize: 32),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatDuration(item.duration)}  -  ${item.extension}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: 34,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.entity});
  final AssetEntity entity;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  late final Future<Uint8List?> _future =
      widget.entity.thumbnailDataWithSize(const ThumbnailSize(240, 240));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return ColoredBox(
            color: Colors.white.withValues(alpha: 0.08),
            child: const Icon(Icons.movie_rounded, color: Colors.white54),
          );
        }
        return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}

/// Glass mini-player: shows while music is loaded, so audio that keeps
/// playing after leaving the full screen is always reachable.
class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final player = AudioController.instance.player;
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snap) {
        final tag = snap.data?.currentSource?.tag;
        if (tag is! MediaItem) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PressableScale(
            hapticOnDown: false,
            onTap: onOpen,
            child: LiquidGlassContainer(
              borderRadius: LiquidGlassContainer.capsuleRadius,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ArtBox(seed: tag.title, radius: 22, iconSize: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tag.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, s) {
                      final playing = s.data?.playing ?? false;
                      return LiquidGlassButton(
                        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 44,
                        onTap: () {
                          if (playing) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassMessage extends StatelessWidget {
  const _GlassMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showSpinner = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(34),
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              )
            else
              Icon(icon, size: 42, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.4),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }
}
