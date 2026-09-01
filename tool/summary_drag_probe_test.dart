// tool/summary_drag_probe_test.dart — one-off probe: painter census while
// DRAGGING the run summary (perf book: drag 11.6/frame). Uses autoplay to
// reach run_won/run_lost. Reports, never asserts.
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

  testWidgets('summary drag painter census', (tester) async {
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
    // Seed 1 kindler easy wins on a fresh profile (LESSONS).
    c.startRun(character: 'kindler', seed: 1, boons: false, difficulty: 'easy');
    var guard = 0;
    while (c.state!['phase'] != 'run_won' &&
        c.state!['phase'] != 'run_lost' &&
        guard++ < 4000) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    // ignore: avoid_print
    print('PHASE ${c.state!['phase']} after $guard steps');

    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: SummaryScreen(c),
    ));
    for (var i = 0; i < 90; i++) {
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
    // Slow scrub drag: 60 move frames down then up.
    final g = await tester.startGesture(const Offset(180, 500));
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(0, -6));
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    await g.up();
    debugOnProfilePaint = null;

    final top = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('SUMMARY DRAG frames=$frames paints=$paints '
        '(${(paints / frames).toStringAsFixed(1)}/frame)');
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ')
        .convert({for (final e in top.take(20)) e.key: e.value}));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
