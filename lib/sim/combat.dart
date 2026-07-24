// sim/combat.dart — Encounter layer (v3).
// SEALED SIM MODULE: pure Dart, no Flutter imports, no dart:io, no Random.
//
// Seam rules (docs/m3-contract.md §1 — LAW):
//   * encounter layer ONLY: never imports run_layer.dart or map_gen.dart,
//     never generates rewards/reward offers, never sets run-level phases.
//   * on encounter end it sets sim.combatOver = "won"|"lost" and pushes
//     events; runPost performs the phase transition.
//   * Relic hooks (data/relics.dart) are read via relic_hooks.dart. The one
//     deliberate exception to "combat never touches run": on_max_gold credits
//     run['gold'] during a roll (incidental economy, not a phase/reward
//     transition) — documented here and in the contract.
//
// Fair-play pillars (docs/spec.md §Ethics):
//   * enemy intent is ALWAYS visible before the player commits
//   * the shown intent resolves EXACTLY as shown — never rerolled by the game
//   * randomness decides what you roll, never how a stated action resolves

import '../data/dice.dart';
import '../data/enemies.dart';
import 'combos.dart';
import 'relic_hooks.dart';
import 'sim.dart';

// Exact-kill / overkill tuning (docs/m4-sim-contract.md §4).
const int exactKillEmbers = 5; // ember bonus for a kill at exactly 0 hp
const int overkillSplashCap = 5; // surplus damage carried to the next enemy

void _push(List<Map<String, Object?>> events, Map<String, Object?> ev) =>
    events.add(ev);

void _invalid(List<Map<String, Object?>> events, String reason) =>
    _push(events, {'type': 'invalid_command', 'reason': reason});

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

bool _isTough(Map<String, dynamic> enemy) =>
    enemy['elite'] == true || enemy['boss'] == true;

// Apply the per-turn-start relic block (turn_block). Called for turn 1 in
// combatBegin and for every subsequent turn in end_turn.
void _applyTurnBlock(Sim sim, List<Map<String, Object?>> events) {
  final tb = relicSum(sim, 'turn_block');
  if (tb > 0) {
    sim.player['block'] = (sim.player['block'] as int) + tb;
    _push(events, {
      'type': 'block_gained',
      'amount': tb,
      'total_block': sim.player['block'],
      'source': 'relic',
    });
  }
}

// ---------------------------------------------------------------------------
// internal seam — called by the run layer, NOT a public command
// ---------------------------------------------------------------------------

/// Early-mercy stat shave for REGULAR fights on layer 2 — the first combat
/// row (v0.3.1 F7): the shared roster stays intact, but node-one fights stop
/// being a coin-flip against a fresh 30 HP / 3xd6 delver. Deterministic,
/// pre-ascension, regulars only (elites/boss are opt-in risk).
/// Tuned by measurement (bin/autoplay.dart, 200 seeds): baseline bot winrate
/// 53.5% with ~44% of ALL bot losses on the first fight; shave 2 + HP cap 28
/// on layer 2 only => 74.0% bot winrate (band 20-80), layers 3+ untouched.
/// Stronger variants (shave 3-4, cap 26, layer-3 shave) hit 79-82% — too
/// soft overall. Revisit with human telemetry before v0.4.0.
int earlyMercyAttackShave(int layer) => layer <= 2 ? 2 : 0;
int earlyMercyHpCap(int layer) => layer <= 2 ? 28 : 1 << 30;

/// Hard-mode layer ramp (v0.3.3): +1 early, +2 mid, +3 late/boss.
int hardAttackBonus(int layer) => layer <= 3 ? 1 : (layer <= 6 ? 2 : 3);

/// Hard-mode enemy HP scalar by layer: x1.10 early, x1.25 mid, x1.40 late.
double hardHpScalar(int layer) => layer <= 3 ? 1.10 : (layer <= 6 ? 1.25 : 1.40);

