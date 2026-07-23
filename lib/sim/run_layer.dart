// sim/run_layer.dart — Run layer (v3): map position, node entry, rewards,
// rest+forge, shop, events, gold, relics, and the run win/loss ledger with
// the fair-death insight payout.
// SEALED SIM MODULE: pure Dart, no Flutter imports, no dart:io, no Random.
//
// Seam rules (docs/m3-contract.md §1 — LAW): combat.dart sets sim.combatOver;
// after EVERY dispatched command sim.dart calls runPost, which performs all
// run-level transitions. New sub-systems (shop, event, forge) live here.
//
// RNG discipline:
//   map     -> map generation only
//   combat  -> dice rolls + enemy spawn pick
//   loot    -> ember/gold amounts, reward + shop + event + insight picks
//   shuffle -> event deck order + random die/relic grants inside events
//   offer   -> map reward telegraphs (per-node offers precomputed at start_run)
//   boon    -> starting-boon 1-of-3 offering (start_run {boons:true})

import '../data/boons.dart';
import '../data/characters.dart';
import '../data/dice.dart';
import '../data/enemies.dart';
import '../data/events.dart';
import '../data/insights.dart';
import '../data/relics.dart';
import 'combat.dart';
import 'map_gen.dart';
import 'relic_hooks.dart';
import 'sim.dart';

void _push(List<Map<String, Object?>> events, Map<String, Object?> ev) =>
    events.add(ev);

void _invalid(List<Map<String, Object?>> events, String reason) =>
    _push(events, {'type': 'invalid_command', 'reason': reason});

// Enemy pools built deterministically from enemiesOrder, filtered by fromLayer
// at spawn time.
List<String> _regularsFor(int layer) => [
      for (final id in enemiesOrder)
        if (!enemies[id]!.boss &&
            !enemies[id]!.elite &&
            enemies[id]!.fromLayer <= layer)
          id
    ];
List<String> _elitesFor(int layer) => [
      for (final id in enemiesOrder)
        if (enemies[id]!.elite && enemies[id]!.fromLayer <= layer) id
    ];
final String _boss = enemiesOrder.firstWhere((id) => enemies[id]!.boss);

int _rollEmbers(Sim sim) => sim.rng['loot']!.range(8, 20);
int _rollGold(Sim sim) => sim.rng['loot']!.range(12, 22);

// Tier ceiling for reward/shop dice by map layer (keeps the early curve gentle).
int _tierCeiling(int layer) => layer <= 3 ? 1 : (layer <= 6 ? 2 : 3);

// Heal the player by `amount`, capped at max hp. Returns the actual heal.
int _heal(Sim sim, int amount) {
  final p = sim.player;
  final hp = p['hp'] as int, maxHp = p['max_hp'] as int;
  var h = amount;
  if (hp + h > maxHp) h = maxHp - hp;
  if (h < 0) h = 0;
  p['hp'] = hp + h;
  return h;
}

// Add a relic to the run; apply its one-time max_hp hook on pickup.
void _grantRelic(Sim sim, String id, List<Map<String, Object?>> events) {
  final relics0 = sim.run!['relics'] as List;
  if (relics0.contains(id)) return;
  relics0.add(id);
  final mh = relics[id]!.hooks['max_hp'] ?? 0;
  if (mh > 0) {
    sim.player['max_hp'] = (sim.player['max_hp'] as int) + mh;
    sim.player['hp'] = (sim.player['hp'] as int) + mh;
  }
  _push(events, {'type': 'relic_gained', 'relic': id});
}

void _gainGold(Sim sim, int amount, List<Map<String, Object?>> events,
    [String? source]) {
  sim.run!['gold'] = (sim.run!['gold'] as int) + amount;
  _push(events, {
    'type': 'gold_gained',
    'amount': amount,
    'total': sim.run!['gold'],
    if (source != null) 'source': source,
  });
}

// ---------------------------------------------------------------------------
// command handlers
// ---------------------------------------------------------------------------

