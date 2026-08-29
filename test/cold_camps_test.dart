// test/cold_camps_test.dart — v0.106.0 The Cold Camps (no_rests mutator).
//
// Fifth Weekly rule: every rest node becomes a fight. Locks the same three
// things weekly_test locks for the others: the rule does exactly what it
// says, it composes with the existing rules, and unmutated runs of the same
// seed still have their camps (nothing drifted for normal play).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/sim/sim.dart';

Map<String, String> _mapKinds(Sim sim) {
  final nodes = (sim.map!['nodes'] as Map).cast<String, Map>();
  return {for (final e in nodes.entries) e.key: e.value['kind'] as String};
}

Sim _startedRun(int seed, {List<String> mutators = const []}) {
  final sim = Sim(seed);
  sim.apply({
    'type': 'start_run',
    'boons': true,
    if (mutators.isNotEmpty) 'mutators': mutators,
  });
  return sim;
}

void main() {
  test('no_rests removes every rest; same seed unmutated keeps them', () {
    var seedsWithRests = 0;
    for (var seed = 1; seed <= 20; seed++) {
      final plain = _mapKinds(_startedRun(seed));
      final cold = _mapKinds(_startedRun(seed, mutators: ['no_rests']));
      expect(
        cold.values.where((k) => k == 'rest'),
        isEmpty,
        reason: 'no_rests left a rest on seed $seed',
      );
      if (plain.containsValue('rest')) {
        seedsWithRests++;
        // Every removed rest became exactly a fight; nothing else moved.
        for (final id in plain.keys) {
          expect(
            cold[id],
            plain[id] == 'rest' ? 'fight' : plain[id],
            reason: 'node $id drifted on seed $seed',
          );
        }
      }
    }
    // The comparison must actually have bitten.
    expect(seedsWithRests, greaterThan(10));
  });

  test('composes with elites_only: no rests AND no plain fights', () {
    final kinds = _mapKinds(
      _startedRun(7, mutators: ['no_rests', 'elites_only']),
    );
    expect(kinds.values.where((k) => k == 'rest'), isEmpty);
    expect(kinds.values.where((k) => k == 'fight'), isEmpty);
    expect(kinds.values.where((k) => k == 'elite'), isNotEmpty);
  });

  test('catalog entry is declared, honest, and in the rotation', () {
    expect(mutatorsOrder, contains('no_rests'));
    final def = mutatorDef('no_rests');
    expect(def.name, 'Cold Camps');
    // Same ethics sweep the news copy passes: a rule, not pressure.
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
    final copy = '${def.name} ${def.blurb}'.toLowerCase();
    for (final word in banned) {
      expect(copy.contains(word), isFalse, reason: 'banned word: $word');
    }
  });
}