void combatBegin(
    Sim sim, String enemyId, bool elite, List<Map<String, Object?>> events,
    {int layer = 99}) {
  final def = enemyDef(enemyId);
  final ascAmount = (sim.run?['ascension'] as int? ?? 0);
  // Difficulty (v0.3.2): deterministic flat/scalar adjustments, no RNG, so
  // determinism and replays are untouched. 'normal' is byte-identical to the
  // pre-difficulty sim (golden anchor). Tuned by measurement (bin/autoplay):
  // easy = enemy HP x0.8 and attacks -2 (min 1), flat.
  //
  // Hard (v0.3.3) is a LAYER-SCALED RAMP, not a flat wall: the original flat
  // +2 / HP x1.25 put 68% of all hard losses on the very first fight (bot
  // histogram, 200 seeds) — a bouncer, not a climb. The ramp keeps hard's
  // late-run bite while letting a fresh pool get through the door:
  //   layers 2-3: +1, HP x1.10   ·   layers 4-6: +2, HP x1.25
  //   layers 7+ and the boss:    +3, HP x1.40
  // (The boss call site passes no layer, so it lands in the 7+ bracket by
  // the `layer = 99` default — intentional.) Deterministic pure function of
  // (difficulty, layer); normal and easy paths are untouched.
  final difficulty = sim.run?['difficulty'] as String? ?? 'normal';
  final diffAmount = difficulty == 'easy'
      ? -2
      : difficulty == 'hard'
          ? hardAttackBonus(layer)
          : 0;
  final mercy = (!elite && !def.boss) ? earlyMercyAttackShave(layer) : 0;
  final hpCap = (!elite && !def.boss) ? earlyMercyHpCap(layer) : (1 << 30);
  var hp = def.hp > hpCap ? hpCap : def.hp;
  if (difficulty == 'easy') hp = (hp * 0.8).round();
  if (difficulty == 'hard') hp = (hp * hardHpScalar(layer)).round();
  if (hp < 1) hp = 1;
  int shaved(int amount) {
    final v = amount - mercy;
    return v < 1 ? 1 : v;
  }

  // Ascension raises enemy attack/block amounts by a fixed integer per rung
  // (deterministic, no RNG). Applied here so the sim stays pure. The early
  // mercy shave applies to the base amount, before the ascension bonus.
  // The difficulty delta stacks the same way and clamps at 1 so easy mode
  // never zeroes an intent (the shown intent still resolves exactly as shown).
  int adjusted(int base) {
    final v = shaved(base) + (base > 0 ? ascAmount + diffAmount : 0);
    return v < 1 ? 1 : v;
  }

  final pattern = [
    for (final it in def.pattern)
      {
        'kind': it.kind,
        'amount': adjusted(it.amount),
        if (it.kind == 'attack_block')
          'block': (it.block + ascAmount + diffAmount) < 0
              ? 0
              : it.block + ascAmount + diffAmount,
      }
  ];
  final enemy = <String, dynamic>{
    'id': def.id,
    'name': def.name,
    'hp': hp,
    'max_hp': hp,
    'block': 0,
    'boss': def.boss,
    'elite': def.elite,
    'pattern': pattern,
    'pattern_index': 1,
  };
  enemy['intent'] = Map<String, Object?>.from(pattern[0]);
  sim.enemy = enemy;
  sim.combatOver = null;
  sim.phase = 'player_turn';
  sim.turn = 1;
  sim.player['block'] = 0;
  sim.player['rolled'] = null;
  sim.player['rolled_max'] = null;
  sim.player['assigned'] = <String, String>{};
  sim.player['rerolls_left'] = relicSum(sim, 'rerolls');
  sim.player['combo_bonus'] = null;
  sim.player['risky_used'] = false;
  sim.player['free_reroll'] = false;
  sim.player['free_reroll_next'] = false;
  sim.player['ignited'] = false;
  enemy['burn'] = 0;
  _push(events, {
    'type': 'encounter_started',
    'enemy': enemy['id'],
    'enemy_hp': enemy['hp'],
    'turn': sim.turn,
    'elite': elite,
  });
  _applyTurnBlock(sim, events);
  // Overkill splash carried over from the previous encounter (m4 §4).
  final splash = sim.run?['pending_splash'] as int? ?? 0;
  if (splash > 0) {
    sim.run!['pending_splash'] = 0;
    var dmg = splash;
    final hp = enemy['hp'] as int;
    if (dmg >= hp) dmg = hp - 1; // splash softens, never pre-kills
    if (dmg > 0) {
      enemy['hp'] = hp - dmg;
      _push(events, {
        'type': 'splash_damage',
        'amount': dmg,
        'enemy_hp': enemy['hp'],
      });
    }
  }
  _push(events, _intentEvent(enemy));
}

