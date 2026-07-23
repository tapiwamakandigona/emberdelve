// test/map_test.dart — port of legacy/defold/tests/map_tests.lua (all 12
// property tests, same 200 seeds, same assertions) plus a golden-fixture
// parity test proving lib/sim/map_gen.dart is bit-identical to the Lua
// oracle for the golden run seed.
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/sim/map_gen.dart';
import 'package:emberdelve/sim/rng.dart';
import 'package:test/test.dart';

const seedsCount = 200;

/// Mix of small, large and "awkward" seeds; deterministic list
/// (map_tests.lua:15-20).
List<int> seedList() {
  final s = List<int>.generate(seedsCount, (i) => (i + 1) * 7919 + 13);
  s[0] = 0; // edge seeds: 0, 1, MOD-1
  s[1] = 1;
  s[2] = 2147483646;
  return s;
}

Map<String, dynamic> gen(int seed, [Map<String, dynamic>? cfg]) =>
    generateMap(Rng(seed, 'map'), cfg);

/// Canonical serialization: fixed field order, ids ascending — mirrors
/// map_tests.lua:46-63 (`%.6f` for x → toStringAsFixed(6)).
String serialize(Map<String, dynamic> m) {
  final nodes = m['nodes'] as Map<int, Map<String, dynamic>>;
  final edges = m['edges'] as Map<int, List<int>>;
  final out = <String>['L', '${m['layers']}', 'S', '${m['start']}', 'B', '${m['boss']}'];
  final ids = nodes.keys.toList()..sort();
  for (final id in ids) {
    final n = nodes[id]!;
    out.add(
        'n${n['id']}:${n['layer']}:${n['kind']}:${(n['x'] as num).toStringAsFixed(6)}');
    final es = List<int>.from(edges[id] ?? const [])..sort();
    out.add('e${es.join(',')}');
  }
  return out.join('|');
}

List<int> nodeIds(Map<String, dynamic> m) =>
    (m['nodes'] as Map<int, Map<String, dynamic>>).keys.toList()..sort();

void forSeeds(void Function(int seed, Map<String, dynamic> m) fn) {
  for (final seed in seedList()) {
    fn(seed, gen(seed));
  }
}

Never failSeed(int seed, String msg) => fail('seed $seed: $msg');

