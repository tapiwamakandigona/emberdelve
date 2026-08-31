// chute_trap_test.dart — no level may contain a 1-wide chute trap.
//
// Found by the 2026-08-31 playthrough probe: w1_l4's Cinder Steps had
// 1-tile-wide, 3-4 tile deep slots between the staircase towers. Slip off a
// tower top and you were standing in a pit whose only exit was a
// frame-perfect wall-hugging double jump (the col-59 slot needed rise 6
// forward — beyond the rise-4 double-jump budget entirely). The casual bot
// stalled there for the rest of a 300s run on every seed; a phone player
// would fare no better. The reachability test never caught it because the
// fill only asks "can you get TO each target", not "can you get back OUT of
// every standable cell".
//
// Rule: a cell the player can stand in must not sit at the bottom of a
// 1-wide chute (solid on both sides, open above) 3 or more tiles deep.
// 2-deep slots are fine: a single jump (rise 4 > depth 2 + headroom) clears
// them comfortably.
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
    test('$id has no 1-wide chute traps', () {
      final g = loadGrid(id);
      final h = g.length, w = g[0].length;
      // Solid = walls and breakables ('B' can be standing-room BEFORE it is
      // broken, and broken-open chutes are exactly how you fall in).
      bool solid(int x, int y) {
        if (x < 0 || x >= w || y < 0 || y >= h) return true;
        final t = g[y][x];
        return t == '#' || t == 'B';
      }

      final traps = <String>[];
      for (var x = 1; x < w - 1; x++) {
        for (var y = 1; y < h - 1; y++) {
          if (solid(x, y) || !solid(x, y + 1)) continue;
          // (x, y) is the lowest standing cell in this column; measure the
          // 1-wide chute above it.
          var depth = 0;
          var yy = y;
          while (yy >= 0 &&
              !solid(x, yy) &&
              solid(x - 1, yy) &&
              solid(x + 1, yy)) {
            depth++;
            yy--;
          }
          if (depth >= 3) traps.add('col $x row $y depth $depth');
          break;
        }
      }
      expect(traps, isEmpty,
          reason: '$id: 1-wide chute trap(s) a casual player cannot escape: '
              '${traps.join('; ')}');
    });
  }
}
