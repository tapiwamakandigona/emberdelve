// sim/sim.dart — Emberdelve simulation core: the sealed black box.
//
// CONTRACT (docs/architecture.md — do not change without a revision):
//   Sim(runSeed)                -> sim
//   sim.apply(cmd)              -> events (list of flat event maps)
//   sim.state()                 -> read-only view of current state
//   sim.snapshot()              -> plain JSON-safe map
//   Sim.restore(snap)           -> sim (continues identically)
//   sim.stateHash()             -> deterministic int
//   sim.eventHash               -- running hash over every emitted event
//
// RULES:
//   * Pure Dart. Zero Flutter/engine APIs. Zero dart:io / dart:math.Random.
//   * All randomness through sim.rng[<domain>] streams (rng.dart).
//   * Same seed + same command sequence => identical events, hashes, state.
//     The test suite enforces this, including against the Lua-era golden.
//   * Events are flat maps: string `type` + scalar fields only.

import 'combat.dart';
import 'hashing.dart';
import 'rng.dart';
import 'run_layer.dart';

const int simVersion = 3;

const List<String> simStreams = ['map', 'combat', 'loot', 'shuffle'];

typedef Handler = void Function(Sim, Map, List<Map<String, Object?>>);

final Map<String, Handler> _handlers = {
  'start_run': runStartRun,
  'choose_node': runChooseNode,
  'roll': combatRoll,
  'assign': combatAssign,
  'reroll': combatReroll,
  'end_turn': combatEndTurn,
  'choose_reward': runChooseReward,
  'rest': runRest,
  'forge': runForge,
  'buy': runBuy,
  'leave_shop': runLeaveShop,
  'event_choose': runEventChoose,
};

class Sim {
  int version = simVersion;
  final int runSeed;
  final Map<String, Rng> rng = {};
  int turn = 0;
  String phase = 'idle'; // idle|map|player_turn|reward|rest|run_won|run_lost
  Map<String, dynamic> player = {};
  Map<String, dynamic>? enemy;
  Map<String, dynamic>? map;
  List<String>? offers; // die ids while phase == "reward"
  Map<String, dynamic>? shop; // stock map while phase == "shop"
  String? event; // current event id while phase == "event"
  Map<String, dynamic>? run; // run ledger (embers, gold, relics, ...)
  int turnsTotal = 0; // combat turns accumulated across encounters
  String? combatOver; // transient "won"|"lost" flag consumed by runPost
  int eventHash = 0;
  int eventCount = 0;

  Sim(this.runSeed) {
    for (final name in simStreams) {
      rng[name] = Rng.create(runSeed, name);
    }
    player = <String, dynamic>{
      'hp': 30,
      'max_hp': 30,
      'block': 0,
      'dice': <String>['d6', 'd6', 'd6'],
      'rolled': null,
      'rolled_max': null,
      'assigned': <String, String>{},
    };
  }

  Map<String, Object?> snapshot() {
    final snap = <String, Object?>{
      'version': version,
      'run_seed': runSeed,
      'turn': turn,
      'phase': phase,
      'player': deepCopy(player),
      'enemy': deepCopy(enemy),
      'map': deepCopy(map),
      'offers': deepCopy(offers),
      'shop': deepCopy(shop),
      'event': event,
      'run': deepCopy(run),
      'turns_total': turnsTotal,
      'combat_over': combatOver,
      'event_hash': eventHash,
      'event_count': eventCount,
      'rng': {for (final name in simStreams) name: rng[name]!.snapshot()},
    };
    return snap;
  }

  factory Sim.restore(Map<String, dynamic> snap) {
    if (snap['version'] != simVersion) {
      throw StateError(
          'cannot restore snapshot: version ${snap['version']} is not '
          '$simVersion (stale save; start a new run)');
    }
    final sim = Sim._blank(snap['run_seed'] as int);
    sim.turn = snap['turn'] as int;
    sim.phase = snap['phase'] as String;
    sim.player = (deepCopy(snap['player']) as Map).cast<String, dynamic>();
    sim.enemy = snap['enemy'] == null
        ? null
        : (deepCopy(snap['enemy']) as Map).cast<String, dynamic>();
    sim.map = snap['map'] == null
        ? null
        : (deepCopy(snap['map']) as Map).cast<String, dynamic>();
    sim.offers =
        snap['offers'] == null ? null : (snap['offers'] as List).cast<String>().toList();
    sim.shop = snap['shop'] == null
        ? null
        : (deepCopy(snap['shop']) as Map).cast<String, dynamic>();
    sim.event = snap['event'] as String?;
    sim.run = snap['run'] == null
        ? null
        : (deepCopy(snap['run']) as Map).cast<String, dynamic>();
    sim.turnsTotal = snap['turns_total'] as int;
    sim.combatOver = snap['combat_over'] as String?;
    sim.eventHash = snap['event_hash'] as int;
    sim.eventCount = snap['event_count'] as int;
    final rngSnap = snap['rng'] as Map;
    for (final name in simStreams) {
      sim.rng[name] =
          Rng.restore((rngSnap[name] as Map).cast<String, dynamic>());
    }
    return sim;
  }

  Sim._blank(this.runSeed);

  /// Apply one command; returns the ordered list of resulting events.
  List<Map<String, Object?>> apply(Map cmd) {
    final type = cmd['type'];
    if (type is! String) {
      throw ArgumentError("command must be a map with a string 'type'");
    }
    final events = <Map<String, Object?>>[];
    final handler = _handlers[type];
    if (handler == null) {
      events.add({'type': 'invalid_command', 'reason': 'unknown_command'});
    } else {
      handler(this, cmd, events);
    }
    // After EVERY dispatched command the run layer's post hook consumes
    // combatOver and performs all run-level phase transitions. Its events
    // join this command's batch (hashed below).
    runPost(this, events);
    for (final ev in events) {
      eventHash = hashValue(eventHash, ev);
      eventCount += 1;
    }
    return events;
  }

  Map<String, Object?> state() => {
        'turn': turn,
        'phase': phase,
        'player': player,
        'enemy': enemy,
        'map': map,
        'offers': offers,
        'shop': shop,
        'event': event,
        'run': run,
      };

  int stateHash() {
    var h = 17;
    h = hashValue(h, turn);
    h = hashValue(h, phase);
    h = hashValue(h, player);
    h = hashValue(h, enemy ?? 'none');
    h = hashValue(h, map ?? 'none');
    h = hashValue(h, offers ?? 'none');
    h = hashValue(h, shop ?? 'none');
    h = hashValue(h, event ?? 'none');
    h = hashValue(h, run ?? 'none');
    h = hashValue(h, turnsTotal);
    h = hashValue(h, combatOver ?? 'none');
    for (final name in simStreams) {
      h = hashValue(h, rng[name]!.snapshot());
    }
    return h;
  }
}
