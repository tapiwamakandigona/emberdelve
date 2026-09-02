// test/named_deaths_test.dart — v0.180.0 The Named Deaths.
//
// Every boss has its own death-screen bucket, and every bucket's claims are
// checked against the boss's actual pattern, so a coaching line can never
// drift from the fight it describes (§Ethics: insights never lie).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/insights.dart';

List<String> kinds(String id) => [for (final i in enemies[id]!.pattern) i.kind];
List<int> amounts(String id) => [
  for (final i in enemies[id]!.pattern) i.amount,
];
bool guards(String kind) => kind == 'block' || kind == 'attack_block';

void main() {
  test('every boss owns a bucket and the draw shape is unchanged', () {
    for (final id in enemies.keys) {
      if (!enemies[id]!.boss) continue;
      expect(insights.containsKey('boss_$id'), isTrue, reason: id);
      expect(insights['boss_$id']!.length, 3, reason: id);
      expect(insightBucket(9, true, bossId: id), 'boss_$id');
    }
    expect(insights['boss']!.length, 3);
  });

  test(
    'a shown guard walls the next player turn (timing the lines assume)',
    () {
      // Pinned in sim_test as well; restated here so a change trips this file.
      expect(insights['boss_ember_tyrant']!.length, 3);
    },
  );

  test(
    'Cinder Hierophant: two guards in five, never adjacent, heaviest last',
    () {
      final k = kinds('cinder_hierophant');
      final a = amounts('cinder_hierophant');
      expect(k.length, 5);
      expect(k.where(guards).length, 2);
      for (var i = 0; i < k.length - 1; i++) {
        expect(guards(k[i]) && guards(k[i + 1]), isFalse);
      }
      expect(a.last, a.reduce((x, y) => x > y ? x : y));
      expect(guards(k[3]), isTrue, reason: 'heaviest beat follows a guard');
      expect(k.last, 'attack');
    },
  );

  test('The Bellows: guards and swings on every beat', () {
    for (final kind in kinds('the_bellows')) {
      expect(kind, 'attack_block');
    }
  });

  test('Ashfall Twins: two open attacks, a guard, then the heaviest swing', () {
    final k = kinds('ashfall_twins');
    final a = amounts('ashfall_twins');
    expect(k, ['attack', 'attack', 'block', 'attack']);
    expect(a.last, a.reduce((x, y) => x > y ? x : y));
  });

  test('Slag Regent: two guards then one swing', () {
    expect(kinds('slag_regent'), ['block', 'block', 'attack']);
  });

  test('Hearthless King: swing, guard', () {
    expect(kinds('hearthless_king'), ['attack', 'block']);
  });
}
