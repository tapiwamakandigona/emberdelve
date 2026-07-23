// bin/parity.dart — Port-parity prover (Lua -> Dart).
// Drives the Dart sim with the exact greedy policy used by the Lua reference
// suite and prints per-seed terminal (phase, event_hash) lines plus the golden
// seed hash, so the output can be diffed 1:1 against the Lua dump.
//
// Usage: dart run bin/parity.dart

import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/sim/sim.dart';

Map<String, Object?>? nextCmd(Sim sim) {
  final phase = sim.phase;
  if (phase == 'idle') return {'type': 'start_run'};
  if (phase == 'map') {
    final map = sim.map!;
    final position = map['position'] as int;
    final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
    final wantRest =
        (sim.player['hp'] as int) * 2 < (sim.player['max_hp'] as int);
    int? pick;
    for (final e in edges) {
      final kind = (map['nodes'] as Map)['$e']!['kind'];
      if (wantRest && kind == 'rest') {
        pick = e;
        break;
      }
      if (!wantRest && kind != 'rest') pick ??= e;
    }
    return {'type': 'choose_node', 'node': pick ?? edges[0]};
  }
  if (phase == 'player_turn') {
    final rolled = (sim.player['rolled'] as List?)?.cast<int>();
    if (rolled == null) return {'type': 'roll'};
    final assigned = sim.player['assigned'] as Map;
    for (var i = 1; i <= rolled.length; i++) {
      if (assigned['$i'] == null) {
        final mods = dieDef((sim.player['dice'] as List)[i - 1] as String).mods;
        final intent = sim.enemy!['intent'] as Map;
        var incoming = 0;
        if (intent['kind'] == 'attack' || intent['kind'] == 'attack_block') {
          incoming = intent['amount'] as int;
        }
        String action;
        if (incoming > (sim.player['block'] as int) &&
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
  }
  if (phase == 'reward') return {'type': 'choose_reward', 'index': 1};
  if (phase == 'rest') return {'type': 'rest'};
  return null; // terminal
}

Sim play(int seed, {int? snapAt}) {
  var sim = Sim(seed);
  var applied = 0;
  while (applied < 3000) {
    final cmd = nextCmd(sim);
    if (cmd == null) break;
    sim.apply(cmd);
    applied += 1;
    if (snapAt != null && applied == snapAt) {
      sim = Sim.restore(sim.snapshot());
    }
  }
  return sim;
}

void main() {
  final golden = play(20260723);
  print('golden ${golden.eventHash}');
  var wins = 0, losses = 0;
  for (var seed = 1; seed <= 100; seed++) {
    final sim = play(seed);
    if (sim.phase == 'run_won') wins++;
    if (sim.phase == 'run_lost') losses++;
    print('seed $seed ${sim.phase} ${sim.eventHash}');
  }
  print('wins=$wins losses=$losses');
  // snapshot/restore twin check
  for (var seed = 1; seed <= 10; seed++) {
    final plain = play(seed);
    final resumed = play(seed, snapAt: 25);
    if (plain.eventHash != resumed.eventHash ||
        plain.stateHash() != resumed.stateHash()) {
      print('TWIN FAIL seed $seed');
    }
  }
  print('twin check done');
}
