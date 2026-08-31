// Collectible reachability: every chest, secret, feather, coin, campfire
// and exit in every shipped level must be reachable with the player's real
// movement budget. The runner-bot tests prove the DOOR is reachable;
// nothing proved the collectibles were — and alpha.5 shipped sky-vault
// secret rooms 16px tall for a 20px body, so every sky-vault secret was
// physically unenterable and the "all chests" medal impossible on four
// levels.
//
// Model (mirrors tool/reachability_lint.py; budgets verified empirically
// 2026-07-26):
//   * a standing double-jump lands on a ledge up to 4 rows above the feet
//   * airborne horizontal reach ~6 columns; falls are unbounded
//   * the body is taller than one 16px tile: a cell is passable only with
//     head clearance above it
//   * cracked walls are breakable, so they are passable and standable-on
// Every move is collision-checked per cell, so the fill never reaches
// anything a player could not; exotic-but-legal routes may be missed, so a
// failure here means "review the geometry", and has so far always meant
// "the geometry is wrong".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const rise = 4; // usable double-jump rise, in tile rows
const reach = 6; // airborne horizontal reach, in columns

const levels = [
  'w1_l1', 'w1_l2', 'w1_l3', 'w1_l4', 'w1_l5', 'w1_boss',
  'w2_l1', 'w2_l2', 'w2_l3', 'w2_l4', 'w2_l5', 'w2_boss',
];

List<String> loadGrid(String id) {
  final rows = File('assets/levels/$id.txt')
      .readAsLinesSync()
      .where((l) => !l.startsWith('meta:'))
      .toList();
  final w = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  return [for (final r in rows) r.padRight(w, '.')];
}

List<String> unreachableTargets(List<String> g) {
  final h = g.length, w = g[0].length;

  String tile(int x, int y) =>
      (x < 0 || x >= w || y < 0 || y >= h) ? '#' : g[y][x];
  bool passable(int x, int y) => tile(x, y) != '#' && tile(x, y - 1) != '#';
  bool standable(int x, int y) {
    final below = tile(x, y + 1);
    return passable(x, y) && (below == '#' || below == '=' || below == 'B');
  }

  late final int startX, startY;
  outer:
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (g[y][x] == 'P') {
        startX = x;
        startY = y;
        break outer;
      }
    }
  }

  final seen = <int>{};
  final touched = <int>{};
  int key(int x, int y) => y * w + x;
  void touch(int x, int y) {
    touched.add(key(x, y));
    if (y > 0) touched.add(key(x, y - 1));
  }

  final frontier = <List<int>>[
    [startX, startY]
  ];
  while (frontier.isNotEmpty) {
    final cell = frontier.removeLast();
    final sx = cell[0], sy = cell[1];
    if (seen.contains(key(sx, sy)) || !passable(sx, sy)) continue;
    seen.add(key(sx, sy));
    touch(sx, sy);
    for (var r1 = 0; r1 <= rise; r1++) {
      var ok = true;
      for (var dy = 1; dy <= r1; dy++) {
        if (!passable(sx, sy - dy)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      for (var r2 = 0; r2 <= rise - r1; r2++) {
        final driftY = sy - r1;
        final apexTarget = driftY - r2;
        for (final dir in [-1, 1]) {
          for (var drift = 0; drift <= reach; drift++) {
            var ax = sx, blocked = false;
            for (var dx = 1; dx <= drift; dx++) {
              ax = sx + dir * dx;
              if (!passable(ax, driftY)) {
                blocked = true;
                break;
              }
              touch(ax, driftY);
            }
            if (blocked) continue;
            var ok2 = true;
            for (var yy = driftY - 1; yy >= apexTarget; yy--) {
              if (!passable(ax, yy)) {
                ok2 = false;
                break;
              }
              touch(ax, yy);
            }
            if (!ok2) continue;
            var fy = apexTarget;
            while (fy < h) {
              if (standable(ax, fy)) {
                if (!seen.contains(key(ax, fy))) frontier.add([ax, fy]);
                break;
              }
              if (!passable(ax, fy + 1)) break;
              touch(ax, fy + 1);
              fy++;
            }
          }
        }
      }
    }
  }

  const targets = {'c', 'a', 'f', 'h', 'C', 'X', 'K', 'E'};
  final missed = <String>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final ch = g[y][x];
      if (!targets.contains(ch)) continue;
      final near = [
        key(x, y),
        if (y > 0) key(x, y - 1),
        if (y < h - 1) key(x, y + 1),
        if (x > 0) key(x - 1, y),
        if (x < w - 1) key(x + 1, y),
      ];
      if (!near.any(touched.contains)) missed.add('$ch@($x,$y)');
    }
  }
  return missed;
}

void main() {
  for (final id in levels) {
    test('$id: every collectible is reachable', () {
      final missed = unreachableTargets(loadGrid(id));
      expect(missed, isEmpty,
          reason: '$id has unreachable collectibles: ${missed.join(', ')} '
              '— run tool/reachability_lint.py for the same result with '
              'faster iteration');
    });
  }
}
