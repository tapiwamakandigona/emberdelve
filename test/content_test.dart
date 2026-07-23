// test/content_test.dart — M1 content + encounter-layer tests.
// 1:1 port of legacy/defold/tests/content_tests.lua (all 21 tests, same
// assertions; balance numbers referenced from the data modules, never
// hardcoded — mirrors how the Lua tests read data.dice / data.enemies).
//
// Standalone: does NOT import lib/sim/sim.dart (owned by the run-worker,
// rewritten in parallel) — uses a TEST FAKE Sim below, exactly as the Lua
// suite uses its `fake_sim` table.

import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/sim/combat.dart' as combat;
import 'package:emberdelve/sim/rng.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// TEST FAKE — stands in for class Sim (lib/sim/sim.dart, owned by a later
// worker; does not exist yet). The real Sim replaces it at integration.
// Field names/types are contract-exact (docs/flutter-port-contract.md §3 +
// combat seam): player/enemy maps, phase String, turn int,
// combatOver String?, rng = map of named Rng streams.
// Mirrors content_tests.lua `fake_sim`.
// ---------------------------------------------------------------------------
class TestSim {
  Map<String, Rng> rng;
  Map<String, dynamic> player;
  Map<String, dynamic>? enemy;
  String phase;
  int turn;
  String? combatOver;

  TestSim(int seed, List<String>? pool)
      : rng = {'combat': Rng(seed, 'combat')},
        player = {
          'hp': 30, 'max_hp': 30, 'block': 0,
          'dice': pool ?? ['d6', 'd6', 'd6'],
          'rolled': null, 'assigned': <int, String>{},
        },
        phase = 'idle',
        turn = 0;
}

TestSim fakeSim([int seed = 42, List<String>? pool]) => TestSim(seed, pool);

(TestSim, List<Map<String, dynamic>>) beginFight(int seed, String enemyId,
    [List<String>? pool, bool elite = false]) {
  final sim = fakeSim(seed, pool);
  final evs = <Map<String, dynamic>>[];
  combat.begin(sim, enemyId, elite, evs);
  return (sim, evs);
}

/// Deterministic seed search: first seed in [1,20000] whose fresh combat
/// stream satisfies [pred]. Pure arithmetic — stable across VMs.
int findSeed(bool Function(Rng) pred) {
  for (var seed = 1; seed <= 20000; seed++) {
    if (pred(Rng(seed, 'combat'))) return seed;
  }
  throw StateError('no seed found in [1,20000]');
}

/// Returns (event, 1-based index) or (null, -1) — Lua `find_event`.
(Map<String, dynamic>?, int) findEvent(
    List<Map<String, dynamic>> evs, String etype) {
  for (var i = 0; i < evs.length; i++) {
    if (evs[i]['type'] == etype) return (evs[i], i + 1);
  }
  return (null, -1);
}

/// Shallow-ish state fingerprint for "state untouched" assertions.
/// Mirrors content_tests.lua `fingerprint` field-for-field.
String fingerprint(TestSim sim) {
  var rolled = 'nil';
  final r = sim.player['rolled'] as List<int>?;
  if (r != null) rolled = r.join(',');
  final assigned = <String>[
    for (final e in (sim.player['assigned'] as Map<int, String>).entries)
      '${e.key}=${e.value}',
  ]..sort();
  return [
    sim.phase, sim.turn, sim.combatOver ?? 'nil',
    sim.player['hp'], sim.player['block'], rolled, assigned.join(','),
    sim.enemy != null ? sim.enemy!['hp'] : -1,
    sim.enemy != null ? sim.enemy!['block'] : -1,
    sim.enemy != null ? sim.enemy!['pattern_index'] : -1,
    sim.rng['combat']!.calls,
  ].join('|');
}

const dieMods = {
  'attack_bonus': int, 'block_bonus': int,
  'min_value': int, 'on_max_bonus': int,
  'attack_only': bool, 'block_only': bool,
};

