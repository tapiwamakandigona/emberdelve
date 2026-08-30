// test/flintwright_test.dart — v0.118.0 The Flintwright (7th delver).
//
// The SWARM archetype: the only delver who starts with FOUR dice, and none
// of them grand. Pure data — existing dice only, no relic — so seeded runs
// for every other delver are untouched (no golden re-anchor; the tinker
// precedent, v0.50.0). Balance swept 400 seeds per difficulty at 24 HP:
// easy 350/400 (87.5%), normal 229/400 (57.25%), hard 137/400 (34.25%) —
// in the roster band (tinker landed 85.25/58.25/31.0).
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('definition and sim application match the card text exactly', () {
    final def = characters['flintwright']!;
    // v0.135.0: runesmith appended — index pin, not 'last' (the lesson,
    // fifth catalog). The index IS the delve-code contract.
    expect(charactersOrder.indexOf('flintwright'), 6);
    expect(def.maxHp, 24);
    expect(def.startDice, [
      'd4',
      'd4',
      'd4_spark',
      'd4_guard',
    ], reason: 'four dice — the archetype IS the pool size');
    expect(
      def.startRelic,
      isNull,
      reason: 'no relic on purpose — the fourth die is the relic',
    );
    expect(def.unlockEmbers, 750);
    for (final id in def.startDice) {
      expect(id, startsWith('d4'), reason: 'shards and chips, nothing grand');
    }

    final c = GameController();
    c.startRun(character: 'flintwright', seed: 1, boons: false);
    expect(c.sim!.player['max_hp'], 24);
    expect((c.sim!.player['dice'] as List).whereType<String>().toList(), [
      'd4',
      'd4',
      'd4_spark',
      'd4_guard',
    ]);
  });

  test('delve code round-trips the flintwright, old indexes stable', () {
    expect(charactersOrder.indexOf('flintwright'), 6);
    final code = encodeDelveCode(
      seed: 42,
      character: 'flintwright',
      difficulty: 'normal',
      ascension: 0,
    );
    expect(code, isNotNull);
    final back = decodeDelveCode(code!);
    expect(back!.character, 'flintwright');
    expect(back.seed, 42);
    // Pre-v0.118.0 indexes unchanged: a code minted before the roster grew
    // still names the same delver.
    for (final (i, id) in [
      'kindler',
      'warden',
      'gambler',
      'ascetic',
      'peddler',
      'tinker',
    ].indexed) {
      expect(charactersOrder.indexOf(id), i);
    }
  });

  test(
    'bot viability pins: seed 1 wins easy and normal, seed 3 loses easy',
    () {
      expect(
        playRun(1, character: 'flintwright', difficulty: 'easy').sim.phase,
        'run_won',
      );
      expect(
        playRun(1, character: 'flintwright', difficulty: 'normal').sim.phase,
        'run_won',
      );
      expect(
        playRun(3, character: 'flintwright', difficulty: 'easy').sim.phase,
        'run_lost',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('the flintwright carries their own signature weapon', () {
    final w = weaponFor('flintwright');
    expect(w.id, 'knapping_pick');
    // Signature means signature — no other delver shares it.
    for (final id in charactersOrder.where((id) => id != 'flintwright')) {
      expect(weaponFor(id).id, isNot('knapping_pick'));
    }
  });

  test('flintwright copy is honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    final def = characters['flintwright']!;
    final low = '${def.name} ${def.text}'.toLowerCase();
    for (final b in banned) {
      expect(low.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
