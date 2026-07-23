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
  final audio = AudioService(await SettingsStore.load());
  AudioService.instance = audio;
  final controller = GameController()..audio = audio;
  await controller.boot();
  runApp(EmberdelveApp(controller));
}

class EmberdelveApp extends StatelessWidget {
  final GameController controller;
  const EmberdelveApp(this.controller, {super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emberdelve',
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(controller),
    );
  }
}
