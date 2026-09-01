// test/fourth_cycle_test.dart — v0.137.0 The Fourth Cycle.
//
// Ten new hearth tales touring the anvil and the calendar. The charter:
// every tale states one fact the game can prove — so these tests prove
// them, mirror-asserting the copy against the live constants it cites.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> cycle4() => hearthTales.sublist(30, 40);

  test('four full cycles, hearthgold frozen at the first', () {
    expect(hearthTales.length, 63); // v0.181.0: the brewster's tale
    expect(hearthgoldTales, 10, reason: 'the vista gate never moves');
  });

  test('the tales state facts the game can prove', () {
    final all = cycle4().join(' ');
    // 'two a delve is the smith's limit' — the v0.132 cap.
    final sim = Sim(3)..apply({'type': 'start_run'});
    sim.run!['tempers_used'] = 2;
    sim.phase = 'rest';
    final events = sim.apply({
      'type': 'temper_face',
      'die': 1,
      'face': 2,
      'rune': 'mend',
    });
    expect(events.single['reason'], 'temper_used');
    expect(all.contains('two a delve'), isTrue);
    // 'Six runes come off that anvil' — the live rune set.
    expect(faceRunes.length, 6);
    expect(all.contains('Six runes'), isTrue);
    // 'Sixteen chairs' — the FIRST CIRCLE, which stays complete exactly
    // as published: the hearthkeeper holds index 15 forever (delve-code
    // contract). The roster itself grew past it (v0.179.0 second circle);
    // the tale speaks of the first fire and stays true.
    expect(charactersOrder.indexOf('hearthkeeper'), 15);
    expect(characters.length, greaterThanOrEqualTo(16));
    expect(all.contains('Sixteen chairs'), isTrue); // first circle complete
  });

  test('the new tales keep the charter (short, honest)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    for (final t in cycle4()) {
      expect(t.trim(), isNotEmpty);
      expect(t.length, lessThan(260), reason: 'tales stay short');
      final low = t.toLowerCase();
      for (final b in banned) {
        expect(low.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
