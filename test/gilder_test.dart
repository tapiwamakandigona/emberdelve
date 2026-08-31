// test/gilder_test.dart — v0.162.0 The Gilder.
//
// The twelfth delver: the GOLDSMITH — the first kit with TWO smith's
// marks. Gilt is worked into both Ember Dice sixes, so the pouch itself
// pays: coin on the roll, not on the kill (the peddler's opposite pole).
// Three plain d6s otherwise; the pair of marks, not the pouch, is the kit.
//
// Balance (400-seed bot sweep, HP 28): 90.25/65.50/41.50 win% easy/normal/
// hard vs kindler 89.75/67.25/41.50 — in band, slightly under on normal
// like the other skill delvers, hard exactly at par (sweeps in
// docs/improvements/v0.162.0).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['gilder']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('gilder'), 11);
    expect(def.maxHp, 28);
    expect(def.startDice, ['d6', 'd6', 'd6']);
    expect(def.startRelic, isNull, reason: 'the twin marks ARE the kit');
    expect(def.unlockEmbers, 1500, reason: 'ladder stays ascending');
    expect(def.startTempers, [
      {'die': 1, 'face': 6, 'rune': 'gilt'},
      {'die': 2, 'face': 6, 'rune': 'gilt'},
    ]);

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'gilder'});
    expect(sim.player['max_hp'], 28);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['custom_1', 'custom_2', 'd6']);
    for (final id in ['custom_1', 'custom_2']) {
      final custom = (sim.run!['custom_dice'] as Map)[id] as Map;
      // Tier-1 marks write NO tier key (v0.155.0 optional-key contract).
      expect(custom, {'base': 'd6', 'face': 6, 'rune': 'gilt'});
      final resolved = resolveRunDie(sim.run, id);
      expect(resolved.custom, isTrue);
      expect(resolved.rune, 'gilt');
      expect(resolved.temperedFace, 6);
      expect(resolved.tier, 1, reason: 'the smith struck once per die');
    }
  });

  test("two smith's marks are still not the player's forge work", () {
    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'gilder'});
    expect(sim.run!['tempers_used'], 0, reason: 'the temper cap is untouched');
    expect(
      sim.run!['runes_tempered'],
      isNull,
      reason: 'the Six Marks bank is untouched',
    );
    expect(sim.run!['next_custom_die'], 3, reason: 'both marks applied');
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // Hunt 2026-08-31: easy wins 1-2/4-12 (loss 3); normal wins
    // 1/4/6/9/10/11, losses 2/3/5/7/8/12. A pinned loss keeps the
    // difficulty claim honest.
    expect(
      playRun(1, character: 'gilder', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(4, character: 'gilder', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(5, character: 'gilder', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
