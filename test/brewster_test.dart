// test/brewster_test.dart — v0.179.0 The Brewster: the NINETEENTH delver,
// third chair of the second circle, and the rest-economy identity the gap
// analysis flagged — thin dice and a Hearth Kettle, the delve walked rest
// to rest. Pins, per the roster doctrine:
//   1. Definition and sim application match the card text exactly; the
//      staircase pouch (d8/d6/d4) is the only strictly-descending set.
//   2. HP 25 is the swept value (tool/brewster_sweep_probe_test.dart,
//      400 seeds: easy 87.75 / normal 57.75 / hard 32.00 — all bands;
//      24 sat on the hard floor at 30.50).
//   3. Seeded replays pin a win and a loss so the identity can never
//      drift silently.
//   4. The nineteenth honors follow the v0.119 pattern; earlier honors
//      did NOT re-price.
//   5. The delve code rides the v2 long form and round-trips.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['brewster']!;
    expect(charactersOrder.indexOf('brewster'), 18);
    expect(def.maxHp, 25, reason: 'swept value');
    expect(def.startDice, [
      'd8',
      'd6',
      'd4',
    ], reason: 'the staircase — the only strictly-descending pouch');
    expect(def.startRelic, 'hearth_kettle', reason: 'the kettle IS the kit');
    expect(def.startTempers, isEmpty);
    expect(def.unlockEmbers, 2550, reason: 'ladder stays ascending');

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'brewster'});
    expect(sim.player['max_hp'], 25);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d8', 'd6', 'd4']);
    expect((sim.run!['relics'] as List).cast<String>(), ['hearth_kettle']);
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // From the HP-25 sweep: seed 29 wins on normal (the proving seed),
    // seed 19 — the chair number — loses. If either flips, the identity
    // moved — investigate, never re-pin blindly.
    expect(
      playRun(29, character: 'brewster', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(19, character: 'brewster', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });

  test("the brewster's proving stands third among the second circle's", () {
    final p = provingById('brewsters_proving')!;
    expect(p.character, 'brewster');
    expect(p.difficulty, 'normal');
    expect(
      p.seed,
      29,
      reason: 'the chair seed 19 loses at HP 25; 29 is pinned and unused',
    );
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('brewsters_proving'),
      ids.indexOf('millers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(29, character: 'brewster', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the nineteenth honors follow the v0.119 pattern', () {
    final wins = achievements['brewster_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'brewster');
    expect(wins.target, 1);
    final nineteen = achievements['nineteen_ways_down']!;
    expect(nineteen.stat, 'delvers_cleared');
    expect(nineteen.target, 19);
    // The frozen predecessors kept their earned prices.
    expect(achievements['eighteen_ways_down']!.target, 18);
    expect(achievements['seventeen_ways_down']!.target, 17);
    expect(achievements['sixteen_ways_down']!.target, 16);
  });

  test('the delve code rides the v2 long form and round-trips', () {
    final code = encodeDelveCode(
      seed: 515151,
      character: 'brewster',
      difficulty: 'hard',
      ascension: 1,
    );
    expect(code, isNotNull);
    expect(code!.length, 'DELVE-'.length + 11);
    final back = decodeDelveCode(code)!;
    expect(back.character, 'brewster');
    expect(back.seed, 515151);
    expect(back.difficulty, 'hard');
    expect(back.ascension, 1);
  });
}
