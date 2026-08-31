// test/cutler_test.dart — v0.168.0 The Cutler.
//
// The thirteenth delver: the KNIFE-MAKER — the first kit with two
// DIFFERENT marks. A Blade rides the Deep Coal's 8 and an Aegis rides an
// Ember Die's 6: one face cuts, one face holds. Otherwise a plain
// d6/d6/d8 pouch; the paired marks, not the dice, are the kit.
//
// Balance (400-seed bot sweep, HP 24): 90.25/66.50/43.75 win% easy/normal/
// hard vs kindler 89.75/67.25/41.50 — in band at the first HP guess
// (sweeps in docs/improvements/v0.168.0).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['cutler']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('cutler'), 12);
    expect(def.maxHp, 24);
    expect(def.startDice, ['d6', 'd6', 'd8']);
    expect(def.startRelic, isNull, reason: 'the paired marks ARE the kit');
    expect(def.unlockEmbers, 1650, reason: 'ladder stays ascending');
    expect(def.startTempers, [
      {'die': 3, 'face': 8, 'rune': 'blade'},
      {'die': 1, 'face': 6, 'rune': 'aegis'},
    ]);

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'cutler'});
    expect(sim.player['max_hp'], 24);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['custom_2', 'd6', 'custom_1']);
    // The edge: Blade on the Deep Coal's own top face.
    final blade = resolveRunDie(sim.run, 'custom_1');
    expect(blade.custom, isTrue);
    expect(blade.rune, 'blade');
    expect(blade.temperedFace, 8);
    expect(blade.tier, 1, reason: 'the smith struck once');
    // The spine: Aegis on an Ember Die's six.
    final aegis = resolveRunDie(sim.run, 'custom_2');
    expect(aegis.custom, isTrue);
    expect(aegis.rune, 'aegis');
    expect(aegis.temperedFace, 6);
    expect(aegis.tier, 1, reason: 'shallow — the shieldwright keeps the deep');
    // Tier-1 marks write NO tier key (v0.155.0 optional-key contract).
    for (final id in ['custom_1', 'custom_2']) {
      final custom = (sim.run!['custom_dice'] as Map)[id] as Map;
      expect(custom.containsKey('tier'), isFalse);
    }
  });

  test("two different marks are still not the player's forge work", () {
    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'cutler'});
    expect(sim.run!['tempers_used'], 0, reason: 'the temper cap is untouched');
    expect(
      sim.run!['runes_tempered'],
      isNull,
      reason: 'the Six Marks bank is untouched',
    );
    expect(sim.run!['next_custom_die'], 3, reason: 'both marks applied');
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // Hunt 2026-08-31: easy wins 1-2/4-12/14 (losses 3/13); normal wins
    // 1/2/4/5/6/9/10/11/14, losses 3/7/8/12/13. A pinned loss keeps the
    // difficulty claim honest.
    expect(
      playRun(1, character: 'cutler', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(4, character: 'cutler', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(7, character: 'cutler', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