// ---------------------------------------------------------------------------
// combos (m4 §3) — pure function of the rolled pool; NO RNG consumed here
// ---------------------------------------------------------------------------

// Detect combos over the current rolled values and (re)apply their effects.
// Pair bonuses are recomputed in full; ignite fires at most once per turn.
void _detectAndApplyCombos(Sim sim, List<Map<String, Object?>> events) {
  final rolled = (sim.player['rolled'] as List).cast<int>();
  final combos = detectCombos(rolled);
  sim.player['combo_bonus'] = combos.bonus;
  for (final pair in combos.pairs) {
    _push(events, {
      'type': 'combo_pair',
      'value': pair.value,
      'd1': pair.dice[0],
      'd2': pair.dice[1],
      'bonus': pairBonusPerDie * 2,
    });
  }
  for (final triple in combos.triples) {
    _push(events, {
      'type': 'combo_triple',
      'value': triple.value,
      'count': triple.dice.length,
    });
  }
  if (combos.hasTriple && sim.player['ignited'] != true) {
    sim.player['ignited'] = true;
    final enemy = sim.enemy!;
    enemy['burn'] = (enemy['burn'] as int? ?? 0) + igniteBurnStacks;
    _push(events, {
      'type': 'burn_applied',
      'stacks': igniteBurnStacks,
      'total_burn': enemy['burn'],
      'target': enemy['id'],
    });
  }
  if (combos.hasStraight) {
    final st = combos.straight!;
    _push(events, {
      'type': 'combo_straight',
      'low': st.low,
      'high': st.high,
      'length': st.length,
    });
    if (sim.player['free_reroll_next'] != true) {
      sim.player['free_reroll_next'] = true;
      _push(events, {'type': 'free_reroll_earned'});
    }
  }
}

// ---------------------------------------------------------------------------
// shared end-of-encounter protocol
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

// Roll one die id, applying its own min_value and the relic min_roll floor,
// and (for on_max_gold) crediting gold when the natural face is the max.
int _rollOne(Sim sim, String id, List<bool> maxedOut,
    List<Map<String, Object?>> events) {
  final def = dieDef(id);
  final raw = sim.rng['combat']!.die(def.size);
  final isMax = raw == def.size;
  maxedOut.add(isMax);
  if (isMax) {
    final g = relicSum(sim, 'on_max_gold');
    if (g > 0 && sim.run != null) {
      sim.run!['gold'] = (sim.run!['gold'] as int) + g;
      _push(events, {
        'type': 'gold_gained',
        'amount': g,
        'total': sim.run!['gold'],
        'source': 'relic',
      });
    }
  }
  var v = raw;
  final minValue = def.mods['min_value'] as int?;
  if (minValue != null && v < minValue) v = minValue;
  final minRoll = relicSum(sim, 'min_roll');
  if (minRoll > 0 && v < minRoll) v = minRoll;
  return v;
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
    values.add(_rollOne(sim, id, maxed, events));
  }
  sim.player['rolled'] = values;
  sim.player['rolled_max'] = maxed;
  sim.player['assigned'] = <String, String>{};
  final ev = <String, Object?>{'type': 'dice_rolled', 'count': values.length};
  for (var i = 0; i < values.length; i++) {
    ev['d${i + 1}'] = values[i];
  }
  _push(events, ev);
  _detectAndApplyCombos(sim, events);
}

