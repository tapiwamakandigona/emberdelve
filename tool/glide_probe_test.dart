// tool/glide_probe_test.dart — repaint cost probe for the two newest hot
// paths (tool/, NOT in CI; same method as perf_probe_test.dart):
//
//   1. The Codex lane glide (v0.177+ THE CODEX LANES): walkToAnchor drives
//      a 1200px/70ms linear walk down a 119-entry ListView. Scroll frames
//      MUST repaint the viewport — the question is whether the glide also
//      drags the lane chips, the app bar, or the whole route with it.
//   2. The title with the day-2 return line active (THE RETURNED DELVER):
//      idle cost must be identical to the plain title — the line is a
//      static Text, so anything above EmberDrift's own layer is a leak.
//
//   flutter test tool/glide_probe_test.dart
//
// Reports to build/glide_probe/metrics.json. Reports, never asserts perf.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/glide_probe';

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

  testWidgets('codex lane glide + day-2 title repaint probe', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory('$outDir/save')..createSync(recursive: true);
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    c.markTutorialSeen();

    // ------ 1 & 2. Codex: idle baseline, then the lane glide -------------
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: CodexScreen(c),
      ),
    );
    await pumpFrames(tester, 30);

    await measure('codex_idle_60f', () => pumpFrames(tester, 60));

    // Tap the far lane (Dice, the book's last section) and pump until the
    // walk lands. The tap's future completes only when the glide ends, so
    // drive frames alongside it.
    // The chip's onTap discards the glide future, so tap() returns at once
    // and the walk runs while we pump frames. Chips beyond the 360px
    // viewport need ensureVisible first (codex_lanes_test lesson).
    await tester.ensureVisible(find.byKey(const ValueKey('codex-lane-dice')));
    await tester.pump();
    await measure('codex_glide_world_to_dice', () async {
      await tester.tap(
        find.byKey(const ValueKey('codex-lane-dice')),
        warnIfMissed: false,
      );
      // Worst case: 48 steps x 70ms + 250ms settle at 16ms frames.
      await pumpFrames(tester, 220);
    });

    // And back up (preferUp path). Re-anchor the chip row first: the
    // ensureVisible above scrolled World off the left edge.
    await tester.ensureVisible(find.byKey(const ValueKey('codex-lane-world')));
    await tester.pump();
    await measure('codex_glide_dice_to_world', () async {
      await tester.tap(
        find.byKey(const ValueKey('codex-lane-world')),
        warnIfMissed: false,
      );
      await pumpFrames(tester, 220);
    });

    // ------ 3 & 4. Title idle: plain vs day-2 return line ----------------
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    );
    await pumpFrames(tester, 40);
    await measure('title_idle_plain_60f', () => pumpFrames(tester, 60));

    c.meta.lastDailyDate = dailyKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    c.meta.lastDailyWon = false;
    c.meta.lastDailyFloor = 5;
    c.meta.lastDailyFloors = 9;
    c.announce('rebuild');
    await pumpFrames(tester, 20);
    expect(find.byKey(const ValueKey('daily-return')), findsOneWidget);
    await measure('title_idle_day2_60f', () => pumpFrames(tester, 60));

    final json = const JsonEncoder.withIndent('  ').convert({
      'generated': DateTime.now().toIso8601String(),
      'scenarios': [for (final m in results) m.toJson()],
    });
    File('$outDir/metrics.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(json);
    // ignore: avoid_print
    print('PERF wrote $outDir/metrics.json');
  });
}
