// sim/combat.dart — Encounter layer (M1, v2).
// SEALED SIM MODULE: pure Dart, no Flutter, no dart:io, no dart:math Random,
// no clocks.
//
// 1:1 port of legacy/defold/sim/combat.lua (the behavioral oracle — RNG
// consumption order copied line-by-line; combat stream only).
//
// Seam rules (docs/m1-contract.md §1 — LAW):
//   * encounter layer ONLY: never imports sim/run_layer.dart or
//     sim/map_gen.dart, never generates rewards/loot, never sets run-level
//     phases.
//   * on encounter end it pushes encounter_won/encounter_lost (plus
//     boss_defeated for the boss), sets sim.combatOver = 'won'|'lost',
//     and does NOT touch sim.phase — run.post performs phase transitions.
//   * public command handlers keep M0 signatures (sim, cmd, events):
//     [roll], [assign], [endTurn]. start_encounter is REMOVED from the
//     public set; the run layer starts fights via the internal seam [begin].
//
// `sim` is typed `dynamic`: `class Sim` (lib/sim/sim.dart) is owned by the
// run-worker and does not exist yet. This module codes against the exact
// field surface the Lua uses — sim.player / sim.enemy (Map<String,dynamic>),
// sim.phase (String), sim.turn (int), sim.combatOver (String?),
// sim.rng (Map<String, Rng>). Lua `sim.combat_over` maps to `sim.combatOver`
// and `sim.rng.combat` to `sim.rng['combat']` per the port contract.
//
// Fair-play pillars (docs/spec.md §Ethics):
//   * enemy intent is ALWAYS visible before the player commits
//   * the shown intent resolves EXACTLY as shown — never rerolled
//   * randomness decides what you roll, never how a stated action resolves

import '../data/dice.dart';
import '../data/enemies.dart';
import 'rng.dart';

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

void _invalid(List<Map<String, dynamic>> events, String reason) {
  events.add({'type': 'invalid_command', 'reason': reason});
}

/// Deep copy of plain data trees (data/*.dart entries are scalar-only trees).
/// Port of combat.lua `deep_copy` — also un-freezes the const data maps so
/// the live enemy is mutable without corrupting the data module.
dynamic _deepCopy(dynamic v) {
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) e.key as String: _deepCopy(e.value),
    };
  }
  if (v is List) {
    return <dynamic>[for (final x in v) _deepCopy(x)];
  }
  return v;
}

Map<String, dynamic> _dieDef(String id) {
  final def = diceData[id];
  if (def == null) {
    throw StateError('unknown die id: $id'); // Lua: assert(def ~= nil, ...)
  }
  return def;
}

/// Event for the currently shown intent. For attack_block the block amount
/// rides along as an additional scalar field (contract §4).
Map<String, dynamic> _intentEvent(Map<String, dynamic> enemy) {
  final intent = enemy['intent'] as Map<String, dynamic>;
  final ev = <String, dynamic>{
    'type': 'intent_shown',
    'enemy': enemy['id'],
    'kind': intent['kind'],
    'amount': intent['amount'],
  };
  if (intent['kind'] == 'attack_block') {
    ev['block'] = intent['block'];
  }
  return ev;
}

// ---------------------------------------------------------------------------
// internal seam — called by the run layer (sim/run_layer.dart), NOT a public
// command
// ---------------------------------------------------------------------------

/// Begin an encounter against [enemyId] (key into data/enemies.dart).
/// [elite] is a boolean carried onto the encounter_started event.
/// Port of combat.lua `combat.begin`.
void begin(dynamic sim, String enemyId, bool elite,
    List<Map<String, dynamic>> events) {
  final def = enemiesData[enemyId];
  if (def == null) {
    throw StateError('unknown enemy id: $enemyId'); // Lua: assert
  }
  final enemy = _deepCopy(def) as Map<String, dynamic>;
  enemy['max_hp'] = enemy['hp'];
  enemy['block'] = 0;
  enemy['pattern_index'] = 1; // 1-based, as in Lua (crosses sim boundary)
  enemy['intent'] = _deepCopy((enemy['pattern'] as List)[0]);
  sim.enemy = enemy;
  sim.combatOver = null;
  sim.phase = 'player_turn';
  sim.turn = 1;
  sim.player['block'] = 0;
  sim.player['rolled'] = null;
  sim.player['rolled_max'] = null;
  sim.player['assigned'] = <int, String>{};
  events.add({
    'type': 'encounter_started',
    'enemy': enemy['id'],
    'enemy_hp': enemy['hp'],
    'turn': sim.turn,
    'elite': elite, // Lua: elite and true or false
  });
  events.add(_intentEvent(enemy));
}

