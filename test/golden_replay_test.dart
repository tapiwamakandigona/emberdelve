// Master parity gate (docs/flutter-port-contract.md §5): replay the
// Lua-generated golden trace (test/fixtures/golden_trace.json, seed
// 20260723) through the Dart Sim. After EVERY command the emitted events
// must deep-equal the fixture step's events (field names AND values) and
// the running eventHash must match. Final anchors: eventHash 311044885,
// stateHash == fixture final_state_hash, snapshot deep-equals
// final_snapshot (after key normalization), and a mid-run snapshot
// round-trip (restore(jsonDecode(jsonEncode(snapshot())))) continues
// identically to the non-round-tripped twin.
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/sim/sim.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Canonicalization + diffing.
//
// Lua tables make no distinction between arrays and int-keyed maps, and the
// fixture encoder (tool/parity/gen_fixtures.lua) emits DENSE int-keyed
// tables as JSON arrays. Canonical form therefore maps both Dart Lists and
// Maps onto string-keyed maps (lists get 1-based keys, mirroring
// hashValue's list rule), so `{1:'a'}`, `['a']` and `{'1':'a'}` all compare
// equal — exactly Lua-table equality.
// ---------------------------------------------------------------------------

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
  // num == handles int-vs-double (Lua "0" decodes int, Dart x may be 0.0).
  return a == b;
}

Map<String, dynamic> loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Debugging aid (quality bar): on the first divergent command, fail with
/// the command index, the command, and expected vs actual events.
void expectStepEvents(int stepIndex, Map<String, dynamic> cmd,
    List<Map<String, dynamic>> actual, List expected) {
  final ca = canon(actual);
  final ce = canon(expected);
  if (!deepEq(ca, ce)) {
    fail('golden replay diverged at command index $stepIndex '
        '(0-based)\n  cmd:      ${jsonEncode(cmd)}\n'
        '  expected: ${jsonEncode(expected)}\n'
        '  actual:   ${jsonEncode(actual)}');
  }
}

void main() {
  test(
      'golden replay: seed 20260723 trace matches Lua per-command '
      '(events, hashes, snapshot round-trip)', () {
    final fx = loadFixture('golden_trace.json');
    final steps = (fx['steps'] as List).cast<Map<String, dynamic>>();
    expect(steps, isNotEmpty);

    final sim = Sim(fx['seed'] as int);
    Sim? twin; // snapshot round-trip twin, forked mid-run
    final forkAt = steps.length ~/ 2;

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final cmd = (step['cmd'] as Map).cast<String, dynamic>();
      final evs = sim.apply(Map<String, dynamic>.of(cmd));
      expectStepEvents(i, cmd, evs, step['events'] as List);
      expect(sim.eventHash, step['event_hash'],
          reason: 'running eventHash diverged at command index $i '
              '(cmd ${jsonEncode(cmd)})');
      expect(sim.eventCount, step['event_count'],
          reason: 'eventCount diverged at command index $i');

      if (twin != null) {
        final twinEvs = twin.apply(Map<String, dynamic>.of(cmd));
        expectStepEvents(i, cmd, twinEvs, step['events'] as List);
        expect(twin.eventHash, sim.eventHash,
            reason: 'round-tripped twin eventHash diverged at index $i');
      }
      if (i == forkAt) {
        // Mid-run persistence proof: JSON round-trip the snapshot (int map
        // keys become strings; restore must normalize) and continue on the
        // twin in lockstep with the original.
        final wire = jsonEncode(sim.snapshot()); // must not throw
        twin = Sim.restore(jsonDecode(wire) as Map<String, dynamic>);
        expect(twin.stateHash(), sim.stateHash(),
            reason: 'stateHash changed across snapshot JSON round-trip');
      }
    }

    // Final anchors.
    expect(sim.eventHash, 311044885, reason: 'M1 golden anchor');
    expect(sim.eventHash, fx['final_event_hash']);
    expect(sim.eventCount, fx['final_event_count']);
    expect(sim.phase, fx['final_phase']);
    expect(sim.stateHash(), fx['final_state_hash'],
        reason: 'final stateHash() diverged from Lua');
    expect(twin, isNotNull, reason: 'twin never forked (trace too short?)');
    expect(twin!.eventHash, sim.eventHash,
        reason: 'twin final eventHash diverged');
    expect(twin.stateHash(), sim.stateHash(),
        reason: 'twin final stateHash diverged');
    expect(twin.phase, sim.phase);

    // final_snapshot deep-equals Dart snapshot() after key normalization.
    final snap = canon(sim.snapshot());
    final want = canon(fx['final_snapshot']);
    if (!deepEq(snap, want)) {
      fail('final snapshot differs from fixture\n'
          '  expected: ${jsonEncode(want)}\n'
          '  actual:   ${jsonEncode(snap)}');
    }
  });
}
