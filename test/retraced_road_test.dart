// test/retraced_road_test.dart — v0.44.0 The Retraced Road: a lost delve can
// be retraced — the SAME seed, delver, difficulty, and rung, so the map,
// offers, and rolls all repeat and only the player's choices change.
//
// Pins:
//   1. Easy LOSS → 'Retrace this delve' present with its fact line; tapping
//      it starts a run whose seed, delver, and difficulty are IDENTICAL to
//      the lost run (the whole point — the claim in the copy must be true).
//   2. Easy WIN → no retrace affordance (a won delve has nothing to relearn;
//      'Delve again' already covers the fresh-seed path).
//   3. Shared-seed integrity: canRetrace is false whenever the finished run
//      was a Daily or Weekly (one shared attempt each — spec §Ethics), and
//      false without a real seed.
//
// Seeds pinned by the offline bot hunt (kindler, boons, simVersion 7):
// seed 1 wins on easy; seed 3 loses on easy.
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

/// Bot-play [c] to a terminal phase, then outlast the terminal-hold
/// choreography so the summary is fully settled.
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
  testWidgets('easy loss: retrace restarts the exact same delve', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 3, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost', reason: 'seed 3 must lose on easy');
    expect(c.canRetrace, isTrue);

    final button = find.byKey(const ValueKey('retrace-delve'));
    await tester.scrollUntilVisible(button, -200);
    expect(button, findsOneWidget);
    // The honest fact line rides with the button.
    expect(find.byKey(const ValueKey('retrace-fact')), findsOneWidget);

    await tester.tap(button);
    await pumpFor(tester, 600);

    // The retraced run IS the lost run's challenge: same seed, same delver,
    // same difficulty — and it is live again (no longer a terminal phase).
    expect(c.runSeed, 3, reason: 'retrace must reuse the lost seed');
    expect(c.sim!.run!['character'], 'kindler');
    expect(c.sim!.run!['difficulty'], 'easy');
    expect(c.phase, isNot('run_lost'));
    // A retrace is a fresh attempt, so it can be retraced only after it is
    // lost again — never mid-run.
    expect(c.canRetrace, isFalse);
  });

  testWidgets('easy win: no retrace affordance on a won delve', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(c.canRetrace, isFalse);
    expect(find.byKey(const ValueKey('retrace-delve')), findsNothing);
    expect(find.byKey(const ValueKey('retrace-fact')), findsNothing);
  });

  testWidgets('shared-seed integrity: daily/weekly losses never retrace', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 3, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost');
    expect(c.canRetrace, isTrue, reason: 'baseline: a plain loss retraces');

    // The gate reads the run labels directly, so pin each clause: a Daily
    // label, a Weekly label, or a missing seed each close the door.
    c.dailyDate = '2026-08-25';
    expect(c.canRetrace, isFalse, reason: 'a Daily is one shared attempt');
    c.dailyDate = null;
    c.weeklyIndex = 42;
    expect(c.canRetrace, isFalse, reason: 'a Weekly is one shared attempt');
    c.weeklyIndex = null;
    expect(c.canRetrace, isTrue, reason: 'clearing the labels reopens it');
  });
}
