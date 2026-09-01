// tool/entrance_probe_test.dart — repaint cost probe for the two new
// entrance effects (tool/, NOT in CI; same method as glide/summary probes).
//
//   1. DealtIn (boon screen): while the hand deals (~30 frames) each card's
//      FadeTransition/Transform repaints — that cost is owed. Settled, the
//      widgets are identity wrappers: the screen should fall back to the
//      EmberDrift baseline and nothing card-shaped should paint.
//   2. SmolderIn (rest hollow): during the 900ms sweep the ShaderMask over
//      the tale repaints — owed. Settled, the mask is DROPPED (`return
//      child!`), so the hollow must cost exactly the EmberDrift baseline;
//      any ShaderMask paint after settle is a leak.
//
//   flutter test tool/entrance_probe_test.dart
//
// Reports to build/entrance_probe/metrics.json. Reports, never asserts perf.
import 'dart:convert';
import 'dart:io';

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

const outDir = 'build/entrance_probe';

class Metrics {
  final String label;
  int frames = 0;
  int paints = 0;
  final Map<String, int> paintsByType = {};
  Metrics(this.label);
  double get paintsPerFrame => frames == 0 ? 0 : paints / frames;
  Map<String, Object?> toJson() {
    final top = paintsByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'label': label,
      'frames': frames,
      'paints': paints,
      'paints_per_frame': double.parse(paintsPerFrame.toStringAsFixed(1)),
      'top_painted': {for (final e in top.take(14)) e.key: e.value},
    };
  }
}

final List<Metrics> results = [];
Metrics? _live;

Future<Metrics> measure(String label, Future<void> Function() body) async {
  final m = Metrics(label);
  _live = m;
  debugOnProfilePaint = (RenderObject ro) {
    m.paints++;
    final t = ro.runtimeType.toString();
    m.paintsByType[t] = (m.paintsByType[t] ?? 0) + 1;
  };
  try {
    await body();
  } finally {
    debugOnProfilePaint = null;
    _live = null;
  }
  results.add(m);
  // ignore: avoid_print
  print(
    'PERF ${m.label}: frames=${m.frames} paints=${m.paints} '
    '(${m.paintsPerFrame.toStringAsFixed(1)}/frame)',
  );
  return m;
}

Future<void> pumpFrames(
  WidgetTester tester,
  int n, {
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(step);
    _live?.frames++;
  }
}

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
}

GameController _seasoned() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boon screen: dealing vs settled', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _seasoned();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    // Mount BoonScreen DIRECTLY (no GameRoot): the PhaseSwitcher fade
    // legitimately repaints the whole incoming screen every frame, which
    // would drown the DealtIn signal this probe is after.
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: BoonScreen(c),
      ),
    );
    await tester.pump(const Duration(milliseconds: 25));
    expect(find.byKey(const ValueKey('boon-1')), findsOneWidget);

    // ---- 1. The deal: ~30 frames covering the stagger window -----------
    await measure('boon_dealing_30f', () => pumpFrames(tester, 30));

    // Let every card settle (third card done at ~480ms) plus slack.
    await pumpFrames(tester, 60);

    // ---- 2. Settled: EmberDrift baseline only ---------------------------
    await measure('boon_settled_60f', () => pumpFrames(tester, 60));
  });

  testWidgets('map idle: pulse cost, walls must stay quiet', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _seasoned();
    c.startRun(character: 'kindler', seed: 6, difficulty: 'easy');
    var guard = 0;
    while (c.phase != 'map' && guard++ < 50) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'map');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: MapScreen(c),
      ),
    );
    // Let the entrance walk/camera settle before measuring.
    await pumpFrames(tester, 90);

    // Idle: the reachable-node pulse and EmberDrift are the only owed
    // costs. THE CARVED CHASM walls live in the scene painter behind a
    // RepaintBoundary — any _MapScenePainter repaint here is a leak.
    final m = await measure('map_idle_60f', () => pumpFrames(tester, 60));
    final scenePaints = m.paintsByType.entries
        .where((e) => e.key.contains('CustomPaint'))
        .fold(0, (a, e) => a + e.value);
    // Report only (probe doctrine), but surface the number loudly.
    // ignore: avoid_print
    print('MAP custom-paint paints over 60 idle frames: $scenePaints');

    // THE DEEP WALL: drag cost. The parallax far plane repaints only on
    // scrolled frames — measure a steady drag to price it.
    final drag = await measure('map_drag_30f', () async {
      final gesture = await tester.startGesture(const Offset(180, 400));
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(0, -4));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
    });
    // ignore: avoid_print
    print('MAP drag paints/frame: ${drag.paintsPerFrame}');
    // The deep wall must have repainted during the drag (parallax is
    // scroll-driven) — find its RenderCustomPaint via the ValueKey.
    final wallEl = tester.element(find.byKey(const ValueKey('deep-wall')));
    var wallPaints = 0;
    debugOnProfilePaint = (ro) {
      if (ro == wallEl.renderObject) wallPaints++;
    };
    final g2 = await tester.startGesture(const Offset(180, 400));
    for (var i = 0; i < 10; i++) {
      await g2.moveBy(const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g2.up();
    debugOnProfilePaint = null;
    // ignore: avoid_print
    print('MAP deep-wall paints over 10 scrolled frames: $wallPaints');
  });

  testWidgets('rest hollow: smolder vs settled', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _seasoned();
    c.startRun(character: 'kindler', seed: 6, difficulty: 'easy');
    var guard = 0;
    while (c.phase != 'rest' &&
        c.phase != 'run_won' &&
        c.phase != 'run_lost' &&
        guard++ < 400) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'rest');

    // Mount RestScreen DIRECTLY (no GameRoot) for the same reason as the
    // boon test: keep the PhaseSwitcher fade out of the measurement.
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: RestScreen(c),
      ),
    );
    await tester.pump(const Duration(milliseconds: 25));
    expect(find.byKey(const ValueKey('hearth-tale')), findsOneWidget);

    // ---- 3. The sweep: ~40 frames inside the 900ms smolder --------------
    await measure('rest_smolder_40f', () => pumpFrames(tester, 40));

    // Finish the sweep with slack, then confirm the mask is gone.
    await pumpFrames(tester, 60);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('hearth-tale')),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );

    // ---- 4. Settled: EmberDrift baseline only ---------------------------
    await measure('rest_settled_60f', () => pumpFrames(tester, 60));

    // Write the report.
    Directory(outDir).createSync(recursive: true);
    File('$outDir/metrics.json').writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert([for (final m in results) m.toJson()]),
    );
    // ignore: avoid_print
    print('WROTE $outDir/metrics.json');
  });
}
