// sim/sim.dart — Emberdelve simulation core: the sealed black box.
// SEALED SIM MODULE: pure Dart, no Flutter, no dart:io, no dart:math Random,
// no clocks.
//
// 1:1 port of legacy/defold/sim/init.lua (the behavioral oracle), per
// docs/flutter-port-contract.md §3.
//
// CONTRACT (frozen in docs/architecture.md §2 — do not change without an
// architecture revision):
//   Sim(runSeed)            -> sim              (Lua Sim.new)
//   sim.apply(cmd)          -> events (List of flat event Maps)
//   sim.state()             -> read-only view of current state
//   sim.snapshot()          -> plain JSON-safe Map (jsonEncode must work)
//   Sim.restore(snap)       -> sim (continues identically; accepts
//                              jsonDecode output — int map keys that became
//                              strings are normalized back)
//   sim.stateHash()         -> deterministic int
//   sim.eventHash           -- running hash over every emitted event
//
// RULES:
//   * All randomness through sim.rng[<domain>] streams (sim/rng.dart).
//   * Same seed + same command sequence => identical events, hashes, state,
//     on every platform. CI enforces this (test/run_test.dart,
//     test/golden_replay_test.dart).
//   * Events are flat Maps: string `type` + scalar fields only.
//
// Lua-nil convention: Lua tables cannot hold nil, so a field set to nil is
// simply absent. Dart Maps CAN hold null (combat.dart sets
// player['rolled'] = null), so both snapshot() and stateHash() strip
// null-valued keys before serializing/hashing — bit-identical to Lua.

import 'combat.dart' as combat;
import 'hashing.dart';
import 'rng.dart';
import 'run_layer.dart' as run_layer;

const int simVersion = 2;

/// The four rng streams, in canonical order (init.lua STREAMS).
const List<String> _streams = ['map', 'combat', 'loot', 'shuffle'];

typedef _Handler = void Function(
    dynamic sim, Map<String, dynamic> cmd, List<Map<String, dynamic>> events);

// v2 public command set (docs/m1-contract.md §2). start_encounter is gone:
// encounters auto-start when a fight/elite/boss node is entered.
const Map<String, _Handler> _handlers = {
  'start_run': run_layer.startRun,
  'choose_node': run_layer.chooseNode,
  'roll': combat.roll,
  'assign': combat.assign,
  'end_turn': combat.endTurn,
  'choose_reward': run_layer.chooseReward,
  'rest': run_layer.rest,
};

// ---------------------------------------------------------------------------
// deep copy / JSON-safety helpers
// ---------------------------------------------------------------------------

/// Deep copy that is JSON-safe: map keys stringified, null-valued entries
/// dropped (a Lua table never holds nil — the key is simply absent).
dynamic _jsonCopy(dynamic v) {
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        if (e.value != null) e.key.toString(): _jsonCopy(e.value),
    };
  }
  if (v is List) return <dynamic>[for (final x in v) _jsonCopy(x)];
  return v;
}

/// View of [v] with null-valued map entries stripped, for hashing (Lua
/// tables cannot hold nil; hashValue rejects null by design).
dynamic _stripNulls(dynamic v) {
  if (v is Map) {
    return {
      for (final e in v.entries)
        if (e.value != null) e.key: _stripNulls(e.value),
    };
  }
  if (v is List) return [for (final x in v) _stripNulls(x)];
  return v;
}

// -------------------------------------------------------------------------
// restore normalization: jsonDecode turns int-keyed maps into string-keyed
// objects, and the Lua fixture encoder even turns DENSE int-keyed tables
// into JSON arrays. Normalize either shape back to the in-memory types
// (contract §2 "normalize on restore").
// -------------------------------------------------------------------------

/// [v] as a Map keyed by int: accepts Map (int or numeric-string keys) or a
/// List (treated as a dense 1-based table, the Lua-JSON array encoding).
Map<int, dynamic> _intKeyed(dynamic v) {
  if (v is List) {
    return {for (var i = 0; i < v.length; i++) i + 1: v[i]};
  }
  final m = v as Map;
  return {
    for (final e in m.entries)
      (e.key is int ? e.key as int : int.parse(e.key as String)): e.value,
  };
}

