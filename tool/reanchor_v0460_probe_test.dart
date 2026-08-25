// tool/reanchor_v0460_probe_test.dart — one-shot re-anchor probe for the
// v0.46.0 content drop (events 39->45, relics 32->36). Not part of CI.
// Prints everything the fifth golden re-anchor needs:
//   1. goldenV6 replacement (seed 20260723 full-run hash).
//   2. Boss reach per residue class + new bossGoldens.
//   3. Kindler easy-loss seed (boons on) to replace seed 13.
//   4. Peddler pins: seed 1 easy/normal verify + easy-loss seed to replace 5.
//   5. Peddler normal-win set among seeds 1..8 (docs pin {1,2,4,6}).
//   6. ash_summit proving: ascetic hard A15 winnable seed to replace 908.
//   7. A20 hard first-win seeds per character.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

bool metBoss(int seed, String boss) {
  final sim = Sim(seed);
  var met = false;
  for (var i = 0; i < 4000; i++) {
    final cmd = botCmd(sim);
    if (cmd == null) break;
    for (final ev in sim.apply(cmd)) {
      if (ev['type'] == 'encounter_started' && ev['enemy'] == boss) met = true;
    }
  }
  return met;
}

void main() {
  test('golden + boss anchors', () {
    // ignore: avoid_print
    print('GOLDENV6 seed=20260723 hash=${playRun(20260723).sim.eventHash}');
    for (var base = 20260720; base <= 20260727; base++) {
      for (var k = 0; k < 10; k++) {
        final seed = base + 8 * k;
        final boss = bossForSeed(seed);
        final met = metBoss(seed, boss);
        final r = playRun(seed);
        // ignore: avoid_print
        print('REACH seed=$seed boss=$boss met=$met phase=${r.sim.phase} '
            'hash=${r.sim.eventHash}');
        if (met) break;
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('kindler and peddler pins', () {
    for (final probe in [
      ['kindler', 'easy', 1],
      ['kindler', 'normal', 1],
      ['peddler', 'easy', 1],
      ['peddler', 'normal', 1],
    ]) {
      final r = playRun(probe[2] as int,
          character: probe[0] as String, difficulty: probe[1] as String);
      // ignore: avoid_print
      print('VERIFY ${probe[0]} ${probe[1]} seed=${probe[2]}: ${r.sim.phase}');
    }
    for (final ch in ['kindler', 'peddler']) {
      for (var s = 2; s <= 60; s++) {
        if (playRun(s, character: ch, difficulty: 'easy').sim.phase ==
            'run_lost') {
          // ignore: avoid_print
          print('LOSS-SEED $ch easy: $s');
          break;
        }
      }
    }
    final wins = <int>[];
    for (var s = 1; s <= 8; s++) {
      if (playRun(s, character: 'peddler', difficulty: 'normal').sim.phase ==
          'run_won') {
        wins.add(s);
      }
    }
    // ignore: avoid_print
    print('PEDDLER normal wins 1..8: $wins');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('ash_summit re-hunt', () {
    // Old seed 908; try it first, then hunt forward.
    for (var s = 908; s <= 1400; s++) {
      final r = playRun(s, character: 'ascetic', difficulty: 'hard',
          ascension: 15);
      if (r.sim.phase == 'run_won') {
        // ignore: avoid_print
        print('ASH_SUMMIT winnable seed: $s');
        return;
      }
    }
    // ignore: avoid_print
    print('ASH_SUMMIT: none in 908..1400');
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('A20 ladder re-hunt', () {
    for (final ch in ['kindler', 'warden', 'gambler', 'ascetic']) {
      final wins = <int>[];
      for (var seed = 1; seed <= 400 && wins.length < 2; seed++) {
        final r = playRun(seed,
            character: ch, difficulty: 'hard', ascension: 20);
        if (r.sim.phase == 'run_won') wins.add(seed);
      }
      // ignore: avoid_print
      print('A20 $ch winning seeds: $wins');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
