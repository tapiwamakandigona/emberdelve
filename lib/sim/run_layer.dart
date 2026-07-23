// sim/run_layer.dart — Run layer (M1, v2): map position, node entry,
// rewards, rest, and the run win/loss ledger.
// SEALED SIM MODULE: pure Dart, no Flutter, no dart:io, no dart:math Random,
// no clocks.
//
// 1:1 port of legacy/defold/sim/run.lua (the behavioral oracle — RNG
// consumption order copied line-by-line; comments cite run.lua lines for
// the tricky parts, especially the post-hook ordering and ember/loot math).
//
// Seam rules (docs/m1-contract.md §1 — LAW):
//   * combat.dart never touches run state; when an encounter ends it sets
//     sim.combatOver = 'won'|'lost' and pushes its events. After EVERY
//     dispatched command sim.dart calls run_layer.post(sim, events), which
//     reads sim.combatOver, clears it, and performs ALL run-level phase
//     transitions (rewards, defeat ledger, run victory).
//   * Encounters are started via the internal seam combat.begin — the
//     public start_encounter command no longer exists.
//
// RNG discipline (contract §8):
//   * map stream    → map generation only (inside generateMap)
//   * combat stream → dice rolls (combat.dart) + enemy spawn pick (here)
//   * loot stream   → ember amounts + reward offer picks (here)
//   * shuffle       → reserved, unused in M1
//   All pool iteration goes through the data order lists ([enemiesOrder],
//   [diceOrder]) — never map iteration order.
//
// `sim` is typed `dynamic` (same convention as combat.dart): this module
// codes against the exact field surface of class Sim (lib/sim/sim.dart) —
// sim.map / sim.run (Map), sim.offers (List?), sim.player (Map),
// sim.phase (String), sim.turn (int), sim.turnsTotal (int),
// sim.combatOver (String?), sim.runSeed (int), sim.rng (Map<String, Rng>).

import '../data/dice.dart';
import '../data/enemies.dart';
import 'combat.dart' as combat;
import 'map_gen.dart';
import 'rng.dart';

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

void _invalid(List<Map<String, dynamic>> events, String reason) {
  events.add({'type': 'invalid_command', 'reason': reason});
}

// Enemy pools, built once from the authoring order (run.lua:43-57 builds
// them from enemies._order — deterministic, never pairs()).
final List<String> _regulars = _buildPool(boss: false, elite: false);
final List<String> _elites = _buildPool(boss: false, elite: true);
final String _boss = enemiesOrder
    .firstWhere((id) => enemiesData[id]!['boss'] == true, orElse: () {
  throw StateError('run: data/enemies.dart has no boss');
});

List<String> _buildPool({required bool boss, required bool elite}) {
  final pool = <String>[
    for (final id in enemiesOrder)
      if ((enemiesData[id]!['boss'] == true) == boss &&
          (enemiesData[id]!['elite'] == true) == elite)
        id,
  ];
  if (pool.isEmpty) {
    throw StateError('run: enemy pools incomplete'); // run.lua:58
  }
  return pool;
}

/// Ember payout for one won fight (contract §4: loot stream, range 8–20).
/// Port of run.lua:61-63 `roll_embers`.
int _rollEmbers(dynamic sim) => (sim.rng['loot'] as Rng).range(8, 20);

// ---------------------------------------------------------------------------
// command handlers (signature: (sim, cmd, events) — same as combat's)
// ---------------------------------------------------------------------------

/// Port of run.lua `run.start_run`.
void startRun(dynamic sim, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> events) {
  if (sim.phase != 'idle') {
    return _invalid(events, 'not_idle');
  }
  final map = generateMap(sim.rng['map'] as Rng);
  map['position'] = map['start'];
  map['visited'] = <int>[map['start'] as int];
  sim.map = map;
  sim.run = <String, dynamic>{'embers': 0, 'fights_won': 0};
  sim.turnsTotal = 0;
  sim.phase = 'map';
  // Lua counts nodes by probing ids 1..n (run.lua:81-82); ids are dense.
  final nodes = map['nodes'] as Map;
  var nodeCount = 0;
  while (nodes.containsKey(nodeCount + 1)) {
    nodeCount = nodeCount + 1;
  }
  events.add({
    'type': 'run_started',
    'seed': sim.runSeed,
    'nodes': nodeCount,
    'layers': map['layers'],
  });
}

/// Port of run.lua `run.choose_node`.
void chooseNode(dynamic sim, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> events) {
  if (sim.phase != 'map') {
    return _invalid(events, 'not_map_phase');
  }
  final dynamic target = cmd['node'];
  final map = sim.map as Map<String, dynamic>;
  final out = (map['edges'] as Map)[map['position']] as List;
  var adjacent = false;
  for (var i = 0; i < out.length; i++) {
    if (out[i] == target) {
      adjacent = true;
      break;
    }
  }
  if (!adjacent) {
    return _invalid(events, 'not_adjacent');
  }
  map['position'] = target;
  (map['visited'] as List).add(target);
  final node = (map['nodes'] as Map)[target] as Map;
  events.add({
    'type': 'node_entered',
    'node': target,
    'kind': node['kind'],
    'layer': node['layer'],
  });
  if (node['kind'] == 'fight') {
    // 1-based pick from the pool (run.lua:110): combat stream.
    final pick =
        _regulars[(sim.rng['combat'] as Rng).range(1, _regulars.length) - 1];
    combat.begin(sim, pick, false, events);
  } else if (node['kind'] == 'elite') {
    final pick =
        _elites[(sim.rng['combat'] as Rng).range(1, _elites.length) - 1];
    combat.begin(sim, pick, true, events);
  } else if (node['kind'] == 'boss') {
    combat.begin(sim, _boss, false, events);
  } else if (node['kind'] == 'rest') {
    sim.phase = 'rest';
  }
}

