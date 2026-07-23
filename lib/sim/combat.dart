// sim/combat.dart — Encounter layer.
// SEALED SIM MODULE: pure Dart, no Flutter imports, no dart:io, no Random.
//
// Seam rules (docs/m2-contract.md §1 — LAW):
//   * encounter layer ONLY: never imports run_layer.dart or map_gen.dart,
//     never generates rewards/loot, never sets run-level phases.
//   * on encounter end it pushes encounter_won/encounter_lost (plus
//     boss_defeated for the boss), sets sim.combatOver = "won"|"lost",
//     and does NOT touch sim.phase — runPost performs phase transitions.
//
// Fair-play pillars (docs/spec.md §Ethics):
//   * enemy intent is ALWAYS visible before the player commits
//   * the shown intent resolves EXACTLY as shown — never rerolled
//   * randomness decides what you roll, never how a stated action resolves

import '../data/dice.dart';
import '../data/enemies.dart';
import 'sim.dart';

void _push(List<Map<String, Object?>> events, Map<String, Object?> ev) =>
    events.add(ev);

void _invalid(List<Map<String, Object?>> events, String reason) =>
    _push(events, {'type': 'invalid_command', 'reason': reason});

// Event for the currently shown intent. For attack_block the block amount
// rides along as an additional scalar field.
Map<String, Object?> _intentEvent(Map<String, dynamic> enemy) {
  final intent = enemy['intent'] as Map;
  return {
    'type': 'intent_shown',
    'enemy': enemy['id'],
    'kind': intent['kind'],
    'amount': intent['amount'],
    if (intent['kind'] == 'attack_block') 'block': intent['block'],
  };
}

// ---------------------------------------------------------------------------
// internal seam — called by the run layer, NOT a public command
// ---------------------------------------------------------------------------

/// Begin an encounter against [enemyId]. `elite` is carried onto the
/// encounter_started event.
void combatBegin(
    Sim sim, String enemyId, bool elite, List<Map<String, Object?>> events) {
  final def = enemyDef(enemyId);
  final enemy = <String, dynamic>{
    'id': def.id,
    'name': def.name,
    'hp': def.hp,
    'max_hp': def.hp,
    'block': 0,
    'boss': def.boss,
    'elite': def.elite,
    'pattern': [for (final it in def.pattern) it.toMap()],
    'pattern_index': 1,
  };
  enemy['intent'] = Map<String, Object?>.from(enemy['pattern'][0] as Map);
  sim.enemy = enemy;
  sim.combatOver = null;
  sim.phase = 'player_turn';
  sim.turn = 1;
  sim.player['block'] = 0;
  sim.player['rolled'] = null;
  sim.player['rolled_max'] = null;
  sim.player['assigned'] = <String, String>{};
  _push(events, {
    'type': 'encounter_started',
    'enemy': enemy['id'],
    'enemy_hp': enemy['hp'],
    'turn': sim.turn,
    'elite': elite,
  });
  _push(events, _intentEvent(enemy));
}

// ---------------------------------------------------------------------------
// shared end-of-encounter protocol (seam rule: flag + events, never phase)
// ---------------------------------------------------------------------------

void _encounterWon(Sim sim, List<Map<String, Object?>> events) {
  sim.combatOver = 'won';
  _push(events, {'type': 'encounter_won', 'turns': sim.turn});
  if (sim.enemy!['boss'] == true) {
    _push(events, {'type': 'boss_defeated', 'turns': sim.turn});
  }
}

void _encounterLost(Sim sim, List<Map<String, Object?>> events) {
  sim.combatOver = 'lost';
  _push(events, {'type': 'encounter_lost', 'turns': sim.turn});
}

// ---------------------------------------------------------------------------
// public command handlers
// ---------------------------------------------------------------------------

void combatRoll(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'player_turn' || sim.enemy == null) {
    return _invalid(events, 'not_player_turn');
  }
  if (sim.combatOver != null) return _invalid(events, 'encounter_over');
  if (sim.player['rolled'] != null) {
    return _invalid(events, 'already_rolled_this_turn');
  }
  final poolIds = (sim.player['dice'] as List).cast<String>();
  final values = <int>[];
  final maxed = <bool>[];
  for (final id in poolIds) {
    final def = dieDef(id);
    var raw = sim.rng['combat']!.die(def.size);
    maxed.add(raw == def.size);
    final minValue = def.mods['min_value'] as int?;
    if (minValue != null && raw < minValue) raw = minValue;
    values.add(raw);
  }
  sim.player['rolled'] = values;
  sim.player['rolled_max'] = maxed;
  sim.player['assigned'] = <String, String>{};
  final ev = <String, Object?>{'type': 'dice_rolled', 'count': values.length};
  for (var i = 0; i < values.length; i++) {
    ev['d${i + 1}'] = values[i];
  }
  _push(events, ev);
}

