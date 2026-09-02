// test/eighth_cycle_test.dart — v0.180.0 The Eighth Cycle.
//
// Ten more hearth tales (80 = 8 × hearthgoldTales). Every line states a
// fact the game can prove, so every line is coupled here to the data it
// speaks of: boss patterns, the obsidian gate, the first-lantern room, the
// daily seed, the spoken badge, the short road, the tour, and the count.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/daily.dart';
import 'package:emberdelve/sim/map_gen.dart';

void main() {
  final cycle = hearthTales.sublist(70, 80);
  final all = cycle.join(' ');

  test('eighth cycle: ten tales, eight whole cycles, charter kept', () {
    expect(hearthTales.length, 8 * hearthgoldTales);
    expect(hearthgoldTales, 10, reason: 'the milestone stays frozen');
    for (final t in cycle) {
      expect(t.trim(), isNotEmpty);
      expect(t.length, lessThanOrEqualTo(200), reason: t);
    }
    // The eighth tale of the eighth cycle is reached in order, unchanged.
    expect(hearthTale(79), hearthTales[79]);
    expect(hearthTale(80), hearthTales[0], reason: 'then round again');
  });

  test('the crowns behave as the fire says', () {
    final tyrant = enemies['ember_tyrant']!.pattern.map((i) => i.kind);
    expect(tyrant, ['attack', 'block', 'attack_block', 'attack']);
    expect(
      enemies['ember_tyrant']!.pattern.last.amount,
      enemies['ember_tyrant']!.pattern
          .map((i) => i.amount)
          .reduce((a, b) => a > b ? a : b),
      reason: 'strikes hardest of all on the fourth beat',
    );
    final matriarch = enemies['pyre_matriarch']!.pattern;
    expect(matriarch.map((i) => i.kind), everyElement('attack'));
    expect(matriarch.length, 3);
    for (var i = 1; i < matriarch.length; i++) {
      expect(matriarch[i].amount, greaterThan(matriarch[i - 1].amount));
    }
    final colossus = enemies['ashen_colossus']!.pattern;
    expect(colossus.first.kind, 'block', reason: 'opens with its shield up');
    expect(colossus[1].kind, 'attack_block');
    expect(all, contains('Four beats'));
    expect(all, contains('Three blows'));
    expect(all, contains('shield up'));
  });

  test('the black glass asks every crown', () {
    final bosses = enemies.values.where((e) => e.boss).length;
    bool glass(int felled) => vistaUnlockedFor(
      'obsidian',
      runsWon: 0,
      distinctFelled: 0,
      hardWins: 0,
      provingsCleared: 0,
      bestFloor: 0,
      talesHeard: 0,
      doubledWins: 0,
      tempersSet: 0,
      runesMarked: 0,
      charsUnlocked: 0,
      delversCleared: 0,
      bossesFelled: felled,
    );
    expect(glass(bosses), isTrue);
    expect(glass(bosses - 1), isFalse);
    expect(all, contains('black glass'));
  });

  test('the first lantern offers what the tale offers', () {
    final labels = events['the_first_lantern']!.options.map((o) => o.label);
    expect(labels.any((l) => l.startsWith('Warm your hands')), isTrue);
    expect(labels.any((l) => l.startsWith('Take the ember')), isTrue);
    expect(labels.any((l) => l.startsWith('Leave it burning')), isTrue);
    expect(all, contains('lantern hangs'));
  });

  test('the shared road is one seed per day', () {
    expect(dailySeed(2026, 9, 2), dailySeed(2026, 9, 2));
    expect(dailySeed(2026, 9, 2), isNot(dailySeed(2026, 9, 3)));
    expect(all, contains('one road to everyone'));
  });

  test('the short road is six floors against nine', () {
    expect(shortRoadCfg.layers, 6);
    expect(const MapCfg().layers, 9);
    expect(all, contains('six floors instead of nine'));
  });

  test('the held hand is five steps', () {
    expect(TourBeats.all.length, 5);
    expect(TourBeats.all.first, TourBeats.roll);
    expect(TourBeats.all.last, TourBeats.reroll);
    expect(all, contains('five steps, roll to reroll'));
  });
}
