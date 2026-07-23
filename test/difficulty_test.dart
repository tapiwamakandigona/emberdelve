// test/difficulty_test.dart — easy/normal/hard switch (v0.3.2).
// Guards three contracts:
//   1. normal is byte-identical to the pre-difficulty sim (golden anchor in
//      sim_test.dart already pins this; here we pin event-level equivalence).
//   2. easy/hard apply the documented deterministic adjustments.
//   3. empirically, easy is not harder than normal and hard is not easier
//      than normal across a seed sweep (bot win rates, 120 seeds).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/sim/autoplay.dart';

Map<String, Object?> _firstEncounterEnemy(String difficulty) {
  final sim = Sim(42);
  sim.apply({
    'type': 'start_run',
    if (difficulty != 'normal') 'difficulty': difficulty,
  });
  // Walk to the first fight node deterministically.
  for (var guard = 0; guard < 10 && sim.phase == 'map'; guard++) {
    final map = sim.map!;
    final position = map['position'] as int;
    final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
    int? fight;
    for (final e in edges) {
      final kind = (map['nodes'] as Map)['$e']!['kind'] as String;
      if (kind == 'fight' || kind == 'elite') fight = e;
    }
    sim.apply({'type': 'choose_node', 'node': fight ?? edges.first});
  }
  expect(sim.phase, 'player_turn',
      reason: 'walk should land in a fight for seed 42');
  return Map<String, Object?>.from(sim.enemy!);
}

void main() {
  test('difficulty is stored on the run and defaults to normal', () {
    final sim = Sim(7)..apply({'type': 'start_run'});
    expect(sim.run!['difficulty'], 'normal');
    final hard = Sim(7)..apply({'type': 'start_run', 'difficulty': 'hard'});
    expect(hard.run!['difficulty'], 'hard');
    // Unknown values fall back to normal instead of corrupting the run.
    final junk = Sim(7)..apply({'type': 'start_run', 'difficulty': 'nightmare'});
    expect(junk.run!['difficulty'], 'normal');
  });

  test('run_started stamps difficulty only when off-normal', () {
    final normal = Sim(7).apply({'type': 'start_run'});
    final started =
        normal.firstWhere((e) => e['type'] == 'run_started');
    expect(started.containsKey('difficulty'), isFalse,
        reason: 'normal must keep pre-difficulty event shape (golden)');
    final easy = Sim(7).apply({'type': 'start_run', 'difficulty': 'easy'});
    expect(easy.firstWhere((e) => e['type'] == 'run_started')['difficulty'],
        'easy');
  });

  test('easy shrinks enemy HP and attacks; hard swells them', () {
    final normal = _firstEncounterEnemy('normal');
    final easy = _firstEncounterEnemy('easy');
    final hard = _firstEncounterEnemy('hard');
    // Same seed => same enemy id in all three runs (map RNG untouched).
    expect(easy['id'], normal['id']);
    expect(hard['id'], normal['id']);

    final nHp = normal['max_hp'] as int;
    expect(easy['max_hp'], (nHp * 0.8).round());
    expect(hard['max_hp'], (nHp * 1.25).round());

    int firstAttack(Map e) {
      for (final it in (e['pattern'] as List).cast<Map>()) {
        if (it['kind'] == 'attack' || it['kind'] == 'attack_block') {
          return it['amount'] as int;
        }
      }
      return -1;
    }

    final na = firstAttack(normal);
    expect(na, greaterThan(0));
    expect(firstAttack(easy), (na - 2) < 1 ? 1 : na - 2);
    expect(firstAttack(hard), na + 2);
  });

  test('normal replay of a difficulty-less command is unchanged', () {
    // A normal-difficulty start emits the exact same events as an old-style
    // start with no difficulty key at all.
    final a = Sim(20260723).apply({'type': 'start_run'});
    final b = Sim(20260723)
        .apply({'type': 'start_run', 'difficulty': 'normal'});
    expect(b, a);
  });

  test('bot win rates order: easy >= normal >= hard (120 seeds)', () {
    int wins(String d) {
      var w = 0;
      for (var seed = 1; seed <= 120; seed++) {
        if (playRun(seed, difficulty: d).sim.phase == 'run_won') w++;
      }
      return w;
    }

    final e = wins('easy'), n = wins('normal'), h = wins('hard');
    // Printed so balance sweeps in CI logs stay observable.
    // ignore: avoid_print
    print('difficulty win rates over 120 seeds: '
        'easy=${e / 1.2}% normal=${n / 1.2}% hard=${h / 1.2}%');
    expect(e, greaterThanOrEqualTo(n),
        reason: 'easy must not be harder than normal');
    expect(n, greaterThanOrEqualTo(h),
        reason: 'hard must not be easier than normal');
    expect(e, greaterThan(h), reason: 'the switch must actually matter');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