/// Deep copy as a string-keyed map tree (nested maps become
/// Map<String, dynamic>, which combat.dart's casts require). Snapshots are
/// null-free by construction (snapshot() strips nils like Lua), so the
/// null-dropping _jsonCopy is an exact deep copy here.
Map<String, dynamic> _strMap(dynamic v) =>
    _jsonCopy(v as Map) as Map<String, dynamic>;

/// Player map with rolled/rolled_max/assigned re-typed for combat.dart.
Map<String, dynamic> _normalizePlayer(dynamic v) {
  final p = _strMap(v);
  p['dice'] = List<dynamic>.of(p['dice'] as List);
  if (p['rolled'] != null) {
    p['rolled'] = List<int>.from(p['rolled'] as List);
  }
  if (p['rolled_max'] != null) {
    p['rolled_max'] = List<bool>.from(p['rolled_max'] as List);
  }
  final assigned = p['assigned'];
  p['assigned'] = <int, String>{
    if (assigned != null)
      for (final e in _intKeyed(assigned).entries) e.key: e.value as String,
  };
  return p;
}

/// Map (the run map) with nodes/edges keyed by int node id again.
Map<String, dynamic> _normalizeMap(dynamic v) {
  final m = _strMap(v);
  m['nodes'] = <int, Map<String, dynamic>>{
    for (final e in _intKeyed(m['nodes']).entries) e.key: _strMap(e.value),
  };
  m['edges'] = <int, List<int>>{
    for (final e in _intKeyed(m['edges']).entries)
      e.key: List<int>.from(e.value as List),
  };
  m['visited'] = List<int>.from(m['visited'] as List);
  return m;
}

// ---------------------------------------------------------------------------
// Sim
// ---------------------------------------------------------------------------

class Sim {
  int version;
  final int runSeed;
  final Map<String, Rng> rng;
  int turn;
  String phase; // idle|map|player_turn|reward|rest|run_won|run_lost
  Map<String, dynamic> player;
  Map<String, dynamic>? enemy;
  Map<String, dynamic>? map; // set by start_run (incl. position + visited)
  List<dynamic>? offers; // die ids while phase == 'reward'
  Map<String, dynamic>? run; // { embers, fights_won } run ledger
  int turnsTotal; // combat turns accumulated across encounters
  String? combatOver; // transient 'won'|'lost' flag consumed by run_layer.post
  int eventHash;
  int eventCount;

  /// Port of init.lua `Sim.new`.
  Sim(this.runSeed)
      : version = simVersion,
        rng = {for (final name in _streams) name: Rng(runSeed, name)},
        turn = 0,
        phase = 'idle',
        player = {
          'hp': 30, 'max_hp': 30, 'block': 0,
          // die ids into data/dice.dart (dice-builder axis)
          'dice': <dynamic>['d6', 'd6', 'd6'],
          'rolled': null, 'assigned': <int, String>{},
        },
        enemy = null,
        map = null,
        offers = null,
        run = null,
        turnsTotal = 0,
        combatOver = null,
        eventHash = 0,
        eventCount = 0;

  Sim._restored({
    required this.version,
    required this.runSeed,
    required this.rng,
    required this.turn,
    required this.phase,
    required this.player,
    required this.enemy,
    required this.map,
    required this.offers,
    required this.run,
    required this.turnsTotal,
    required this.combatOver,
    required this.eventHash,
    required this.eventCount,
  });

  /// Port of init.lua `Sim:snapshot` — plain JSON-safe data (jsonEncode
  /// works: int keys stringified, absent/nil fields omitted, as in Lua).
  Map<String, dynamic> snapshot() {
    final snap = <String, dynamic>{
      'version': version,
      'run_seed': runSeed,
      'turn': turn,
      'phase': phase,
      'player': _jsonCopy(player),
      if (enemy != null) 'enemy': _jsonCopy(enemy),
      if (map != null) 'map': _jsonCopy(map),
      if (offers != null) 'offers': _jsonCopy(offers),
      if (run != null) 'run': _jsonCopy(run),
      'turns_total': turnsTotal,
      if (combatOver != null) 'combat_over': combatOver,
      'event_hash': eventHash,
      'event_count': eventCount,
      'rng': {for (final name in _streams) name: this.rng[name]!.snapshot()},
    };
    return snap;
  }

