// totem_squeeze_test.dart — no ember totem may body-block a squeeze pocket.
//
// Found by the 2026-08-31 wipe probe (per-hit attribution): three levels
// parked a stationary totem 1 free tile from a >=2-tall wall at its own
// standing row — w1_l5 O@44 vs the col 46-48 pillar, w2_l4 O@50 vs the col
// 48 block, w2_l5 O@94 vs the col 91-92 block. A player squeezing along the
// ground route lands in that 1-wide pocket, takes unavoidable contact
// damage (totems deal 1 heart on touch and never move), and re-takes it on
// every life. The probe logged the same pocket hit on every seed in all
// three levels; hearts (alpha.11) softened but could not fix it.
//
// Rule: at a totem's standing row, the free gap between its tile and the
// nearest >=2-tall wall on either side must be >= 2 tiles. The scan stops
// early at a drop (no floor under the free tile — the pocket opens
// downward) or at a 1-tall step (hop-out escape), because neither can trap.
// Scan is capped at 8 tiles: beyond its own range a totem guards nothing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

void main() {
  for (final id in levels) {
    test('$id has no totem squeeze pockets', () {
      final g = loadGrid(id);
      final h = g.length, w = g[0].length;
      // Solid = walls and breakables (a totem pocket behind an unbroken 'B'
      // is still a pocket the moment the wall breaks).
      bool solid(int x, int y) {
        if (x < 0 || x >= w || y < 0 || y >= h) return true;
        final t = g[y][x];
        return t == '#' || t == 'B';
      }

      // Floor = anything standable: solid or a one-way platform.
      bool floor(int x, int y) => solid(x, y) || (y >= 0 && y < h && x >= 0 && x < w && g[y][x] == '=');

      final pockets = <String>[];
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (g[y][x] != 'O') continue;
          for (final dir in [-1, 1]) {
            for (var d = 1; d <= 8; d++) {
              final xx = x + d * dir;
              if (xx < 0 || xx >= w) break; // level edge, not a wall
              final tall = solid(xx, y) && solid(xx, y - 1);
              if (tall) {
                final gap = d - 1;
                if (gap < 2) {
                  pockets.add('O@($x,$y) ${dir < 0 ? 'left' : 'right'} wall '
                      'at x=$xx leaves a $gap-tile pocket');
                }
                break;
              }
              if (solid(xx, y)) break; // 1-tall step: hop-out escape
              if (!floor(xx, y + 1)) break; // drop: pocket opens downward
            }
          }
        }
      }
      expect(pockets, isEmpty,
          reason: '$id: a stationary totem flush against a tall wall deals '
              'unavoidable contact damage in the pocket:\n${pockets.join('\n')}');
    });
  }
}
