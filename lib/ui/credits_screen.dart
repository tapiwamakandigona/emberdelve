// lib/ui/credits_screen.dart — in-app "Credits & Licenses". Renders the
// bundled repo-root CREDITS.md (CC-BY attributions are legally required to
// ship with the game, so the file itself is the single source of truth).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/audio_service.dart';
import 'theme.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Credits & Licenses', style: EmberText.h2),
        backgroundColor: EmberColors.bg,
        leading: BackButton(onPressed: () {
          AudioService.instance?.playSfx('ui_back');
          Navigator.of(context).pop();
        }),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString('CREDITS.md'),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: EmberColors.ember));
            }
            return ListView(
              padding: const EdgeInsets.all(Space.l),
              children: [
                for (final line in snap.data!.split('\n')) _line(line),
                const SizedBox(height: Space.xl),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Minimal markdown-ish rendering: #/##/### headings, everything else body.
  Widget _line(String raw) {
    final line = raw.trimRight();
    if (line.isEmpty) return const SizedBox(height: Space.s);
    TextStyle style;
    String text = line;
    if (line.startsWith('### ')) {
      text = line.substring(4);
      style = EmberText.h2.copyWith(fontSize: 17);
    } else if (line.startsWith('## ')) {
      text = line.substring(3);
      style = EmberText.h2;
    } else if (line.startsWith('# ')) {
      text = line.substring(2);
      style = EmberText.h1;
    } else {
      style = EmberText.bodyDim.copyWith(fontSize: 14);
      text = line
          .replaceAll('**', '')
          .replaceAll(RegExp(r'^\s*-\s'), '• ');
    }
    return Padding(
      padding: EdgeInsets.only(
          top: line.startsWith('#') ? Space.m : 2, bottom: 2),
      child: Text(text, style: style),
    );
  }
}
