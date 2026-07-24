// ui/title_screen.dart — M1 placeholder title: logo, Play, version.
// M4 replaces this with the full art-directed title (parallax, hearth glow).
import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import 'level_select_screen.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  @override
  void initState() {
    super.initState();
    AudioService.instance?.playMusic('title_menu');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'EMBERDELVE',
              style: TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 42,
                letterSpacing: 6,
                color: Color(0xFFE8A33D),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Delve the Emberwood',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E8948),
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              ),
              onPressed: () {
                AudioService.instance?.playSfx('ui_tap');
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LevelSelectScreen()));
              },
              child: const Text('PLAY', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
