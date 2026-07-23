// sim/map_gen.dart — StS-style layered node-map generator (M1 contract §6).
// SEALED SIM MODULE: pure Dart, no Flutter, no dart:io, no dart:math Random.
//
// 1:1 port of legacy/defold/sim/map.lua (the behavioral ORACLE — bit-parity
// enforced by test/map_test.dart, incl. a golden-fixture parity test).
// RNG consumption order is copied line-by-line from the Lua; comments cite
// the corresponding Lua source lines for the tricky parts.
//
// Guarantees (enforced by construction, property-tested in test/map_test.dart):
//   * Pure: same rng state + cfg ⇒ identical map. All randomness comes from
//     the single `rng` stream passed in; iteration everywhere follows
//     deterministic numeric index order.
//   * Shape: `layers` layers; layer 1 = single `start`, layer N = single
//     `boss`; middle layers have min_nodes..max_nodes nodes each.
//   * Edges span exactly one layer, built as a random monotone "staircase
//     walk" per adjacent layer pair — every node has ≥1 forward edge AND
//     ≥1 incoming edge (no dead ends), with no crossing edges.
//   * Kinds: fight-dominant; ≥1 elite (layer elite_from+ only); ≥1 rest with
//     one guaranteed on layer rest_guarantee_from+ (before the boss); no two
//     rest nodes ever adjacent on any path (no rest→rest edge exists).

import 'rng.dart';

// Tuning constants (map.lua:26-28): percent rolls out of 100; one roll per
// middle node so rng consumption is a fixed function of the node layout.
const int _elitePct = 16; // r in [1..16]  → elite (on eligible layers)
const int _restLo = 17; //   r in [17..30] → rest (if no rest parent)
const int _restHi = 30;

// DEFAULTS (map.lua:31-37).
const int _defLayers = 9;
const int _defMinNodes = 2; // middle-layer node count bounds
const int _defMaxNodes = 4;
const int _defEliteFromLayer = 4; // elites only on this layer or deeper
const int _defRestGuaranteeLayer = 6; // ≥1 rest on this layer or deeper