// ---------------------------------------------------------------------------
// shared end-of-encounter protocol (seam rule: flag + events, never phase)
// ---------------------------------------------------------------------------

void _encounterWon(dynamic sim, List<Map<String, dynamic>> events) {
  sim.combatOver = 'won';
  events.add({'type': 'encounter_won', 'turns': sim.turn});
  if (sim.enemy['boss'] == true) {
    events.add({'type': 'boss_defeated', 'turns': sim.turn});
  }
}

void _encounterLost(dynamic sim, List<Map<String, dynamic>> events) {
  sim.combatOver = 'lost';
  events.add({'type': 'encounter_lost', 'turns': sim.turn});
}

// ---------------------------------------------------------------------------
// public command handlers (M0 signatures preserved)
// ---------------------------------------------------------------------------

/// Port of combat.lua `combat.roll`.
void roll(dynamic sim, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> events) {
  if (sim.phase != 'player_turn' || sim.enemy == null) {
    return _invalid(events, 'not_player_turn');
  }
  if (sim.combatOver != null) {
    return _invalid(events, 'encounter_over');
  }
  if (sim.player['rolled'] != null) {
    return _invalid(events, 'already_rolled_this_turn');
  }
  final dice = sim.player['dice'] as List;
  final values = <int>[];
  final maxed = <bool>[];
  // RNG consumption order: one combat-stream die() per pool die, in pool
  // order — exactly combat.lua lines `for i = 1, #sim.player.dice do ...`.
  for (var i = 0; i < dice.length; i++) {
    final def = _dieDef(dice[i] as String);
    final size = def['size'] as int;
    var raw = (sim.rng['combat'] as Rng).die(size);
    maxed.add(raw == size);
    final minValue = (def['mods'] as Map)['min_value'] as int?;
    if (minValue != null && raw < minValue) raw = minValue;
    values.add(raw);
  }
  sim.player['rolled'] = values;
  // Additive internal field: which dice showed their max face this turn
  // (plain list of booleans — snapshot/serialization safe).
  sim.player['rolled_max'] = maxed;
  sim.player['assigned'] = <int, String>{};
  final ev = <String, dynamic>{'type': 'dice_rolled', 'count': values.length};
  for (var i = 0; i < values.length; i++) {
    ev['d${i + 1}'] = values[i]; // 1-based event fields (contract §2)
  }
  events.add(ev);
}