void main() {
  // ---- the 12 ported property tests (map_tests.lua) ------------------------

  test('map: determinism — same seed ⇒ identical serialized map', () {
    for (final seed in seedList()) {
      final a = serialize(gen(seed)), b = serialize(gen(seed));
      if (a != b) failSeed(seed, 'two generates from fresh streams differ');
    }
  });

  test(
      'map: purity — fresh same-seeded stream reproduces map; input cfg untouched',
      () {
    // (Lua also snapshots _G for leaked globals — not applicable in Dart.)
    for (final seed in seedList()) {
      final r1 = Rng(seed, 'map');
      final m1 = generateMap(r1);
      final r2 = Rng(seed, 'map');
      final m2 = generateMap(r2);
      if (serialize(m1) != serialize(m2)) {
        failSeed(seed, 'second generate differs');
      }
      if (r1.calls != r2.calls || r1.seed != r2.seed) {
        failSeed(seed, 'rng consumption differs between identical generates');
      }
      // cfg map must not be mutated (pure function of its inputs).
      final cfg = <String, dynamic>{'layers': 9};
      generateMap(Rng(seed, 'map'), cfg);
      if (cfg.length != 1 || cfg['layers'] != 9) {
        failSeed(seed, 'cfg map was mutated');
      }
    }
  });

  test('map: layer/node-count bounds, start and boss placement, x in [0,1]',
      () {
    forSeeds((seed, m) {
      if (m['layers'] != 9) failSeed(seed, 'layers != 9');
      final nodes = m['nodes'] as Map<int, Map<String, dynamic>>;
      final perLayer = <int, int>{};
      for (final id in nodeIds(m)) {
        final n = nodes[id]!;
        if (n['id'] is! int || n['id'] != id) {
          failSeed(seed, 'id mismatch at $id');
        }
        final layer = n['layer'] as int;
        if (layer < 1 || layer > 9) failSeed(seed, 'layer out of range');
        final x = n['x'] as num;
        if (x < 0 || x > 1) failSeed(seed, 'x out of [0,1] at node $id');
        perLayer[layer] = (perLayer[layer] ?? 0) + 1;
      }
      if (perLayer[1] != 1) failSeed(seed, 'layer 1 not a single node');
      if (perLayer[9] != 1) failSeed(seed, 'layer 9 not a single node');
      for (var l = 2; l <= 8; l++) {
        final c = perLayer[l] ?? 0;
        if (c < 2 || c > 4) failSeed(seed, 'layer $l has $c nodes');
      }
      final start = nodes[m['start'] as int]!;
      if (start['kind'] != 'start' || start['layer'] != 1) {
        failSeed(seed, 'bad start node');
      }
      final boss = nodes[m['boss'] as int]!;
      if (boss['kind'] != 'boss' || boss['layer'] != 9) {
        failSeed(seed, 'bad boss node');
      }
    });
  });

  test(
      'map: every edge spans exactly one layer forward, targets exist, no duplicates',
      () {
    forSeeds((seed, m) {
      final nodes = m['nodes'] as Map<int, Map<String, dynamic>>;
      final edges = m['edges'] as Map<int, List<int>>;
      for (final id in nodeIds(m)) {
        final n = nodes[id]!;
        final seen = <int>{};
        for (final to in edges[id] ?? const <int>[]) {
          final t = nodes[to];
          if (t == null) failSeed(seed, 'edge to missing node $to');
          final span = (t['layer'] as int) - (n['layer'] as int);
          if (span != 1) failSeed(seed, 'edge $id→$to spans $span layers');
          if (!seen.add(to)) failSeed(seed, 'duplicate edge $id→$to');
        }
      }
    });
  });

  test('map: every node reachable from start (forward BFS covers all nodes)',
      () {
    forSeeds((seed, m) {
      final edges = m['edges'] as Map<int, List<int>>;
      final ids = nodeIds(m);
      final reached = <int>{m['start'] as int};
      final queue = <int>[m['start'] as int];
      var head = 0;
      while (head < queue.length) {
        final id = queue[head];
        head += 1;
        for (final to in edges[id] ?? const <int>[]) {
          if (reached.add(to)) queue.add(to);
        }
      }
      for (final id in ids) {
        if (!reached.contains(id)) {
          failSeed(seed, 'node $id unreachable from start');
        }
      }
    });
  });

  test(
      'map: boss reachable from every node — no dead ends (reverse BFS covers all)',
      () {
    forSeeds((seed, m) {
      final edges = m['edges'] as Map<int, List<int>>;
      final ids = nodeIds(m);
      final parents = <int, List<int>>{};
      for (final id in ids) {
        for (final to in edges[id] ?? const <int>[]) {
          (parents[to] ??= []).add(id);
        }
      }
      final reaches = <int>{m['boss'] as int};
      final queue = <int>[m['boss'] as int];
      var head = 0;
      while (head < queue.length) {
        final id = queue[head];
        head += 1;
        for (final p in parents[id] ?? const <int>[]) {
          if (reaches.add(p)) queue.add(p);
        }
      }
      for (final id in ids) {
        if (!reaches.contains(id)) {
          failSeed(seed, 'boss not reachable from node $id');
        }
      }
      // Directly: every non-boss node must have ≥1 forward edge.
      for (final id in ids) {
        if (id != m['boss'] && (edges[id] ?? const <int>[]).isEmpty) {
          failSeed(seed, 'node $id has no forward edge');
        }
      }
    });
  });

  test('map: all forward paths end at the boss (walk any greedy path)', () {
    // Complements the BFS tests: exhaustively walk every path via DFS with a
    // per-seed cap; since edges only go forward, path count is finite.
    forSeeds((seed, m) {
      final edges = m['edges'] as Map<int, List<int>>;
      var walked = 0;
      void dfs(int id) {
        walked += 1;
        if (walked > 20000) return; // safety cap; maps are tiny
        final out = edges[id] ?? const <int>[];
        if (out.isEmpty) {
          if (id != m['boss']) failSeed(seed, 'path dead-ends at node $id');
          return;
        }
        for (final to in out) {
          dfs(to);
        }
      }

      dfs(m['start'] as int);
    });
  });

  test('map: kinds valid; elites ≥1 and only on layer 4+ (never layer 9)', () {
    const valid = {'start', 'fight', 'elite', 'rest', 'boss'};
    forSeeds((seed, m) {
      final nodes = m['nodes'] as Map<int, Map<String, dynamic>>;
      var elites = 0;
      for (final id in nodeIds(m)) {
        final n = nodes[id]!;
        final kind = n['kind'] as String;
        if (!valid.contains(kind)) failSeed(seed, 'bad kind $kind');
        if ((kind == 'start') != (id == m['start'])) {
          failSeed(seed, 'stray start kind');
        }
        if ((kind == 'boss') != (id == m['boss'])) {
          failSeed(seed, 'stray boss kind');
        }
        if (kind == 'elite') {
          elites += 1;
          final layer = n['layer'] as int;
          if (layer < 4 || layer > 8) failSeed(seed, 'elite on layer $layer');
        }
      }
      if (elites < 1) failSeed(seed, 'no elite node');
    });
  });

  test('map: rests ≥1 with one on layer 6+ before the boss', () {
    forSeeds((seed, m) {
      final nodes = m['nodes'] as Map<int, Map<String, dynamic>>;
      var rests = 0, late = 0;
      for (final id in nodeIds(m)) {
        final n = nodes[id]!;
        if (n['kind'] == 'rest') {
          rests += 1;
          final layer = n['layer'] as int;
          if (layer >= 6 && layer <= 8) late += 1;
          if (layer < 2 || layer > 8) failSeed(seed, 'rest on layer $layer');
        }
      }
      if (rests < 1) failSeed(seed, 'no rest node');
      // All nodes are reachable from start (proven above), so ≥1 rest on
      // layer 6..8 ⇒ a rest is guaranteed reachable before the boss.
      if (late < 1) failSeed(seed, 'no rest on layers 6-8');
    });
  });

  test('map: no two rests adjacent on any path (no rest→rest edge)', () {
    // Edge-level check is equivalent to the path property: two rests can only
    // be consecutive on a path if a rest→rest edge exists.
    forSeeds((seed, m) {
      final nodes = m['nodes'] as Map<int, Map<String, dynamic>>;
      final edges = m['edges'] as Map<int, List<int>>;
      for (final id in nodeIds(m)) {
        if (nodes[id]!['kind'] == 'rest') {
          for (final to in edges[id] ?? const <int>[]) {
            if (nodes[to]!['kind'] == 'rest') {
              failSeed(seed, 'adjacent rests $id→$to');
            }
          }
        }
      }
    });
  });

  test('map: seeds actually vary the maps (generator is not constant)', () {
    final distinct = <String>{};
    for (final seed in seedList()) {
      distinct.add(serialize(gen(seed)));
    }
    // 200+ seeds must not collapse to a handful of layouts.
    if (distinct.length < seedsCount / 2) {
      fail('only ${distinct.length} distinct maps across $seedsCount seeds');
    }
  });

  test('map: determinism holds from mid-consumed streams too (same rng STATE)',
      () {
    // The contract says same rng STATE ⇒ same map — not just fresh streams.
    for (var i = 1; i <= 50; i++) {
      final seed = i * 104729;
      final r1 = Rng(seed, 'map');
      final r2 = Rng(seed, 'map');
      for (var k = 0; k < i; k++) {
        r1.nextRaw(); // advance both equally
        r2.nextRaw();
      }
      if (serialize(generateMap(r1)) != serialize(generateMap(r2))) {
        failSeed(seed, 'mid-stream generates differ');
      }
    }
  });

  // ---- golden-fixture parity: Dart map == Lua oracle map --------------------

  test(
      'map: golden fixture parity — Rng(20260723,"map") reproduces '
      'golden_trace.json final_snapshot.map (excl. position/visited)', () {
    final trace = jsonDecode(
            File('test/fixtures/golden_trace.json').readAsStringSync())
        as Map<String, dynamic>;
    final want = (trace['final_snapshot']
        as Map<String, dynamic>)['map'] as Map<String, dynamic>;

    final got = generateMap(Rng(20260723, 'map'));

    expect(got['layers'], want['layers'], reason: 'layers');
    expect(got['start'], want['start'], reason: 'start');
    expect(got['boss'], want['boss'], reason: 'boss');

    // Lua's dense 1..N id-keyed tables serialize to JSON arrays; normalize
    // the fixture back to id-keyed maps (id = array index + 1; node objects
    // also carry their own `id`). position/visited are mutable run-layer
    // fields — deliberately excluded from the comparison.
    final gotNodes = got['nodes'] as Map<int, Map<String, dynamic>>;
    final gotEdges = got['edges'] as Map<int, List<int>>;
    final wantNodes = (want['nodes'] as List).cast<Map<String, dynamic>>();
    final wantEdges = (want['edges'] as List).cast<List<dynamic>>();

    expect(gotNodes.length, wantNodes.length, reason: 'node count');
    expect(gotEdges.length, wantEdges.length, reason: 'edge-list count');

    for (var idx = 0; idx < wantNodes.length; idx++) {
      final id = idx + 1;
      final w = wantNodes[idx];
      expect(w['id'], id, reason: 'fixture node array is id-dense');
      final g = gotNodes[id];
      expect(g, isNotNull, reason: 'missing node $id');
      expect(g!['id'], w['id'], reason: 'node $id id');
      expect(g['layer'], w['layer'], reason: 'node $id layer');
      expect(g['kind'], w['kind'], reason: 'node $id kind');
      // JSON may render 0.0 as 0; compare numerically, exactly.
      expect((g['x'] as num).toDouble(), (w['x'] as num).toDouble(),
          reason: 'node $id x');

      expect(gotEdges[id], wantEdges[idx].cast<int>(),
          reason: 'edges of node $id (order-sensitive)');
    }
  });
}
