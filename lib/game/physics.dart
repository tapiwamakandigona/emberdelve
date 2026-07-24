// game/physics.dart — AABB vs tile-grid movement. Pure Dart, headless-tested.
// Axis-separated sweep with substepping; one-way platforms collide only when
// falling onto them from above (and never while dropping through).

import 'level/level_data.dart';
import 'tuning.dart';

typedef TileQuery = TileKind Function(int tx, int ty);

bool _isSolid(TileKind t) =>
    t == TileKind.solid || t == TileKind.crackedWall;

class Body {
  double x, y; // top-left, px
  final double w, h;
  double vx = 0, vy = 0;
  bool onGround = false;
  bool hitCeiling = false;
  bool hitWall = false;

  Body({required this.x, required this.y, required this.w, required this.h});

  double get left => x;
  double get right => x + w;
  double get top => y;
  double get bottom => y + h;
  double get centerX => x + w / 2;
  double get centerY => y + h / 2;
}

int _tileLo(double v) => (v / kTileSize).floor();
int _tileHi(double v) => ((v / kTileSize).ceil() - 1);

/// Move [b] by its velocity over [dt], resolving collisions against the grid.
/// [dropThrough] lets the body pass one-way platforms (down+jump input).
void integrate(Body b, double dt, TileQuery tileAt,
    {bool dropThrough = false}) {
  b.onGround = false;
  b.hitCeiling = false;
  b.hitWall = false;

  // Substep so fast bodies can't tunnel through a tile.
  final maxDisp =
      (b.vx.abs() > b.vy.abs() ? b.vx.abs() : b.vy.abs()) * dt;
  final steps = (maxDisp / (kTileSize / 2)).ceil().clamp(1, 8);
  final sdt = dt / steps;

  for (var i = 0; i < steps; i++) {
    _stepX(b, sdt, tileAt);
    _stepY(b, sdt, tileAt, dropThrough);
  }
}

void _stepX(Body b, double dt, TileQuery tileAt) {
  final dx = b.vx * dt;
  if (dx == 0) return;
  b.x += dx;
  final ty0 = _tileLo(b.top + 0.01), ty1 = _tileHi(b.bottom - 0.01);
  if (dx > 0) {
    final tx = _tileLo(b.right - 0.001);
    for (var ty = ty0; ty <= ty1; ty++) {
      if (_isSolid(tileAt(tx, ty))) {
        b.x = tx * kTileSize - b.w;
        b.vx = 0;
        b.hitWall = true;
        return;
      }
    }
  } else {
    final tx = _tileLo(b.left + 0.001);
    for (var ty = ty0; ty <= ty1; ty++) {
      if (_isSolid(tileAt(tx, ty))) {
        b.x = (tx + 1) * kTileSize;
        b.vx = 0;
        b.hitWall = true;
        return;
      }
    }
  }
}

void _stepY(Body b, double dt, TileQuery tileAt, bool dropThrough) {
  final dy = b.vy * dt;
  if (dy == 0) return;
  final prevBottom = b.bottom;
  b.y += dy;
  final tx0 = _tileLo(b.left + 0.01), tx1 = _tileHi(b.right - 0.01);
  if (dy > 0) {
    final ty = _tileLo(b.bottom - 0.001);
    for (var tx = tx0; tx <= tx1; tx++) {
      final t = tileAt(tx, ty);
      final landOnSolid = _isSolid(t);
      final tileTop = ty * kTileSize;
      final landOnPlatform = t == TileKind.platform &&
          !dropThrough &&
          prevBottom <= tileTop + 0.01;
      if (landOnSolid || landOnPlatform) {
        b.y = tileTop - b.h;
        b.vy = 0;
        b.onGround = true;
        return;
      }
    }
  } else {
    final ty = _tileLo(b.top + 0.001);
    for (var tx = tx0; tx <= tx1; tx++) {
      if (_isSolid(tileAt(tx, ty))) {
        b.y = (ty + 1) * kTileSize;
        b.vy = 0;
        b.hitCeiling = true;
        return;
      }
    }
  }
}

/// True when the body is standing on ground right now (probe 1px down).
bool groundBelow(Body b, TileQuery tileAt) {
  final ty = _tileLo(b.bottom + 0.5);
  final tx0 = _tileLo(b.left + 0.01), tx1 = _tileHi(b.right - 0.01);
  final onTileTop = (b.bottom % kTileSize) < 1.0;
  for (var tx = tx0; tx <= tx1; tx++) {
    final t = tileAt(tx, ty);
    if (_isSolid(t)) return true;
    if (t == TileKind.platform && onTileTop) return true;
  }
  return false;
}

/// Hazard contact: any spikes/fire tile overlapping a slightly shrunken box.
bool touchesHazard(Body b, TileQuery tileAt) {
  const inset = 2.0;
  final tx0 = _tileLo(b.left + inset), tx1 = _tileHi(b.right - inset);
  final ty0 = _tileLo(b.top + inset), ty1 = _tileHi(b.bottom - inset);
  for (var ty = ty0; ty <= ty1; ty++) {
    for (var tx = tx0; tx <= tx1; tx++) {
      final t = tileAt(tx, ty);
      if (t == TileKind.spikes || t == TileKind.fire) return true;
    }
  }
  return false;
}
