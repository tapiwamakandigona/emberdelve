// tool/reanchor_v1140_probe_test.dart — one-shot re-anchor probe for the
// v0.114.0 content drop (events 50->53). Not part of CI.
// SEVENTH golden re-anchor. Prints everything the re-anchor needs:
//   1. goldenV6 replacement (seed 20260723 full-run hash, measured twice).
//   2. Boss reach per residue class + new bossGoldens (measured twice).
//   3. Proving winnability per def; hunt replacement seeds for any loser.
//   4. Kindler/peddler pins: seed 1 verify, loss seeds, peddler normal
//      win-set 1..8.
//   5. Kindler easy rest/forge walk seeds (rest_preview/hearth_tale/
//      counted_forge/ration helpers).
//   6. A20 hard win seeds per character (ladder + rung_open + peddler A20).
import 'package:emberdelve/data/provings.dart';
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
    print(
      'GOLDENV6 seed=20260723 a=${playRun(20260723).sim.eventHash} '
      'b=${playRun(20260723).sim.eventHash}',
    );
    for (var base = 20260720; base <= 20260727; base++) {
      for (var k = 0; k < 10; k++) {
        final seed = base + 8 * k;
        final boss = bossForSeed(seed);
        final met = metBoss(seed, boss);
        final a = playRun(seed).sim.eventHash;
        final b = playRun(seed).sim.eventHash;
        // ignore: avoid_print
        print('REACH seed=$seed boss=$boss met=$met a=$a b=$b');
        if (met) break;
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('provings winnability + re-hunt', () {
    for (final p in provings) {
      final r = playRun(
        p.seed,
        character: p.character,
        difficulty: p.difficulty,
        ascension: p.ascension,
        mutators: p.mutators,
      );
      // ignore: avoid_print
      print('PROVING ${p.id} seed=${p.seed}: ${r.sim.phase}');
      if (r.sim.phase != 'run_won') {
        for (var s = p.seed + 1; s <= p.seed + 300; s++) {
          final h = playRun(
            s,
            character: p.character,
            difficulty: p.difficulty,
            ascension: p.ascension,
            mutators: p.mutators,
          );
          if (h.sim.phase == 'run_won') {
            // ignore: avoid_print
            print('PROVING ${p.id} REPLACEMENT seed: $s');
            break;
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  test(
    'kindler/peddler pins + walk seeds',
    () {
      for (final probe in [
        ['kindler', 'easy', 1],
        ['kindler', 'normal', 1],
        ['peddler', 'easy', 1],
        ['peddler', 'normal', 1],
        ['peddler', 'easy', 16],
      ]) {
        final r = playRun(
          probe[2] as int,
          character: probe[0] as String,
          difficulty: probe[1] as String,
        );
        // ignore: avoid_print
        print(
          'VERIFY ${probe[0]} ${probe[1]} seed=${probe[2]}: ${r.sim.phase}',
        );
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
      // Walk seeds: first kindler easy seeds whose bot path visits a rest /
      // a forge (controller-idiom parity: botCmd defaults, boons off).
      final rests = <int>[];
      final forges = <int>[];
      for (var s = 1; s <= 60 && (rests.length < 3 || forges.length < 3); s++) {
        final sim = Sim(s);
        var sawRest = false, sawForge = false;
        for (var i = 0; i < 4000; i++) {
          final cmd = botCmd(sim, character: 'kindler', difficulty: 'easy');
          if (cmd == null) break;
          sim.apply(cmd);
          if (sim.phase == 'rest') sawRest = true;
          if (sim.phase == 'forge') sawForge = true;
        }
        if (sawRest && rests.length < 3) rests.add(s);
        if (sawForge && forges.length < 3) forges.add(s);
      }
      // ignore: avoid_print
      print('KINDLER easy rest-walk seeds: $rests forge-walk seeds: $forges');
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  test('A20 ladder re-hunt', () {
    for (final ch in ['kindler', 'warden', 'gambler', 'ascetic']) {
      final wins = <int>[];
      for (var seed = 1; seed <= 400 && wins.length < 3; seed++) {
        final r = playRun(
          seed,
          character: ch,
          difficulty: 'hard',
          ascension: 20,
        );
        if (r.sim.phase == 'run_won') wins.add(seed);
      }
      // ignore: avoid_print
      print('A20 $ch winning seeds: $wins');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
