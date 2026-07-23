// Restores the Lua-GENERATED mid-run snapshot fixture
// (test/fixtures/midrun_snapshot.json, seed 4242, captured by
// tool/parity/gen_fixtures.lua after 25 drive-policy commands) directly
// into the Dart Sim. This is the strongest proof for the UI autosave path:
// a snapshot produced by the *Lua* engine must restore losslessly in Dart
// (docs/flutter-port-contract.md §5, run-worker follow-up).
//
// Checks:
//   1. Replaying the 25 fixture steps through Sim(4242) reproduces every
//      per-step running event_hash, the fixture snapshot (canon-equal) and
//      state_hash.
//   2. Sim.restore(<raw jsonDecode of the Lua snapshot>) yields the same
//      stateHash — key/array normalization works on real Lua output.
//   3. The restored sim and the replayed sim continue to terminal under the
//      shared drive policy with identical events and final hashes.
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:test/test.dart';

const int kMaxCmds = 3000;

// --- canon/deepEq: same Lua-table equality used by golden_replay_test ---
dynamic canon(dynamic v) {
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        if (e.value != null) e.key.toString(): canon(e.value),
    };
  }
  if (v is List) {
    return <String, dynamic>{
      for (var i = 0; i < v.length; i++) '${i + 1}': canon(v[i]),
    };
  }
  return v;
}

bool deepEq(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !deepEq(e.value, b[e.key])) return false;
    }
    return true;
  }
  return a == b;
}

// --- drive policy: verbatim tool/parity/gen_fixtures.lua next_cmd (same
// copy as autoplay_test.dart; test files cannot import each other) ---
Map<String, dynamic>? botCmd(Sim sim) {
  final st = sim.state();
  final phase = st['phase'] as String;
  if (phase == 'idle') {
    return {'type': 'start_run'};
  } else if (phase == 'map') {
    final map = st['map'] as Map<String, dynamic>;
    final edges = (map['edges'] as Map)[map['position']] as List;
    final player = st['player'] as Map<String, dynamic>;
    final wantRest = (player['hp'] as int) * 2 < (player['max_hp'] as int);
    int? pick;
    for (var i = 0; i < edges.length; i++) {
      final kind = ((map['nodes'] as Map)[edges[i]] as Map)['kind'];
      if (wantRest && kind == 'rest') {
        pick = edges[i] as int;
        break;
      }
      if (!wantRest && kind != 'rest' && pick == null) pick = edges[i] as int;
    }
    return {'type': 'choose_node', 'node': pick ?? edges[0]};
  } else if (phase == 'player_turn') {
    final player = st['player'] as Map<String, dynamic>;
    final rolled = player['rolled'] as List?;
    if (rolled == null) return {'type': 'roll'};
    final assigned = player['assigned'] as Map;
    for (var i = 1; i <= rolled.length; i++) {
      if (!assigned.containsKey(i)) {
        final mods =
            diceData[(player['dice'] as List)[i - 1]]!['mods'] as Map;
        final intent = (st['enemy'] as Map)['intent'] as Map;
        var incoming = 0;
        if (intent['kind'] == 'attack' || intent['kind'] == 'attack_block') {
          incoming = intent['amount'] as int;
        }
        String action;
        if (incoming > (player['block'] as int) &&
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
  } else if (phase == 'reward') {
    return {'type': 'choose_reward', 'index': 1};
  } else if (phase == 'rest') {
    return {'type': 'rest'};
  }
  return null;
}

void main() {
  final fx = jsonDecode(
          File('test/fixtures/midrun_snapshot.json').readAsStringSync())
      as Map<String, dynamic>;
  final steps = fx['steps'] as List;
  final fixtureStateHash = fx['state_hash'] as int;

  // Shared by both tests: the replayed twin at the snapshot point.
  late Sim replayed;
  setUpAll(() {
    replayed = Sim(fx['seed'] as int);
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i] as Map<String, dynamic>;
      final evs = replayed.apply(
          Map<String, dynamic>.of(step['cmd'] as Map<String, dynamic>));
      if (!deepEq(canon(evs), canon(step['events'])) ||
          replayed.eventHash != step['event_hash']) {
        fail('replay diverged at fixture step ${i + 1}: '
            'cmd=${step['cmd']} expected=${step['events']} actual=$evs '
            'expectedHash=${step['event_hash']} actualHash='
            '${replayed.eventHash}');
      }
    }
  });

  test(
      'midrun fixture: replaying 25 Lua steps reproduces snapshot + '
      'state_hash $fixtureStateHash', () {
    expect(replayed.stateHash(), fixtureStateHash);
    expect(deepEq(canon(replayed.snapshot()), canon(fx['snapshot'])), isTrue,
        reason: 'Dart snapshot() must canon-equal the Lua fixture snapshot');
  });

  test(
      'midrun fixture: Sim.restore(raw Lua snapshot) matches state_hash and '
      'continues identically to the replayed twin', () {
    final restored =
        Sim.restore(Map<String, dynamic>.of(fx['snapshot'] as Map<String, dynamic>));
    expect(restored.stateHash(), fixtureStateHash,
        reason: 'restore must normalize Lua-encoded keys/arrays losslessly');

    // Continue BOTH sims to terminal under the shared policy; every command
    // must produce identical events and hashes.
    var applied = 0;
    while (applied < kMaxCmds) {
      final cmd = botCmd(replayed);
      if (cmd == null) break;
      final a = replayed.apply(Map<String, dynamic>.of(cmd));
      final b = restored.apply(Map<String, dynamic>.of(cmd));
      applied += 1;
      if (!deepEq(canon(a), canon(b)) ||
          replayed.eventHash != restored.eventHash) {
        fail('twins diverged $applied cmd(s) after restore: cmd=$cmd '
            'replayed=$a restored=$b');
      }
    }
    expect(applied, greaterThan(0), reason: 'run should not already be over');
    expect(restored.stateHash(), replayed.stateHash());
    expect((restored.state()['phase'] as String).startsWith('run_'), isTrue,
        reason: 'seed 4242 must reach a terminal phase within $kMaxCmds');
  });
}
