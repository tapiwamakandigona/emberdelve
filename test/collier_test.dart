// test/collier_test.dart — v0.171.0 The Collier.
//
// The fourteenth delver: the CHARCOAL-BURNER — the first kit whose WHOLE
// pool arrives worked. Three Ember Dice, three tier-1 marks: a Blade on
// one six, a Gilt on another, a Mend banked on a low face. Every prior
// marked kit left plain dice in the pouch; here nothing is plain.
//
// Balance (400-seed bot sweep, HP 27): 88.75/65.25/40.50 win% easy/normal/
// hard vs kindler 89.75/67.25/41.50 — in band at the second HP guess
// (25 swept 87.75/62.75/37.50, low; sweeps in docs/improvements/v0.171.0).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['collier']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('collier'), 13);
    expect(def.maxHp, 27);
    expect(def.startDice, ['d6', 'd6', 'd6']);
    expect(def.startRelic, isNull, reason: 'the worked pool IS the kit');
    expect(def.unlockEmbers, 1800, reason: 'ladder stays ascending');
    expect(def.startTempers, [
      {'die': 1, 'face': 6, 'rune': 'blade'},
      {'die': 2, 'face': 6, 'rune': 'gilt'},
      {'die': 3, 'face': 1, 'rune': 'mend'},
    ]);

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'collier'});
    expect(sim.player['max_hp'], 27);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(
      pool,
      ['custom_1', 'custom_2', 'custom_3'],
      reason: 'nothing plain: every die out of the same clamp',
    );
    // The edge: Blade on the first six.
    final blade = resolveRunDie(sim.run, 'custom_1');
    expect(blade.custom, isTrue);
    expect(blade.rune, 'blade');
    expect(blade.temperedFace, 6);
    expect(blade.tier, 1, reason: 'the smith struck once');
    // The purse: Gilt on the second six.
    final gilt = resolveRunDie(sim.run, 'custom_2');
    expect(gilt.custom, isTrue);
    expect(gilt.rune, 'gilt');
    expect(gilt.temperedFace, 6);
    expect(gilt.tier, 1);
    // The small coal: Mend hidden on the low face.
    final mend = resolveRunDie(sim.run, 'custom_3');
    expect(mend.custom, isTrue);
    expect(mend.rune, 'mend');
    expect(mend.temperedFace, 1);
    expect(mend.tier, 1);
    // Tier-1 marks write NO tier key (v0.155.0 optional-key contract).
    for (final id in ['custom_1', 'custom_2', 'custom_3']) {
      final custom = (sim.run!['custom_dice'] as Map)[id] as Map;
      expect(custom.containsKey('tier'), isFalse);
    }
  });

  test("a fully worked pool is still not the player's forge work", () {
    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'collier'});
    expect(sim.run!['tempers_used'], 0, reason: 'the temper cap is untouched');
    expect(
      sim.run!['runes_tempered'],
      isNull,
      reason: 'the Six Marks bank is untouched',
    );
    expect(sim.run!['next_custom_die'], 4, reason: 'all three marks applied');
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // Hunt 2026-08-31: easy wins 1-2/4-12/14 (losses 3/13); normal wins
    // 1/4/6/9/10/11/14, losses 2/3/5/7/8/12/13. A pinned loss keeps the
    // difficulty claim honest.
    expect(
      playRun(1, character: 'collier', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(4, character: 'collier', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(7, character: 'collier', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