/// Generate a map. [rng] = the sim's map stream; [cfg] optional with the
/// same keys as the Lua cfg (`layers`, `min_nodes`, `max_nodes`,
/// `elite_from_layer`, `rest_guarantee_layer`). Returns the contract §5 map
/// view minus position/visited (those belong to the run layer):
/// `{layers, start, boss, nodes: Map<int,{id,layer,kind,x}>, edges: Map<int,List<int>>}`.
Map<String, dynamic> generateMap(Rng rng, [Map<String, dynamic>? cfg]) {
  cfg ??= const {};
  final layers = (cfg['layers'] ?? _defLayers) as int;
  final minNodes = (cfg['min_nodes'] ?? _defMinNodes) as int;
  final maxNodes = (cfg['max_nodes'] ?? _defMaxNodes) as int;
  final eliteFrom = (cfg['elite_from_layer'] ?? _defEliteFromLayer) as int;
  final restFrom = (cfg['rest_guarantee_layer'] ?? _defRestGuaranteeLayer) as int;
  assert(layers >= 3, 'map: need at least 3 layers');
  assert(minNodes >= 1 && maxNodes >= minNodes, 'map: bad node bounds');
  // Placement rules below assume the guarantee layers exist and leave room
  // for the adjacency argument that makes repair always possible (map.lua:52-55).
  assert(eliteFrom >= 2 && eliteFrom < layers,
      'map: elite_from_layer out of range');
  assert(restFrom >= 2 && restFrom <= layers - 1,
      'map: rest_guarantee_layer out of range');

  // ---- 1. Node layout (consumes rng: one range() per middle layer) --------
  // layerNodes[l] = node ids in that layer, in x order (1-based, index 0
  // unused, mirroring Lua's layer_nodes). Ids are layer-major: deterministic.
  // (map.lua:57-83)
  final layerNodes = List<List<int>>.filled(layers + 1, const []);
  final nodes = <int, Map<String, dynamic>>{};
  var nextId = 1;
  for (var l = 1; l <= layers; l++) {
    final int count;
    if (l == 1 || l == layers) {
      count = 1;
    } else {
      count = rng.range(minNodes, maxNodes);
    }
    final row = <int>[];
    for (var i = 1; i <= count; i++) {
      final id = nextId;
      nextId = nextId + 1;
      // x: evenly spread 0..1 — Lua float division (i-1)/(count-1); Dart /
      // on ints yields the identical IEEE double (map.lua:74-76).
      final num x = count == 1 ? 0.5 : (i - 1) / (count - 1);
      nodes[id] = {'id': id, 'layer': l, 'kind': 'fight', 'x': x};
      row.add(id);
    }
    layerNodes[l] = row;
  }
  nodes[layerNodes[1][0]]!['kind'] = 'start';
  nodes[layerNodes[layers][0]]!['kind'] = 'boss';

  // ---- 2. Edges: random monotone staircase per adjacent layer pair --------
  // Walk (i,j) from (1,1) to (#A,#B), connecting A[i]→B[j] at every step.
  // rng is consumed only when BOTH indices can still advance — exactly as
  // map.lua:85-116. i/j are kept 1-based to keep the transcription literal.
  final edges = <int, List<int>>{};
  for (var id = 1; id <= nextId - 1; id++) {
    edges[id] = [];
  }
  for (var l = 1; l <= layers - 1; l++) {
    final a = layerNodes[l], b = layerNodes[l + 1];
    var i = 1, j = 1;
    void connect() {
      // The walk revisits a node only with a strictly larger j, so targets
      // stay unique and ascending; no dedupe needed (map.lua:99-102).
      edges[a[i - 1]]!.add(b[j - 1]);
    }

    connect();
    while (i < a.length || j < b.length) {
      if (i < a.length && j < b.length) {
        final m = rng.range(1, 3); // map.lua:106
        if (m == 1) {
          i = i + 1;
        } else if (m == 2) {
          j = j + 1;
        } else {
          i = i + 1;
          j = j + 1;
        }
      } else if (i < a.length) {
        i = i + 1;
      } else {
        j = j + 1;
      }
      connect();
    }
  }

  // Reverse adjacency (parents), needed for the rest-adjacency rule.
  // Built by deterministic id order; consumes no rng (map.lua:118-127).
  final parents = <int, List<int>>{};
  for (var id = 1; id <= nextId - 1; id++) {
    parents[id] = [];
  }
  for (var id = 1; id <= nextId - 1; id++) {
    for (final to in edges[id]!) {
      parents[to]!.add(id);
    }
  }

  bool hasRestParent(int id) {
    for (final p in parents[id]!) {
      if (nodes[p]!['kind'] == 'rest') return true;
    }
    return false;
  }

  bool hasRestChild(int id) {
    for (final to in edges[id]!) {
      if (nodes[to]!['kind'] == 'rest') return true;
    }
    return false;
  }

  // ---- 3. Kinds: sprinkle in id order (exactly one roll per middle node) --
  // Processing in id order = layer order, so when a node considers becoming
  // a rest, all its parents already have final-ish kinds. A node becomes rest
  // only if no parent is a rest ⇒ no rest→rest edge can ever be created.
  // (map.lua:145-160) — skip start (1) and boss (nextId-1).
  for (var id = 2; id <= nextId - 2; id++) {
    final n = nodes[id]!;
    final r = rng.range(1, 100);
    if ((n['layer'] as int) >= eliteFrom && r <= _elitePct) {
      n['kind'] = 'elite';
    } else if (r >= _restLo && r <= _restHi && !hasRestParent(id)) {
      n['kind'] = 'rest';
    }
  }

  // ---- 4. Guarantee: ≥1 rest on layer rest_from+ (before the boss) --------
  // If the sprinkle produced none, convert a safe node: candidates must not
  // touch a rest on either side (map.lua:162-186). The fallback candidate
  // list is provably non-empty — see the Lua comment.
  var haveLateRest = false;
  for (var id = 2; id <= nextId - 2; id++) {
    final n = nodes[id]!;
    if (n['kind'] == 'rest' && (n['layer'] as int) >= restFrom) {
      haveLateRest = true;
    }
  }
  if (!haveLateRest) {
    final fights = <int>[], nonrest = <int>[];
    for (var id = 2; id <= nextId - 2; id++) {
      final n = nodes[id]!;
      if ((n['layer'] as int) >= restFrom &&
          !hasRestParent(id) &&
          !hasRestChild(id)) {
        if (n['kind'] == 'fight') fights.add(id);
        if (n['kind'] != 'rest') nonrest.add(id);
      }
    }
    final pool = fights.isNotEmpty ? fights : nonrest;
    assert(pool.isNotEmpty, 'map: no candidate for guaranteed rest');
    // Lua: pool[rng:range(1, #pool)] — 1-based pick (map.lua:185).
    nodes[pool[rng.range(1, pool.length) - 1]]!['kind'] = 'rest';
  }

  // ---- 5. Guarantee: ≥1 elite (layer elite_from+ only) --------------------
  // Runs after the rest repair so a rest conversion can never erase the last
  // elite unnoticed. Converting fight→elite has no adjacency constraint.
  // (map.lua:188-205)
  var haveElite = false;
  for (var id = 2; id <= nextId - 2; id++) {
    if (nodes[id]!['kind'] == 'elite') haveElite = true;
  }
  if (!haveElite) {
    final cands = <int>[];
    for (var id = 2; id <= nextId - 2; id++) {
      final n = nodes[id]!;
      if ((n['layer'] as int) >= eliteFrom && n['kind'] == 'fight') {
        cands.add(id);
      }
    }
    // Non-empty: rests are never adjacent, so layers eliteFrom..layers-1
    // cannot be all-rest; with no elites the non-rest nodes are all fights.
    assert(cands.isNotEmpty, 'map: no candidate for guaranteed elite');
    nodes[cands[rng.range(1, cands.length) - 1]]!['kind'] = 'elite';
  }

  return {
    'layers': layers,
    'start': layerNodes[1][0],
    'boss': layerNodes[layers][0],
    'nodes': nodes,
    'edges': edges, // forward edges only; boss id maps to an empty list
  };
}
