// sim/map_gen.dart — StS-style layered node-map generator.
// SEALED SIM MODULE: pure Dart, no Flutter/dart:io/Random.
//
// Faithful port of the golden-verified Lua generator (repo history:
// sim/map.lua). Guarantees, by construction:
//   * Pure: same rng state + cfg => identical map; all randomness from the
//     single passed-in stream; iteration in deterministic numeric id order.
//   * Layer 1 = single `start`, layer N = single `boss`; middle layers have
//     minNodes..maxNodes nodes.
//   * Edges = random monotone staircase per adjacent layer pair: every node
//     has >=1 forward and >=1 incoming edge (no dead ends), planar.
//   * Kinds fight-dominant; >=1 elite (eliteFrom+), >=1 rest guaranteed on
//     restFrom+; no two rests ever adjacent.
//
// The map structure is plain JSON-safe data: node ids are ints; `nodes` and
// `edges` are keyed by the id's string form.

import 'rng.dart';

// Kind roll bands (percent out of 100; one roll per middle node). Order of
// checks matters — see the sprinkle step. rest requires no rest parent; shop
// only on shopFromLayer+; event on eventFromLayer+.
const int elitePct = 16; //  r in [1..16]   -> elite (eligible layers)
const int restLo = 17; //    r in [17..28]  -> rest (if no rest parent)
const int restHi = 28;
const int shopLo = 29; //    r in [29..40]  -> shop (shopFrom+)
const int shopHi = 40;
const int eventLo = 41; //   r in [41..56]  -> event (eventFrom+)
const int eventHi = 56;

class MapCfg {
  final int layers;
  final int minNodes;
  final int maxNodes;
  final int eliteFromLayer;
  final int restGuaranteeLayer;
  final int shopFromLayer;
  final int shopGuaranteeLayer;
  final int eventFromLayer;
  const MapCfg({
    this.layers = 9,
    this.minNodes = 2,
    this.maxNodes = 4,
    this.eliteFromLayer = 4,
    this.restGuaranteeLayer = 6,
    this.shopFromLayer = 3,
    this.shopGuaranteeLayer = 3,
    this.eventFromLayer = 2,
  });
}

/// v0.49.0 The Shorter Road: the Short Delve's map shape. Six layers instead
/// of nine — a true run (elite, rest, shop, boss) in roughly half a sit.
/// Guarantee layers are pulled forward proportionally so the format keeps the
/// full delve grammar: elites can appear from layer 3, a rest is guaranteed by
/// layer 4, shops from layer 2. Only [startRun] selects this cfg (mutator id
/// `short_road`); every other caller keeps the 9-layer default, so existing
/// goldens and pinned seeds are untouched by construction.
const MapCfg shortRoadCfg = MapCfg(
  layers: 6,
  // Elites hold to layer 4 exactly like the long delve — the 400-seed sweep
  // with eliteFromLayer 3 put a death spike on floor 3 (34/147 normal
  // losses): a fresh pool meeting an elite two fights in is a bouncer.
  eliteFromLayer: 4,
  // Rest guaranteed on the LAST middle layer, mirroring the long delve's
  // near-boss guarantee: with restGuaranteeLayer 4 the kind probe put 71/400
  // normal losses on the boss — runs whose only rest landed on floor 4
  // reached it unhealed. Layer 5 pins the guaranteed hearth beside the door.
  restGuaranteeLayer: 5,
  shopFromLayer: 2,
  shopGuaranteeLayer: 2,
  eventFromLayer: 2,
);