  /// Port of init.lua `Sim.restore`. Accepts both in-memory snapshots and
  /// jsonDecode output (string keys / arrays normalized back, see contract
  /// §2 row "map keyed by node id").
  factory Sim.restore(Map<String, dynamic> snap) {
    if (snap['version'] != simVersion) {
      throw StateError('cannot restore snapshot: version ${snap['version']} '
          'is not SIM_VERSION $simVersion (stale save; start a new run)');
    }
    return Sim._restored(
      version: snap['version'] as int,
      runSeed: snap['run_seed'] as int,
      rng: {
        for (final name in _streams)
          name: Rng.restore(
              _strMap((snap['rng'] as Map)[name])),
      },
      turn: snap['turn'] as int,
      phase: snap['phase'] as String,
      player: _normalizePlayer(snap['player']),
      enemy: snap['enemy'] == null ? null : _strMap(snap['enemy']),
      map: snap['map'] == null ? null : _normalizeMap(snap['map']),
      offers: snap['offers'] == null
          ? null
          : List<dynamic>.of(snap['offers'] as List),
      run: snap['run'] == null ? null : _strMap(snap['run']),
      turnsTotal: snap['turns_total'] as int,
      combatOver: snap['combat_over'] as String?,
      eventHash: snap['event_hash'] as int,
      eventCount: snap['event_count'] as int,
    );
  }

  // -------------------------------------------------------------------------
  // Command dispatch
  // -------------------------------------------------------------------------

  /// Apply one command; returns the ordered list of resulting events.
  /// Port of init.lua `Sim:apply`.
  List<Map<String, dynamic>> apply(Map<String, dynamic> cmd) {
    if (cmd['type'] is! String) {
      throw ArgumentError("command must be a Map with a String 'type'");
    }
    final events = <Map<String, dynamic>>[];
    final handler = _handlers[cmd['type']];
    if (handler == null) {
      events.add({'type': 'invalid_command', 'reason': 'unknown_command'});
    } else {
      handler(this, cmd, events);
    }
    // Contract §1: after EVERY dispatched command (valid or not) the run
    // layer's post hook consumes sim.combatOver and performs all run-level
    // phase transitions. Its events join this command's batch (hashed below).
    run_layer.post(this, events);
    for (final ev in events) {
      eventHash = hashValue(eventHash, ev);
      eventCount = eventCount + 1;
    }
    return events;
  }

  /// Port of init.lua `Sim:state` — a read-only view (live references).
  Map<String, dynamic> state() => {
        'turn': turn,
        'phase': phase,
        'player': player,
        'enemy': enemy,
        'map': map, // incl. position + visited (contract §5)
        'offers': offers, // only while phase == 'reward'
        'run': run,
      };

  /// Port of init.lua `Sim:state_hash` — same 9 fields + 4 rng snapshots,
  /// same order; absent fields substitute 'none' exactly like the Lua.
  int stateHash() {
    var h = 17;
    h = hashValue(h, turn);
    h = hashValue(h, phase);
    h = hashValue(h, _stripNulls(player));
    h = hashValue(h, enemy == null ? 'none' : _stripNulls(enemy));
    h = hashValue(h, map == null ? 'none' : _stripNulls(map));
    h = hashValue(h, offers == null ? 'none' : _stripNulls(offers));
    h = hashValue(h, run == null ? 'none' : _stripNulls(run));
    h = hashValue(h, turnsTotal);
    h = hashValue(h, combatOver ?? 'none');
    for (final name in _streams) {
      h = hashValue(h, rng[name]!.snapshot());
    }
    return h;
  }
}
