// game/enemies/enemy_core.dart — pure-Dart enemy brains (no Flame imports).
// Each enemy is a small state machine over a physics Body; the Flame
// components in lib/game/enemies/enemy_components.dart only draw this state.
//
// Contact with the player always deals 1 heart (spec §4). Death is handled by
// the session (fx + sfx + kill counting); cores only track hp/alive/flash.

import 'dart:math' as math;

import '../level/level_data.dart';
import '../physics.dart';
import '../tuning.dart';

enum EnemyKind { thornling, ashbat, hopper }

abstract class EnemyCore {
  final EnemyKind kind;
  final Body body;
  int hp;
  bool alive = true;

  /// Seconds of white hurt-flash remaining (render hint).
  double hurtFlash = 0;

  /// Burn DoT (Ember Fang): seconds remaining + tick accumulator.
  double burnLeft = 0;
  double _burnTick = 0;

  /// Set by the session when > 1.5 screens from the camera; skips update.
  bool sleeping = false;

  int facing = 1;

  EnemyCore({
    required this.kind,
    required double x,
    required double y,
    required double w,
    required double h,
    required this.hp,
  }) : body = Body(x: x, y: y, w: w, h: h);

  double get centerX => body.centerX;
  double get centerY => body.centerY;

  /// Advance one frame. [tileAt] queries the (mutable) level grid.
  /// Returns true if the burn DoT killed the enemy this frame.
  bool update(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    if (!alive) return false;
    hurtFlash = (hurtFlash - dt).clamp(0, 10);
    var burnKill = false;
    if (burnLeft > 0) {
      burnLeft = (burnLeft - dt).clamp(0, 10);
      _burnTick += dt;
      if (_burnTick >= 1.0) {
        _burnTick -= 1.0;
        if (damage(1)) burnKill = !alive;
      }
    }
    if (!sleeping && alive) {
      behave(dt, tileAt, playerX: playerX, playerY: playerY);
    }
    return burnKill;
  }

  /// Enemy-specific movement/AI, only called while awake and alive.
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY});

  /// Apply damage. Returns true if it landed (enemy was alive).
  bool damage(int amount) {
    if (!alive) return false;
    hp -= amount;
    hurtFlash = 0.15;
    if (hp <= 0) {
      hp = 0;
      alive = false;
    }
    return true;
  }

  /// AABB overlap with an arbitrary rect.
  bool overlaps(double x, double y, double w, double h) =>
      alive &&
      body.left < x + w &&
      body.right > x &&
      body.top < y + h &&
      body.bottom > y;

  bool overlapsBody(Body other) =>
      overlaps(other.x, other.y, other.w, other.h);
}

/// Thornling — ground patroller. Walks a platform, turns at walls and ledges.
class ThornlingCore extends EnemyCore {
  static const double speed = 30;

  ThornlingCore({required super.x, required super.y})
      : super(kind: EnemyKind.thornling, w: 24, h: 22, hp: 6);

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    body.vx = facing * speed;
    body.vy += kGravity * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt);
    // Turn at walls.
    if (body.hitWall) {
      facing = -facing;
      return;
    }
    // Turn at ledges: probe the tile below the leading edge.
    if (body.onGround) {
      final aheadX = facing > 0 ? body.right + 1 : body.left - 1;
      final tx = (aheadX / kTileSize).floor();
      final ty = ((body.bottom + 1) / kTileSize).floor();
      final below = tileAt(tx, ty);
      final walkable = below == TileKind.solid ||
          below == TileKind.crackedWall ||
          below == TileKind.platform;
      if (!walkable) facing = -facing;
    }
  }
}

/// Ashbat — kinematic sine-wave flyer around its spawn point.
class AshbatCore extends EnemyCore {
  static const double amplitude = 24;
  static const double patrolHalf = 36; // horizontal sway around spawn
  final double anchorX, anchorY;
  double t = 0;

  AshbatCore({required super.x, required super.y})
      : anchorX = x,
        anchorY = y,
        super(kind: EnemyKind.ashbat, w: 28, h: 24, hp: 4);

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    t += dt;
    final prevX = body.x;
    body.x = anchorX + math.sin(t * 1.1) * patrolHalf;
    body.y = anchorY + math.sin(t * 2.4) * amplitude;
    facing = body.x >= prevX ? 1 : -1;
  }
}

/// Hopper — sits still, hops toward the player when within 6 tiles.
class HopperCore extends EnemyCore {
  static const double aggroRange = 6 * kTileSize;
  static const double hopVy = 210;
  static const double hopVx = 62;
  double hopCooldown = 0;
  bool get airborne => !body.onGround;

  HopperCore({required super.x, required super.y})
      : super(kind: EnemyKind.hopper, w: 24, h: 22, hp: 4) {
    body.onGround = true;
  }

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    hopCooldown = (hopCooldown - dt).clamp(0, 10);
    final grounded = body.onGround || groundBelow(body, tileAt);
    if (grounded && hopCooldown <= 0) {
      final dx = playerX - body.centerX;
      if (dx.abs() <= aggroRange && (playerY - body.centerY).abs() < 80) {
        facing = dx >= 0 ? 1 : -1;
        body.vy = -hopVy;
        body.vx = facing * hopVx;
        body.onGround = false;
        hopCooldown = 0.9;
      } else {
        body.vx = 0;
      }
    }
    if (grounded && body.vy >= 0 && body.onGround) body.vx = 0;
    body.vy += kGravity * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt);
  }
}
