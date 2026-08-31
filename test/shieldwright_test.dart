// test/shieldwright_test.dart — v0.158.0 The Shieldwright.
//
// The eleventh delver: the WARD — the first kit to lead with a DEEP mark
// (v0.155.0). Aegis II is already worked into an Ember Die's 6, so the
// shield was forged before the first stair. Three plain d6s otherwise;
// the depth of the mark, not the pouch, is the kit.
//
// Balance (400-seed bot sweep, HP 26): 89.00/68.00/41.50 win% easy/normal/
// hard vs kindler 89.75/67.25/41.50 — in band, hard exactly at par
// (sweeps in docs/improvements/v0.158.0).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['shieldwright']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('shieldwright'), 10);
    expect(def.maxHp, 26);
    expect(def.startDice, ['d6', 'd6', 'd6']);
    expect(def.startRelic, isNull, reason: 'the deep mark IS the kit');
    expect(def.unlockEmbers, 1350, reason: 'ladder stays ascending');
    expect(def.startTempers, [
      {'die': 1, 'face': 6, 'rune': 'aegis', 'tier': 2},
    ]);

    final sim = Sim(11)
      ..apply({'type': 'start_run', 'character': 'shieldwright'});
    expect(sim.player['max_hp'], 26);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['custom_1', 'd6', 'd6']);
    final custom = (sim.run!['custom_dice'] as Map)['custom_1'] as Map;
    // The tier KEY is present (v0.155.0 save contract: absent = 1, so the
    // deep mark must write it).
    expect(custom, {'base': 'd6', 'face': 6, 'rune': 'aegis', 'tier': 2});
    final resolved = resolveRunDie(sim.run, 'custom_1');
    expect(resolved.custom, isTrue);
    expect(resolved.rune, 'aegis');
    expect(resolved.temperedFace, 6);
    expect(resolved.tier, 2, reason: 'the smith struck twice');
    expect(runeTierName('aegis', 2), 'Aegis II');
  });

  test("a tier-1 smith's mark still writes NO tier key", () {
    // The runesmith predates tiers; their record must stay byte-identical
    // (v0.155.0 optional-key contract applied to startTempers).
    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'runesmith'});
    final custom = (sim.run!['custom_dice'] as Map)['custom_1'] as Map;
    expect(custom.containsKey('tier'), isFalse);
  });

  test("the smith's deep mark is not the player's forge work", () {
    final sim = Sim(11)
      ..apply({'type': 'start_run', 'character': 'shieldwright'});
    expect(sim.run!['tempers_used'], 0, reason: 'the temper cap is untouched');
    expect(
      sim.run!['runes_tempered'],
      isNull,
      reason: 'the Six Marks bank is untouched',
    );
  });

  test('seeded runs replay exactly (win and loss pins)', () {
    // Hunt 2026-08-31: easy wins 1-2/4-12 (loss 3); normal wins
    // 1/2/4/6/9/10/11, losses 3/5/7/8/12. A pinned loss keeps the
    // difficulty claim honest.
    expect(
      playRun(1, character: 'shieldwright', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(4, character: 'shieldwright', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(5, character: 'shieldwright', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
