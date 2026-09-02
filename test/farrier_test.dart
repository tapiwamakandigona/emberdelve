// test/farrier_test.dart — v0.179.0 The Farrier: the TWENTY-FIRST delver,
// fifth chair of the second circle, and the STEADY counterpart to the
// lamplighter's spike — three Forged Embers (d6_forged, flat +1 attack
// and +1 block on every roll; never started by any kit) on the thinnest
// skin at any fire. Pins, per the roster doctrine:
//   1. Definition and sim application match the card text exactly.
//   2. HP 12 is the swept value (tool/farrier_sweep_probe_test.dart,
//      400 seeds: easy 85.50 / normal 64.25 / hard 44.25 — all bands;
//      22 started 93.75/81.50/64.00, the strongest raw kit ever swept,
//      and 15 and 13 still broke the hard ceiling).
//   3. Seeded replays pin a win and a loss so the identity can never
//      drift silently.
//   4. The twenty-first honors follow the v0.119 pattern; earlier
//      honors did NOT re-price.
//   5. The delve code rides the v2 long form and round-trips.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['farrier']!;
    expect(charactersOrder.indexOf('farrier'), 20);
    expect(
      def.maxHp,
      12,
      reason: 'swept value — the frailest chair at any fire',
    );
    expect(def.startDice, [
      'd6_forged',
      'd6_forged',
      'd6_forged',
    ], reason: 'three Forged Embers — sure iron IS the identity');
    expect(def.startRelic, isNull);
    expect(def.startTempers, isEmpty);
    expect(def.unlockEmbers, 2850, reason: 'ladder stays ascending');
    // The piece itself: a Forged Ember is +1/+1 flat, every roll.
    expect(dice['d6_forged']!.mods['attack_bonus'], 1);
    expect(dice['d6_forged']!.mods['block_bonus'], 1);

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'farrier'});
    expect(sim.player['max_hp'], 12);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d6_forged', 'd6_forged', 'd6_forged']);
    expect((sim.run!['relics'] as List), isEmpty);
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // From the HP-12 sweep: seed 21 — the chair number — wins on normal
    // (the proving seed), seed 43 loses. If either flips, the identity
    // moved — investigate, never re-pin blindly.
    expect(
      playRun(21, character: 'farrier', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(43, character: 'farrier', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });

  test("the farrier's proving stands fifth among the second circle's", () {
    final p = provingById('farriers_proving')!;
    expect(p.character, 'farrier');
    expect(p.difficulty, 'normal');
    expect(p.seed, 21, reason: 'chair-number seed, bot-win pinned');
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('farriers_proving'),
      ids.indexOf('lamplighters_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(21, character: 'farrier', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the twenty-first honors follow the v0.119 pattern', () {
    final wins = achievements['farrier_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'farrier');
    expect(wins.target, 1);
    final twentyone = achievements['twentyone_ways_down']!;
    expect(twentyone.stat, 'delvers_cleared');
    expect(twentyone.target, 21);
    // The frozen predecessors kept their earned prices.
    expect(achievements['twenty_ways_down']!.target, 20);
    expect(achievements['nineteen_ways_down']!.target, 19);
    expect(achievements['sixteen_ways_down']!.target, 16);
  });

  test('the delve code rides the v2 long form and round-trips', () {
    final code = encodeDelveCode(
      seed: 717171,
      character: 'farrier',
      difficulty: 'normal',
      ascension: 3,
    );
    expect(code, isNotNull);
    expect(code!.length, 'DELVE-'.length + 11);
    final back = decodeDelveCode(code)!;
    expect(back.character, 'farrier');
    expect(back.seed, 717171);
    expect(back.difficulty, 'normal');
    expect(back.ascension, 3);
  });
}
