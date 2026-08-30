// test/bearer_test.dart — v0.145.0 The Bearer.
//
// The ninth delver: the GIANT — the flintwright's exact opposite pole.
// TWO dice only, the biggest starting pair in any kit (a Molten Core d12
// and a Deep Coal d8), an Iron Scale, and the smith's Echo already worked
// into the 12. Few rolls, grand promises, and the largest frame at the
// fire (36 HP — the bearer carries).
//
// Balance (400-seed bot sweep, HP 36): 91.75/67.50/39.50 win% easy/normal/
// hard vs kindler 89.75/67.25/41.50 — in band (kit iterations in
// docs/improvements/v0.145.0: two dice starve intent coverage, so the kit
// buys coverage back with size, steel, and the mark).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['bearer']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('bearer'), 8);
    expect(def.maxHp, 36);
    expect(def.startDice, ['d12', 'd8']);
    expect(def.startRelic, 'iron_scale');
    expect(def.unlockEmbers, 1050, reason: 'ladder stays ascending');
    expect(def.startTempers, [
      {'die': 1, 'face': 12, 'rune': 'echo'},
    ]);

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'bearer'});
    expect(sim.player['max_hp'], 36);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['custom_1', 'd8'], reason: 'two dice — the whole pouch');
    final custom = (sim.run!['custom_dice'] as Map)['custom_1'] as Map;
    expect(custom, {'base': 'd12', 'face': 12, 'rune': 'echo'});
    final resolved = resolveRunDie(sim.run, 'custom_1');
    expect(resolved.custom, isTrue);
    expect(resolved.rune, 'echo');
    expect(resolved.temperedFace, 12);
    final relics = (sim.run!['relics'] as List).cast<String>();
    expect(relics, contains('iron_scale'));
  });

  test("the smith's mark is not the player's forge work", () {
    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'bearer'});
    expect(sim.run!['tempers_used'], 0, reason: 'the temper cap is untouched');
    expect(
      sim.run!['runes_tempered'],
      isNull,
      reason: 'the Six Marks bank is untouched',
    );
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // Hunt 2026-08-30: easy wins 1-12 straight; normal wins 1/4/6, normal
    // losses 2/3/5. A pinned loss keeps the difficulty claim honest.
    expect(
      playRun(1, character: 'bearer', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(4, character: 'bearer', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(2, character: 'bearer', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
