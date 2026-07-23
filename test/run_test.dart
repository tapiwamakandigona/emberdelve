// Port of legacy/defold/tests/run_tests.lua — all 18 tests, same assertions.
// The golden anchor test reads EMBERDELVE_GOLDEN like the Lua one (dart:io
// is allowed in test/ only).
import 'dart:io';

import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/sim/rng.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Deterministic greedy driver (public v2 command set only) — verbatim port
// of run_tests.lua `next_cmd`/`drive`/`replay`. A pure function of
// sim.state() -> next command, so the same seed always produces the same
// command sequence.
// ---------------------------------------------------------------------------

Map<String, dynamic>? nextCmd(Sim sim) {
  final st = sim.state();
  final phase = st['phase'] as String;
  if (phase == 'idle') {
    return {'type': 'start_run'};
  } else if (phase == 'map') {
    final map = st['map'] as Map<String, dynamic>;
    final edges = (map['edges'] as Map)[map['position']] as List;
    final player = st['player'] as Map<String, dynamic>;
    final wantRest = (player['hp'] as int) * 2 < (player['max_hp'] as int);
    int? pick;
    for (var i = 0; i < edges.length; i++) {
      final kind = ((map['nodes'] as Map)[edges[i]] as Map)['kind'];
      if (wantRest && kind == 'rest') {
        pick = edges[i] as int;
        break;
      }
      if (!wantRest && kind != 'rest' && pick == null) pick = edges[i] as int;
    }
    return {'type': 'choose_node', 'node': pick ?? edges[0]};
  } else if (phase == 'player_turn') {
    final player = st['player'] as Map<String, dynamic>;
    final rolled = player['rolled'] as List?;
    if (rolled == null) return {'type': 'roll'};
    final assigned = player['assigned'] as Map;
    for (var i = 1; i <= rolled.length; i++) {
      if (!assigned.containsKey(i)) {
        final mods =
            diceData[(player['dice'] as List)[i - 1]]!['mods'] as Map;
        final intent = (st['enemy'] as Map)['intent'] as Map;
        var incoming = 0;
        if (intent['kind'] == 'attack' || intent['kind'] == 'attack_block') {
          incoming = intent['amount'] as int;
        }
        String action;
        if (incoming > (player['block'] as int) &&
            mods['attack_only'] != true) {
          action = 'block';
        } else if (mods['block_only'] != true) {
          action = 'attack';
        } else {
          action = 'block';
        }
        return {'type': 'assign', 'die': i, 'action': action};
      }
    }
    return {'type': 'end_turn'};
  } else if (phase == 'reward') {
    return {'type': 'choose_reward', 'index': 1};
  } else if (phase == 'rest') {
    return {'type': 'rest'};
  }
  return null; // terminal
}

/// Drive [sim] for up to [maxCmds] commands (default: to terminal).
/// Returns (all events, applied commands).
(List<Map<String, dynamic>>, List<Map<String, dynamic>>) drive(Sim sim,
    [int maxCmds = 3000]) {
  final all = <Map<String, dynamic>>[];
  final cmds = <Map<String, dynamic>>[];
  for (var n = 0; n < maxCmds; n++) {
    final cmd = nextCmd(sim);
    if (cmd == null) break;
    cmds.add(cmd);
    all.addAll(sim.apply(cmd));
  }
  return (all, cmds);
}

List<Map<String, dynamic>> replay(Sim sim, List<Map<String, dynamic>> cmds) {
  final all = <Map<String, dynamic>>[];
  for (final cmd in cmds) {
    all.addAll(sim.apply(cmd));
  }
  return all;
}

/// Deterministic seed search (style: tests/content_tests.lua).
int findSeed(bool Function(int seed) pred) {
  for (var seed = 1; seed <= 20000; seed++) {
    if (pred(seed)) return seed;
  }
  fail('no seed found in [1,20000]');
}

/// Fresh sim advanced into its first fight node. Returns (sim, events of the
/// node entry) or null when the first layer has no plain fight edge.
(Sim, List<Map<String, dynamic>>)? enterFirstFight(int seed) {
  final sim = Sim(seed);
  sim.apply({'type': 'start_run'});
  final map = sim.map!;
  final edges = (map['edges'] as Map)[map['position']] as List;
  for (var i = 0; i < edges.length; i++) {
    if (((map['nodes'] as Map)[edges[i]] as Map)['kind'] == 'fight') {
      return (sim, sim.apply({'type': 'choose_node', 'node': edges[i]}));
    }
  }
  return null;
}

