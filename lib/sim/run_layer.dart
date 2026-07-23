// sim/run_layer.dart — Run layer: map position, node entry, rewards, rest,
// and the run win/loss ledger.
// SEALED SIM MODULE: pure Dart, no Flutter imports, no dart:io, no Random.
//
// Seam rules (docs/m2-contract.md §1 — LAW):
//   * combat.dart never touches run state; when an encounter ends it sets
//     sim.combatOver = "won"|"lost" and pushes its events. After EVERY
//     dispatched command sim.dart calls runPost(sim, events), which reads
//     sim.combatOver, clears it, and performs ALL run-level transitions.
//   * Encounters start via the internal seam combatBegin.
//
// RNG discipline:
//   * map stream    -> map generation only (inside generateMap)
//   * combat stream -> dice rolls (combat.dart) + enemy spawn pick (here)
//   * loot stream   -> ember amounts + reward offer picks (here)
//   * shuffle       -> reserved
//   All pool iteration goes through the data `*Order` lists.

import '../data/dice.dart';
import '../data/enemies.dart';
import 'combat.dart';
import 'map_gen.dart';
import 'sim.dart';

void _push(List<Map<String, Object?>> events, Map<String, Object?> ev) =>
    events.add(ev);

void _invalid(List<Map<String, Object?>> events, String reason) =>
    _push(events, {'type': 'invalid_command', 'reason': reason});

// Enemy pools, built deterministically from enemiesOrder.
final List<String> _regulars = [
  for (final id in enemiesOrder)
    if (!enemies[id]!.boss && !enemies[id]!.elite) id
];
final List<String> _elites = [
  for (final id in enemiesOrder)
    if (enemies[id]!.elite) id
];
final String _boss =
    enemiesOrder.firstWhere((id) => enemies[id]!.boss);

// Ember payout for one won fight (loot stream, range 8–20).
int _rollEmbers(Sim sim) => sim.rng['loot']!.range(8, 20);

// ---------------------------------------------------------------------------
// command handlers
// ---------------------------------------------------------------------------

void runStartRun(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'idle') return _invalid(events, 'not_idle');
  final map = generateMap(sim.rng['map']!);
  map['position'] = map['start'];
  map['visited'] = <int>[map['start'] as int];
  sim.map = map;
  sim.run = <String, dynamic>{'embers': 0, 'fights_won': 0};
  sim.turnsTotal = 0;
  sim.phase = 'map';
  final nodeCount = (map['nodes'] as Map).length;
  _push(events, {
    'type': 'run_started',
    'seed': sim.runSeed,
    'nodes': nodeCount,
    'layers': map['layers'],
  });
}

void runChooseNode(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'map') return _invalid(events, 'not_map_phase');
  final target = cmd['node'];
  final map = sim.map!;
  final position = map['position'] as int;
  final out = ((map['edges'] as Map)['$position'] as List).cast<int>();
  if (target is! int || !out.contains(target)) {
    return _invalid(events, 'not_adjacent');
  }
  map['position'] = target;
  (map['visited'] as List).add(target);
  final node = (map['nodes'] as Map)['$target'] as Map;
  _push(events, {
    'type': 'node_entered',
    'node': target,
    'kind': node['kind'],
    'layer': node['layer'],
  });
  final kind = node['kind'];
  if (kind == 'fight') {
    final pick = _regulars[sim.rng['combat']!.range(1, _regulars.length) - 1];
    combatBegin(sim, pick, false, events);
  } else if (kind == 'elite') {
    final pick = _elites[sim.rng['combat']!.range(1, _elites.length) - 1];
    combatBegin(sim, pick, true, events);
  } else if (kind == 'boss') {
    combatBegin(sim, _boss, false, events);
  } else if (kind == 'rest') {
    sim.phase = 'rest';
  }
}

/// cmd: { type:"choose_reward", index: 1..#offers | 0 to skip }
void runChooseReward(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'reward' || sim.offers == null) {
    return _invalid(events, 'not_reward_phase');
  }
  final i = cmd['index'];
  final offers = sim.offers!;
  if (i is! int || i < 0 || i > offers.length) {
    return _invalid(events, 'no_such_offer');
  }
  if (i == 0) {
    _push(events, {'type': 'reward_skipped'});
  } else {
    final die = offers[i - 1];
    (sim.player['dice'] as List).add(die);
    _push(events, {'type': 'reward_chosen', 'die': die});
  }
  sim.offers = null;
  sim.phase = 'map';
}

void runRest(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'rest') return _invalid(events, 'not_rest_phase');
  final p = sim.player;
  // 30% of max hp, floored; integer-exact arithmetic.
  var healed = ((p['max_hp'] as int) * 3) ~/ 10;
  final hp = p['hp'] as int;
  final maxHp = p['max_hp'] as int;
  if (hp + healed > maxHp) healed = maxHp - hp;
  p['hp'] = hp + healed;
  _push(events, {'type': 'rested', 'healed': healed, 'hp': p['hp']});
  sim.phase = 'map';
}

// ---------------------------------------------------------------------------
// post hook — called by sim.dart after EVERY dispatched command
// ---------------------------------------------------------------------------

/// Reads sim.combatOver, clears it, performs all run-level transitions.
void runPost(Sim sim, List<Map<String, Object?>> events) {
  final outcome = sim.combatOver;
  if (outcome == null) return;
  sim.combatOver = null;
  sim.turnsTotal += sim.turn;
  final map = sim.map!;
  final node =
      (map['nodes'] as Map)['${map['position']}'] as Map;
  final run = sim.run!;
  if (outcome == 'won') {
    run['fights_won'] = (run['fights_won'] as int) + 1;
    if (node['kind'] == 'boss') {
      run['embers'] = (run['embers'] as int) + _rollEmbers(sim) + 40;
      sim.phase = 'run_won';
      _push(events, {
        'type': 'run_won',
        'embers': run['embers'],
        'fights_won': run['fights_won'],
        'turns_total': sim.turnsTotal,
      });
    } else {
      run['embers'] = (run['embers'] as int) + _rollEmbers(sim);
      // Reward offers: 2–3 distinct die ids picked via the loot stream from
      // diceOrder (uniform, without replacement).
      final count = sim.rng['loot']!.range(2, 3);
      final pool = List<String>.from(diceOrder);
      final offers = <String>[];
      for (var k = 0; k < count; k++) {
        final idx = sim.rng['loot']!.range(1, pool.length);
        offers.add(pool.removeAt(idx - 1));
      }
      sim.offers = offers;
      sim.phase = 'reward';
      _push(events, {
        'type': 'reward_offered',
        'o1': offers[0],
        'o2': offers[1],
        if (offers.length > 2) 'o3': offers[2],
      });
    }
  } else {
    // "lost": the death ledger keeps half the embers.
    run['embers'] = (run['embers'] as int) ~/ 2;
    sim.phase = 'run_lost';
    _push(events, {
      'type': 'run_lost',
      'embers': run['embers'],
      'fights_won': run['fights_won'],
      'layer': node['layer'],
    });
  }
}