Map<String, Object?> generateMap(Rng rng, [MapCfg cfg = const MapCfg()]) {
  final layers = cfg.layers;
  final minNodes = cfg.minNodes;
  final maxNodes = cfg.maxNodes;
  final eliteFrom = cfg.eliteFromLayer;
  final restFrom = cfg.restGuaranteeLayer;
  final shopFrom = cfg.shopFromLayer;
  final shopGuarantee = cfg.shopGuaranteeLayer;
  final eventFrom = cfg.eventFromLayer;
  assert(layers >= 3, 'map: need at least 3 layers');
  assert(minNodes >= 1 && maxNodes >= minNodes, 'map: bad node bounds');
  assert(eliteFrom >= 2 && eliteFrom < layers, 'map: eliteFrom out of range');
  assert(restFrom >= 2 && restFrom <= layers - 1, 'map: restFrom out of range');

  // ---- 1. Node layout (consumes rng: one range() per middle layer) --------
  final layerNodes = <List<int>>[]; // index l-1 -> ids in x order
  final nodes = <String, Map<String, Object?>>{};
  var nextId = 1;
  for (var l = 1; l <= layers; l++) {
    final count = (l == 1 || l == layers) ? 1 : rng.range(minNodes, maxNodes);
    final row = <int>[];
    for (var i = 1; i <= count; i++) {
      final id = nextId;
      nextId += 1;
      final double x = count == 1 ? 0.5 : (i - 1) / (count - 1);
      nodes['$id'] = {'id': id, 'layer': l, 'kind': 'fight', 'x': x};
      row.add(id);
    }
    layerNodes.add(row);
  }
  nodes['${layerNodes[0][0]}']!['kind'] = 'start';
  nodes['${layerNodes[layers - 1][0]}']!['kind'] = 'boss';

  // ---- 2. Edges: random monotone staircase per adjacent layer pair --------
  final edges = <String, List<int>>{};
  for (var id = 1; id < nextId; id++) {
    edges['$id'] = <int>[];
  }
  for (var l = 1; l <= layers - 1; l++) {
    final a = layerNodes[l - 1];
    final b = layerNodes[l];
    var i = 1, j = 1;
    void connect() => edges['${a[i - 1]}']!.add(b[j - 1]);
    connect();
    while (i < a.length || j < b.length) {
      if (i < a.length && j < b.length) {
        final m = rng.range(1, 3);
        if (m == 1) {
          i += 1;
        } else if (m == 2) {
          j += 1;
        } else {
          i += 1;
          j += 1;
        }
      } else if (i < a.length) {
        i += 1;
      } else {
        j += 1;
      }
      connect();
    }
  }

  // Reverse adjacency (parents); deterministic id order, consumes no rng.
  final parents = <int, List<int>>{};
  for (var id = 1; id < nextId; id++) {
    parents[id] = <int>[];
  }
  for (var id = 1; id < nextId; id++) {
    for (final t in edges['$id']!) {
      parents[t]!.add(id);
    }
  }

  bool hasRestParent(int id) =>
      parents[id]!.any((p) => nodes['$p']!['kind'] == 'rest');
  bool hasRestChild(int id) =>
      edges['$id']!.any((c) => nodes['$c']!['kind'] == 'rest');

  // ---- 3. Kinds: sprinkle in id order (exactly one roll per middle node) --
  for (var id = 2; id <= nextId - 2; id++) {
    final n = nodes['$id']!;
    final r = rng.range(1, 100);
    final layer = n['layer'] as int;
    if (layer >= eliteFrom && r <= elitePct) {
      n['kind'] = 'elite';
    } else if (r >= restLo && r <= restHi && !hasRestParent(id)) {
      n['kind'] = 'rest';
    } else if (layer >= shopFrom && r >= shopLo && r <= shopHi) {
      n['kind'] = 'shop';
    } else if (layer >= eventFrom && r >= eventLo && r <= eventHi) {
      n['kind'] = 'event';
    }
  }

  // ---- 4. Guarantee: >=1 rest on layer restFrom+ (before the boss) --------
  var haveLateRest = false;
  for (var id = 2; id <= nextId - 2; id++) {
    final n = nodes['$id']!;
    if (n['kind'] == 'rest' && (n['layer'] as int) >= restFrom) {
      haveLateRest = true;
    }
  }
  if (!haveLateRest) {
    // v0.49.0: on the short cfg the window can be a single layer whose every
    // node touches a sprinkled rest — relax the floor one layer at a time
    // (never past 2) so the guarantee always lands without ever placing two
    // rests adjacent. Nine-layer maps always found a candidate in the first
    // pass (golden-verified), so the relaxation never fires for them.
    var pool = const <int>[];
    for (var from = restFrom; from >= 2 && pool.isEmpty; from--) {
      final fights = <int>[];
      final nonrest = <int>[];
      for (var id = 2; id <= nextId - 2; id++) {
        final n = nodes['$id']!;
        if ((n['layer'] as int) >= from &&
            !hasRestParent(id) &&
            !hasRestChild(id)) {
          if (n['kind'] == 'fight') fights.add(id);
          if (n['kind'] != 'rest') nonrest.add(id);
        }
      }
      pool = fights.isNotEmpty ? fights : nonrest;
    }
    assert(pool.isNotEmpty, 'map: no candidate for guaranteed rest');
    nodes['${pool[rng.range(1, pool.length) - 1]}']!['kind'] = 'rest';
  }

  // ---- 5. Guarantee: >=1 elite (layer eliteFrom+ only) --------------------
  var haveElite = false;
  for (var id = 2; id <= nextId - 2; id++) {
    if (nodes['$id']!['kind'] == 'elite') haveElite = true;
  }
  if (!haveElite) {
    final fights = <int>[];
    final nonRest = <int>[];
    for (var id = 2; id <= nextId - 2; id++) {
      final n = nodes['$id']!;
      if ((n['layer'] as int) >= eliteFrom) {
        if (n['kind'] == 'fight') fights.add(id);
        if (n['kind'] != 'rest') nonRest.add(id);
      }
    }
    // v0.49.0: short maps have only three elite-eligible layers, so the
    // sprinkle + rest guarantee can occasionally leave no plain fight there.
    // Mirror the rest guarantee: prefer fights, fall back to any non-rest
    // node (provably non-empty — rests are never adjacent, so consecutive
    // layers cannot all be rest). Nine-layer maps always had a fight
    // candidate here (golden-verified), so the fallback never fires for
    // them and this stays byte-identical for every default map.
    final pool = fights.isNotEmpty ? fights : nonRest;
    assert(pool.isNotEmpty, 'map: no candidate for guaranteed elite');
    nodes['${pool[rng.range(1, pool.length) - 1]}']!['kind'] = 'elite';
  }

  // ---- 6. Guarantee: >=1 shop on layer shopGuarantee+ ---------------------
  // Convert a fight (no adjacency constraint on shops). Non-empty because
  // shopGuarantee <= layers-1 always has fight-or-convertible nodes.
  var haveShop = false;
  for (var id = 2; id <= nextId - 2; id++) {
    if (nodes['$id']!['kind'] == 'shop') haveShop = true;
  }
  if (!haveShop) {
    final cands = <int>[];
    for (var id = 2; id <= nextId - 2; id++) {
      final n = nodes['$id']!;
      if ((n['layer'] as int) >= shopGuarantee && n['kind'] == 'fight') {
        cands.add(id);
      }
    }
    if (cands.isNotEmpty) {
      nodes['${cands[rng.range(1, cands.length) - 1]}']!['kind'] = 'shop';
    }
  }

  return {
    'layers': layers,
    'start': layerNodes[0][0],
    'boss': layerNodes[layers - 1][0],
    'nodes': nodes,
    'edges': edges, // forward edges only; boss id maps to an empty list
  };
}
