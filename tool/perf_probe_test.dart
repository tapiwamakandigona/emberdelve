// tool/perf_probe_test.dart — deterministic repaint/rebuild cost probe
// (tool/, NOT in CI). Answers "why does it feel laggy?" with numbers instead
// of opinion.
//
//   flutter test tool/perf_probe_test.dart
//
// Metric 1 — RENDER OBJECTS PAINTED PER FRAME. Flutter calls
// [debugOnProfilePaint] for every RenderObject painted in a frame (debug
// builds only, gated behind an assert). On a well-isolated UI an idle
// animation repaints only the animated subtree; a UI missing RepaintBoundary
// repaints the whole screen every frame. The number IS the jank.
//
// Metric 2 — ELEMENTS REBUILT PER FRAME ([debugOnRebuildDirtyWidget]):
// setState blast radius.
//
// Scenarios: idle on title, rapid-tap storm on title, idle in combat, and a
// rapid-tap storm in combat (the "clicking too quick lags" report).
//
// Results are written to build/perf_probe/metrics.json so before/after runs
// can be diffed. Nothing here asserts a perf target — it reports.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

const outDir = 'build/perf_probe';
const viewSize = Size(360, 800);

class Metrics {
  final String label;
  int frames = 0;
  int paints = 0;
  int rebuilds = 0;
  final Map<String, int> paintsByType = {};
  final Map<String, int> rebuiltByType = {};
  Metrics(this.label);

  double get paintsPerFrame => frames == 0 ? 0 : paints / frames;
  double get rebuildsPerFrame => frames == 0 ? 0 : rebuilds / frames;

  Map<String, Object?> toJson() {
    final top = paintsByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'label': label,
      'frames': frames,
      'paints': paints,
      'rebuilds': rebuilds,
      'paints_per_frame': double.parse(paintsPerFrame.toStringAsFixed(1)),
      'rebuilds_per_frame': double.parse(rebuildsPerFrame.toStringAsFixed(1)),
      'top_painted': {for (final e in top.take(12)) e.key: e.value},
      'top_rebuilt': {
        for (final e
            in (rebuiltByType.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(12))
          e.key: e.value,
      },
    };
  }
}

final List<Metrics> results = [];

/// Run [body] with the paint/rebuild hooks installed. [frames] is counted by
/// the caller pumping; we count via a frame callback on the binding.
Future<Metrics> measure(
  WidgetTester tester,
  String label,
  Future<void> Function() body,
) async {
  final m = Metrics(label);
  debugOnProfilePaint = (RenderObject ro) {
    m.paints++;
    final t = ro.runtimeType.toString();
    m.paintsByType[t] = (m.paintsByType[t] ?? 0) + 1;
  };
  debugOnRebuildDirtyWidget = (Element e, bool builtOnce) {
    m.rebuilds++;
    final t = e.widget.runtimeType.toString();
    m.rebuiltByType[t] = (m.rebuiltByType[t] ?? 0) + 1;
  };
  m.frames = 0;
  void counter() => m.frames++;
  _frameCounters.add(counter);
  try {
    await body();
  } finally {
    _frameCounters.remove(counter);
    debugOnProfilePaint = null;
    debugOnRebuildDirtyWidget = null;
  }
  results.add(m);
  // ignore: avoid_print
  print(
    'PERF ${m.label}: frames=${m.frames} paints=${m.paints} '
    '(${m.paintsPerFrame.toStringAsFixed(1)}/frame) '
    'rebuilds=${m.rebuilds} (${m.rebuildsPerFrame.toStringAsFixed(1)}/frame)',
  );
  return m;
}

final List<void Function()> _frameCounters = [];

/// Pump [n] frames of [step] and count them.
Future<void> pumpFrames(
  WidgetTester tester,
  int n, {
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(step);
    for (final c in List.of(_frameCounters)) {
      c();
    }
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

Future<void> precacheAllImages(WidgetTester tester) async {
  final manifest = await tester.binding.runAsync(
    () => AssetManifest.loadFromAssetBundle(rootBundle),
  );
  final keys = manifest!.listAssets().where((k) => k.endsWith('.png')).toList();
  final context = tester.element(find.byType(MaterialApp));
  await tester.binding.runAsync(() async {
    for (final k in keys) {
      try {
        await precacheImage(AssetImage(k), context);
      } catch (_) {}
    }
  });
  await tester.pump();
}

void drain(WidgetTester tester) {
  for (var i = 0; i < 30; i++) {
    if (tester.takeException() == null) break;
  }
}

Finder buttonWithLabel(String label, {bool startsWith = false}) =>
    find.byWidgetPredicate(
      (w) =>
          w is EmberButton &&
          w.onTap != null &&
          (startsWith ? w.label.startsWith(label) : w.label == label),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('repaint/rebuild cost probe', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory('$outDir/save')..createSync(recursive: true);
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    );
    await precacheAllImages(tester);
    await pumpFrames(tester, 40);
    drain(tester);

    // -- 1. Title screen, idle -------------------------------------------
    await measure(tester, 'title_idle_60f', () async {
      await pumpFrames(tester, 60);
    });

    // -- 2. Title screen, rapid tap storm on the difficulty/menu chrome ---
    // Taps the primary button repeatedly with 16ms between them — the
    // "clicking too quick" case. Uses the settings gear (opens/closes) if a
    // safe idempotent target exists; otherwise the primary CTA press/release
    // cycle without committing the tap.
    final cta = buttonWithLabel('Delve', startsWith: true);
    if (cta.evaluate().isNotEmpty) {
      await measure(tester, 'title_tap_storm_12', () async {
        for (var i = 0; i < 12; i++) {
          final g = await tester.startGesture(tester.getCenter(cta.first));
          await pumpFrames(tester, 1);
          await g.cancel(); // press + release visuals, no navigation
          await pumpFrames(tester, 4);
        }
        await pumpFrames(tester, 10);
      });
    }
    drain(tester);

    // -- 3. Drive into combat via the sim bot -----------------------------
    c.startRun(seed: 20260725, character: null);
    await pumpFrames(tester, 30);
    var guard = 0;
    while (c.phase != 'player_turn' && guard++ < 200) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
      await pumpFrames(tester, 6);
    }
    drain(tester);
    // ignore: avoid_print
    print('PERF reached phase=${c.phase} after $guard bot commands');

    if (c.phase == 'player_turn') {
      await pumpFrames(tester, 40);
      // -- 4. Combat idle -------------------------------------------------
      await measure(tester, 'combat_idle_60f', () async {
        await pumpFrames(tester, 60);
      });

      // -- 5. Combat rapid tap storm --------------------------------------
      // Hammer the primary action button the way an impatient player does.
      // Real taps, hammered: the impatient-player case. Re-finds the primary
      // action each time because the label changes with the turn state.
      await measure(tester, 'combat_tap_storm_12', () async {
        for (var i = 0; i < 12; i++) {
          final t = buttonWithLabel('Roll', startsWith: true);
          final any = t.evaluate().isNotEmpty
              ? t
              : find.byWidgetPredicate(
                  (w) => w is EmberButton && w.onTap != null,
                );
          if (any.evaluate().isEmpty) break;
          await tester.tap(any.first, warnIfMissed: false);
          await pumpFrames(tester, 5);
        }
        await pumpFrames(tester, 20);
      });
    }
    drain(tester);

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
