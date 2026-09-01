// test/sixth_cycle_test.dart — The Sixth Cycle.
//
// Ten new hearth tales: the last chairs get theirs (cutler, collier,
// stoker, hearthkeeper), then the closed fire's honors. The charter:
// every tale states one fact the game can prove — so these tests prove
// them, mirror-asserting the copy against the live data.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/data/ranks.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> cycle6() => hearthTales.sublist(50, 60);

  test('six full cycles, hearthgold frozen at the first', () {
    expect(hearthTales.length, 65); // v0.183.0: the farrier's tale
    expect(hearthgoldTales, 10, reason: 'the vista gate never moves');
  });

  test('the tales state facts the game can prove', () {
    final all = cycle6().join(' ');
    // 'an edge struck on one die and a guard on another' — the cutler.
    final cutler = characters['cutler']!;
    expect(cutler.startTempers.length, 2);
    expect(
      cutler.startTempers.map((t) => t['rune']).toSet(),
      {'blade', 'aegis'},
    );
    expect(all.contains('an edge struck on one die'), isTrue);
    // 'no relic, only three small marks' — the collier.
    final collier = characters['collier']!;
    expect(collier.startRelic, isNull);
    expect(collier.startTempers.length, 3);
    expect(all.contains('carries no relic'), isTrue);
    // 'three big coals and sixteen points of skin' — the stoker.
    final stoker = characters['stoker']!;
    expect(stoker.startDice, ['d8', 'd8', 'd8']);
    expect(stoker.maxHp, 16);
    expect(stoker.startRelic, isNull);
    expect(stoker.startTempers, isEmpty);
    expect(all.contains('sixteen points of skin'), isTrue);
    // 'forged to their work' — the hearthkeeper's sworn pouch, unmarked.
    final keeper = characters['hearthkeeper']!;
    expect(keeper.startDice, ['d6_brand', 'd6_ward', 'd6_steady']);
    expect(keeper.startTempers, isEmpty);
    expect(all.contains('forged to their work'), isTrue);
    // 'Sixteen chairs, and the fire is done making chairs' — the roster.
    // v0.179.0: the second circle opened; the sixth-cycle facts are about
    // first-circle delvers, whose indexes are frozen.
    expect(characters.length, 21);
    expect(all.contains('done making chairs'), isTrue);
    // 'the Many-Handed' asks every chair (v0.140 AUDIT RULE: an
    // 'every X' promise follows the catalog — and the catalog is closed).
    final many = epithets['the_six_handed']!;
    expect(many.target, characters.length);
    expect(all.contains('the Many-Handed'), isTrue);
    // 'Eight crowned things' — the live bestiary's bosses.
    final bosses = enemies.values.where((e) => e.boss).length;
    expect(bosses, 8);
    expect(all.contains('Eight crowned things'), isTrue);
    // 'thirteen rungs, and the topmost is the Worldflame' — the ladder.
    expect(rankTiers.length, 13);
    expect(rankTiers.last.name, 'Worldflame');
    expect(all.contains('the Worldflame'), isTrue);
    // 'The provings end at the summit of ash' — the list's last entry.
    expect(provings.last.id, 'ash_summit');
    expect(all.contains('summit of ash'), isTrue);
    // 'Six times round now' — the book itself.
    expect(hearthTales.length ~/ hearthgoldTales, 6);
    expect(all.contains('Six times round'), isTrue);
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
    for (final t in cycle6()) {
      expect(t.trim(), isNotEmpty);
      expect(t.length, lessThanOrEqualTo(200), reason: 'sequence tale cap');
      final low = t.toLowerCase();
      for (final b in banned) {
        expect(low.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
