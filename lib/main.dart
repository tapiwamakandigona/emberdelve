// lib/main.dart — Emberdelve entry point.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio/audio_service.dart';
import 'audio/settings.dart';
import 'game/controller.dart';
import 'ui/screens.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // Must run before the first AudioPlayer exists — see initPlatformAudio.
  await AudioService.initPlatformAudio();
  final audio = AudioService(await SettingsStore.load());
  AudioService.instance = audio;
  final controller = GameController()..audio = audio;
  await controller.boot();
  runApp(EmberdelveApp(controller));
}

class EmberdelveApp extends StatefulWidget {
  final GameController controller;
  const EmberdelveApp(this.controller, {super.key});
  @override
  State<EmberdelveApp> createState() => _EmberdelveAppState();
}

/// App-lifecycle audio handling (v0.3.1 F3): pause music/ambience when the
/// app leaves the foreground (Home button, lock screen, incoming call) and
/// resume on return — Android keeps audioplayers running otherwise.
class _EmberdelveAppState extends State<EmberdelveApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = widget.controller.audio;
    if (audio == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        audio.resumeAll();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        audio.pauseAll();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emberdelve',
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(widget.controller),
    );
  }
}
