// test/reduced_motion_stillness_test.dart — regression tests for the
// 2026-09-01 stillness audit: every continuous decorative loop must stop
// under reduce motion (Motion.instance.reduced), and resume when it lifts.
//
// Gated loops covered here:
//   • EmberLogotype glow/spark clock (lib/ui/logo.dart)
//   • WeaponView idle sway (lib/ui/weapons.dart)
//   • SpriteView bob/sway life ticker (lib/ui/sprites.dart)
//
// Census pattern: debugOnProfilePaint by runtimeType, warmup frames first,
// end with pumpWidget(SizedBox.shrink()).
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/logo.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _paintCensus(
  WidgetTester tester,
  Widget child, {
  int warmup = 30,
  int census = 60,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  // Let async asset loads (sprite sheets) finish before counting.
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  for (var i = 0; i < warmup; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  var paints = 0;
  debugOnProfilePaint = (ro) {
    if (ro is RenderCustomPaint) paints++;
  };
  for (var i = 0; i < census; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  debugOnProfilePaint = null;
  return paints;
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(Motion.instance.reset);
  tearDown(Motion.instance.reset);

  testWidgets('EmberLogotype is still under reduce, alive without', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    final still = await _paintCensus(
      tester,
      const EmberLogotype('EMBERDELVE'),
    );
    await _teardown(tester);
    expect(still, 0, reason: 'logotype must not repaint under reduce motion');

    Motion.instance.update(setting: 'off');
    final alive = await _paintCensus(
      tester,
      const EmberLogotype('EMBERDELVE'),
    );
    await _teardown(tester);
    expect(
      alive,
      greaterThan(30),
      reason: 'without reduce, the glow clock repaints every frame',
    );
  });

  testWidgets('EmberLogotype resumes when reduce lifts mid-session', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: EmberLogotype('EMBERDELVE'))),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    Motion.instance.update(setting: 'off');
    var paints = 0;
    debugOnProfilePaint = (ro) {
      if (ro is RenderCustomPaint) paints++;
    };
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnProfilePaint = null;
    await _teardown(tester);
    expect(paints, greaterThan(15), reason: 'clock must resume on toggle');
  });

  testWidgets('WeaponView idle sway is still under reduce, alive without', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    final still = await _paintCensus(
      tester,
      const WeaponView('kindler', height: 64),
    );
    await _teardown(tester);
    expect(still, 0, reason: 'idle sway must not repaint under reduce');

    Motion.instance.update(setting: 'off');
    final alive = await _paintCensus(
      tester,
      const WeaponView('kindler', height: 64),
    );
    await _teardown(tester);
    expect(alive, greaterThan(30), reason: 'sway clock repaints every frame');
  });

  testWidgets('flame wipe falls back to plain fade under reduce', (
    tester,
  ) async {
    Future<void> mount(String phase) => tester.pumpWidget(
      MaterialApp(
        home: PhaseSwitcher(
          phaseKey: phase,
          flameWipe: true,
          child: ColoredBox(
            color: phase == 'a' ? Colors.red : Colors.blue,
          ),
        ),
      ),
    );

    // Baseline: CustomPaints present when idle (framework-owned ones).
    Motion.instance.update(setting: 'off');
    await mount('a');
    final idle = find.byType(CustomPaint).evaluate().length;

    // Without reduce: the map->combat wipe adds its flame overlay painter.
    await mount('b');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(CustomPaint).evaluate().length,
      idle + 1,
      reason: 'flame wipe painter must be present mid-transition',
    );
    await tester.pumpAndSettle();
    await _teardown(tester);

    // Under reduce: same transition dissolves through plain black —
    // opacity only, no displacement sweep, no extra painter.
    Motion.instance.update(setting: 'on');
    await mount('a');
    await mount('b');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(CustomPaint).evaluate().length,
      idle,
      reason: 'under reduce the wipe must fall back to the plain fade',
    );
    await tester.pumpAndSettle();
    await _teardown(tester);
  });

  testWidgets('SpriteView bob life ticker is still under reduce', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    final still = await _paintCensus(
      tester,
      const SpriteView('kindler', height: 64, bob: true, animate: true),
    );
    await _teardown(tester);
    // Both sprite clocks gate on reduce: the bob/sway life ticker AND the
    // sheet frame loop (parked on frame 0, the portrait pose).
    expect(
      still,
      0,
      reason: 'no sprite clock may drive repaints under reduce',
    );

    Motion.instance.update(setting: 'off');
    final alive = await _paintCensus(
      tester,
      const SpriteView('kindler', height: 64, bob: true, animate: true),
    );
    await _teardown(tester);
    expect(alive, greaterThan(30), reason: 'bob repaints every frame');
  });
}