/// cmd: { type:"reroll_risky", dice:[<1-based index>...] } — reroll any
/// non-empty subset of unassigned dice, at most ONCE per turn. Cost: every
/// rerolled die lands at its new face MINUS 1 pip (floor 1) — unless this
/// turn's reroll is free (earned by a straight last turn). Consumes the
/// seeded combat stream, one draw per die in ascending die order, so replays
/// stay deterministic given the same commands. (docs/m4-sim-contract.md §2)
void combatRerollRisky(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'player_turn' || sim.enemy == null) {
    return _invalid(events, 'not_player_turn');
  }
  if (sim.combatOver != null) return _invalid(events, 'encounter_over');
  final rolled = (sim.player['rolled'] as List?)?.cast<int>();
  if (rolled == null) return _invalid(events, 'roll_first');
  if (sim.player['risky_used'] == true) {
    return _invalid(events, 'risky_reroll_used');
  }
  final raw = cmd['dice'];
  if (raw is! List || raw.isEmpty) return _invalid(events, 'no_dice_chosen');
  final picks = <int>[];
  for (final d in raw) {
    if (d is! int || d < 1 || d > rolled.length) {
      return _invalid(events, 'no_such_die');
    }
    if (picks.contains(d)) return _invalid(events, 'duplicate_die');
    if ((sim.player['assigned'] as Map)['$d'] != null) {
      return _invalid(events, 'die_already_assigned');
    }
    picks.add(d);
  }
  picks.sort(); // ascending order = deterministic stream consumption
  final free = sim.player['free_reroll'] == true;
  final penalty = free ? 0 : 1;
  final maxed = (sim.player['rolled_max'] as List).cast<bool>();
  final ev = <String, Object?>{
    'type': 'risky_reroll',
    'count': picks.length,
    'free': free,
    'penalty': penalty,
  };
  for (var k = 0; k < picks.length; k++) {
    final die = picks[k];
    final tmp = <bool>[];
    var v = _rollOne(
        sim, (sim.player['dice'] as List)[die - 1] as String, tmp, events);
    v -= penalty;
    if (v < 1) v = 1;
    rolled[die - 1] = v;
    maxed[die - 1] = tmp.first && penalty == 0;
    ev['r${k + 1}'] = die;
    ev['v${k + 1}'] = v;
  }
  sim.player['risky_used'] = true;
  sim.player['free_reroll'] = false;
  _push(events, ev);
  _detectAndApplyCombos(sim, events);
}

