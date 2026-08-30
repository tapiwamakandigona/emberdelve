// test/tinker_test.dart — v0.50.0 The Tinker: the sixth delver, the control
// archetype. A Steady Ember (min 3) under Loaded Pips (every die min 2) gives
// the best floors in the roster, traded for the smallest pip ceiling (16 vs
// the Kindler's 18). 30 HP, unlock 600 embers.
//
// Pins:
//   1. Definition + sim application: startRun('tinker') gives exactly the
//      advertised start — HP, dice, relic (the card text can never lie).
//   2. Delve-code round-trip: the tinker is index 5 in charactersOrder;
//      appending kept indexes 0-4 stable, so every code already shared still
//      decodes to the same delver.
//   3. Bot viability pins (simVersion 7): seed 1 wins on easy AND normal,
//      seed 18 loses on easy — 400-seed sweep 85.25/58.25/31.0, level with
//      the skill delvers on normal (peddler 58.7, gambler 58.0).
//   4. Roster achievements grew with the roster: tinker_wins and
//      six_ways_down exist and count real MetaState stats.
//   5. Character screen lists the Tinker with its real 600-ember price.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/achievements.dart';
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
    final def = characters['tinker']!;
    // v0.118.0: the flintwright is appended after; the tinker's INDEX is
    // the stability contract (delve-code bits 31..34), not last place.
    expect(
      charactersOrder.indexOf('tinker'),
      5,
      reason: 'index 5 so existing delve-code indexes stay stable',
    );
    expect(def.maxHp, 30);
    expect(def.startDice, ['d6_steady', 'd6', 'd4']);
    expect(
      def.startRelic,
      'loaded_pips',
      reason:
          'an EXISTING relic on purpose — a new relic would resize the '
          'shop offer pool and re-anchor every golden',
    );
    expect(def.unlockEmbers, 600);

    final c = GameController();
    c.startRun(character: 'tinker', seed: 1, boons: false);
    expect(c.sim!.player['max_hp'], 30);
    expect((c.sim!.player['dice'] as List).whereType<String>().toList(), [
      'd6_steady',
      'd6',
      'd4',
    ]);
    expect(
      (c.sim!.run!['relics'] as List).cast<String>(),
      contains('loaded_pips'),
    );
  });

  test('delve code round-trips the tinker and keeps old indexes stable', () {
    expect(charactersOrder.indexOf('tinker'), 5);
    final code = encodeDelveCode(
      seed: 42,
      character: 'tinker',
      difficulty: 'normal',
      ascension: 0,
    );
    expect(code, isNotNull);
    final back = decodeDelveCode(code!);
    expect(back, isNotNull);
    expect(back!.character, 'tinker');
    expect(back.seed, 42);
    // Pre-v0.50.0 indexes unchanged: a code minted before the roster grew
    // still names the same delver.
    for (final (i, id) in [
      'kindler',
      'warden',
      'gambler',
      'ascetic',
      'peddler',
    ].indexed) {
      expect(charactersOrder.indexOf(id), i);
    }
  });

  test(
    'bot viability pins: seed 1 wins easy and normal, seed 18 loses easy',
    () {
      expect(
        playRun(1, character: 'tinker', difficulty: 'easy').sim.phase,
        'run_won',
      );
      expect(
        playRun(1, character: 'tinker', difficulty: 'normal').sim.phase,
        'run_won',
      );
      expect(
        playRun(18, character: 'tinker', difficulty: 'easy').sim.phase,
        'run_lost',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('roster achievements grew with the roster', () {
    final tw = achievements['tinker_wins']!;
    expect(tw.stat, 'char_wins');
    expect(tw.param, 'tinker');
    final six = achievements['six_ways_down']!;
    expect(six.stat, 'delvers_cleared');
    expect(six.target, 6);
    expect(achievementsOrder, containsAll(['tinker_wins', 'six_ways_down']));
  });

  testWidgets('character screen lists the Tinker at its real price', (
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
      find.text('The Tinker'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(find.text('The Tinker'), findsOneWidget);
    expect(
      find.textContaining('600'),
      findsWidgets,
      reason: 'the real unlock price is stated up front',
    );
  });
}
