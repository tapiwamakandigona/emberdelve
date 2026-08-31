// test/next_delver_test.dart — THE NEXT DELVER (retention lane, DEMAND
// 2026-08-31c focus #1): the run summary names the cheapest locked delver —
// the picker's nextUnlockTarget — with the player's real ember arithmetic.
// The picker has always known who unlocks next; the run's end (the moment a
// player decides about tomorrow) never said it.
//
// Pins:
//   1. Fresh profile, easy LOSS → panel present, names meta.nextUnlockTarget
//      (the Warden on a fresh profile), shows the REAL '<have> / <cost>
//      embers' line (§Ethics honesty — a shown number can never lie).
//   2. Affordable (embers >= cost, delver still locked) → the bar and
//      arithmetic give way to the plain banked statement — a fact, never a
//      countdown or a prod.
//   3. Roster complete → the panel says nothing at all.
//
// Seeds pinned by the offline bot hunt (kindler, boons, simVersion 7):
// seed 18 loses on easy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
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
  testWidgets('easy loss: the next delver is named with real arithmetic', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    final target = c.meta.nextUnlockTarget!;
    expect(
      target.id,
      charactersOrder[1],
      reason: 'fresh profile: the cheapest locked delver is the second',
    );
    final panel = find.byKey(const ValueKey('next-delver'));
    await tester.scrollUntilVisible(panel, 200);
    expect(panel, findsOneWidget);
    expect(
      find.descendant(
        of: panel,
        matching: find.text('NEXT DELVER — ${target.name.toUpperCase()}'),
      ),
      findsOneWidget,
    );
    // The arithmetic is the profile's real numbers, never a mock.
    expect(
      c.meta.embers,
      lessThan(target.unlockEmbers),
      reason: 'one easy loss cannot afford the second delver',
    );
    expect(
      find.descendant(
        of: panel,
        matching: find.text(
          '${c.meta.embers} / ${target.unlockEmbers} embers',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('next-delver-sprite')), findsOneWidget);
  });

  testWidgets('affordable: the arithmetic gives way to the banked fact', (
    tester,
  ) async {
    final c = GameController();
    c.meta.embers = 5000; // more than any unlock, all delvers still locked
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    final panel = find.byKey(const ValueKey('next-delver'));
    await tester.scrollUntilVisible(panel, 200);
    expect(panel, findsOneWidget);
    expect(
      find.descendant(
        of: panel,
        matching: find.text('The embers are banked. They wait at the hearth.'),
      ),
      findsOneWidget,
    );
    // No bar arithmetic when the fact is already banked.
    expect(
      find.descendant(
        of: panel,
        matching: find.textContaining('/ '),
      ),
      findsNothing,
    );
  });

  testWidgets('roster complete: the panel says nothing at all', (
    tester,
  ) async {
    final c = GameController();
    c.meta.unlockedCharacters.addAll(charactersOrder);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.meta.nextUnlockTarget, isNull);
    expect(find.byKey(const ValueKey('next-delver')), findsNothing);
  });
}
