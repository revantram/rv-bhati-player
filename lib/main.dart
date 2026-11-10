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
        return MaterialApp(
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
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