/// cmd: { type:"reroll", die:<1-based index> } — costs one reroll charge.
void combatReroll(Sim sim, Map cmd, List<Map<String, Object?>> events) {
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
  if ((sim.player['assigned'] as Map)['$die'] != null) {
    return _invalid(events, 'die_already_assigned');
  }
  final left = sim.player['rerolls_left'] as int? ?? 0;
  if (left <= 0) return _invalid(events, 'no_rerolls_left');
  final maxed = (sim.player['rolled_max'] as List).cast<bool>();
  final tmp = <bool>[];
  final newVal = _rollOne(sim, (sim.player['dice'] as List)[die - 1] as String,
      tmp, events);
  rolled[die - 1] = newVal;
  maxed[die - 1] = tmp.first;
  sim.player['rerolls_left'] = left - 1;
  _push(events, {
    'type': 'reroll_used',
    'die': die,
    'value': newVal,
    'left': sim.player['rerolls_left'],
  });
  // Combos are a pure function of the CURRENT pool (m4 §3) — re-detect after
  // a charge reroll too, or `combo_bonus` goes stale: a broken pair kept
  // paying +1 on both dice and a newly rolled pair/triple/straight paid
  // nothing. The once-per-turn guards (`ignited`, `free_reroll_next`) make
  // re-detection safe, exactly as on the risky-reroll path.
  _detectAndApplyCombos(sim, events);
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
    if (mods['block_only'] == true) return _invalid(events, 'die_is_block_only');
    final combo = (sim.player['combo_bonus'] as List?)?.cast<int>();
    var value = rolled[die - 1] +
        (mods['attack_bonus'] as int? ?? 0) +
        bonus +
        (combo != null ? combo[die - 1] : 0) +
        relicSum(sim, 'attack_flat');
    if (_isTough(enemy)) value += relicSum(sim, 'elite_damage');
    assigned['$die'] = 'attack';
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
    final hpAfter = enemy['hp'] as int;
    if (hpAfter <= 0) {
      if (hpAfter == 0) {
        // Exact kill: small ember bonus (m4 §4). Pure arithmetic, no RNG.
        if (sim.run != null) {
          sim.run!['embers'] = (sim.run!['embers'] as int) + exactKillEmbers;
          _push(events, {
            'type': 'exact_kill',
            'embers': exactKillEmbers,
            'total': sim.run!['embers'],
          });
        }
      } else {
        // Overkill: surplus (capped) splashes into the next encounter's
        // enemy — encounters are single-enemy, so "next living enemy" is
        // the next one you meet (m4 §4).
        var surplus = -hpAfter;
        if (surplus > overkillSplashCap) surplus = overkillSplashCap;
        if (sim.run != null) {
          sim.run!['pending_splash'] =
              (sim.run!['pending_splash'] as int? ?? 0) + surplus;
          _push(events, {'type': 'overkill', 'surplus': surplus});
        }
      }
      _encounterWon(sim, events);
    }
  } else if (action == 'block') {
    if (mods['attack_only'] == true) {
      return _invalid(events, 'die_is_attack_only');
    }
    final combo = (sim.player['combo_bonus'] as List?)?.cast<int>();
    final value = rolled[die - 1] +
        (mods['block_bonus'] as int? ?? 0) +
        bonus +
        (combo != null ? combo[die - 1] : 0) +
        relicSum(sim, 'block_flat');
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
  enemy['block'] = 0;
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
    // Player death resolves BEFORE thorns and burn (v0.3.2 zombie-win fix):
    // the shown intent lands first, so a delver dropped to 0 by it is dead
    // before their passive effects tick. Previously a thorns/burn kill on
    // this same tick hit _encounterWon first and the run continued with the
    // player at negative HP.
    if ((sim.player['hp'] as int) <= 0) {
      _encounterLost(sim, events);
      return;
    }
    // Thorns: attackers take damage after resolving an attack intent.
    final thorns = relicSum(sim, 'thorns');
    if (thorns > 0) {
      enemy['hp'] = (enemy['hp'] as int) - thorns;
      _push(events, {
        'type': 'thorns_dealt',
        'amount': thorns,
        'enemy_hp': enemy['hp'],
      });
      if ((enemy['hp'] as int) <= 0) {
        _encounterWon(sim, events);
        return;
      }
    }
  } else if (kind == 'block') {
    enemy['block'] = (enemy['block'] as int) + (intent['amount'] as int);
    _push(events, {
      'type': 'enemy_blocked',
      'enemy': enemy['id'],
      'amount': intent['amount'],
      'enemy_block': enemy['block'],
    });
  }
  // Burn DoT (triple ignite) ticks at end of the enemy's action: damage =
  // current stacks, then stacks decay by 1. Deterministic, no RNG.
  final burn = enemy['burn'] as int? ?? 0;
  if (burn > 0) {
    enemy['hp'] = (enemy['hp'] as int) - burn;
    enemy['burn'] = burn - 1;
    _push(events, {
      'type': 'burn_tick',
      'amount': burn,
      'stacks_left': enemy['burn'],
      'enemy_hp': enemy['hp'],
    });
    if ((enemy['hp'] as int) <= 0) {
      _encounterWon(sim, events);
      return;
    }
  }
  if ((sim.player['hp'] as int) <= 0) {
    _encounterLost(sim, events);
    return;
  }
  sim.turn += 1;
  sim.player['block'] = 0;
  sim.player['rolled'] = null;
  sim.player['rolled_max'] = null;
  sim.player['assigned'] = <String, String>{};
  sim.player['combo_bonus'] = null;
  sim.player['risky_used'] = false;
  sim.player['ignited'] = false;
  sim.player['free_reroll'] = sim.player['free_reroll_next'] == true;
  sim.player['free_reroll_next'] = false;
  final pattern = enemy['pattern'] as List;
  enemy['pattern_index'] = ((enemy['pattern_index'] as int) % pattern.length) + 1;
  enemy['intent'] =
      Map<String, Object?>.from(pattern[(enemy['pattern_index'] as int) - 1] as Map);
  _push(events, {'type': 'turn_started', 'turn': sim.turn});
  if (sim.player['free_reroll'] == true) {
    _push(events, {'type': 'free_reroll_granted'});
  }
  _applyTurnBlock(sim, events);
  _push(events, _intentEvent(enemy));
}