/// cmd: { type='assign', die=<1-based index>, action='attack'|'block' }
/// Port of combat.lua `combat.assign`.
void assign(dynamic sim, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> events) {
  if (sim.phase != 'player_turn' || sim.enemy == null) {
    return _invalid(events, 'not_player_turn');
  }
  if (sim.combatOver != null) {
    return _invalid(events, 'encounter_over');
  }
  final rolled = sim.player['rolled'] as List<int>?;
  if (rolled == null) {
    return _invalid(events, 'roll_first');
  }
  // Lua: `type(i) ~= "number" or not rolled[i]` — non-number or
  // out-of-range index rejects; indices stay 1-based across the boundary.
  final dynamic dieIdx = cmd['die'];
  if (dieIdx is! int || dieIdx < 1 || dieIdx > rolled.length) {
    return _invalid(events, 'no_such_die');
  }
  final i = dieIdx;
  final assigned = sim.player['assigned'] as Map<int, String>;
  if (assigned.containsKey(i)) {
    return _invalid(events, 'die_already_assigned');
  }
  final def = _dieDef((sim.player['dice'] as List)[i - 1] as String);
  final mods = def['mods'] as Map;
  final rolledMax = sim.player['rolled_max'] as List<bool>?;
  final bonus = (rolledMax != null && rolledMax[i - 1])
      ? (mods['on_max_bonus'] as int? ?? 0)
      : 0;

  if (cmd['action'] == 'attack') {
    if (mods['block_only'] == true) {
      return _invalid(events, 'die_is_block_only');
    }
    final value = rolled[i - 1] + (mods['attack_bonus'] as int? ?? 0) + bonus;
    assigned[i] = 'attack';
    // Enemy block (gained from its last block/attack_block intent) absorbs
    // player damage this turn; it resets at enemy turn start.
    var absorbed = value;
    final enemyBlock = sim.enemy['block'] as int;
    if (absorbed > enemyBlock) absorbed = enemyBlock;
    sim.enemy['block'] = enemyBlock - absorbed;
    sim.enemy['hp'] = (sim.enemy['hp'] as int) - (value - absorbed);
    events.add(
        {'type': 'die_assigned', 'die': i, 'action': 'attack', 'value': value});
    events.add({
      'type': 'damage_dealt',
      'target': sim.enemy['id'],
      'amount': value,
      'blocked': absorbed,
      'enemy_hp': sim.enemy['hp'],
    });
    if ((sim.enemy['hp'] as int) <= 0) {
      _encounterWon(sim, events);
    }
  } else if (cmd['action'] == 'block') {
    if (mods['attack_only'] == true) {
      return _invalid(events, 'die_is_attack_only');
    }
    final value = rolled[i - 1] + (mods['block_bonus'] as int? ?? 0) + bonus;
    assigned[i] = 'block';
    sim.player['block'] = (sim.player['block'] as int) + value;
    events.add(
        {'type': 'die_assigned', 'die': i, 'action': 'block', 'value': value});
    events.add({
      'type': 'block_gained',
      'amount': value,
      'total_block': sim.player['block'],
    });
  } else {
    return _invalid(events, 'unknown_action');
  }
}

/// Port of combat.lua `combat.end_turn`.
void endTurn(dynamic sim, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> events) {
  if (sim.phase != 'player_turn' || sim.enemy == null) {
    return _invalid(events, 'not_player_turn');
  }
  if (sim.combatOver != null) {
    return _invalid(events, 'encounter_over');
  }
  final enemy = sim.enemy as Map<String, dynamic>;
  // Enemy turn start: leftover enemy block from last turn expires.
  enemy['block'] = 0;
  // Enemy resolves its VISIBLE intent — exactly as it was shown. Never rerolled.
  final intent = enemy['intent'] as Map<String, dynamic>;
  final kind = intent['kind'] as String;
  if (kind == 'attack' || kind == 'attack_block') {
    final incoming = intent['amount'] as int;
    var blocked = incoming;
    final playerBlock = sim.player['block'] as int;
    if (blocked > playerBlock) blocked = playerBlock;
    final dmg = incoming - blocked;
    sim.player['hp'] = (sim.player['hp'] as int) - dmg;
    final ev = <String, dynamic>{
      'type': 'enemy_attacked',
      'amount': incoming,
      'blocked': blocked,
      'damage': dmg,
      'player_hp': sim.player['hp'],
    };
    if (kind == 'attack_block') {
      enemy['block'] = (enemy['block'] as int) + (intent['block'] as int);
      ev['block'] = intent['block'];
    }
    events.add(ev);
  } else if (kind == 'block') {
    enemy['block'] = (enemy['block'] as int) + (intent['amount'] as int);
    events.add({
      'type': 'enemy_blocked',
      'enemy': enemy['id'],
      'amount': intent['amount'],
      'enemy_block': enemy['block'],
    });
  }
  if ((sim.player['hp'] as int) <= 0) {
    _encounterLost(sim, events);
    return;
  }
  // Next turn: advance the pattern cycle deterministically (no RNG).
  sim.turn = (sim.turn as int) + 1;
  sim.player['block'] = 0;
  sim.player['rolled'] = null;
  sim.player['rolled_max'] = null;
  sim.player['assigned'] = <int, String>{};
  final pattern = enemy['pattern'] as List;
  // Lua: (pattern_index % #pattern) + 1 — stays 1-based.
  enemy['pattern_index'] =
      ((enemy['pattern_index'] as int) % pattern.length) + 1;
  enemy['intent'] =
      _deepCopy(pattern[(enemy['pattern_index'] as int) - 1]);
  events.add({'type': 'turn_started', 'turn': sim.turn});
  events.add(_intentEvent(enemy));
}