void runStartRun(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'idle') return _invalid(events, 'not_idle');
  final ascension = (cmd['ascension'] is int) ? cmd['ascension'] as int : 0;
  // Difficulty (v0.3.2): easy / normal / hard. Unknown or missing values fall
  // back to 'normal', so old saves and old command scripts replay unchanged
  // (no simVersion bump; the golden anchor proves normal ≡ pre-difficulty).
  const difficulties = {'easy', 'normal', 'hard'};
  final difficulty = difficulties.contains(cmd['difficulty'])
      ? cmd['difficulty'] as String
      : 'normal';
  final charId = cmd['character'] as String?;
  final ch = characterDef(charId);
  // Apply character loadout.
  sim.player['max_hp'] = ch.maxHp;
  sim.player['hp'] = ch.maxHp;
  sim.player['dice'] = List<String>.from(ch.startDice);
  sim.run = <String, dynamic>{
    'embers': 0,
    'fights_won': 0,
    'gold': 0,
    'relics': <String>[],
    'insight': null,
    'seen_events': <String>[],
    'pending_splash': 0,
    'ascension': ascension,
    'character': ch.id,
    'difficulty': difficulty,
  };
  sim.turnsTotal = 0;
  if (ch.startRelic != null) {
    _grantRelic(sim, ch.startRelic!, events);
  }
  final map = generateMap(sim.rng['map']!);
  map['position'] = map['start'];
  map['visited'] = <int>[map['start'] as int];
  _resolveRewardTelegraphs(sim, map);
  sim.map = map;
  final nodeCount = (map['nodes'] as Map).length;
  _push(events, {
    'type': 'run_started',
    'seed': sim.runSeed,
    'nodes': nodeCount,
    'layers': map['layers'],
    'character': ch.id,
    'ascension': ascension,
    // Only stamped when off-normal so pre-difficulty event logs (and the
    // golden hash) stay byte-identical for normal runs.
    if (difficulty != 'normal') 'difficulty': difficulty,
  });
  if (cmd['boons'] == true) {
    // Restart flow (m4 §6): deterministic 1-of-3 starting-boon offering from
    // the seeded `boon` stream (without replacement over boonsOrder).
    final pool = List<String>.from(boonsOrder);
    final picks = <String>[];
    for (var k = 0; k < 3 && pool.isNotEmpty; k++) {
      picks.add(pool.removeAt(sim.rng['boon']!.range(1, pool.length) - 1));
    }
    sim.boons = picks;
    sim.phase = 'boon';
    _push(events, {
      'type': 'boon_offered',
      'b1': picks[0],
      'b2': picks.length > 1 ? picks[1] : null,
      if (picks.length > 2) 'b3': picks[2],
    });
  } else {
    sim.phase = 'map';
  }
}

/// cmd: { type:"choose_boon", index:<0 skip | 1-based pick> }
void runChooseBoon(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'boon' || sim.boons == null) {
    return _invalid(events, 'not_boon_phase');
  }
  final i = cmd['index'];
  final picks = sim.boons!;
  if (i is! int || i < 0 || i > picks.length) {
    return _invalid(events, 'no_such_boon');
  }
  if (i == 0) {
    _push(events, {'type': 'boon_skipped'});
  } else {
    final def = boonDef(picks[i - 1]);
    final gold = (def.effects['gold'] as int?) ?? 0;
    if (gold > 0) _gainGold(sim, gold, events, 'boon');
    final maxHp = (def.effects['max_hp'] as int?) ?? 0;
    if (maxHp > 0) {
      sim.player['max_hp'] = (sim.player['max_hp'] as int) + maxHp;
      sim.player['hp'] = (sim.player['hp'] as int) + maxHp;
      _push(events, {
        'type': 'max_hp_changed',
        'amount': maxHp,
        'max_hp': sim.player['max_hp'],
      });
    }
    final gainDie = def.effects['gain_die'] as String?;
    if (gainDie != null) {
      (sim.player['dice'] as List).add(gainDie);
      _push(events, {'type': 'die_gained', 'die': gainDie});
    }
    final embers = (def.effects['embers'] as int?) ?? 0;
    if (embers > 0) {
      sim.run!['embers'] = (sim.run!['embers'] as int) + embers;
      _push(events, {
        'type': 'embers_gained',
        'amount': embers,
        'total': sim.run!['embers'],
      });
    }
    _push(events, {'type': 'boon_chosen', 'boon': def.id});
  }
  sim.boons = null;
  sim.phase = 'map';
}

