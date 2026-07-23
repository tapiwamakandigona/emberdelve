// Bit-parity of lib/sim/hashing.dart against the Lua implementation, proven
// by replaying the Lua golden event trace (seed 20260723) and the mid-run
// snapshot's state_hash. Fixtures from tool/parity/gen_fixtures.lua.
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/sim/hashing.dart';
import 'package:test/test.dart';

Map<String, dynamic> loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Recompute Lua sim:state_hash() from a snapshot map (the snapshot contains
/// every field state_hash reads). Mirrors legacy/defold/sim/init.lua.
int stateHashFromSnapshot(Map<String, dynamic> snap) {
  dynamic orNone(dynamic v) => v ?? 'none';
  var h = 17;
  h = hashValue(h, snap['turn']);
  h = hashValue(h, snap['phase']);
  h = hashValue(h, snap['player']);
  h = hashValue(h, orNone(snap['enemy']));
  h = hashValue(h, orNone(snap['map']));
  h = hashValue(h, orNone(snap['offers']));
  h = hashValue(h, orNone(snap['run']));
  h = hashValue(h, snap['turns_total']);
  h = hashValue(h, orNone(snap['combat_over']));
  final rng = snap['rng'] as Map<String, dynamic>;
  for (final name in const ['map', 'combat', 'loot', 'shuffle']) {
    h = hashValue(h, rng[name]);
  }
  return h;
}

void main() {
  test('golden trace: event hash chain reproduces 311044885 step-by-step', () {
    final trace = loadFixture('golden_trace.json');
    var h = 0;
    var count = 0;
    for (final step in (trace['steps'] as List).cast<Map<String, dynamic>>()) {
      for (final ev in (step['events'] as List)) {
        h = hashValue(h, ev);
        count += 1;
      }
      expect(h, step['event_hash'],
          reason: 'event_hash diverged after cmd ${jsonEncode(step['cmd'])} '
              '(event #$count)');
    }
    expect(h, trace['final_event_hash']);
    expect(h, 311044885, reason: 'M1 golden anchor');
    expect(count, trace['final_event_count']);
  });

  test('mid-run snapshot: state_hash reproduces (nested maps, numeric keys)',
      () {
    final fx = loadFixture('midrun_snapshot.json');
    expect(stateHashFromSnapshot(fx['snapshot'] as Map<String, dynamic>),
        fx['state_hash']);
  });

  test('golden final snapshot: state_hash reproduces', () {
    final trace = loadFixture('golden_trace.json');
    expect(
        stateHashFromSnapshot(trace['final_snapshot'] as Map<String, dynamic>),
        trace['final_state_hash']);
  });

  test('lexicographic key order: "10" sorts before "2" like Lua', () {
    final list11 = List<int>.generate(11, (i) => i + 1);
    // Hash of an 11-element list must equal hash of the equivalent
    // stringified-key map — both follow lexicographic key order.
    final asMap = {for (var i = 0; i < 11; i++) '${i + 1}': list11[i]};
    expect(hashValue(17, list11), hashValue(17, asMap));
  });
}
