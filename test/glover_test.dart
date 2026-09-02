// test/glover_test.dart — v0.179.0 The Glover: the TWENTY-SECOND delver,
// sixth chair of the second circle, and the SPLIT-HANDS identity — one
// Keen Ember (attack-only +1), one Stout Ember (block-only +1), one bare
// Ember Die. With this kit the LAST two unused tier-1 specialty starts
// enter the roster: every start piece in the catalogue's tier-1 row now
// has a delver who begins with it. Pins, per the roster doctrine:
//   1. Definition and sim application match the card text exactly.
//   2. HP 23 is the swept value (tool/glover_sweep_probe_test.dart,
//      400 seeds: easy 89.75 / normal 69.25 / hard 44.50 — all bands;
//      26 broke all three ceilings at 91.00/71.75/49.25).
//   3. Seeded replays pin a win and a loss so the identity can never
//      drift silently.
//   4. The twenty-second honors follow the v0.119 pattern; earlier
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
    final def = characters['glover']!;
    expect(charactersOrder.indexOf('glover'), 21);
    expect(def.maxHp, 23, reason: 'swept value');
    expect(
      def.startDice,
      ['d6_keen', 'd6_stout', 'd6'],
      reason:
          'keen right, stout left, one bare hand — the split IS '
          'the identity',
    );
    expect(def.startRelic, isNull);
    expect(def.startTempers, isEmpty);
    expect(def.unlockEmbers, 3000, reason: 'ladder stays ascending');
    // The pieces themselves: each glove helps ONE hand only.
    expect(dice['d6_keen']!.mods, {'attack_bonus': 1});
    expect(dice['d6_stout']!.mods, {'block_bonus': 1});

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'glover'});
    expect(sim.player['max_hp'], 23);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d6_keen', 'd6_stout', 'd6']);
    expect((sim.run!['relics'] as List), isEmpty);
  });

  test('every tier-1 specialty start is now seated at some fire', () {
    // The glover closes the tier-1 gap pass: keen and stout were the
    // last two specialty starts no delver began with. If a new tier-1
    // die is ever added, this pin names the next gap.
    final started = <String>{};
    for (final id in charactersOrder) {
      started.addAll(characters[id]!.startDice);
    }
    for (final die in ['d6_keen', 'd6_stout', 'd6_ember', 'd6_forged']) {
      expect(
        started.contains(die),
        isTrue,
        reason: '$die should be some delver\'s starting piece',
      );
    }
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // From the HP-23 sweep: seed 22 — the chair number — wins on normal
    // (the proving seed), seed 45 loses. If either flips, the identity
    // moved — investigate, never re-pin blindly.
    expect(
      playRun(22, character: 'glover', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(45, character: 'glover', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });

  test("the glover's proving stands sixth among the second circle's", () {
    final p = provingById('glovers_proving')!;
    expect(p.character, 'glover');
    expect(p.difficulty, 'normal');
    expect(p.seed, 22, reason: 'chair-number seed, bot-win pinned');
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('glovers_proving'),
      ids.indexOf('farriers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(22, character: 'glover', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the twenty-second honors follow the v0.119 pattern', () {
    final wins = achievements['glover_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'glover');
    expect(wins.target, 1);
    final twentytwo = achievements['twentytwo_ways_down']!;
    expect(twentytwo.stat, 'delvers_cleared');
    expect(twentytwo.target, 22);
    // The frozen predecessors kept their earned prices.
    expect(achievements['twentyone_ways_down']!.target, 21);
    expect(achievements['twenty_ways_down']!.target, 20);
    expect(achievements['sixteen_ways_down']!.target, 16);
  });

  test('the delve code rides the v2 long form and round-trips', () {
    final code = encodeDelveCode(
      seed: 727272,
      character: 'glover',
      difficulty: 'normal',
      ascension: 2,
    );
    expect(code, isNotNull);
    expect(code!.length, 'DELVE-'.length + 11);
    final back = decodeDelveCode(code)!;
    expect(back.character, 'glover');
    expect(back.seed, 727272);
    expect(back.difficulty, 'normal');
    expect(back.ascension, 2);
  });
}