// Reward telegraphs (m4 §5): pre-resolve every combat node's die offers from
// the seeded `offer` stream at start_run (node-id order), and stamp an honest
// `reward_preview` on the node — the exact best die the fight will offer.
// Elites always carry one guaranteed tier-3 (rare) die. runPost serves these
// stored offers verbatim, so the preview can never lie.
void _resolveRewardTelegraphs(Sim sim, Map<String, Object?> map) {
  final offer = sim.rng['offer']!;
  final nodes = (map['nodes'] as Map).cast<String, Map>();
  final count = nodes.length;
  for (var id = 1; id <= count; id++) {
    final node = nodes['$id']!;
    final kind = node['kind'];
    if (kind != 'fight' && kind != 'elite') continue;
    final layer = node['layer'] as int;
    final ceiling = _tierCeiling(layer);
    final pool =
        [for (final d in diceOrder) if (dice[d]!.tier <= ceiling) d];
    final offers = <String>[];
    if (kind == 'elite') {
      final rares = [for (final d in diceOrder) if (dice[d]!.tier == 3) d];
      offers.add(rares[offer.range(1, rares.length) - 1]);
    }
    final n = offer.range(2, 3);
    final rest = [for (final d in pool) if (!offers.contains(d)) d];
    while (offers.length < n && rest.isNotEmpty) {
      offers.add(rest.removeAt(offer.range(1, rest.length) - 1));
    }
    node['offers'] = offers;
    // Preview = the single best die on offer (highest tier, then size).
    var best = offers[0];
    for (final d in offers) {
      final a = dice[d]!, b = dice[best]!;
      if (a.tier > b.tier || (a.tier == b.tier && a.size > b.size)) best = d;
    }
    node['reward_preview'] = best;
  }
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
  final layer = node['layer'] as int;
  _push(events, {
    'type': 'node_entered',
    'node': target,
    'kind': node['kind'],
    'layer': layer,
  });
  switch (node['kind']) {
    case 'fight':
      final pool = _regularsFor(layer);
      combatBegin(sim, pool[sim.rng['combat']!.range(1, pool.length) - 1],
          false, events,
          layer: layer);
      break;
    case 'elite':
      final pool = _elitesFor(layer);
      combatBegin(sim, pool[sim.rng['combat']!.range(1, pool.length) - 1],
          true, events,
          layer: layer);
      break;
    case 'boss':
      combatBegin(sim, _boss, false, events);
      break;
    case 'rest':
      sim.phase = 'rest';
      break;
    case 'shop':
      _openShop(sim, layer, events);
      break;
    case 'event':
      _openEvent(sim, events);
      break;
  }
}

// ---- rewards ---------------------------------------------------------------

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

// ---- rest + forge ----------------------------------------------------------

void runRest(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'rest') return _invalid(events, 'not_rest_phase');
  final base = ((sim.player['max_hp'] as int) * 3) ~/ 10;
  final healed = _heal(sim, base + relicSum(sim, 'rest_bonus'));
  _push(events, {'type': 'rested', 'healed': healed, 'hp': sim.player['hp']});
  sim.phase = 'map';
}

/// cmd: `{ type:"forge", die:<pool index 1-based>, into:<die id> }`
void runForge(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'rest') return _invalid(events, 'not_rest_phase');
  final pool = sim.player['dice'] as List;
  final idx = cmd['die'];
  if (idx is! int || idx < 1 || idx > pool.length) {
    return _invalid(events, 'no_such_die');
  }
  final from = pool[idx - 1] as String;
  final into = cmd['into'];
  if (into is! String || !dieDef(from).forgeTo.contains(into)) {
    return _invalid(events, 'illegal_forge');
  }
  pool[idx - 1] = into;
  _push(events, {'type': 'forged', 'from': from, 'into': into});
  sim.phase = 'map';
}

// ---- shop ------------------------------------------------------------------

