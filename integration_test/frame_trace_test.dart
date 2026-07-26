// integration_test/frame_trace_test.dart — real frame-time trace for the
// scenarios the perf probe measures with paint counts (remaining-work §1).
//
// Runs on a real device or emulator in --profile mode and records a timeline
// per scenario. The driver (test_driver/perf_driver.dart) summarizes each
// timeline into frame build/raster percentiles:
//
//   flutter drive --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/frame_trace_test.dart
//
// Scenarios mirror tool/perf_probe_test.dart so the paint-count numbers and
// the frame-time numbers name the same thing:
//   title_tap_storm   — 12 press/release cycles on the title CTA
//   combat_button_storm — 12 rapid taps on the primary combat action
//   map_drag          — 30-step drag on the delve map while the glow pulses
//
// CAVEAT recorded here so nobody over-reads the numbers: on a CI emulator the
// raster thread runs on SwiftShader (software GPU). UI-thread frame build
// times are representative; raster times are pessimistic. A run on real
// hardware uses the same test verbatim.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

const int kSessionSeed = 20260725; // same seed as the probe: same fight.

Finder buttonWithLabel(String label, {bool startsWith = false}) =>
    find.byWidgetPredicate(
      (w) =>
          w is EmberButton &&
          w.onTap != null &&
          (startsWith ? w.label.startsWith(label) : w.label == label),
    );

Future<void> pumpFrames(
  WidgetTester tester,
  int n, {
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(step);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame trace: title storm, combat storm, map drag', (
    tester,
  ) async {
    final saveDir = Directory.systemTemp.createTempSync('ember_frame_trace');
    final c = GameController(saveDirOverride: saveDir.path);
    await c.boot();
    // Fresh save => first-fight tutorial scrim would eat the taps (probe
    // harness bug, fixed 2026-07-25). Measure the game, not the tutorial.
    c.markTutorialSeen();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    );
    await pumpFrames(tester, 60); // warm up: images decode, shaders compile.

    // -- 1. Title tap storm ----------------------------------------------
    final cta = buttonWithLabel('Delve', startsWith: true);
    expect(cta, findsWidgets, reason: 'title CTA must exist to storm it');
    await binding.traceAction(() async {
      for (var i = 0; i < 12; i++) {
        final g = await tester.startGesture(tester.getCenter(cta.first));
        await pumpFrames(tester, 1);
        await g.cancel(); // press + release visuals, no navigation.
        await pumpFrames(tester, 4);
      }
      await pumpFrames(tester, 10);
    }, reportKey: 'title_tap_storm');

    // -- 2. Drive into combat via the sim bot ------------------------------
    c.startRun(seed: kSessionSeed, character: null);
    await pumpFrames(tester, 30);
    var guard = 0;
    while (c.phase != 'player_turn' && guard++ < 200) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
      await pumpFrames(tester, 6);
    }
    expect(c.phase, 'player_turn', reason: 'bot must reach combat');
    await pumpFrames(tester, 40);

    // -- 3. Combat button storm --------------------------------------------
    await binding.traceAction(() async {
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
    }, reportKey: 'combat_button_storm');

    // -- 4. Drive to the map ------------------------------------------------
    var guard2 = 0;
    while (c.phase != 'map' && guard2++ < 600) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
      await pumpFrames(tester, 1);
    }
    if (c.phase == 'map') {
      await pumpFrames(tester, 60); // let the auto-follow scroll settle.
      final scroller = find.byType(SingleChildScrollView);
      if (scroller.evaluate().isNotEmpty) {
        await binding.traceAction(() async {
          final g = await tester.startGesture(
            tester.getCenter(scroller.first),
          );
          for (var i = 0; i < 30; i++) {
            await g.moveBy(const Offset(0, 4));
            await pumpFrames(tester, 1);
          }
          await g.up();
          await pumpFrames(tester, 30);
        }, reportKey: 'map_drag');
      }
    }
    // Map is best-effort: some seeds die in fight 1; the two traced storms
    // above are the complaint. Missing map_drag shows up in the driver output.
  });
}
