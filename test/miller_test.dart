// test/miller_test.dart — v0.180.0 The Miller: the EIGHTEENTH delver,
// second chair of the second circle, and the roster's widest pouch — the
// millstone and the grist (d12 + two d4s; the bearer went all-grand, the
// flintwright all-small, nobody straddled). Pins, per the roster doctrine:
//   1. Definition and sim application match the card text exactly; the
//      index IS the delve-code contract (17 rides the v2 long form).
//   2. HP 27 is the swept value (tool/miller_sweep_probe_test.dart,
//      400 seeds: easy 89.50 / normal 69.50 / hard 44.50 — all bands).
//   3. Seeded replays pin a win and a loss so the identity can never
//      drift silently.
//   4. The eighteenth honors follow the v0.119 pattern; earlier honors
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
    final def = characters['miller']!;
    expect(charactersOrder.indexOf('miller'), 17);
    expect(def.maxHp, 27, reason: 'swept value');
    expect(
      def.startDice,
      ['d12', 'd4', 'd4'],
      reason: 'the millstone and the grist — the spread IS the identity',
    );
    expect(def.startRelic, isNull, reason: 'no relic: the pouch is the kit');
    expect(def.startTempers, isEmpty);
    expect(def.unlockEmbers, 2400, reason: 'ladder stays ascending');

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'miller'});
    expect(sim.player['max_hp'], 27);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d12', 'd4', 'd4']);
    expect((sim.run!['relics'] as List), isEmpty);
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // From the HP-27 sweep: seed 24 wins on normal (the proving seed),
    // seed 25 lost (v0.180.0 re-anchor, events 53->56: 25 now wins; 5 loses).
    // If either flips, the identity moved — investigate,
    // never re-pin blindly.
    expect(
      playRun(24, character: 'miller', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(5, character: 'miller', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });

  test("the miller's proving stands second among the second circle's", () {
    final p = provingById('millers_proving')!;
    expect(p.character, 'miller');
    expect(p.difficulty, 'normal');
    expect(
      p.seed,
      24,
      reason: 'chair-number seeds 18..23 lose or collide; 24 is pinned',
    );
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('millers_proving'),
      ids.indexOf('hedgers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(24, character: 'miller', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the eighteenth honors follow the v0.119 pattern', () {
    final wins = achievements['miller_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'miller');
    expect(wins.target, 1);
    final eighteen = achievements['eighteen_ways_down']!;
    expect(eighteen.stat, 'delvers_cleared');
    expect(eighteen.target, 18);
    // The frozen predecessors kept their earned prices.
    expect(achievements['seventeen_ways_down']!.target, 17);
    expect(achievements['sixteen_ways_down']!.target, 16);
  });

  test('the delve code rides the v2 long form and round-trips', () {
    final code = encodeDelveCode(
      seed: 424242,
      character: 'miller',
      difficulty: 'hard',
      ascension: 2,
    );
    expect(code, isNotNull);
    expect(code!.length, 'DELVE-'.length + 11);
    final back = decodeDelveCode(code)!;
    expect(back.character, 'miller');
    expect(back.seed, 424242);
    expect(back.difficulty, 'hard');
    expect(back.ascension, 2);
  });
}
