// test/peddler_test.dart — v0.40.0 The Peddler: the fifth delver, the economy
// archetype. Lean pouch (d6+d6+d4, 14 pips vs the Kindler's 18), 31 HP, and a
// Kiln Key (+8 gold per won fight) so the shops do the delver's forging.
//
// Pins:
//   1. Definition + sim application: startRun('peddler') gives exactly the
//      advertised start — HP, dice, relic (the card text can never lie).
//   2. Delve-code round-trip: the peddler is index 4 in charactersOrder;
//      appending kept indexes 0-3 stable, so every code already shared still
//      decodes to the same delver.
//   3. Bot viability pins (simVersion 7): seed 1 wins on easy AND normal,
//      seed 5 loses on easy — the balance point sits with the Gambler and
//      the Ascetic (sweep: 88.0/58.7/28.7 vs roster band 87-93/58-80/28-56).
//   4. Character screen lists the Peddler with its real 450-ember price.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['peddler']!;
    expect(charactersOrder.last, 'peddler',
        reason: 'appended LAST so existing delve-code indexes stay stable');
    expect(def.maxHp, 31);
    expect(def.startDice, ['d6', 'd6', 'd4']);
    expect(def.startRelic, 'kiln_key');
    expect(def.unlockEmbers, 450);

    final c = GameController();
    c.startRun(character: 'peddler', seed: 1, boons: false);
    expect(c.sim!.player['max_hp'], 31);
    expect(
      (c.sim!.player['dice'] as List).whereType<String>().toList(),
      ['d6', 'd6', 'd4'],
    );
    expect(
      (c.sim!.run!['relics'] as List).cast<String>(),
      contains('kiln_key'),
    );
  });

  test('delve code round-trips the peddler and keeps old indexes stable', () {
    expect(charactersOrder.indexOf('peddler'), 4);
    final code = encodeDelveCode(
      seed: 42,
      character: 'peddler',
      difficulty: 'normal',
      ascension: 0,
    );
    expect(code, isNotNull);
    final back = decodeDelveCode(code!);
    expect(back, isNotNull);
    expect(back!.character, 'peddler');
    expect(back.seed, 42);
    // Pre-v0.40.0 indexes unchanged: a code minted before the roster grew
    // still names the same delver.
    for (final (i, id) in ['kindler', 'warden', 'gambler', 'ascetic'].indexed) {
      expect(charactersOrder.indexOf(id), i);
    }
  });

  test('bot viability pins: seed 1 wins easy and normal, seed 5 loses easy',
      () {
    expect(
      playRun(1, character: 'peddler', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(1, character: 'peddler', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(5, character: 'peddler', difficulty: 'easy').sim.phase,
      'run_lost',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('character screen lists the Peddler at its real price', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 300);
    await tester.ensureVisible(find.text('Choose a delver'));
    await pumpFor(tester, 100);
    await tester.tap(find.text('Choose a delver'));
    await pumpFor(tester, 700);
    // Lower cards are lazily built; drag the last one into view.
    await tester.dragUntilVisible(
      find.text('The Peddler'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(find.text('The Peddler'), findsOneWidget);
    expect(
      find.textContaining('450'),
      findsWidgets,
      reason: 'the real unlock price is stated up front',
    );
  });
}
