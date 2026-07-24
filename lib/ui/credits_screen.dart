// ui/credits_screen.dart — renders the bundled CREDITS.md (the CC-BY
// attributions legally must ship visibly in-app; CREDITS.md is registered as
// a Flutter asset in pubspec.yaml). Lightweight markdown-ish rendering:
// headers by #-depth, list items, plain paragraphs. No new dependencies.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('CREDITS & LICENSES',
            style: TextStyle(
                fontFamily: 'Cinzel',
                color: Color(0xFFE8A33D),
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('CREDITS.md'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFE8A33D)));
          }
          final lines = snap.data!.split('\n');
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: lines.length,
            itemBuilder: (context, i) => _line(lines[i]),
          );
        },
      ),
    );
  }

  Widget _line(String raw) {
    final line = raw.trimRight();
    if (line.isEmpty) return const SizedBox(height: 8);
    if (line.startsWith('#')) {
      final depth = line.indexOf(' ');
      final text = line.substring(depth + 1).trim();
      return Padding(
        padding: EdgeInsets.only(top: depth <= 1 ? 4 : 14, bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'Cinzel',
                fontWeight: FontWeight.bold,
                fontSize: depth <= 1 ? 20 : (depth == 2 ? 16 : 14),
                color: const Color(0xFFE8A33D))),
      );
    }
    final isItem = line.startsWith('- ');
    final text = _stripMd(isItem ? line.substring(2) : line);
    return Padding(
      padding: EdgeInsets.only(left: isItem ? 12 : 0, bottom: 4),
      child: Text(isItem ? '•  $text' : text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, height: 1.4)),
    );
  }

  /// Drop **bold** markers and [label](url) syntax noise, keep the content.
  String _stripMd(String s) => s.replaceAll('**', '');
}
