// secret_vault_test.dart — every secret-chest vault must be leavable.
//
// Found by the 2026-08-31 probe sweep: w2_l3 TIMED OUT on every seed with
// the bot pinned 177 s at col 91. Its loot vault broke the established
// `B.X.B` grammar — cracked walls on BOTH lateral sides — and shipped as
// `B.cXc.#`: breakable on the entry side, solid on the exit side, under a
// solid roof. Any player who breaks in and moves right is stuck re-walking
// the same wall; the greedy probe never escaped.
//
// Rule: for every secret chest ('X'), scan left and right along its
// standing row. If the first barrier within 8 tiles on a side is 2-tall
// (solid at the row and the row above — a 1-tall step is a hop-out), then
// that barrier's tile at the chest's row must be a cracked wall 'B', not
// bare '#'. Both sides: vaults are entered from either direction and the
// direction of travel is always one of them.
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
    test('$id secret vaults are leavable on both sides', () {
      final g = loadGrid(id);
      final h = g.length, w = g[0].length;
      bool solid(int x, int y) {
        if (x < 0 || x >= w || y < 0 || y >= h) return true;
        final t = g[y][x];
        return t == '#' || t == 'B';
      }

      final trapped = <String>[];
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (g[y][x] != 'X') continue;
          for (final dir in [-1, 1]) {
            for (var d = 1; d <= 8; d++) {
              final xx = x + d * dir;
              if (xx < 0 || xx >= w) break; // level edge, not a vault wall
              if (!solid(xx, y)) continue;
              // 1-tall step: hop-out escape, not a trap.
              if (!solid(xx, y - 1)) break;
              if (g[y][xx] != 'B') {
                trapped.add('$id X@($x,$y): solid ${dir < 0 ? "left" : "right"}'
                    ' wall at ($xx,$y) is not breakable');
              }
              break; // judged the first barrier; done with this side
            }
          }
        }
      }
      expect(trapped, isEmpty,
          reason: 'one-way secret vaults trap players:\n${trapped.join('\n')}');
    });
  }
}
