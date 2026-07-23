// sim/autoplay.dart — deterministic greedy policy bot + run driver.
// SEALED-adjacent: pure Dart, drives ONLY the public v3 command set. Shared by
// bin/autoplay.dart (stats) and test/autoplay_test.dart (gates).

import '../data/boons.dart';
import '../data/dice.dart';
import '../data/events.dart';
import 'sim.dart';

/// A pure function of sim.state() -> next command (or null at terminal). The
/// bot spends gold in shops, forges duplicates upward at rests, takes value
/// events, and plays fights greedily (block vs the shown intent, else attack).
/// v4: it also takes a starting boon, risky-rerolls dead dice (1s), and hunts
/// exact kills when attacking (docs/m4-sim-contract.md).
Map<String, Object?>? botCmd(Sim sim,
    {String? character, int ascension = 0, bool boons = true}) {
  final phase = sim.phase;
  switch (phase) {
    case 'idle':
      return {
        'type': 'start_run',
        if (character != null) 'character': character,
        'ascension': ascension,
        if (boons) 'boons': true,
      };
    case 'boon':
      // Prefer a die boon (permanent pool value), else take the first.
      final picks = sim.boons!;
      for (var i = 0; i < picks.length; i++) {
        if (boonDef(picks[i]).effects.containsKey('gain_die')) {
          return {'type': 'choose_boon', 'index': i + 1};
        }
      }
      return {'type': 'choose_boon', 'index': 1};
    case 'map':
      final map = sim.map!;
      final position = map['position'] as int;
      final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
      final hp = sim.player['hp'] as int, maxHp = sim.player['max_hp'] as int;
      final wantRest = hp * 2 < maxHp;
      // Priority: rest if hurt, else shop, else event, else fight, else first.
      int? pick;
      int rank(String kind) {
        if (wantRest && kind == 'rest') return 0;
        if (kind == 'shop') return 1;
        if (kind == 'event') return 2;
        if (kind == 'fight' || kind == 'elite' || kind == 'boss') return 3;
        return 4; // rest when not hurt (skip if possible)
      }
      var best = 99;
      for (final e in edges) {
        final kind = (map['nodes'] as Map)['$e']!['kind'] as String;
        final r = rank(kind);
        if (r < best) {
          best = r;
          pick = e;
        }
      }
      return {'type': 'choose_node', 'node': pick ?? edges[0]};
    case 'player_turn':
      final rolled = (sim.player['rolled'] as List?)?.cast<int>();
      if (rolled == null) return {'type': 'roll'};
      final assigned = sim.player['assigned'] as Map;
      // Risky reroll (once per turn): before assigning anything, reroll dead
      // dice. A rolled 1 is +EV to reroll even with the -1-pip cost; with a
      // free reroll (straight earned) widen the net to 1s and 2s.
      if (sim.player['risky_used'] != true && assigned.isEmpty) {
        final free = sim.player['free_reroll'] == true;
        final threshold = free ? 2 : 1;
        final picks = <int>[
          for (var i = 1; i <= rolled.length; i++)
            if (rolled[i - 1] <= threshold) i
        ];
        if (picks.isNotEmpty) return {'type': 'reroll_risky', 'dice': picks};
      }
      final combo = (sim.player['combo_bonus'] as List?)?.cast<int>();
      int attackValue(int i) {
        final mods =
            dieDef((sim.player['dice'] as List)[i - 1] as String).mods;
        return rolled[i - 1] +
            (mods['attack_bonus'] as int? ?? 0) +
            (combo != null ? combo[i - 1] : 0);
      }
      // Exact-kill hunt: if some unassigned attack-capable die kills the
      // enemy at exactly 0 hp (through block), assign it first.
      final enemy = sim.enemy!;
      final lethal = (enemy['hp'] as int) + (enemy['block'] as int);
      for (var i = 1; i <= rolled.length; i++) {
        if (assigned['$i'] != null) continue;
        final mods =
            dieDef((sim.player['dice'] as List)[i - 1] as String).mods;
        if (mods['block_only'] == true) continue;
        if (attackValue(i) == lethal) {
          return {'type': 'assign', 'die': i, 'action': 'attack'};
        }
      }
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
    case 'reward':
      // Take the largest-size offer (greedy pool upgrade); index 1..n.
      final offers = sim.offers!;
      var bestIdx = 1, bestSize = -1;
      for (var i = 0; i < offers.length; i++) {
        final size = dieDef(offers[i]).size;
        if (size > bestSize) {
          bestSize = size;
          bestIdx = i + 1;
        }
      }
      return {'type': 'choose_reward', 'index': bestIdx};
    case 'rest':
      // Forge the first forgeable duplicate-ish die if cheap value, else heal.
      final hp = sim.player['hp'] as int, maxHp = sim.player['max_hp'] as int;
      if (hp * 4 >= maxHp * 3) {
        // healthy enough: forge the first die that can upgrade
        final pool = (sim.player['dice'] as List).cast<String>();
        for (var i = 0; i < pool.length; i++) {
          final ft = dieDef(pool[i]).forgeTo;
          if (ft.isNotEmpty) {
            return {'type': 'forge', 'die': i + 1, 'into': ft.first};
          }
        }
      }
      return {'type': 'rest'};
    case 'shop':
      final slots = (sim.shop!['slots'] as List);
      final gold = sim.run!['gold'] as int;
      // Buy the most expensive affordable non-heal slot (value-greedy).
      var buyIdx = -1, buyPrice = -1;
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i] as Map;
        if (s['sold'] == true) continue;
        final p = s['price'] as int;
        if (p <= gold && s['kind'] != 'heal' && p > buyPrice) {
          buyPrice = p;
          buyIdx = i + 1;
        }
      }
      if (buyIdx > 0) return {'type': 'buy', 'slot': buyIdx};
      return {'type': 'leave_shop'};
    case 'event':
      // Pick the first LEGAL option (affordable gold, legal die-loss) so the
      // bot never stalls on an invalid choice. Options are authored safest-last
      // often, but the first legal one is always guaranteed valid.
      final def = eventDef(sim.event!);
      final gold = sim.run!['gold'] as int;
      final poolSize = (sim.player['dice'] as List).length;
      for (var i = 0; i < def.options.length; i++) {
        final e = def.options[i].effects;
        final cost = (e['gold'] as int?) ?? 0;
        if (cost < 0 && gold + cost < 0) continue;
        if (e['lose_random_die'] == 1 && poolSize <= 3) continue;
        return {'type': 'event_choose', 'option': i + 1};
      }
      return {'type': 'event_choose', 'option': def.options.length};
  }
  return null; // terminal
}

class RunResult {
  final Sim sim;
  final int applied;
  final int invalids;
  RunResult(this.sim, this.applied, this.invalids);
}

RunResult playRun(int seed,
    {String? character,
    int ascension = 0,
    bool boons = true,
    int? snapAt,
    int maxCmds = 4000}) {
  var sim = Sim(seed);
  var applied = 0, invalids = 0;
  while (applied < maxCmds) {
    final cmd =
        botCmd(sim, character: character, ascension: ascension, boons: boons);
    if (cmd == null) break;
    final evs = sim.apply(cmd);
    applied += 1;
    for (final e in evs) {
      if (e['type'] == 'invalid_command') invalids += 1;
    }
    if (snapAt != null && applied == snapAt) {
      sim = Sim.restore(sim.snapshot());
    }
  }
  return RunResult(sim, applied, invalids);
}
