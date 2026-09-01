// tool/summary_probe_test.dart — repaint cost probe for the grown summary
// screen (tool/, NOT in CI; same method as glide_probe_test.dart). Since
// v0.177 the summary gained the next-delver panel (a second live SpriteView)
// and THE NAMED FOE row. Questions:
//
//   1. Idle cost on a loss summary: two SpriteViews tick (hero + next
//      delver, 2800ms _life tickers) — do their RepaintBoundaries hold, or
//      does a tick drag the ledger/route with it?
//   2. Scroll cost: dragging the summary list — viewport repaint is owed;
//      panel interiors crossing the screen are lazy-inflation, fine; the
//      leak to watch is anything OUTSIDE the scrollable repainting.
//   3. The named-foe tap: the codex route push + openEntry glide — the walk
//      already measured clean on codex_screen; this measures the push.
//
//   flutter test tool/summary_probe_test.dart
//
// Reports to build/summary_probe/metrics.json. Reports, never asserts perf.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/summary_probe';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('summary idle + scroll + named-foe push repaint probe', (
    tester,
  ) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory('$outDir/save')..createSync(recursive: true);
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    c.markTutorialSeen();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await pumpFrames(tester, 20);
    var guard = 0;
    while (guard++ < 400 && c.phase != 'run_lost' && c.phase != 'run_won') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'run_lost');
    // Let the sprite sheets decode and the summary settle before measuring.
    await tester.binding.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await pumpFrames(tester, 40);

    // ------ 1. Idle: two live sprites, everything else must sleep --------
    await measure('summary_idle_loss_60f', () => pumpFrames(tester, 60));

    // ------ 2. Scroll: one full drag down and back ------------------------
    final scrollable = find
        .descendant(
          of: find.byType(SummaryScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await measure('summary_drag_down_up', () async {
      await tester.drag(scrollable, const Offset(0, -900));
      await pumpFrames(tester, 30);
      await tester.drag(scrollable, const Offset(0, 900));
      await pumpFrames(tester, 30);
    });

    // ------ 3. Named-foe push: route transition into the codex glide ------
    final row = find.byKey(const ValueKey('named-foe'));
    await tester.scrollUntilVisible(row, 200);
    await pumpFrames(tester, 20);
    await measure('named_foe_push_and_glide', () async {
      await tester.tap(row);
      await pumpFrames(tester, 120);
    });
    expect(find.byType(CodexScreen), findsOneWidget);

    File('$outDir/metrics.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert([for (final m in results) m.toJson()]),
      );
  });
}
