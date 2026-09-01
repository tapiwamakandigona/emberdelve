// tool/combat_idle_probe_test.dart — probe: painter census on an IDLE combat
// screen (player_turn, dice dealt, waiting for input). Reports, never asserts.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('combat idle painter census', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = GameController();
    c.meta
      ..tutorialSeen = true
      ..tourSeenVersion = tourVersion
      ..tipsSeen.addAll(ContextTips.all);
    c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
    c.startRun(character: 'kindler', seed: 1, boons: false, difficulty: 'easy');
    var guard = 0;
    while (c.state!['phase'] != 'player_turn' && guard++ < 500) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    // ignore: avoid_print
    print('PHASE ${c.state!['phase']} after $guard steps');

    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: CombatScreen(c),
    ));
    // Warm up past entrance animations.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    var frames = 0;
    var paints = 0;
    final byType = <String, int>{};
    debugOnProfilePaint = (RenderObject ro) {
      paints++;
      final t = ro.runtimeType.toString();
      byType[t] = (byType[t] ?? 0) + 1;
    };
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    debugOnProfilePaint = null;

    final top = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('COMBAT IDLE frames=$frames paints=$paints '
        '(${(paints / frames).toStringAsFixed(1)}/frame)');
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ')
        .convert({for (final e in top.take(24)) e.key: e.value}));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
