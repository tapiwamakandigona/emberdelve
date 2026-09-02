// test/fallen_crown_test.dart — v0.180.0 The Fallen Crown.
//
// A win names what was put down. One sentence per boss (lib/data/crowns.dart),
// chosen by bossForSeed — no RNG. Pins: every boss and only bosses have a
// line; ≤150 chars; banned-word sweep; number words match the patterns they
// describe; the won screen shows the line for the seed's boss; the lost
// screen shows none.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/crowns.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart' show bossForSeed;
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const bannedWords = [
  'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
  'bet you', 'only today', "can't", 'loser', //
];

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every boss, and only bosses, has a crown line', () {
    final bosses = enemiesOrder.where((id) => enemies[id]!.boss).toSet();
    expect(crownLines.keys.toSet(), bosses);
    expect(bosses.length, 8);
  });

  test('lines are short, honest, and clean', () {
    for (final e in crownLines.entries) {
      expect(e.value.length, lessThanOrEqualTo(110), reason: e.key);
      expect(e.value.trim(), endsWith('.'), reason: e.key);
      for (final w in bannedWords) {
        expect(e.value.toLowerCase().contains(w), isFalse, reason: e.key);
      }
    }
  });

  test('number words answer the boss patterns', () {
    expect(crownLines['ember_tyrant'], contains('four beats'));
    expect(enemies['ember_tyrant']!.pattern.length, 4);
    expect(crownLines['pyre_matriarch'], contains('three blows'));
    final m = enemies['pyre_matriarch']!.pattern;
    expect(m.length, 3);
    expect(m.every((i) => i.kind == 'attack'), isTrue);
    // The King keeps two beats: strike, guard.
    expect(crownLines['hearthless_king'], contains('strike and guard'));
    expect(enemies['hearthless_king']!.pattern.map((i) => i.kind).toList(), [
      'attack',
      'block',
    ]);
  });

  testWidgets('the won screen names the fallen crown; the lost one does not', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500);
    final crown = find.byKey(const ValueKey('fallen-crown'));
    expect(crown, findsOneWidget);
    expect((tester.widget<Text>(crown)).data, crownLines[bossForSeed(1)]);

    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost');
    await pumpFor(tester, 2500);
    expect(find.byKey(const ValueKey('fallen-crown')), findsNothing);
  });
}
