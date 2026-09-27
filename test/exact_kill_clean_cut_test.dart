// Exact-kill "Clean Cut" (v0.184.0): the signature exactly-lethal kill earns a
// distinct CleanCutFlash contact read over the foe; ordinary and overkill kills
// do not. Presentation-only — the sealed sim still resolves synchronously at
// tap time (the contact-timeline tests own that contract); this only asserts
// which killing blows get the flourish. No simulation state or hashes change.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as fixture;

Finder _dice() =>
    find.byWidgetPredicate((w) => w is DieChip && w.value != null);

Future<void> _roll(WidgetTester tester) async {
  await tester.tap(fixture.button('Roll'));
  await fixture.pumpFor(tester, 1800);
}

/// First 1-based die whose attack assignment resolves to a positive value,
/// using the same pure preview combat itself calls. Skips block-only dice.
(int, int) _firstAttackDie(dynamic sim) {
  final n = (sim.player['rolled'] as List).length;
  for (var die = 1; die <= n; die++) {
    final r = resolveAssignment(
      player: sim.player,
      enemy: sim.enemy!,
      run: sim.run,
      die: die,
      action: 'attack',
    );
    if (r.allowed && r.value > 0) return (die, r.value);
  }
  throw StateError('no attack-capable die in this roll');
}

void _notify(GameController c) {
  // Explicit fixture state, not an app mutation path (mirrors the
  // contact-timeline test's helper).
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
}

/// True if a CleanCutFlash is mounted at any pump within the next [ms].
Future<bool> _sawCleanCut(WidgetTester tester, int ms) async {
  var seen = false;
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CleanCutFlash).evaluate().isNotEmpty) seen = true;
  }
  return seen;
}

Future<void> _cleanup(WidgetTester tester) async {
  await fixture.pumpFor(tester, 2600);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await fixture.pumpFor(tester, 2200);
}

void main() {
  testWidgets('exact kill shows the clean-cut flourish', (tester) async {
    final c = await fixture.intoFight(tester);
    await _roll(tester);
    final (die, value) = _firstAttackDie(c.sim!);
    // Exactly lethal: hp + block == this die's attack value.
    c.sim!.enemy!['hp'] = value;
    c.sim!.enemy!['block'] = 0;
    _notify(c);
    await tester.pump();
    await tester.tap(_dice().at(die - 1));
    await tester.pump();
    await tester.tap(fixture.button('Attack'));
    expect(c.phase, isNot('player_turn'), reason: 'the blow is lethal');
    expect(
      await _sawCleanCut(tester, 900),
      isTrue,
      reason: 'an exact kill earns the CleanCutFlash contact read',
    );
    await _cleanup(tester);
  });

  testWidgets('overkill does not show the clean-cut flourish', (tester) async {
    final c = await fixture.intoFight(tester);
    await _roll(tester);
    final (die, value) = _firstAttackDie(c.sim!);
    expect(value, greaterThan(1), reason: 'need surplus for a real overkill');
    // One HP of foe, a die worth more: lethal with surplus — not exact.
    c.sim!.enemy!['hp'] = 1;
    c.sim!.enemy!['block'] = 0;
    _notify(c);
    await tester.pump();
    await tester.tap(_dice().at(die - 1));
    await tester.pump();
    await tester.tap(fixture.button('Attack'));
    expect(c.phase, isNot('player_turn'), reason: 'the blow is lethal');
    expect(
      await _sawCleanCut(tester, 900),
      isFalse,
      reason: 'a sloppy overkill must not read as an exact kill',
    );
    await _cleanup(tester);
  });

  testWidgets('CleanCutFlash renders, then reports done and stops painting', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: CleanCutFlash(onDone: () => done = true),
          ),
        ),
      ),
    );
    expect(find.byType(CleanCutFlash), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100)); // mid-beat
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 500)); // past the 440ms life
    expect(done, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