/// cmd: { type:"assign", die:<1-based index>, action:"attack"|"block" }
void combatAssign(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'player_turn' || sim.enemy == null) {
    return _invalid(events, 'not_player_turn');
  }
  if (sim.combatOver != null) return _invalid(events, 'encounter_over');
  final rolled = (sim.player['rolled'] as List?)?.cast<int>();
  if (rolled == null) return _invalid(events, 'roll_first');
  final die = cmd['die'];
  if (die is! int || die < 1 || die > rolled.length) {
    return _invalid(events, 'no_such_die');
  }
  final assigned = sim.player['assigned'] as Map;
  if (assigned['$die'] != null) return _invalid(events, 'die_already_assigned');
  final def = dieDef((sim.player['dice'] as List)[die - 1] as String);
  final mods = def.mods;
  final rolledMax = (sim.player['rolled_max'] as List?)?.cast<bool>();
  final bonus = (rolledMax != null && rolledMax[die - 1])
      ? (mods['on_max_bonus'] as int? ?? 0)
      : 0;
  final enemy = sim.enemy!;
  final action = cmd['action'];

  if (action == 'attack') {
    if (mods['block_only'] == true) {
      return _invalid(events, 'die_is_block_only');
    }
    final value = rolled[die - 1] + (mods['attack_bonus'] as int? ?? 0) + bonus;
    assigned['$die'] = 'attack';
    // Enemy block absorbs player damage this turn; resets at enemy turn start.
    var absorbed = value;
    final enemyBlock = enemy['block'] as int;
    if (absorbed > enemyBlock) absorbed = enemyBlock;
    enemy['block'] = enemyBlock - absorbed;
    enemy['hp'] = (enemy['hp'] as int) - (value - absorbed);
    _push(events,
        {'type': 'die_assigned', 'die': die, 'action': 'attack', 'value': value});
    _push(events, {
      'type': 'damage_dealt',
      'target': enemy['id'],
      'amount': value,
      'blocked': absorbed,
      'enemy_hp': enemy['hp'],
    });
    if ((enemy['hp'] as int) <= 0) _encounterWon(sim, events);
  } else if (action == 'block') {
    if (mods['attack_only'] == true) {
      return _invalid(events, 'die_is_attack_only');
    }
    final value = rolled[die - 1] + (mods['block_bonus'] as int? ?? 0) + bonus;
    assigned['$die'] = 'block';
    sim.player['block'] = (sim.player['block'] as int) + value;
    _push(events,
        {'type': 'die_assigned', 'die': die, 'action': 'block', 'value': value});
    _push(events, {
      'type': 'block_gained',
      'amount': value,
      'total_block': sim.player['block'],
    });
  } else {
    return _invalid(events, 'unknown_action');
  }
}

void combatEndTurn(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'player_turn' || sim.enemy == null) {
    return _invalid(events, 'not_player_turn');
  }
  if (sim.combatOver != null) return _invalid(events, 'encounter_over');
  final enemy = sim.enemy!;
  // Enemy turn start: leftover enemy block from last turn expires.
  enemy['block'] = 0;
  // Enemy resolves its VISIBLE intent — exactly as shown. Never rerolled.
  final intent = enemy['intent'] as Map;
  final kind = intent['kind'];
  if (kind == 'attack' || kind == 'attack_block') {
    final incoming = intent['amount'] as int;
    var blocked = incoming;
    final playerBlock = sim.player['block'] as int;
    if (blocked > playerBlock) blocked = playerBlock;
    final dmg = incoming - blocked;
    sim.player['hp'] = (sim.player['hp'] as int) - dmg;
    final ev = <String, Object?>{
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
    _push(events, ev);
  } else if (kind == 'block') {
    enemy['block'] = (enemy['block'] as int) + (intent['amount'] as int);
    _push(events, {
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
  sim.turn += 1;
  sim.player['block'] = 0;
  sim.player['rolled'] = null;
  sim.player['rolled_max'] = null;
  sim.player['assigned'] = <String, String>{};
  final pattern = enemy['pattern'] as List;
  enemy['pattern_index'] = ((enemy['pattern_index'] as int) % pattern.length) + 1;
  enemy['intent'] =
      Map<String, Object?>.from(pattern[(enemy['pattern_index'] as int) - 1] as Map);
  _push(events, {'type': 'turn_started', 'turn': sim.turn});
  _push(events, _intentEvent(enemy));
}
