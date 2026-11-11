import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'screens/home_screen.dart';
import 'services/app_state.dart';
import 'services/download_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppState.instance.init();
  await DownloadService.instance.init();

  // Background audio: notification + lock-screen controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.rvbhati.player.channel.audio',
    androidNotificationChannelName: 'RV Bhati Player',
    androidNotificationChannelDescription: 'Music playback controls',
    androidNotificationIcon: 'mipmap/ic_launcher',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidShowNotificationBadge: true,
    notificationColor: const Color(0xFF7C6CFF),
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));

  // Ensure TV focus highlights are ALWAYS drawn on Fire TV / Android TV
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;

  runApp(const RvBhatiPlayerApp());
}

class RvBhatiPlayerApp extends StatelessWidget {
  const RvBhatiPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final accent = AppState.instance.accentColor;
        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            ...WidgetsApp.defaultShortcuts,
            // Fire TV Stick and Android TV remote Center / Select / OK key:
            const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
            // D-Pad directional navigation:
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                const DirectionalFocusIntent(TraversalDirection.up),
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                const DirectionalFocusIntent(TraversalDirection.down),
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                const DirectionalFocusIntent(TraversalDirection.left),
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                const DirectionalFocusIntent(TraversalDirection.right),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ...WidgetsApp.defaultActions,
            },
            child: MaterialApp(
              title: 'RV Bhati Player',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: Brightness.dark,
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF0B0F1E),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: accent,
                  brightness: Brightness.dark,
                ),
                focusColor: accent.withValues(alpha: 0.45),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
              ),
              home: const HomeScreen(),
            ),
          ),
        );
      },
    );
  }
}
