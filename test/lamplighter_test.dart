// test/lamplighter_test.dart — v0.182.0 The Lamplighter: the TWENTIETH
// delver, fourth chair of the second circle, and the JACKPOT identity from
// the second gap pass — three Glowing Embers (d6_ember, +2 whenever the
// max face lands), an all-specialty pouch on the runesmith's precedent.
// Pins, per the roster doctrine:
//   1. Definition and sim application match the card text exactly.
//   2. HP 24 is the swept value (tool/lamplighter_sweep_probe_test.dart,
//      400 seeds: easy 88.50 / normal 67.00 / hard 43.00 — all bands;
//      26 broke all three ceilings).
//   3. Seeded replays pin a win and a loss so the identity can never
//      drift silently.
//   4. The twentieth honors follow the v0.119 pattern; earlier honors
//      did NOT re-price.
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
    final def = characters['lamplighter']!;
    expect(charactersOrder.indexOf('lamplighter'), 19);
    expect(def.maxHp, 24, reason: 'swept value');
    expect(def.startDice, [
      'd6_ember',
      'd6_ember',
      'd6_ember',
    ], reason: 'three Glowing Embers — the flare IS the identity');
    expect(def.startRelic, isNull);
    expect(def.startTempers, isEmpty);
    expect(def.unlockEmbers, 2700, reason: 'ladder stays ascending');
    // The piece itself: a Glowing Ember pays +2 on its max face.
    expect(dice['d6_ember']!.mods['on_max_bonus'], 2);

    final sim = Sim(11)
      ..apply({'type': 'start_run', 'character': 'lamplighter'});
    expect(sim.player['max_hp'], 24);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d6_ember', 'd6_ember', 'd6_ember']);
    expect((sim.run!['relics'] as List), isEmpty);
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // From the HP-24 sweep: seed 20 — the chair number — wins on normal
    // (the proving seed; the tradition holds again), seed 35 loses. If
    // either flips, the identity moved — investigate, never re-pin
    // blindly.
    expect(
      playRun(20, character: 'lamplighter', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(35, character: 'lamplighter', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });

  test("the lamplighter's proving stands fourth among the second circle's", () {
    final p = provingById('lamplighters_proving')!;
    expect(p.character, 'lamplighter');
    expect(p.difficulty, 'normal');
    expect(p.seed, 20, reason: 'chair-number seed, bot-win pinned');
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('lamplighters_proving'),
      ids.indexOf('brewsters_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(20, character: 'lamplighter', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the twentieth honors follow the v0.119 pattern', () {
    final wins = achievements['lamplighter_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'lamplighter');
    expect(wins.target, 1);
    final twenty = achievements['twenty_ways_down']!;
    expect(twenty.stat, 'delvers_cleared');
    expect(twenty.target, 20);
    // The frozen predecessors kept their earned prices.
    expect(achievements['nineteen_ways_down']!.target, 19);
    expect(achievements['eighteen_ways_down']!.target, 18);
    expect(achievements['seventeen_ways_down']!.target, 17);
    expect(achievements['sixteen_ways_down']!.target, 16);
  });

  test('the delve code rides the v2 long form and round-trips', () {
    final code = encodeDelveCode(
      seed: 616161,
      character: 'lamplighter',
      difficulty: 'easy',
      ascension: 0,
    );
    expect(code, isNotNull);
    expect(code!.length, 'DELVE-'.length + 11);
    final back = decodeDelveCode(code)!;
    expect(back.character, 'lamplighter');
    expect(back.seed, 616161);
    expect(back.difficulty, 'easy');
    expect(back.ascension, 0);
  });
}
