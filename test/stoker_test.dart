// test/stoker_test.dart — v0.175.0 The Stoker.
//
// The fifteenth delver: the FURNACE-FEEDER — the first all-heavy pouch.
// Three plain d8s, no relic, no smith's marks: the identity is the weight
// of the dice themselves. Every prior pouch mixed sizes or stayed at
// sixes (the flintwright went the other way, four small); the uniform
// heavy pool is the open novelty slot.
//
// Balance (400-seed bot sweep): the heavy pouch is STRONG, so the skin is
// thin. HP 24 swept 94.00/78.75/57.75 (hot); HP 20 swept 92.75/72.75/
// 51.25 (still hot); HP 16 swept 89.00/64.75/44.00 vs kindler
// 89.75/67.25/41.50 — in band at the third guess (sweeps in
// docs/improvements/v0.175.0).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['stoker']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('stoker'), 14);
    expect(def.maxHp, 16, reason: 'big coals, thin skin');
    expect(def.startDice, ['d8', 'd8', 'd8']);
    expect(def.startRelic, isNull, reason: 'the heavy pouch IS the kit');
    expect(def.startTempers, isEmpty, reason: 'nothing worked, all weight');
    expect(def.unlockEmbers, 1950, reason: 'ladder stays ascending');

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'stoker'});
    expect(sim.player['max_hp'], 16);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d8', 'd8', 'd8'], reason: 'three big coals, all plain');
    expect(sim.run!['tempers_used'], 0);
    expect(sim.run!['custom_dice'], anyOf(isNull, isEmpty),
        reason: 'no smith touched this pouch');
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // Hunt 2026-08-31: easy wins 1-2/4-12/14 (losses 3/13); normal wins
    // 1/2/4/5/6/9/10/11/12/14, losses 3/7/8/13. A pinned loss keeps the
    // difficulty claim honest.
    expect(
      playRun(1, character: 'stoker', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(4, character: 'stoker', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(7, character: 'stoker', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
