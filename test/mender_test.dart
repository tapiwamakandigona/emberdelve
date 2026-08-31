// test/mender_test.dart — v0.150.0 The Mender.
//
// The tenth delver: the HEALER — the Mend rune arrives worked into the
// WORST face of a Deep Coal, so the roll every delver curses is the one
// that stitches. Three dice, no relic, the roster's second-smallest frame
// (24 HP — menders patch others, rarely themselves).
//
// Balance (400-seed bot sweep, HP 24): 90.00/66.00/41.50 win% easy/normal/
// hard vs kindler 89.75/67.25/41.50 — in band, hard exactly at par (kit
// iterations in docs/improvements/v0.150.0: a d8 upgrade plus a steady
// drip of stitches buys back what four missing HP cost).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['mender']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('mender'), 9);
    expect(def.maxHp, 24);
    expect(def.startDice, ['d8', 'd6', 'd6']);
    expect(def.startRelic, isNull, reason: 'the mark IS the kit');
    expect(def.unlockEmbers, 1200, reason: 'ladder stays ascending');
    expect(def.startTempers, [
      {'die': 1, 'face': 1, 'rune': 'mend'},
    ]);

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'mender'});
    expect(sim.player['max_hp'], 24);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['custom_1', 'd6', 'd6']);
    final custom = (sim.run!['custom_dice'] as Map)['custom_1'] as Map;
    expect(custom, {'base': 'd8', 'face': 1, 'rune': 'mend'});
    final resolved = resolveRunDie(sim.run, 'custom_1');
    expect(resolved.custom, isTrue);
    expect(resolved.rune, 'mend');
    expect(resolved.temperedFace, 1);
  });

  test("the smith's mark is not the player's forge work", () {
    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'mender'});
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
      playRun(1, character: 'mender', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(4, character: 'mender', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(5, character: 'mender', difficulty: 'normal').sim.phase,
      'run_lost',
    );
  });
}
