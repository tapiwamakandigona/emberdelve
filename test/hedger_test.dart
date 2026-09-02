// test/hedger_test.dart — v0.179.0 The Hedger: the SEVENTEENTH delver,
// first chair of the second circle (DEMAND 2026-09-01f: the first real
// player words asked for more delvers), and the roster's first
// retaliation identity. Pins, per the roster doctrine:
//   1. Definition and sim application match the card text exactly; the
//      index IS the delve-code contract (16 = first v2 long-form index).
//   2. HP 20 is the swept value (tool/hedger_sweep_probe_test.dart,
//      400 seeds: easy 89.25 / normal 65.50 / hard 43.00 — all bands).
//   3. Seeded replays pin a win and a loss so the identity can never
//      drift silently.
//   4. The seventeenth honors follow the v0.119 pattern; the first
//      circle's historical honors did NOT re-price.
//   5. The delve code for the hedger rides the v2 long form and
//      round-trips.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['hedger']!;
    // Index pin, not 'last': the index IS the delve-code contract — 16 is
    // the FIRST v2 long-form index (delve_code.dart).
    expect(charactersOrder.indexOf('hedger'), 16);
    expect(
      def.maxHp,
      20,
      reason: 'swept value — the hedge is sharp, not thick',
    );
    expect(def.startDice, [
      'd6',
      'd6',
      'd6',
    ], reason: "the kindler's own pouch: the relic IS the identity");
    expect(def.startRelic, 'thorn_band');
    expect(def.startTempers, isEmpty);
    expect(def.unlockEmbers, 2250, reason: 'ladder stays ascending');

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'hedger'});
    expect(sim.player['max_hp'], 20);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d6', 'd6', 'd6']);
    expect((sim.run!['relics'] as List).cast<String>(), ['thorn_band']);
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // From the HP-20 sweep: seed 17 wins on normal (the proving seed),
    // seed 3 lost (v0.180.0 re-anchor, events 53->56: 3 now wins; 5 loses).
    // If either flips, the identity moved — investigate,
    // never re-pin blindly.
    expect(
      playRun(17, character: 'hedger', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(5, character: 'hedger', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });

  test("the hedger's proving stands first among the second circle's", () {
    final p = provingById('hedgers_proving')!;
    expect(p.character, 'hedger');
    expect(p.difficulty, 'normal');
    expect(p.seed, 17, reason: 'seed seventeen for the seventeenth chair');
    expect(p.ascension, 0);
    expect(p.mutators, isEmpty);
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('hedgers_proving'),
      ids.indexOf('hearthkeepers_proving') + 1,
      reason: 'delver provings stand together, in roster order',
    );
  });

  test('the seed is bot-winnable exactly as declared', () {
    final r = playRun(17, character: 'hedger', difficulty: 'normal');
    expect(r.sim.phase, 'run_won');
  });

  test('the seventeenth honors follow the v0.119 pattern', () {
    final wins = achievements['hedger_wins']!;
    expect(wins.stat, 'char_wins');
    expect(wins.param, 'hedger');
    expect(wins.target, 1);
    final seventeen = achievements['seventeen_ways_down']!;
    expect(seventeen.stat, 'delvers_cleared');
    expect(seventeen.target, 17);
    // The frozen predecessors kept their earned prices: the first
    // circle's honors never re-price.
    expect(achievements['sixteen_ways_down']!.target, 16);
    expect(achievements['fifteen_ways_down']!.target, 15);
  });

  test('the delve code rides the v2 long form and round-trips', () {
    final code = encodeDelveCode(
      seed: 424242,
      character: 'hedger',
      difficulty: 'hard',
      ascension: 2,
    );
    expect(code, isNotNull);
    expect(
      code!.length,
      'DELVE-'.length + 11,
      reason: 'index 16 is the first v2 long-form code',
    );
    final back = decodeDelveCode(code)!;
    expect(back.character, 'hedger');
    expect(back.seed, 424242);
    expect(back.difficulty, 'hard');
    expect(back.ascension, 2);
  });
}