void _openShop(Sim sim, int layer, List<Map<String, Object?>> events) {
  final ceiling = _tierCeiling(layer);
  final loot = sim.rng['loot']!;
  final discount = relicSum(sim, 'shop_discount');
  int price(int base) => (base * (100 - discount)) ~/ 100;

  // 3 dice from diceOrder with tier <= ceiling (with replacement is fine; use
  // distinct picks without replacement for variety).
  final diePool = [for (final id in diceOrder) if (dice[id]!.tier <= ceiling) id];
  final dieSlots = <Map<String, Object?>>[];
  final chosen = <String>[];
  for (var k = 0; k < 3 && diePool.isNotEmpty; k++) {
    final id = diePool[loot.range(1, diePool.length) - 1];
    chosen.add(id);
    dieSlots.add({
      'kind': 'die',
      'id': id,
      'price': price(20 + 8 * dice[id]!.tier),
      'sold': false,
    });
  }
  // 2 relics not yet owned.
  final relicPool = [
    for (final id in relicsOrder) if (!ownsRelic(sim, id)) id
  ];
  final relicSlots = <Map<String, Object?>>[];
  final relicPicks = List<String>.from(relicPool);
  for (var k = 0; k < 2 && relicPicks.isNotEmpty; k++) {
    final id = relicPicks.removeAt(loot.range(1, relicPicks.length) - 1);
    relicSlots.add(
        {'kind': 'relic', 'id': id, 'price': price(55), 'sold': false});
  }
  // 1 heal (25% max hp).
  final healSlot = {
    'kind': 'heal',
    'id': 'heal',
    'amount': ((sim.player['max_hp'] as int) * 25) ~/ 100,
    'price': price(25),
    'sold': false,
  };
  final slots = <Map<String, Object?>>[...dieSlots, ...relicSlots, healSlot];
  sim.shop = {'slots': slots};
  sim.phase = 'shop';
  final ev = <String, Object?>{'type': 'shop_stocked', 'count': slots.length};
  for (var i = 0; i < slots.length; i++) {
    ev['s${i + 1}'] = slots[i]['id'];
  }
  _push(events, ev);
}

/// cmd: { type:"buy", slot:<1-based> }
void runBuy(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'shop' || sim.shop == null) {
    return _invalid(events, 'not_shop_phase');
  }
  final slots = sim.shop!['slots'] as List;
  final s = cmd['slot'];
  if (s is! int || s < 1 || s > slots.length) {
    return _invalid(events, 'no_such_slot');
  }
  final slot = slots[s - 1] as Map;
  if (slot['sold'] == true) return _invalid(events, 'already_sold');
  final price = slot['price'] as int;
  if ((sim.run!['gold'] as int) < price) {
    return _invalid(events, 'not_enough_gold');
  }
  sim.run!['gold'] = (sim.run!['gold'] as int) - price;
  _push(events, {
    'type': 'gold_spent',
    'amount': price,
    'total': sim.run!['gold'],
  });
  switch (slot['kind']) {
    case 'die':
      (sim.player['dice'] as List).add(slot['id']);
      break;
    case 'relic':
      _grantRelic(sim, slot['id'] as String, events);
      break;
    case 'heal':
      _heal(sim, slot['amount'] as int);
      break;
  }
  slot['sold'] = true;
  _push(events,
      {'type': 'bought', 'slot': s, 'kind': slot['kind'], 'id': slot['id']});
}

void runLeaveShop(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'shop') return _invalid(events, 'not_shop_phase');
  sim.shop = null;
  sim.phase = 'map';
  _push(events, {'type': 'left_shop'});
}

// ---- events ----------------------------------------------------------------

void _openEvent(Sim sim, List<Map<String, Object?>> events) {
  final seen = (sim.run!['seen_events'] as List).cast<String>();
  final unseen = [for (final id in eventsOrder) if (!seen.contains(id)) id];
  final pool = unseen.isNotEmpty ? unseen : List<String>.from(eventsOrder);
  final id = pool[sim.rng['shuffle']!.range(1, pool.length) - 1];
  seen.add(id);
  sim.event = id;
  sim.phase = 'event';
  final def = eventDef(id);
  final ev = <String, Object?>{
    'type': 'event_shown',
    'event': id,
    'options': def.options.length,
  };
  _push(events, ev);
}

