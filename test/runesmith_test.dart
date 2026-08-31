// test/runesmith_test.dart — v0.135.0 The Runesmith.
//
// The eighth delver: the temper specialist, who arrives with one mark
// already worked (Surge on the Deep Coal's 8). The smith's mark is applied
// deterministically at start_run and is NOT the player's forge work — it
// touches neither the temper cap nor the Six Marks bank.
//
// Balance (400-seed bot sweep, HP 26): 90.00/65.50/42.50 win% easy/normal/
// hard vs kindler 89.75/67.25/41.50 — in band on the first knob setting.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('definition and sim application match the card text exactly', () {
    final def = characters['runesmith']!;
    // Index pin, not 'last': the index IS the delve-code contract.
    expect(charactersOrder.indexOf('runesmith'), 7);
    expect(def.maxHp, 26);
    expect(def.startDice, ['d6', 'd6', 'd8']);
    expect(def.startRelic, isNull);
    expect(def.unlockEmbers, 900, reason: 'ladder stays ascending');
    expect(def.startTempers, [
      {'die': 3, 'face': 8, 'rune': 'surge'},
    ]);

    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'runesmith'});
    expect(sim.player['max_hp'], 26);
    final pool = (sim.player['dice'] as List).cast<String>();
    expect(pool, ['d6', 'd6', 'custom_1']);
    final custom = (sim.run!['custom_dice'] as Map)['custom_1'] as Map;
    expect(custom, {'base': 'd8', 'face': 8, 'rune': 'surge'});
    final resolved = resolveRunDie(sim.run, 'custom_1');
    expect(resolved.custom, isTrue);
    expect(resolved.rune, 'surge');
    expect(resolved.temperedFace, 8);
  });

  test("the smith's mark is not the player's forge work", () {
    final sim = Sim(11)..apply({'type': 'start_run', 'character': 'runesmith'});
    expect(sim.run!['tempers_used'], 0, reason: 'the temper cap is untouched');
    expect(
      sim.run!['runes_tempered'],
      isNull,
      reason: 'the Six Marks bank is untouched',
    );
    expect(
      sim.run!['next_custom_die'],
      2,
      reason: 'the id sequence advanced past the mark',
    );
    // Both player marks are still available on top of the smith's.
    sim.phase = 'rest';
    sim.apply({'type': 'temper_face', 'die': 1, 'face': 2, 'rune': 'mend'});
    sim.phase = 'rest';
    final events = sim.apply({
      'type': 'temper_face',
      'die': 2,
      'face': 2,
      'rune': 'gilt',
    });
    expect(
      events.any((e) => e['type'] == 'invalid_command'),
      isFalse,
      reason: 'two player tempers remain legal',
    );
    expect(sim.run!['tempers_used'], 2);
  });

  test('viability pins hold (sweep spot checks)', () {
    expect(
      playRun(1, character: 'runesmith', difficulty: 'easy').sim.phase,
      'run_won',
    );
    expect(
      playRun(1, character: 'runesmith', difficulty: 'normal').sim.phase,
      'run_won',
    );
    expect(
      playRun(3, character: 'runesmith', difficulty: 'easy').sim.phase,
      'run_lost',
      reason: 'the runesmith can still lose — the mark is not a crutch',
    );
  });

  test('the roster-growth contracts all moved with the roster', () {
    final c = GameController();
    expect(characters.length, 12); // v0.162.0: the gilder
    // Unlock ladder ascends through the new tail.
    final ladder = [
      for (final id in charactersOrder) characters[id]!.unlockEmbers,
    ];
    for (var i = 1; i < ladder.length; i++) {
      expect(
        ladder[i] > ladder[i - 1],
        isTrue,
        reason: 'ladder must ascend at index $i',
      );
    }
    expect(
      c.meta.unlockedCharacters.contains('runesmith'),
      isFalse,
      reason: 'the eighth chair is earned, never given',
    );
  });
}
