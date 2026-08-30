// test/earned_titles_test.dart — v0.129.0 The Earned Titles.
//
// The temper and rotation arcs, wearable: two epithets reading the same
// banked counters the honors read. The Weathered is promise-worded, so
// its target is pinned to the LIVE rotation; the Proven stays the last
// word by real contract.
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the new titles sit before the Proven, which stays last', () {
    expect(epithetsOrder.indexOf('the_tempered'), 12);
    expect(epithetsOrder.indexOf('the_weathered'), 13);
    expect(epithetsOrder.last, 'the_proven');
  });

  test('the Tempered flips at the forgelight rung', () {
    final c = GameController();
    c.meta.tempersSet = 9;
    expect(c.epithetUnlocked('the_tempered'), isFalse);
    c.meta.tempersSet = 10;
    expect(c.epithetUnlocked('the_tempered'), isTrue);
  });

  test('the Weathered asks the live rotation, junk-proof', () {
    expect(
      epithets['the_weathered']!.target,
      legalRuleLabels().length,
      reason: 'promise wording tracks the rotation',
    );
    final c = GameController();
    c.meta.weeklyRulesWon.addAll({'ghost_rule', 'all_d4+ghost'});
    expect(c.epithetUnlocked('the_weathered'), isFalse);
    c.meta.weeklyRulesWon.addAll(legalRuleLabels());
    expect(c.epithetUnlocked('the_weathered'), isTrue);
  });

  test('title copy is honest (no pressure language)', () {
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
    for (final id in ['the_tempered', 'the_weathered']) {
      final d = epithets[id]!;
      final t = '${d.title} ${d.unlockLine}'.toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