Map<String, dynamic>? findEvent(List<Map<String, dynamic>> evs, String etype) {
  for (final ev in evs) {
    if (ev['type'] == etype) return ev;
  }
  return null;
}

int min(int a, int b) => a < b ? a : b;

void main() {
  // ---------------------------------------------------------------------
  // Tests: RNG (unchanged from M0)
  // ---------------------------------------------------------------------

  test('rng: die rolls stay in bounds and hit all faces', () {
    final r = Rng(42, 'combat');
    final seen = <int>{};
    for (var i = 0; i < 1000; i++) {
      final v = r.die(6);
      expect(v >= 1 && v <= 6, isTrue, reason: 'die out of bounds: $v');
      seen.add(v);
    }
    for (var face = 1; face <= 6; face++) {
      expect(seen.contains(face), isTrue, reason: 'face never rolled: $face');
    }
  });

  test('rng: streams are independent', () {
    // Draining the combat stream must not shift the loot stream.
    final aLoot = Rng(7, 'loot');
    final bCombat = Rng(7, 'combat');
    final bLoot = Rng(7, 'loot');
    for (var i = 0; i < 100; i++) {
      bCombat.nextRaw();
    }
    for (var i = 1; i <= 20; i++) {
      expect(aLoot.nextRaw(), bLoot.nextRaw(),
          reason: 'loot stream shifted at draw $i');
    }
  });

  test('rng: snapshot/restore continues identically', () {
    final r = Rng(99, 'map');
    for (var i = 0; i < 10; i++) {
      r.nextRaw();
    }
    final twin = Rng.restore(r.snapshot());
    for (var i = 1; i <= 50; i++) {
      expect(r.nextRaw(), twin.nextRaw(), reason: 'diverged at draw $i');
    }
  });

  // ---------------------------------------------------------------------
  // Tests: sim v2 determinism + persistence
  // ---------------------------------------------------------------------

  test('sim: same seed + same commands => identical event and state hashes',
      () {
    final a = Sim(123456);
    final (_, cmds) = drive(a);
    final b = Sim(123456);
    replay(b, cmds);
    expect(a.eventHash, b.eventHash, reason: 'event hashes differ');
    expect(a.eventCount, b.eventCount, reason: 'event counts differ');
    expect(a.stateHash(), b.stateHash(), reason: 'state hashes differ');
  });

  test('sim: different seeds => different runs', () {
    final a = Sim(1);
    final b = Sim(2);
    drive(a);
    drive(b);
    expect(a.eventHash, isNot(b.eventHash),
        reason: 'event hashes should differ across seeds');
  });

  test('sim: snapshot mid-run, restore, continue => identical', () {
    final a = Sim(777);
    drive(a, 30); // into the run: map + combat state live
    final b = Sim.restore(a.snapshot());
    final (_, tail) = drive(a); // finish a with the policy, recording cmds
    replay(b, tail); // twin replays the exact same commands
    expect(a.eventHash, b.eventHash,
        reason: 'event hashes diverged after restore');
    expect(a.stateHash(), b.stateHash(),
        reason: 'state hashes diverged after restore');
    expect(a.phase, b.phase, reason: 'phases diverged after restore');
  });

  test('sim: restore rejects non-v2 snapshots', () {
    final sim = Sim(5);
    final snap = sim.snapshot();
    snap['version'] = 1;
    expect(
        () => Sim.restore(snap),
        throwsA(predicate((e) => e.toString().contains('SIM_VERSION'),
            'error message mentions SIM_VERSION')));
  });

  // ---------------------------------------------------------------------
  // Tests: run layer
  // ---------------------------------------------------------------------

  test('sim: start_run builds the map, run ledger, and map phase', () {
    final sim = Sim(2026);
    final evs = sim.apply({'type': 'start_run'});
    final started = findEvent(evs, 'run_started');
    expect(started, isNotNull, reason: 'no run_started event');
    expect(started!['seed'], 2026, reason: 'run_started.seed wrong');
    expect((started['nodes'] as int) > 0 && started['layers'] == 9, isTrue,
        reason: 'run_started shape wrong');
    final st = sim.state();
    expect(st['phase'], 'map', reason: 'phase should be map');
    final map = st['map'] as Map<String, dynamic>;
    expect(map['position'], map['start'], reason: 'position not at start');
    final visited = map['visited'] as List;
    expect(visited.length, 1, reason: 'visited should hold only start');
    expect(visited[0], map['start'], reason: 'visited[1] must be start');
    expect((st['run'] as Map)['embers'], 0, reason: 'embers not zeroed');
    expect((st['run'] as Map)['fights_won'], 0,
        reason: 'fights_won not zeroed');
    // second start_run is invalid and mutates nothing
    final before = sim.stateHash();
    final evs2 = sim.apply({'type': 'start_run'});
    expect(evs2[0]['type'], 'invalid_command',
        reason: 'second start_run should be invalid');
    expect(sim.stateHash(), before,
        reason: 'state changed by invalid start_run');
  });

  test('sim: choose_node accepts only edges of the current position', () {
    final sim = Sim(4242);
    sim.apply({'type': 'start_run'});
    final before = sim.stateHash();
    // non-adjacent: the boss node is never one hop from start (9 layers)
    final evs = sim.apply({'type': 'choose_node', 'node': sim.map!['boss']});
    expect(evs[0]['type'], 'invalid_command',
        reason: 'boss node should not be adjacent');
    expect(evs[0]['reason'], 'not_adjacent', reason: 'wrong reason');
    expect(sim.stateHash(), before,
        reason: 'state changed by invalid choose_node');
    // adjacent node enters and emits node_entered with kind + layer
    final target =
        ((sim.map!['edges'] as Map)[sim.map!['position']] as List)[0];
    final evs2 = sim.apply({'type': 'choose_node', 'node': target});
    final entered = findEvent(evs2, 'node_entered');
    expect(entered, isNotNull, reason: 'no node_entered event');
    expect(entered!['node'], target, reason: 'wrong node entered');
    expect(entered['layer'], 2, reason: 'first hop must reach layer 2');
    expect(sim.map!['position'], target, reason: 'position not updated');
    expect((sim.map!['visited'] as List)[1], target,
        reason: 'visited not updated');
  });

  test('sim: entering a fight node auto-starts the encounter with visible intent',
      () {
    final seed = findSeed((s) => enterFirstFight(s) != null);
    final (sim, evs) = enterFirstFight(seed)!;
    final started = findEvent(evs, 'encounter_started');
    expect(started, isNotNull, reason: 'no encounter_started event');
    expect(started!['elite'], false, reason: 'regular fight flagged elite');
    expect(findEvent(evs, 'intent_shown'), isNotNull,
        reason: 'intent not shown at encounter start');
    expect(sim.phase, 'player_turn', reason: 'phase should be player_turn');
    expect(sim.turn, 1, reason: 'turn should be 1');
  });

  test('sim: intent resolves exactly as shown (deterministic resolution)', () {
    final seed = findSeed((s) {
      final r = enterFirstFight(s);
      if (r == null) return false;
      final intent = findEvent(r.$2, 'intent_shown');
      return intent != null && intent['kind'] == 'attack';
    });
    final (sim, evs) = enterFirstFight(seed)!;
    final shown = findEvent(evs, 'intent_shown')!;
    sim.apply({'type': 'roll'});
    final hit =
        findEvent(sim.apply({'type': 'end_turn'}), 'enemy_attacked');
    expect(hit, isNotNull, reason: 'no enemy_attacked event');
    expect(hit!['amount'], shown['amount'],
        reason: 'enemy attack differs from shown intent');
  });

  test('sim: block reduces incoming damage', () {
    final seed = findSeed((s) {
      final r = enterFirstFight(s);
      if (r == null) return false;
      final intent = findEvent(r.$2, 'intent_shown');
      return intent != null && intent['kind'] == 'attack';
    });
    final (sim, evs) = enterFirstFight(seed)!;
    final intent = findEvent(evs, 'intent_shown')!['amount'] as int;
    sim.apply({'type': 'roll'});
    sim.apply({'type': 'assign', 'die': 1, 'action': 'block'});
    sim.apply({'type': 'assign', 'die': 2, 'action': 'block'});
    sim.apply({'type': 'assign', 'die': 3, 'action': 'block'});
    final block = sim.player['block'] as int;
    expect(block >= 3, isTrue, reason: 'expected at least 3 block');
    final hit =
        findEvent(sim.apply({'type': 'end_turn'}), 'enemy_attacked');
    expect(hit, isNotNull, reason: 'no enemy_attacked event');
    expect(hit!['blocked'], min(intent, block),
        reason: 'blocked amount wrong');
    expect(hit['damage'], intent - min(intent, block),
        reason: 'damage after block wrong');
  });

  test('sim: won fight pays embers and offers 2-3 rewards; choosing grows the pool',
      () {
    final sim = Sim(31337);
    final (all, _) = drive(sim); // full run
    final offered = findEvent(all, 'reward_offered');
    expect(offered, isNotNull, reason: 'no reward_offered event in full run');
    expect(offered!['o1'] != null && offered['o2'] != null, isTrue,
        reason: 'offer needs at least o1 and o2');
    expect(
        diceData[offered['o1']] != null && diceData[offered['o2']] != null,
        isTrue,
        reason: 'offers must be die ids');
    // replay the same run and stop AT the first reward phase to inspect it
    final sim2 = Sim(31337);
    for (var i = 0; i < 3000; i++) {
      if (sim2.phase == 'reward') break;
      sim2.apply(nextCmd(sim2)!);
    }
    expect(sim2.phase, 'reward', reason: 'never reached reward phase');
    final st = sim2.state();
    final offers = st['offers'] as List;
    expect(offers.length >= 2 && offers.length <= 3, isTrue,
        reason: 'offers must be 2-3, got ${offers.length}');
    expect((st['run'] as Map)['embers'] as int >= 8, isTrue,
        reason: 'won fight must pay >= 8 embers');
    expect((st['run'] as Map)['fights_won'], 1,
        reason: 'fights_won must be 1 after first win');
    final poolBefore = ((st['player'] as Map)['dice'] as List).length;
    final evs = sim2.apply({'type': 'choose_reward', 'index': 1});
    final chosen = findEvent(evs, 'reward_chosen');
    expect(chosen, isNotNull, reason: 'no reward_chosen event');
    final dice = sim2.player['dice'] as List;
    expect(dice.length, poolBefore + 1, reason: 'die pool did not grow');
    expect(dice.last, chosen!['die'], reason: 'wrong die added');
    expect(sim2.phase, 'map', reason: 'phase should return to map');
    expect(sim2.state()['offers'], isNull,
        reason: 'offers must clear after choosing');
  });

  test('sim: choose_reward index 0 skips without growing the pool', () {
    final sim = Sim(31337);
    for (var i = 0; i < 3000; i++) {
      if (sim.phase == 'reward') break;
      sim.apply(nextCmd(sim)!);
    }
    expect(sim.phase, 'reward', reason: 'never reached reward phase');
    final poolBefore = (sim.player['dice'] as List).length;
    final evs = sim.apply({'type': 'choose_reward', 'index': 0});
    expect(findEvent(evs, 'reward_skipped'), isNotNull,
        reason: 'no reward_skipped event');
    expect((sim.player['dice'] as List).length, poolBefore,
        reason: 'skip must not grow the pool');
    expect(sim.phase, 'map', reason: 'phase should return to map');
  });

  test('sim: rest heals 30% of max hp, floored and capped', () {
    // Drive a wounded run until the policy takes a rest node.
    final seed = findSeed((s) {
      final sim = Sim(s);
      for (var i = 0; i < 3000; i++) {
        if (sim.phase == 'rest') return true;
        final cmd = nextCmd(sim);
        if (cmd == null) return false;
        sim.apply(cmd);
      }
      return false;
    });
    final sim = Sim(seed);
    for (var i = 0; i < 3000; i++) {
      if (sim.phase == 'rest') break;
      sim.apply(nextCmd(sim)!);
    }
    expect(sim.phase, 'rest', reason: 'never reached rest phase');
    final hp = sim.player['hp'] as int;
    final maxHp = sim.player['max_hp'] as int;
    final expected = min(maxHp * 3 ~/ 10, maxHp - hp);
    final rested = findEvent(sim.apply({'type': 'rest'}), 'rested');
    expect(rested, isNotNull, reason: 'no rested event');
    expect(rested!['healed'], expected, reason: 'healed amount wrong');
    expect(rested['hp'], hp + expected, reason: 'hp after rest wrong');
    expect(sim.player['hp'], min(hp + expected, maxHp),
        reason: 'hp overshot max');
    expect(sim.phase, 'map', reason: 'phase should return to map');
  });

  test('sim: full run reaches a terminal phase with a consistent ledger', () {
    final sim = Sim(20260723);
    final (all, _) = drive(sim);
    expect(sim.phase == 'run_won' || sim.phase == 'run_lost', isTrue,
        reason: 'expected terminal phase, got ${sim.phase}');
    final terminal = findEvent(all, sim.phase); // run_won / run_lost event
    expect(terminal, isNotNull, reason: 'no ${sim.phase} event');
    expect(terminal!['embers'], sim.run!['embers'],
        reason: 'event embers != ledger embers');
    expect(terminal['fights_won'], sim.run!['fights_won'],
        reason: 'event fights_won != ledger');
    if (sim.phase == 'run_won') {
      expect(findEvent(all, 'boss_defeated'), isNotNull,
          reason: 'run_won without boss_defeated');
      expect(terminal['turns_total'] as int > 0, isTrue,
          reason: 'turns_total must be positive');
      expect(sim.run!['embers'] as int >= 40, isTrue,
          reason: 'boss bonus missing from embers');
    } else {
      expect(terminal['layer'] as int >= 2, isTrue,
          reason: 'run_lost.layer must be a middle+ layer');
    }
    // terminal phases are dead: every further command is invalid, frozen
    final before = sim.stateHash();
    for (final cmd in [
      {'type': 'start_run'},
      {'type': 'roll'},
      {'type': 'choose_node', 'node': sim.map!['start']},
    ]) {
      final evs = sim.apply(Map<String, dynamic>.of(cmd));
      expect(evs[0]['type'], 'invalid_command',
          reason: 'terminal phase accepted ${cmd['type']}');
    }
    expect(sim.stateHash(), before, reason: 'terminal state mutated');
  });

  test('sim: invalid commands emit events but never mutate state', () {
    final sim = Sim(42);
    sim.apply({'type': 'start_run'});
    final before = sim.stateHash();
    final cases = <Map<String, dynamic>>[
      {'type': 'roll'}, // not in combat
      {'type': 'assign', 'die': 1, 'action': 'attack'},
      {'type': 'end_turn'},
      {'type': 'choose_reward', 'index': 1}, // no offers
      {'type': 'rest'}, // not at a rest node
      {'type': 'start_run'}, // already running
      {'type': 'choose_node', 'node': -1}, // no such edge
      {'type': 'nonsense'}, // unknown
    ];
    for (final cmd in cases) {
      final evs = sim.apply(cmd);
      expect(evs[0]['type'], 'invalid_command',
          reason: 'expected invalid_command for ${cmd['type']}');
      expect(evs.length, 1,
          reason: 'invalid command must emit exactly one event');
    }
    expect(sim.stateHash(), before,
        reason: 'state changed by invalid commands');
  });

  test('sim: golden determinism anchor (cross-VM regression guard)', () {
    // If this hash ever changes, sim behavior changed for existing seeds:
    // bump SIM_VERSION and document in progress.md.
    final sim = Sim(20260723);
    drive(sim);
    // self-consistency: same seed + same commands must reproduce the hash
    final twin = Sim(20260723);
    drive(twin);
    expect(sim.eventHash, twin.eventHash,
        reason: 'golden run is not self-consistent');
    final golden =
        int.tryParse(Platform.environment['EMBERDELVE_GOLDEN'] ?? '0') ?? 0;
    if (golden != 0) {
      expect(sim.eventHash, golden,
          reason: 'event hash drifted from golden value');
    } else {
      // ignore: avoid_print
      print('      golden event_hash = ${sim.eventHash}');
    }
  });
}
