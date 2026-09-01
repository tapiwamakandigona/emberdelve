// THE SETTLING COUNT (summary_screen.dart) — the banked-embers number
// counts up once and rests at the exact value. Contracts under test:
//   1. The resting value is EXACT (honesty: the animation may style the
//      arrival, never the fact).
//   2. Mid-animation the number is climbing (the settle exists at all).
//   3. Under reduce motion the exact value shows on the FIRST frame — a
//      delayed fact is a cost, not a courtesy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';

GameController summaryFixture() {
  final c = GameController();
  c.startRun(character: 'kindler', seed: 1, boons: true);
  var guard = 0;
  while (guard++ < 4000 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect({'run_won', 'run_lost'}.contains(c.phase), isTrue);
  return c;
}

int shownValue(WidgetTester tester) {
  final t = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const ValueKey('settling-count')),
      matching: find.byType(Text),
      matchRoot: true,
    ),
  );
  return int.parse(t.data!);
}

void main() {
  setUp(() => Motion.instance.reset());
  tearDown(() => Motion.instance.reset());

  testWidgets('counts up and rests at the exact banked value', (tester) async {
    final c = summaryFixture();
    final banked = ((c.state!['run'] as Map)['embers'] as num).toInt();
    expect(
      banked,
      greaterThan(0),
      reason: 'fixture must bank embers for the test to mean anything',
    );

    await tester.pumpWidget(MaterialApp(home: SummaryScreen(c)));
    // First frame: the count starts below its resting value.
    expect(shownValue(tester), lessThan(banked));

    // Mid-flight (250ms of 700ms): strictly between start and rest.
    await tester.pump(const Duration(milliseconds: 250));
    final mid = shownValue(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(banked));

    // Past the end: at rest, exact.
    await tester.pump(const Duration(milliseconds: 600));
    expect(shownValue(tester), banked);
    // And it STAYS at rest — no loop, no replay.
    await tester.pump(const Duration(milliseconds: 400));
    expect(shownValue(tester), banked);
  });

  testWidgets('reduce motion shows the exact value on the first frame', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on'); // 'on' = always reduced
    final c = summaryFixture();
    final banked = ((c.state!['run'] as Map)['embers'] as num).toInt();

    await tester.pumpWidget(MaterialApp(home: SummaryScreen(c)));
    expect(shownValue(tester), banked);
  });
}
