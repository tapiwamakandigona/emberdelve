// test/hearthkeeper_test.dart — The Hearthkeeper.
//
// The SIXTEENTH and FINAL delver: the sworn pouch — every die a forged
// specialist and none of them plain. A Brand Iron that only strikes, a
// Ward Iron that only shields, a Steady Ember that never rolls under 3.
// The collier's pouch was worked BY the smith (plain dice, rune faces);
// the hearthkeeper's dice were BORN to their work (forged die types,
// committed roles). Two of three dice locked to a single job is the
// tension the sweep prices in.
//
// The delve-code delver index (bits 31..34) holds sixteen values and
// this delver takes the last one: the roster is complete. No seventeenth.
//
// Balance (400-seed bot sweep): HP 28 swept 92.00/70.25/45.75 (slightly
// hot); HP 26 swept 91.50/68.25/42.00 vs kindler 89.75/67.25/41.50 —
// in band at the second guess (sweeps in docs/improvements).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['hearthkeeper']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('hearthkeeper'), 15);
    expect(charactersOrder.length, 20,
        reason: 'v0.179.0: the second circle opened (DEMAND 2026-09-01f); '
            'the hearthkeeper still closes the FIRST circle at index 15 — '
            'v1 delve-code bits 31..34 stay full, index 16+ rides v2');
    expect(def.maxHp, 26);
    expect(def.startDice, ['d6_brand', 'd6_ward', 'd6_steady'],
        reason: 'every die sworn, none of them plain');
    expect(def.startRelic, isNull, reason: 'the sworn pouch IS the kit');
    expect(def.startTempers, isEmpty,
        reason: 'born to their work, not worked by the smith');
    expect(def.unlockEmbers, 2100, reason: 'ladder stays ascending');

    final sim = Sim(11)
      ..apply({'type': 'start_run', 'character': 'hearthkeeper'});
    expect(sim.player['max_hp'], 26);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d6_brand', 'd6_ward', 'd6_steady']);
    expect(sim.run!['tempers_used'], 0);
    expect(sim.run!['custom_dice'], anyOf(isNull, isEmpty),
        reason: 'no smith touched this pouch');
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // Hunt 2026-08-31: easy wins 1-2/4-14 (loss 3); normal wins
    // 1/2/4-7/9-12/14, losses 3/8/13. A pinned loss keeps the
    // difficulty claim honest.
    expect(
      playRun(1, character: 'hearthkeeper', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(3, character: 'hearthkeeper', difficulty: 'easy').sim.phase,
      'run_lost',
    );
    expect(
      playRun(4, character: 'hearthkeeper', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(8, character: 'hearthkeeper', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