/// cmd: { type='choose_reward', index = 1..#offers | 0 to skip }
/// Port of run.lua `run.choose_reward`.
void chooseReward(dynamic sim, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> events) {
  if (sim.phase != 'reward' || sim.offers == null) {
    return _invalid(events, 'not_reward_phase');
  }
  final offers = sim.offers as List;
  // Lua: type(i) ~= "number" or i ~= math.floor(i) or i < 0 or i > #offers
  // (run.lua:129-131) — non-number, fractional, or out-of-range rejects.
  final dynamic raw = cmd['index'];
  if (raw is! num || raw != raw.floor() || raw < 0 || raw > offers.length) {
    return _invalid(events, 'no_such_offer');
  }
  final i = raw.toInt();
  if (i == 0) {
    events.add({'type': 'reward_skipped'});
  } else {
    final die = offers[i - 1]; // 1-based index across the sim boundary
    (sim.player['dice'] as List).add(die);
    events.add({'type': 'reward_chosen', 'die': die});
  }
  sim.offers = null;
  sim.phase = 'map';
}

/// Port of run.lua `run.rest`.
void rest(dynamic sim, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> events) {
  if (sim.phase != 'rest') {
    return _invalid(events, 'not_rest_phase');
  }
  final p = sim.player as Map<String, dynamic>;
  // 30% of max hp, floored; integer-exact arithmetic — Lua uses
  // math.floor(max_hp * 3 / 10), never x*0.3 (run.lua:152).
  var healed = (p['max_hp'] as int) * 3 ~/ 10;
  if ((p['hp'] as int) + healed > (p['max_hp'] as int)) {
    healed = (p['max_hp'] as int) - (p['hp'] as int);
  }
  p['hp'] = (p['hp'] as int) + healed;
  events.add({'type': 'rested', 'healed': healed, 'hp': p['hp']});
  sim.phase = 'map';
}

// ---------------------------------------------------------------------------
// post hook — called by sim.dart after EVERY dispatched command
// ---------------------------------------------------------------------------

/// Reads sim.combatOver, clears it, performs all run-level transitions.
/// Port of run.lua `run.post` — RNG ordering is LAW here:
///   won non-boss: roll_embers → count=loot:range(2,3) → count offer picks;
///   won boss:     roll_embers only (then +40 flat);
///   lost:         no loot rolls (halved ledger).
void post(dynamic sim, List<Map<String, dynamic>> events) {
  final outcome = sim.combatOver as String?;
  if (outcome == null) return;
  sim.combatOver = null;
  sim.turnsTotal = (sim.turnsTotal as int) + (sim.turn as int);
  final map = sim.map as Map<String, dynamic>;
  final node = (map['nodes'] as Map)[map['position']] as Map;
  final run = sim.run as Map<String, dynamic>;
  if (outcome == 'won') {
    run['fights_won'] = (run['fights_won'] as int) + 1;
    if (node['kind'] == 'boss') {
      // Boss payout: one loot roll + flat 40 (run.lua:169).
      run['embers'] = (run['embers'] as int) + _rollEmbers(sim) + 40;
      sim.phase = 'run_won';
      events.add({
        'type': 'run_won',
        'embers': run['embers'],
        'fights_won': run['fights_won'],
        'turns_total': sim.turnsTotal,
      });
    } else {
      // Ordinary payout FIRST (run.lua:178), then the offer rolls.
      run['embers'] = (run['embers'] as int) + _rollEmbers(sim);
      // Reward offers: 2–3 distinct die ids picked via the loot stream
      // from diceOrder (uniform, without replacement) — run.lua:181-189.
      final count = (sim.rng['loot'] as Rng).range(2, 3);
      final pool = List<String>.of(diceOrder);
      final offers = <String>[];
      for (var k = 1; k <= count; k++) {
        final idx = (sim.rng['loot'] as Rng).range(1, pool.length);
        offers.add(pool[idx - 1]);
        pool.removeAt(idx - 1); // Lua table.remove(pool, idx)
      }
      sim.offers = offers;
      sim.phase = 'reward';
      final ev = <String, dynamic>{
        'type': 'reward_offered',
        'o1': offers[0],
        'o2': offers[1],
      };
      if (offers.length >= 3) ev['o3'] = offers[2];
      events.add(ev);
    }
  } else {
    // 'lost': the death ledger keeps half the embers, floored (contract §4;
    // run.lua:199 math.floor(embers / 2)).
    run['embers'] = (run['embers'] as int) ~/ 2;
    sim.phase = 'run_lost';
    events.add({
      'type': 'run_lost',
      'embers': run['embers'],
      'fights_won': run['fights_won'],
      'layer': node['layer'],
    });
  }
}