/// cmd: { type:"event_choose", option:<1-based> }
void runEventChoose(Sim sim, Map cmd, List<Map<String, Object?>> events) {
  if (sim.phase != 'event' || sim.event == null) {
    return _invalid(events, 'not_event_phase');
  }
  final def = eventDef(sim.event!);
  final o = cmd['option'];
  if (o is! int || o < 1 || o > def.options.length) {
    return _invalid(events, 'no_such_option');
  }
  final effects = def.options[o - 1].effects;
  // Validate gold cost up front (fair: never a hidden failure mid-apply).
  final goldDelta = (effects['gold'] as int?) ?? 0;
  if (goldDelta < 0 && (sim.run!['gold'] as int) + goldDelta < 0) {
    return _invalid(events, 'not_enough_gold');
  }
  // lose_random_die only legal while pool > 3.
  if (effects['lose_random_die'] == 1 && (sim.player['dice'] as List).length <= 3) {
    return _invalid(events, 'pool_too_small');
  }
  _applyEventEffects(sim, effects, events);
  sim.event = null;
  sim.phase = 'map';
  _push(events, {'type': 'event_resolved', 'event': def.id, 'option': o});
}

void _applyEventEffects(
    Sim sim, Map<String, Object> effects, List<Map<String, Object?>> events) {
  final loot = sim.rng['loot']!;
  final shuffle = sim.rng['shuffle']!;
  // Deterministic effect order (contract §4).
  final gold = (effects['gold'] as int?) ?? 0;
  if (gold != 0) {
    if (gold > 0) {
      _gainGold(sim, gold, events, 'event');
    } else {
      sim.run!['gold'] = (sim.run!['gold'] as int) + gold;
      _push(events,
          {'type': 'gold_spent', 'amount': -gold, 'total': sim.run!['gold']});
    }
  }
  final goldAfter = (effects['gold_after'] as int?) ?? 0;
  if (goldAfter > 0) _gainGold(sim, goldAfter, events, 'event');
  final hp = (effects['hp'] as int?) ?? 0;
  if (hp < 0) {
    var v = (sim.player['hp'] as int) + hp;
    if (v < 1) v = 1; // events never kill (fair-death pillar)
    sim.player['hp'] = v;
    _push(events, {'type': 'hp_lost', 'amount': -hp, 'hp': v});
  } else if (hp > 0) {
    final h = _heal(sim, hp);
    _push(events, {'type': 'healed', 'amount': h, 'hp': sim.player['hp']});
  }
  final maxHp = (effects['max_hp'] as int?) ?? 0;
  if (maxHp != 0) {
    var m = (sim.player['max_hp'] as int) + maxHp;
    if (m < 10) m = 10;
    sim.player['max_hp'] = m;
    if ((sim.player['hp'] as int) > m) sim.player['hp'] = m;
    if (maxHp > 0) sim.player['hp'] = (sim.player['hp'] as int) + maxHp;
    _push(events, {'type': 'max_hp_changed', 'amount': maxHp, 'max_hp': m});
  }
  final healPct = (effects['heal_pct'] as int?) ?? 0;
  if (healPct > 0) {
    final h = _heal(sim, ((sim.player['max_hp'] as int) * healPct) ~/ 100);
    _push(events, {'type': 'healed', 'amount': h, 'hp': sim.player['hp']});
  }
  final embers = (effects['embers'] as int?) ?? 0;
  if (embers > 0) {
    sim.run!['embers'] = (sim.run!['embers'] as int) + embers;
    _push(events,
        {'type': 'embers_gained', 'amount': embers, 'total': sim.run!['embers']});
  }
  if (effects['lose_random_die'] == 1) {
    final pool = sim.player['dice'] as List;
    final idx = shuffle.range(1, pool.length);
    final lost = pool.removeAt(idx - 1);
    _push(events, {'type': 'die_lost', 'die': lost});
  }
  final gainDie = effects['gain_die'] as String?;
  if (gainDie != null) {
    (sim.player['dice'] as List).add(gainDie);
    _push(events, {'type': 'die_gained', 'die': gainDie});
  }
  final grt = (effects['gain_random_die'] as int?) ?? 0;
  if (grt > 0) {
    final pool = [for (final id in diceOrder) if (dice[id]!.tier <= grt) id];
    final id = pool[loot.range(1, pool.length) - 1];
    (sim.player['dice'] as List).add(id);
    _push(events, {'type': 'die_gained', 'die': id});
  }
  if (effects['gain_random_relic'] == 1) {
    final pool = [for (final id in relicsOrder) if (!ownsRelic(sim, id)) id];
    if (pool.isEmpty) {
      sim.run!['embers'] = (sim.run!['embers'] as int) + 15;
      _push(events, {
        'type': 'embers_gained',
        'amount': 15,
        'total': sim.run!['embers'],
        'source': 'relic_fallback'
      });
    } else {
      _grantRelic(sim, pool[loot.range(1, pool.length) - 1], events);
    }
  }
}

