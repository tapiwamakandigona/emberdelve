// tool/reanchor_v1800_probe_test.dart — one-shot re-anchor probe for the
// v0.180.0 content drop (events 53->56, "The Spoken Stones"). Not CI.
// EIGHTH golden re-anchor (procedure: docs/releases/v0.114.0.md). Prints:
//   1. goldenV6 replacement + per-boss goldens (each measured twice).
//   2. Proving winnability per def; replacement seed hunt for losers
//      (same rule as v0.114.0: first winner in seed+1..seed+300).
//   3. Character viability pins: win/loss seeds named in the tests.
//   4. Kindler easy loss-with-rest seed (tempered_hand), full-HP shop seed
//      (ration_preview).
//   5. A20 hard win seeds per ladder character.
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

const bossAnchorSeeds = {
  20260728: 'ashen_colossus',
  20260721: 'ember_tyrant',
  20260722: 'pyre_matriarch',
  20260723: 'cinder_hierophant',
  20260724: 'the_bellows',
  20260725: 'ashfall_twins',
  20260726: 'slag_regent',
  20260743: 'hearthless_king',
};

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

void p(Object o) {
  // ignore: avoid_print
  print(o);
}

void main() {
  test('golden + boss anchors', () {
    p(
      'GOLDENV6 seed=20260723 a=${playRun(20260723).sim.eventHash} '
      'b=${playRun(20260723).sim.eventHash}',
    );
    bossAnchorSeeds.forEach((seed, boss) {
      final met = metBoss(seed, boss);
      final a = playRun(seed).sim.eventHash;
      final b = playRun(seed).sim.eventHash;
      p(
        'BOSS seed=$seed boss=$boss maps=${bossForSeed(seed)} met=$met a=$a b=$b',
      );
      if (!met) {
        for (var k = 1; k <= 12; k++) {
          final s = seed + 8 * k;
          if (bossForSeed(s) == boss && metBoss(s, boss)) {
            p(
              'BOSS $boss SUBSTITUTE seed=$s a=${playRun(s).sim.eventHash} b=${playRun(s).sim.eventHash}',
            );
            break;
          }
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('provings winnability + re-hunt', () {
    for (final pr in provings) {
      final r = playRun(
        pr.seed,
        character: pr.character,
        difficulty: pr.difficulty,
        ascension: pr.ascension,
        mutators: pr.mutators,
      );
      p('PROVING ${pr.id} seed=${pr.seed}: ${r.sim.phase}');
      if (r.sim.phase != 'run_won') {
        for (var s = pr.seed + 1; s <= pr.seed + 300; s++) {
          final h = playRun(
            s,
            character: pr.character,
            difficulty: pr.difficulty,
            ascension: pr.ascension,
            mutators: pr.mutators,
          );
          if (h.sim.phase == 'run_won') {
            p('PROVING ${pr.id} REPLACEMENT seed: $s');
            break;
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  test('character pins', () {
    for (final probe in [
      ['flintwright', 'easy', 1],
      ['flintwright', 'normal', 1],
      ['flintwright', 'easy', 3],
      ['peddler', 'easy', 1],
      ['peddler', 'normal', 1],
      ['peddler', 'easy', 13],
      ['runesmith', 'easy', 1],
      ['runesmith', 'normal', 1],
      ['runesmith', 'easy', 3],
      ['hearthkeeper', 'easy', 1],
      ['hearthkeeper', 'easy', 3],
      ['hearthkeeper', 'normal', 4],
      ['hedger', 'normal', 17],
      ['hedger', 'normal', 3],
      ['miller', 'normal', 24],
      ['miller', 'normal', 25],
      ['kindler', 'easy', 1],
      ['kindler', 'normal', 1],
    ]) {
      final r = playRun(
        probe[2] as int,
        character: probe[0] as String,
        difficulty: probe[1] as String,
      );
      p('VERIFY ${probe[0]} ${probe[1]} seed=${probe[2]}: ${r.sim.phase}');
    }
    for (final ch in [
      'flintwright',
      'peddler',
      'runesmith',
      'hearthkeeper',
      'kindler',
    ]) {
      final losses = <int>[];
      for (var s = 2; s <= 80 && losses.length < 3; s++) {
        if (playRun(s, character: ch, difficulty: 'easy').sim.phase ==
            'run_lost') {
          losses.add(s);
        }
      }
      p('LOSS-SEEDS $ch easy: $losses');
    }
    for (final ch in ['hedger', 'miller']) {
      final losses = <int>[];
      for (var s = 2; s <= 80 && losses.length < 3; s++) {
        if (playRun(s, character: ch, difficulty: 'normal').sim.phase ==
            'run_lost') {
          losses.add(s);
        }
      }
      p('LOSS-SEEDS $ch normal: $losses');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('kindler walk seeds', () {
    // tempered_hand: kindler easy seed that LOSES and visits a rest.
    // ration_preview: kindler easy seed that reaches a shop at full HP.
    final lossRest = <int>[];
    final fullShop = <int>[];
    for (
      var s = 1;
      s <= 80 && (lossRest.length < 3 || fullShop.length < 3);
      s++
    ) {
      final sim = Sim(s);
      var sawRest = false, fullHpShop = false;
      for (var i = 0; i < 4000; i++) {
        final cmd = botCmd(sim, character: 'kindler', difficulty: 'easy');
        if (cmd == null) break;
        sim.apply(cmd);
        if (sim.phase == 'rest') sawRest = true;
        if (sim.phase == 'shop' &&
            sim.player['hp'] == sim.player['max_hp'] &&
            !fullHpShop) {
          fullHpShop = true;
        }
      }
      if (sawRest && sim.phase == 'run_lost' && lossRest.length < 3) {
        lossRest.add(s);
      }
      if (fullHpShop && fullShop.length < 3) {
        fullShop.add(s);
      }
    }
    p(
      'KINDLER easy loss+rest seeds: $lossRest ; full-HP shop seeds (first shop only counted if full): $fullShop',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('A20 ladder re-hunt', () {
    for (final ch in ['kindler', 'warden', 'gambler', 'ascetic']) {
      final wins = <int>[];
      for (var seed = 1; seed <= 400 && wins.length < 3; seed++) {
        if (playRun(
              seed,
              character: ch,
              difficulty: 'hard',
              ascension: 20,
            ).sim.phase ==
            'run_won') {
          wins.add(seed);
        }
      }
      p('A20 $ch winning seeds: $wins');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
