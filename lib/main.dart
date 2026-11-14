import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'screens/home_screen.dart';
import 'services/app_state.dart';
import 'services/download_service.dart';
import 'services/jiosaavn_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppState.instance.init();
  await DownloadService.instance.init();
  await JioSaavnAuthService.instance.init();

  // Background audio: notification + lock-screen controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.rvbhati.player.channel.audio',
    androidNotificationChannelName: 'RV Bhati Player',
    androidNotificationChannelDescription: 'BitMusic & Media playback controls',
    androidNotificationIcon: 'mipmap/ic_launcher',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidShowNotificationBadge: true,
    notificationColor: AppState.instance.accentColor,
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Ensure TV focus highlights are ALWAYS drawn on Fire TV / Android TV
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;

  runApp(const RvBhatiPlayerApp());
}

class RvBhatiPlayerApp extends StatefulWidget {
  const RvBhatiPlayerApp({super.key});

  @override
  State<RvBhatiPlayerApp> createState() => _RvBhatiPlayerAppState();
}

class _RvBhatiPlayerAppState extends State<RvBhatiPlayerApp> {
  bool? _lastIsLight;

  void _syncOverlay(bool isLight) {
    if (_lastIsLight == isLight) return;
    _lastIsLight = isLight;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final app = AppState.instance;
        final accent = app.accentColor;
        final isLight = app.isLight;
        _syncOverlay(isLight);

        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
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
                brightness: isLight ? Brightness.light : Brightness.dark,
                useMaterial3: true,
                scaffoldBackgroundColor: app.backgroundColor,
                cardColor: app.surfaceColor,
                dividerColor: app.dividerColor,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: accent,
                  primary: accent,
                  brightness: isLight ? Brightness.light : Brightness.dark,
                  surface: app.surfaceColor,
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
