// test/fifth_cycle_test.dart — v0.165.0 The Fifth Cycle.
//
// Ten new hearth tales: the late chairs get theirs at last (bearer,
// mender, shieldwright, gilder), then the ledger's slower coins. The
// charter: every tale states one fact the game can prove — so these
// tests prove them, mirror-asserting the copy against the live data.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> cycle5() => hearthTales.sublist(40, 50);

  test('five full cycles, hearthgold frozen at the first', () {
    expect(hearthTales.length, 66); // v0.184.0: the glover's tale
    expect(hearthgoldTales, 10, reason: 'the vista gate never moves');
  });

  test('the tales state facts the game can prove', () {
    final all = cycle5().join(' ');
    // 'two dice only and the biggest life' — the bearer's kit.
    final bearer = characters['bearer']!;
    expect(bearer.startDice.length, 2);
    expect(
      bearer.maxHp,
      characters.values.map((c) => c.maxHp).reduce((a, b) => a > b ? a : b),
      reason: 'the biggest life at this fire',
    );
    expect(all.contains('two dice only'), isTrue);
    // 'her mend into the Deep Coal's worst face' — the mender's mark.
    final mender = characters['mender']!;
    expect(mender.startTempers.single['rune'], 'mend');
    expect(mender.startTempers.single['face'], 1);
    expect(all.contains('worst face'), isTrue);
    // 'an aegis deep into a die' — the shieldwright's tier-2 mark.
    final ward = characters['shieldwright']!;
    expect(ward.startTempers.single['rune'], 'aegis');
    expect(ward.startTempers.single['tier'], 2);
    expect(all.contains('aegis'), isTrue);
    // 'both sixes gilded' — the gilder's two marks.
    final gilder = characters['gilder']!;
    expect(gilder.startTempers.length, 2);
    for (final t in gilder.startTempers) {
      expect(t['rune'], 'gilt');
      expect(t['face'], 6);
    }
    expect(all.contains('both sixes gilded'), isTrue);
    // 'a name waiting: the Proven' — target tracks the live provings list
    // (v0.140 AUDIT RULE: an 'every X' promise follows the catalog).
    final proven = epithets['the_proven']!;
    expect(proven.target, provings.length);
    expect(all.contains('the Proven'), isTrue);
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
    for (final t in cycle5()) {
      expect(t.trim(), isNotEmpty);
      expect(t.length, lessThan(260), reason: 'tales stay short');
      final low = t.toLowerCase();
      for (final b in banned) {
        expect(low.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