void main() {
  // -------------------------------------------------------------------------
  // 1–4: data schema validation
  // -------------------------------------------------------------------------

  test('data: dice schema valid, >=10 ids, plain d6 present', () {
    var n = 0;
    diceData.forEach((id, def) {
      n += 1;
      expect(def['id'], id, reason: 'dice id mismatch for $id');
      expect(def['name'], isA<String>(), reason: '$id.name');
      final size = def['size'];
      expect(size is int && size >= 2, isTrue, reason: '$id.size invalid');
      expect(def['mods'], isA<Map>(), reason: '$id.mods');
      (def['mods'] as Map).forEach((mk, mv) {
        expect(dieMods.containsKey(mk), isTrue,
            reason: '$id: illegal mod key $mk');
        expect(mv.runtimeType, dieMods[mk],
            reason: '$id: mod $mk wrong type');
      });
      final mods = def['mods'] as Map;
      expect(mods['attack_only'] == true && mods['block_only'] == true,
          isFalse,
          reason: '$id: attack_only and block_only both set');
    });
    expect(n >= 10, isTrue, reason: 'need >=10 die ids, got $n');
    expect(diceData['d6'] != null && diceData['d6']!['size'] == 6, isTrue,
        reason: 'plain d6 missing or wrong size');
    expect((diceData['d6']!['mods'] as Map).isEmpty, isTrue,
        reason: 'plain d6 must have no mods');
  });

  test('data: dice._order complete, deterministic, no duplicates', () {
    expect(diceOrder, isA<List<String>>(), reason: '_order missing');
    final seen = <String>{};
    for (final id in diceOrder) {
      expect(diceData.containsKey(id), isTrue,
          reason: '_order lists unknown id $id');
      expect(seen.contains(id), isFalse, reason: '_order duplicates $id');
      seen.add(id);
    }
    for (final id in diceData.keys) {
      expect(seen.contains(id), isTrue,
          reason: 'id missing from _order: $id');
    }
  });

  test('data: enemies schema valid; >=3 regular, >=2 elite, exactly 1 boss',
      () {
    var regular = 0, elite = 0, boss = 0;
    enemiesData.forEach((id, def) {
      expect(def['id'], id, reason: 'enemy id mismatch for $id');
      expect(def['name'], isA<String>(), reason: '$id.name');
      final hp = def['hp'];
      expect(hp is int && hp > 0, isTrue, reason: '$id.hp');
      expect(def['boss'], isA<bool>(), reason: '$id.boss');
      expect(def['elite'], isA<bool>(), reason: '$id.elite');
      final pattern = def['pattern'];
      expect(pattern is List && pattern.isNotEmpty, isTrue,
          reason: '$id.pattern');
      for (var pi = 0; pi < (pattern as List).length; pi++) {
        final entry = pattern[pi] as Map;
        final kind = entry['kind'];
        expect(kind == 'attack' || kind == 'block' || kind == 'attack_block',
            isTrue,
            reason: '$id.pattern[${pi + 1}].kind invalid');
        final amount = entry['amount'];
        expect(amount is int && amount > 0, isTrue,
            reason: '$id.pattern[${pi + 1}].amount');
        if (kind == 'attack_block') {
          final block = entry['block'];
          expect(block is int && block > 0, isTrue,
              reason: '$id.pattern[${pi + 1}].block');
        } else {
          expect(entry.containsKey('block'), isFalse,
              reason: '$id.pattern[${pi + 1}]: stray block field');
        }
      }
      if (def['boss'] == true) {
        boss += 1;
      } else if (def['elite'] == true) {
        elite += 1;
      } else {
        regular += 1;
      }
    });
    expect(regular >= 3, isTrue,
        reason: 'need >=3 regular enemies, got $regular');
    expect(elite >= 2, isTrue, reason: 'need >=2 elites, got $elite');
    expect(boss, 1, reason: 'need exactly 1 boss');
  });

  test('data: enemies._order complete, deterministic, no duplicates', () {
    expect(enemiesOrder, isA<List<String>>(), reason: '_order missing');
    final seen = <String>{};
    for (final id in enemiesOrder) {
      expect(enemiesData.containsKey(id), isTrue,
          reason: '_order lists unknown id $id');
      expect(seen.contains(id), isFalse, reason: '_order duplicates $id');
      seen.add(id);
    }
    for (final id in enemiesData.keys) {
      expect(seen.contains(id), isTrue,
          reason: 'id missing from _order: $id');
    }
  });

  // -------------------------------------------------------------------------
  // 5–7: combat.begin + pattern cycling
  // -------------------------------------------------------------------------

  test('combat.begin: state set, deep-copied enemy, correct events', () {
    final (sim, evs) = beginFight(7, 'cinder_wisp');
    expect(sim.phase, 'player_turn');
    expect(sim.turn, 1);
    expect(sim.player['block'], 0);
    expect(sim.player['rolled'], isNull);
    expect(sim.enemy!['hp'], enemiesData['cinder_wisp']!['hp']);
    expect(sim.enemy!['pattern_index'], 1);
    expect(evs[0]['type'], 'encounter_started');
    expect(evs[0]['enemy'], 'cinder_wisp');
    expect(evs[0]['enemy_hp'], enemiesData['cinder_wisp']!['hp']);
    expect(evs[0]['turn'], 1);
    expect(evs[0]['elite'], false);
    expect(evs[1]['type'], 'intent_shown');
    expect(evs[1]['kind'], 'attack');
    final wispP1 =
        (enemiesData['cinder_wisp']!['pattern'] as List)[0] as Map;
    expect(evs[1]['amount'], wispP1['amount']);
    // deep copy: mutating the live enemy must not corrupt the data module
    final origAmount = wispP1['amount'];
    final origHp = enemiesData['cinder_wisp']!['hp'];
    ((sim.enemy!['pattern'] as List)[0] as Map)['amount'] = 999;
    sim.enemy!['hp'] = 1;
    expect(
        ((enemiesData['cinder_wisp']!['pattern'] as List)[0]
            as Map)['amount'],
        origAmount,
        reason: 'data module mutated!');
    expect(enemiesData['cinder_wisp']!['hp'], origHp,
        reason: 'data module mutated!');
  });

  test('combat.begin: elite flag carried onto encounter_started', () {
    final (_, evs) = beginFight(7, 'pyre_howler', null, true);
    expect(evs[0]['elite'], true);
  });

  test('pattern cycling: intents follow authored order, wrap, no RNG', () {
    final (sim, _) = beginFight(11, 'cinder_wisp');
    sim.player['hp'] = 999; // survival is not under test; intent order is
    final p = enemiesData['cinder_wisp']!['pattern'] as List;
    // turns 2..5 after wrap (Lua indices p[2],p[3],p[1],p[2])
    final expected = [
      (p[1] as Map)['amount'],
      (p[2] as Map)['amount'],
      (p[0] as Map)['amount'],
      (p[1] as Map)['amount'],
    ];
    var rngCallsUsed = 0;
    for (var t = 1; t <= 4; t++) {
      final before = sim.rng['combat']!.calls;
      final evs = <Map<String, dynamic>>[];
      combat.endTurn(sim, {'type': 'end_turn'}, evs);
      rngCallsUsed += sim.rng['combat']!.calls - before;
      final (intent, _) = findEvent(evs, 'intent_shown');
      expect(intent!['amount'], expected[t - 1],
          reason: 'turn ${t + 1} intent');
      expect(intent['kind'], 'attack');
    }
    expect(rngCallsUsed, 0, reason: 'intent selection must consume no RNG');
  });

  // -------------------------------------------------------------------------
  // 8–11: dice v2 — rolls, mods
  // -------------------------------------------------------------------------

  test('roll: values from combat stream, in range, dice_rolled shape', () {
    final (sim, _) = beginFight(101, 'cinder_wisp');
    final evs = <Map<String, dynamic>>[];
    combat.roll(sim, {'type': 'roll'}, evs);
    expect(evs.length, 1);
    expect(evs[0]['type'], 'dice_rolled');
    expect(evs[0]['count'], 3);
    final rolled = sim.player['rolled'] as List<int>;
    for (var i = 1; i <= 3; i++) {
      final v = rolled[i - 1];
      expect(v >= 1 && v <= 6, isTrue, reason: 'd$i out of range: $v');
      expect(evs[0]['d$i'], v, reason: 'event d$i mismatch');
    }
    expect(sim.rng['combat']!.calls, 3, reason: 'one rng call per die');
    // determinism: identical seed => identical roll
    final (sim2, _) = beginFight(101, 'cinder_wisp');
    combat.roll(sim2, {'type': 'roll'}, <Map<String, dynamic>>[]);
    final rolled2 = sim2.player['rolled'] as List<int>;
    for (var i = 0; i < 3; i++) {
      expect(rolled2[i], rolled[i], reason: 'not deterministic');
    }
  });

  test('mod min_value: low raw rolls are raised to the floor', () {
    // seed whose first d6 roll is below 3 (raw), so the floor must trigger
    final seed = findSeed((r) => r.die(6) < 3);
    final (sim, _) =
        beginFight(seed, 'cinder_wisp', ['d6_steady', 'd6_steady', 'd6_steady']);
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    final rolled = sim.player['rolled'] as List<int>;
    for (var i = 0; i < 3; i++) {
      expect(rolled[i] >= 3, isTrue,
          reason: 'min_value 3 violated: ${rolled[i]}');
    }
    // same seed, plain dice: first raw roll really was < 3 (floor did something)
    final (plain, _) = beginFight(seed, 'cinder_wisp');
    combat.roll(plain, {'type': 'roll'}, <Map<String, dynamic>>[]);
    expect((plain.player['rolled'] as List<int>)[0] < 3, isTrue,
        reason: 'seed search broken');
  });

  test('mods attack_bonus / block_bonus: applied on assign', () {
    final (sim, _) = beginFight(5, 'cinder_wisp', ['d6_keen', 'd6_stout', 'd6']);
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    final rolled = sim.player['rolled'] as List<int>;
    final r1 = rolled[0], r2 = rolled[1];
    final hp0 = sim.enemy!['hp'] as int;
    var evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs);
    expect(evs[0]['type'], 'die_assigned');
    expect(evs[0]['value'], r1 + 1, reason: 'attack_bonus not applied');
    expect(sim.enemy!['hp'], hp0 - (r1 + 1));
    expect(evs[1]['type'], 'damage_dealt');
    expect(evs[1]['amount'], r1 + 1);
    evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 2, 'action': 'block'}, evs);
    expect(evs[0]['value'], r2 + 1, reason: 'block_bonus not applied');
    expect(sim.player['block'], r2 + 1);
    expect(evs[1]['type'], 'block_gained');
    expect(evs[1]['total_block'], r2 + 1);
  });

  test('mod on_max_bonus: fires only on the max face', () {
    final maxSeed = findSeed((r) => r.die(10) == 10);
    final (sim, _) =
        beginFight(maxSeed, 'ember_tyrant', ['d10_surge', 'd6', 'd6']);
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    expect((sim.player['rolled'] as List<int>)[0], 10,
        reason: 'seed search broken');
    final hp0 = sim.enemy!['hp'] as int;
    final evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs);
    expect(evs[0]['value'], 14,
        reason: 'on_max_bonus 4 not applied to nat 10');
    expect(sim.enemy!['hp'], hp0 - 14);
    // non-max face: no bonus
    final lowSeed = findSeed((r) => r.die(10) < 10);
    final (sim2, _) =
        beginFight(lowSeed, 'ember_tyrant', ['d10_surge', 'd6', 'd6']);
    combat.roll(sim2, {'type': 'roll'}, <Map<String, dynamic>>[]);
    final raw = (sim2.player['rolled'] as List<int>)[0];
    final evs2 = <Map<String, dynamic>>[];
    combat.assign(sim2, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs2);
    expect(evs2[0]['value'], raw, reason: 'bonus applied without max face');
  });

  // -------------------------------------------------------------------------
  // 12–13: attack_only / block_only rejection (invalid-command safety)
  // -------------------------------------------------------------------------

  test('attack_only die: block rejected, single event, state untouched', () {
    final (sim, _) = beginFight(9, 'cinder_wisp', ['d8_blade', 'd6', 'd6']);
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    final fp = fingerprint(sim);
    final evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'block'}, evs);
    expect(evs.length, 1);
    expect(evs[0]['type'], 'invalid_command');
    expect(evs[0]['reason'], 'die_is_attack_only');
    expect(fingerprint(sim), fp, reason: 'state changed on invalid command');
    // die is still usable for its legal action (with its attack_bonus 2)
    final raw = (sim.player['rolled'] as List<int>)[0];
    final evs2 = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs2);
    expect(evs2[0]['type'], 'die_assigned');
    expect(evs2[0]['value'], raw + 2);
  });

  test('block_only die: attack rejected, single event, state untouched', () {
    final (sim, _) = beginFight(9, 'cinder_wisp', ['d8_aegis', 'd6', 'd6']);
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    final fp = fingerprint(sim);
    final evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs);
    expect(evs.length, 1);
    expect(evs[0]['type'], 'invalid_command');
    expect(evs[0]['reason'], 'die_is_block_only');
    expect(fingerprint(sim), fp, reason: 'state changed on invalid command');
    final raw = (sim.player['rolled'] as List<int>)[0];
    final evs2 = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'block'}, evs2);
    expect(evs2[0]['type'], 'die_assigned');
    expect(evs2[0]['value'], raw + 2);
  });

  // -------------------------------------------------------------------------
  // 14–15: attack_block resolution + enemy block absorb/reset
  // -------------------------------------------------------------------------

  test('attack_block: intent + resolution carry block field, both effects land',
      () {
    // soot_shade turn 1 intent: attack_block (amounts from data module)
    final (sim, evs) = beginFight(3, 'soot_shade');
    final p1 = (enemiesData['soot_shade']!['pattern'] as List)[0] as Map;
    final hpStart = sim.player['hp'] as int;
    expect(p1['kind'], 'attack_block',
        reason: 'test premise: soot_shade opens attack_block');
    expect(evs[1]['kind'], 'attack_block');
    expect(evs[1]['amount'], p1['amount']);
    expect(evs[1]['block'], p1['block'],
        reason: 'intent_shown missing block field');
    final evs2 = <Map<String, dynamic>>[];
    combat.endTurn(sim, {'type': 'end_turn'}, evs2);
    final (atk, _) = findEvent(evs2, 'enemy_attacked');
    expect(atk!['amount'], p1['amount']);
    expect(atk['block'], p1['block'],
        reason: 'enemy_attacked missing block field');
    expect(atk['damage'], p1['amount']);
    expect(sim.player['hp'], hpStart - (p1['amount'] as int),
        reason: 'attack part not resolved as shown');
    expect(sim.enemy!['block'], p1['block'], reason: 'block part not resolved');
  });

  test('enemy block: absorbs player damage that turn, resets at enemy turn start',
      () {
    final (sim, _) = beginFight(3, 'soot_shade');
    final p = enemiesData['soot_shade']!['pattern'] as List;
    final b1 = (p[0] as Map)['block'] as int;
    // enemy now has block from turn-1 intent, turn 2
    combat.endTurn(sim, {'type': 'end_turn'}, <Map<String, dynamic>>[]);
    expect(sim.enemy!['block'], b1);
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    final v = (sim.player['rolled'] as List<int>)[0];
    final hp0 = sim.enemy!['hp'] as int;
    final evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs);
    final absorbed = v < b1 ? v : b1; // math.min(v, b1)
    expect(evs[1]['blocked'], absorbed, reason: 'damage_dealt.blocked wrong');
    expect(sim.enemy!['hp'], hp0 - (v - absorbed),
        reason: 'enemy block did not absorb');
    expect(sim.enemy!['block'], b1 - absorbed,
        reason: 'enemy block not consumed');
    // enemy turn start (turn-2 intent is pure attack) resets leftover block
    final evs2 = <Map<String, dynamic>>[];
    combat.endTurn(sim, {'type': 'end_turn'}, evs2);
    expect(sim.enemy!['block'], 0,
        reason: 'enemy block not reset at enemy turn start');
    final (atk2, _) = findEvent(evs2, 'enemy_attacked');
    expect(atk2!['amount'], (p[1] as Map)['amount']);
  });

  test('block intent: enemy_blocked event, no damage to player', () {
    // ember_beetle turn 1 intent: pure block (amount from data module)
    final (sim, evs) = beginFight(13, 'ember_beetle');
    final b = ((enemiesData['ember_beetle']!['pattern'] as List)[0]
        as Map)['amount'];
    expect(evs[1]['kind'], 'block');
    final hp0 = sim.player['hp'];
    final evs2 = <Map<String, dynamic>>[];
    combat.endTurn(sim, {'type': 'end_turn'}, evs2);
    final (blk, _) = findEvent(evs2, 'enemy_blocked');
    expect(blk, isNotNull, reason: 'no enemy_blocked event');
    expect(blk!['amount'], b);
    expect(blk['enemy_block'], b);
    expect(sim.enemy!['block'], b);
    expect(sim.player['hp'], hp0, reason: 'block intent damaged player');
    final (spurious, _) = findEvent(evs2, 'enemy_attacked');
    expect(spurious, isNull, reason: 'spurious enemy_attacked');
  });

  // -------------------------------------------------------------------------
  // 16–18: combat_over protocol
  // -------------------------------------------------------------------------

  test('combat_over won: flag set, phase untouched, no loot, guard on further cmds',
      () {
    final (sim, _) = beginFight(21, 'cinder_wisp');
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    sim.enemy!['hp'] = 1; // force lethal
    final evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs);
    final (won, _) = findEvent(evs, 'encounter_won');
    expect(won, isNotNull, reason: 'no encounter_won');
    expect(won!['turns'], 1);
    expect(sim.combatOver, 'won');
    expect(sim.phase, 'player_turn',
        reason: 'combat must NOT touch sim.phase');
    final (bd, _) = findEvent(evs, 'boss_defeated');
    expect(bd, isNull, reason: 'boss_defeated for non-boss');
    final (loot, _) = findEvent(evs, 'loot_dropped');
    expect(loot, isNull, reason: 'combat generated loot (run-layer job)');
    // further combat commands are rejected without state damage
    final fp = fingerprint(sim);
    final evs2 = <Map<String, dynamic>>[];
    combat.endTurn(sim, {'type': 'end_turn'}, evs2);
    expect(evs2[0]['type'], 'invalid_command');
    expect(fingerprint(sim), fp);
  });

  test('combat_over won vs boss: boss_defeated pushed too', () {
    final (sim, _) = beginFight(21, 'ember_tyrant');
    combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
    sim.enemy!['hp'] = 1;
    final evs = <Map<String, dynamic>>[];
    combat.assign(sim, {'type': 'assign', 'die': 1, 'action': 'attack'}, evs);
    final (won, wi) = findEvent(evs, 'encounter_won');
    final (bd, bi) = findEvent(evs, 'boss_defeated');
    expect(won != null && bd != null, isTrue,
        reason: 'missing encounter_won/boss_defeated');
    expect(wi < bi, isTrue,
        reason: 'encounter_won must precede boss_defeated');
    expect(bd!['turns'], 1);
    expect(sim.combatOver, 'won');
    expect(sim.phase, 'player_turn');
  });

  test('combat_over lost: flag set, phase untouched, correct event', () {
    final (sim, _) = beginFight(31, 'pyre_howler');
    sim.player['hp'] = 2; // turn-1 intent: attack → lethal
    final evs = <Map<String, dynamic>>[];
    combat.endTurn(sim, {'type': 'end_turn'}, evs);
    final (lost, _) = findEvent(evs, 'encounter_lost');
    expect(lost, isNotNull, reason: 'no encounter_lost');
    expect(lost!['turns'], 1);
    expect(sim.combatOver, 'lost');
    expect(sim.phase, 'player_turn',
        reason: 'combat must NOT touch sim.phase');
    final (ts, _) = findEvent(evs, 'turn_started');
    expect(ts, isNull, reason: 'turn advanced after death');
  });

  // -------------------------------------------------------------------------
  // 19: general invalid-command state safety (M0 behavior preserved)
  // -------------------------------------------------------------------------

  test('invalid commands: single event, state bit-untouched', () {
    final (sim, _) = beginFight(55, 'ash_rat');
    final cases = <({
      void Function(dynamic, Map<String, dynamic>, List<Map<String, dynamic>>)
          fn,
      Map<String, dynamic> cmd,
      void Function(TestSim)? pre,
      String reason,
    })>[
      (
        fn: combat.assign,
        cmd: {'type': 'assign', 'die': 1, 'action': 'attack'},
        pre: null,
        reason: 'roll_first',
      ),
      (
        fn: combat.roll,
        cmd: {'type': 'roll'},
        pre: (s) =>
            combat.roll(s, {'type': 'roll'}, <Map<String, dynamic>>[]),
        reason: 'already_rolled_this_turn',
      ),
      (
        fn: combat.assign,
        cmd: {'type': 'assign', 'die': 99, 'action': 'attack'},
        pre: null,
        reason: 'no_such_die',
      ),
      (
        fn: combat.assign,
        cmd: {'type': 'assign', 'die': 1, 'action': 'dance'},
        pre: null,
        reason: 'unknown_action',
      ),
    ];
    for (final c in cases) {
      c.pre?.call(sim);
      final fp = fingerprint(sim);
      final evs = <Map<String, dynamic>>[];
      c.fn(sim, c.cmd, evs);
      expect(evs.length, 1, reason: '${c.reason}: expected single event');
      expect(evs[0]['type'], 'invalid_command', reason: c.reason);
      expect(evs[0]['reason'], c.reason);
      expect(fingerprint(sim), fp, reason: '${c.reason}: state changed');
    }
    // wrong phase: all three handlers reject when not player_turn
    sim.phase = 'map';
    final fp = fingerprint(sim);
    for (final fn in [combat.roll, combat.assign, combat.endTurn]) {
      final evs = <Map<String, dynamic>>[];
      fn(sim, {'type': 'x', 'die': 1, 'action': 'attack'}, evs);
      expect(evs[0]['type'], 'invalid_command');
      expect(evs[0]['reason'], 'not_player_turn');
      expect(fingerprint(sim), fp);
    }
  });

  // -------------------------------------------------------------------------
  // 20: balance smoke — greedy bot beats every regular with the starting pool
  // -------------------------------------------------------------------------

  test('balance: starting pool {d6,d6,d6} beats each regular enemy (seed sweep)',
      () {
    final regulars = <String>[];
    for (final id in enemiesOrder) {
      final e = enemiesData[id]!;
      if (e['boss'] != true && e['elite'] != true) regulars.add(id);
    }
    expect(regulars.length >= 3, isTrue);
    // simple policy: block with the smallest die if intent hurts, attack rest
    for (final id in regulars) {
      var wins = 0;
      for (var seed = 1; seed <= 20; seed++) {
        final (sim, _) = beginFight(seed * 1000 + 7, id);
        for (var t = 0; t < 30; t++) {
          if (sim.combatOver != null) break;
          combat.roll(sim, {'type': 'roll'}, <Map<String, dynamic>>[]);
          final rolled = sim.player['rolled'] as List<int>;
          var smallest = 1, sv = rolled[0]; // 1-based, as in the Lua policy
          for (var i = 2; i <= 3; i++) {
            if (rolled[i - 1] < sv) {
              smallest = i;
              sv = rolled[i - 1];
            }
          }
          final hurts =
              (sim.enemy!['intent'] as Map)['kind'] != 'block';
          for (var i = 1; i <= 3; i++) {
            if (sim.combatOver != null) break;
            final action = (hurts && i == smallest) ? 'block' : 'attack';
            combat.assign(sim, {'type': 'assign', 'die': i, 'action': action},
                <Map<String, dynamic>>[]);
          }
          if (sim.combatOver == null) {
            combat.endTurn(sim, {'type': 'end_turn'}, <Map<String, dynamic>>[]);
          }
        }
        if (sim.combatOver == 'won') wins += 1;
      }
      expect(wins >= 15, isTrue,
          reason: '$id: too hard for starter pool (won $wins/20)');
      expect(wins <= 20, isTrue, reason: id); // sanity
    }
  });
}
