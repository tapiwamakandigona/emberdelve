// test/normal_nudge_test.dart — v0.29.0 post-Easy-win Normal invitation
// (retention hook #3, docs/research/retention-hooks-2026-08-23.md): the
// summary names a next action after an EASY win — one quiet panel that says
// Normal exists, with a CTA that starts a fresh Normal run.
//
// Pins:
//   1. Easy WIN → panel + CTA present; tapping the CTA starts a new run on
//      normal with the same delver AND records normal as the explicit sticky
//      preference (same rule as a title-selector tap).
//   2. Normal WIN → no panel (nothing to nudge toward).
//   3. Easy LOSS → no panel (never a "do better" prod after a death; the
//      summary's loss voice stays recognition-only, spec §5).
//
// Seeds pinned by an offline bot hunt (kindler, boons): seed 1 wins on both
// easy and normal; seed 18 loses on easy. Sim is deterministic (R1), so
// these stay stable until simVersion changes.
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
  testWidgets('easy win shows the Normal invitation; CTA starts a normal run '
      'and sets the sticky preference', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');

    final panel = find.byKey(const ValueKey('normal-nudge'));
    await tester.scrollUntilVisible(panel, -200);
    expect(panel, findsOneWidget);
    final cta = find.byKey(const ValueKey('delve-normal-cta'));
    expect(cta, findsOneWidget);

    await tester.ensureVisible(cta);
    await tester.pump();
    await tester.tap(cta);
    await pumpFor(tester, 400);

    expect(c.sim!.run?['difficulty'], 'normal');
    expect(c.sim!.run?['character'], 'kindler');
    expect(c.meta.preferredDifficulty, 'normal');
    expect(c.meta.difficultyChosen, isTrue);
  });

  testWidgets('normal win shows no nudge', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(
      character: 'kindler',
      seed: 1,
      boons: true,
      difficulty: 'normal',
    );
    await playOut(tester, c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on normal');
    expect(find.byKey(const ValueKey('normal-nudge')), findsNothing);
  });

  testWidgets('easy loss shows no nudge', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    expect(find.byKey(const ValueKey('normal-nudge')), findsNothing);
  });
}
