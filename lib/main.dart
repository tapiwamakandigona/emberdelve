// main.dart — boot: services up, landscape lock, straight to the title.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/audio_service.dart';
import 'audio/settings.dart';
import 'core/save.dart';
import 'ui/app_state.dart';
import 'ui/title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final settings = await SettingsStore.load();
  AudioService.instance = AudioService(settings);
  await AudioService.initPlatformAudio();

  final store = SaveStore();
  final save = await store.load();
  AppState.init(store: store, save: save);

  runApp(const EmberdelveApp());
}

class EmberdelveApp extends StatelessWidget {
  const EmberdelveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emberdelve',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141420),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const TitleScreen(),
    );
  }
}
