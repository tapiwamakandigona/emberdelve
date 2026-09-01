// test/first_fall_test.dart — THE FIRST FALL (retention lane, DEMAND
// 2026-08-31c focus #1, first-session funnel): the profile's very first
// lost run gets one gold framing line. Slay the Spire telemetry puts
// first-run losses near 90% — the first fall IS the genre's normal first
// experience, and Hades' death-moment lesson says it must not read as
// wasted time. The line states only true facts: every death banks embers
// (sim floor 5 + layer), and they persist.
//
// Pins:
//   1. Fresh profile, first run loses → 'first-fall' line present, and the
//      fact it leans on is true (the run banked embers > 0).
//   2. Second loss on the same profile → line absent (once ever).
//   3. Fresh profile, first run WINS → line absent (it frames falls only).
//
// Seeds pinned by the offline bot hunt (kindler, boons, simVersion 7):
// seed 18 loses on easy (also when replayed back-to-back), seed 1 wins.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Future<void> playOut(WidgetTester tester, GameController c) async {
  await pumpFor(tester, 400);
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(
    {'run_won', 'run_lost'}.contains(c.phase),
    isTrue,
    reason: 'bot must reach a terminal phase (guard=$guard)',
  );
  await pumpFor(tester, 2500);
}

void main() {
  final line = find.byKey(const ValueKey('first-fall'));

  testWidgets('first-ever loss: the fall is framed, the fact is true', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    expect(c.meta.runsPlayed, 1);
    expect(
      (c.state!['run'] as Map)['embers'] as int,
      greaterThan(0),
      reason: 'the line claims banked embers — the claim must be true',
    );
    await tester.scrollUntilVisible(line, 200);
    expect(line, findsOneWidget);
  });

  testWidgets('second loss: the line has said its piece', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost');
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    expect(c.meta.runsPlayed, 2);
    expect(line, findsNothing);
  });

  testWidgets('first-ever win: no fall to frame', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(line, findsNothing);
  });
}