// ---------------------------------------------------------------------------
// post hook — called by sim.dart after EVERY dispatched command
// ---------------------------------------------------------------------------

void runPost(Sim sim, List<Map<String, Object?>> events) {
  final outcome = sim.combatOver;
  if (outcome == null) return;
  sim.combatOver = null;
  sim.turnsTotal += sim.turn;
  final map = sim.map!;
  final node = (map['nodes'] as Map)['${map['position']}'] as Map;
  final run = sim.run!;
  final layer = node['layer'] as int;
  if (outcome == 'won') {
    run['fights_won'] = (run['fights_won'] as int) + 1;
    final isBoss = node['kind'] == 'boss';
    // Gold + embers payouts with relic bonuses.
    var gold = _rollGold(sim) + relicSum(sim, 'gold_bonus');
    if (isBoss) gold += 30;
    _gainGold(sim, gold, events, 'fight');
    var embers = _rollEmbers(sim) + relicSum(sim, 'ember_bonus');
    if (isBoss) embers += 40;
    // Difficulty (v0.3.2): fight payouts scale with the risk taken. Shown
    // honestly on the title-screen selector — no hidden math (§Ethics).
    final difficulty = run['difficulty'] as String? ?? 'normal';
    if (difficulty == 'easy') embers = (embers * 0.75).round();
    if (difficulty == 'hard') embers = (embers * 1.25).round();
    run['embers'] = (run['embers'] as int) + embers;
    // heal_after_fight relic.
    final hf = relicSum(sim, 'heal_after_fight');
    if (hf > 0) {
      final h = _heal(sim, hf);
      if (h > 0) {
        _push(events,
            {'type': 'healed', 'amount': h, 'hp': sim.player['hp'], 'source': 'relic'});
      }
    }
    if (isBoss) {
      sim.phase = 'run_won';
      _push(events, {
        'type': 'run_won',
        'embers': run['embers'],
        'fights_won': run['fights_won'],
        'turns_total': sim.turnsTotal,
        'gold': run['gold'],
      });
    } else {
      // Reward offers were pre-resolved at start_run from the `offer` stream
      // and telegraphed on the map node (m4 §5) — serve them verbatim so the
      // preview is honest. Fallback (never expected) keeps old behavior.
      var offers = (node['offers'] as List?)?.cast<String>().toList();
      if (offers == null || offers.isEmpty) {
        final ceiling = _tierCeiling(layer);
        final poolIds =
            [for (final id in diceOrder) if (dice[id]!.tier <= ceiling) id];
        final count = sim.rng['loot']!.range(2, 3);
        final pool = List<String>.from(poolIds);
        offers = <String>[];
        for (var k = 0; k < count && pool.isNotEmpty; k++) {
          offers
              .add(pool.removeAt(sim.rng['loot']!.range(1, pool.length) - 1));
        }
      }
      sim.offers = offers;
      sim.phase = 'reward';
      _push(events, {
        'type': 'reward_offered',
        'o1': offers[0],
        'o2': offers.length > 1 ? offers[1] : null,
        if (offers.length > 2) 'o3': offers[2],
      });
    }
  } else {
    // "lost": death ledger keeps half the embers + a fair-death insight.
    // Ember floor (v0.3.1 F8, fair-death pillar): every death banks at least
    // 5 + the layer reached, so even a node-one death pays something.
    final kept = (run['embers'] as int) ~/ 2;
    final floor = 5 + layer;
    run['embers'] = kept > floor ? kept : floor;
    final bucket = insightBucket(layer, node['kind'] == 'boss');
    final lines = insights[bucket]!;
    final insight = lines[sim.rng['loot']!.range(1, lines.length) - 1];
    run['insight'] = insight;
    sim.phase = 'run_lost';
    _push(events, {
      'type': 'run_lost',
      'embers': run['embers'],
      'fights_won': run['fights_won'],
      'layer': layer,
      'gold': run['gold'],
      'insight': insight,
    });
  }
}
