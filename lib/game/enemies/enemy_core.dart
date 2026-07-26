// game/enemies/enemy_core.dart — pure-Dart enemy brains (no Flame imports).
// Each enemy is a small state machine over a physics Body; the Flame
// components in lib/game/enemies/enemy_components.dart only draw this state.
//
// Contact with the player always deals 1 heart (spec §4). Death is handled by
// the session (fx + sfx + kill counting); cores only track hp/alive/flash.

import 'dart:math' as math;

import '../level/level_data.dart';
import '../difficulty.dart';
import '../physics.dart';
import '../tuning.dart';

enum EnemyKind {
  thornling,
  ashbat,
  hopper,
  emberTotem,
  rotshield,
  groveGolem,
  kilnGolem,
  sootCreeper,
  cinderDiver,
  pyreWisp,
  slagHound,
}

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

  /// Difficulty scaling (Stage 2): set once by the session at spawn.
  /// Scales behaviour only (speed / reaction windows / detection) — never
  /// hp or damage, so combat mastery transfers between modes.
  DifficultyMods mods = DifficultyMods.medium;

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

  /// Whether an attack (melee swing / apple) arriving from (fromX, fromY) is
  /// blocked instead of dealing damage. Base enemies never block; Rotshield
  /// blocks its shielded front side.
  bool blocksHit({required double fromX, required double fromY}) => false;

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

/// Thornling — ground patroller. Walks a platform, turns at walls and
/// ledges. Stage 2 AI: when the player is close, ahead, and at similar
/// height, it breaks into a hunting burst (1.5x) — patrol routes stop
/// being safe to stand next to, but it still respects ledges.
class ThornlingCore extends EnemyCore {
  static const double speed = 30;
  static const double huntRange = 4 * kTileSize;
  static const double huntBoost = 1.5;

  ThornlingCore({required super.x, required super.y})
      : super(kind: EnemyKind.thornling, w: 24, h: 22, hp: 6);

  /// Render hint: hunting burst active.
  bool hunting = false;

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    final dx = playerX - centerX;
    hunting = dx.sign == facing.toDouble().sign &&
        dx.abs() <= huntRange * mods.aggro &&
        (playerY - centerY).abs() < 40;
    body.vx = facing * speed * mods.speed * (hunting ? huntBoost : 1);
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
  static const double leadSeconds = 0.45; // Stage 2 AI: leads moving targets
  double hopCooldown = 0;
  double _lastPlayerX = double.nan;
  bool get airborne => !body.onGround;

  HopperCore({required super.x, required super.y})
      : super(kind: EnemyKind.hopper, w: 24, h: 22, hp: 4) {
    body.onGround = true;
  }

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    hopCooldown = (hopCooldown - dt).clamp(0, 10);
    // Stage 2 AI: estimate player velocity from successive frames so hops
    // land where the player is GOING, not where they were.
    final playerVx =
        _lastPlayerX.isNaN ? 0.0 : (playerX - _lastPlayerX) / dt;
    _lastPlayerX = playerX;
    final grounded = body.onGround || groundBelow(body, tileAt);
    if (grounded && hopCooldown <= 0) {
      final predictedX =
          playerX + playerVx.clamp(-kRunSpeed, kRunSpeed) * leadSeconds;
      final dx = predictedX - body.centerX;
      if ((playerX - body.centerX).abs() <= aggroRange * mods.aggro &&
          (playerY - body.centerY).abs() < 80) {
        facing = dx >= 0 ? 1 : -1;
        body.vy = -hopVy;
        body.vx = facing * hopVx * mods.speed;
        body.onGround = false;
        hopCooldown = 0.9 * mods.telegraph;
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

/// Ember Totem — stationary ranged spitter. When the player is within range
/// AND has line of sight, it aims and requests an ember shot (the session
/// owns the projectile pool). Cooldown between shots; never moves.
class EmberTotemCore extends EnemyCore {
  static const double range = 8 * kTileSize;
  static const double cooldown = 2.2;

  double _cd = 1.0; // spawn grace so it never insta-shoots off-screen players
  ({double dx, double dy})? _pendingShot;

  EmberTotemCore({required super.x, required super.y})
      : super(kind: EnemyKind.emberTotem, w: 20, h: 30, hp: 5) {
    body.onGround = true; // stationary; physics never integrates it
  }

  /// The session consumes at most one aimed shot request per frame.
  ({double dx, double dy})? takeShotRequest() {
    final s = _pendingShot;
    _pendingShot = null;
    return s;
  }

  /// Seconds until the next shot is possible (render layer: charge glow).
  double get cooldownLeft => _cd;

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    _cd = (_cd - dt).clamp(0, 10);
    final dx = playerX - centerX, dy = playerY - centerY;
    facing = dx >= 0 ? 1 : -1;
    if (_cd > 0) return;
    final r = range * mods.aggro;
    final distSq = dx * dx + dy * dy;
    if (distSq > r * r || distSq < 1) return;
    if (!_lineOfSight(tileAt, playerX, playerY)) return;
    final dist = math.sqrt(distSq);
    _pendingShot = (dx: dx / dist, dy: dy / dist);
    _cd = cooldown * mods.telegraph;
  }

  /// Sample the muzzle→player segment every 4px; solid tiles block sight.
  bool _lineOfSight(TileQuery tileAt, double px, double py) {
    final x0 = centerX, y0 = body.top + 6;
    final dx = px - x0, dy = py - y0;
    final dist = math.sqrt(dx * dx + dy * dy);
    final steps = (dist / 4).ceil().clamp(1, 64);
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final tx = ((x0 + dx * t) / kTileSize).floor();
      final ty = ((y0 + dy * t) / kTileSize).floor();
      final tile = tileAt(tx, ty);
      if (tile == TileKind.solid || tile == TileKind.crackedWall) return false;
    }
    return true;
  }
}

/// Rotshield — slow ground patroller with a front shield. Blocks melee and
/// apples arriving from its facing side; vulnerable from behind and above.
/// Stage 2 AI: it is no longer oblivious — linger behind its back for a
/// beat and it turns its shield on you (guardTurnDelay of free backstab
/// time remains, longer on Easy).
class RotshieldCore extends EnemyCore {
  static const double speed = 18;
  static const double guardRange = 3 * kTileSize;
  static const double guardTurnDelay = 0.6;
  double _backstabTimer = 0;

  RotshieldCore({required super.x, required super.y})
      : super(kind: EnemyKind.rotshield, w: 26, h: 24, hp: 6);

  @override
  bool blocksHit({required double fromX, required double fromY}) {
    if (fromY < body.top - 2) return false; // attacks from above get through
    final side = fromX >= centerX ? 1 : -1;
    return side == facing; // shield covers the facing side only
  }

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    // Stage 2 AI guard turn: player close behind for guardTurnDelay ->
    // swing the shield around to face them.
    final dx = playerX - centerX;
    final behind = dx.sign != facing.toDouble().sign;
    if (behind &&
        dx.abs() <= guardRange * mods.aggro &&
        (playerY - centerY).abs() < 48) {
      _backstabTimer += dt;
      if (_backstabTimer >= guardTurnDelay * mods.telegraph) {
        facing = -facing;
        _backstabTimer = 0;
      }
    } else {
      _backstabTimer = 0;
    }
    body.vx = facing * speed * mods.speed;
    body.vy += kGravity * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt);
    if (body.hitWall) {
      facing = -facing;
      return;
    }
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

/// Soot Creeper (World 2) — heavy soot-caked walker. Tankier and a touch
/// faster than a Thornling, turns at walls but NOT at ledges: it walks
/// straight off and keeps crawling wherever it lands. Reads as "relentless".
class SootCreeperCore extends EnemyCore {
  static const double speed = 34;

  SootCreeperCore({required super.x, required super.y})
      : super(kind: EnemyKind.sootCreeper, w: 24, h: 22, hp: 9);

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    body.vx = facing * speed * mods.speed;
    body.vy += kGravity * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt);
    if (body.hitWall) facing = -facing;
    // Deliberately no ledge probe: creepers drop off edges.
  }
}

/// Cinder Diver (World 2) — hovers at its anchor; when the player crosses
/// underneath it telegraphs (shudder), then dives at them, and climbs back
/// to the anchor afterwards. Fragile but scary in vertical rooms.
class CinderDiverCore extends EnemyCore {
  static const double aggroHalfWidth = 3 * kTileSize;
  static const double telegraphTime = 0.4;
  static const double diveSpeed = 200;
  static const double climbSpeed = 55;
  static const double cooldown = 1.2;

  final double anchorX, anchorY;
  double t = 0;

  /// idle -> telegraph -> dive -> climb -> idle
  String phase = 'idle';
  double phaseLeft = 0;
  double _dvx = 0, _dvy = 0;

  CinderDiverCore({required super.x, required super.y})
      : anchorX = x,
        anchorY = y,
        super(kind: EnemyKind.cinderDiver, w: 28, h: 24, hp: 3);

  /// Render hint: shudder amplitude while telegraphing.
  bool get telegraphing => phase == 'telegraph';

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    t += dt;
    switch (phase) {
      case 'idle':
        // Gentle hover around the anchor.
        body.x = anchorX + math.sin(t * 1.3) * 6;
        body.y = anchorY + math.sin(t * 2.1) * 4;
        facing = playerX >= centerX ? 1 : -1;
        final below = playerY > centerY + kTileSize;
        if (below && (playerX - centerX).abs() < aggroHalfWidth * mods.aggro) {
          phase = 'telegraph';
          phaseLeft = telegraphTime * mods.telegraph;
        }
      case 'telegraph':
        phaseLeft -= dt;
        if (phaseLeft <= 0) {
          final dx = playerX - centerX, dy = playerY - centerY;
          final d = math.sqrt(dx * dx + dy * dy).clamp(1.0, 9999.0);
          _dvx = dx / d * diveSpeed * mods.speed;
          _dvy = (dy / d * diveSpeed * mods.speed).abs(); // always downward
          phase = 'dive';
          phaseLeft = 1.0; // max dive time
        }
      case 'dive':
        phaseLeft -= dt;
        body.vx = _dvx;
        body.vy = _dvy;
        integrate(body, dt, tileAt);
        facing = _dvx >= 0 ? 1 : -1;
        if (body.onGround || body.hitWall || phaseLeft <= 0) {
          phase = 'climb';
          phaseLeft = cooldown * mods.telegraph;
        }
      case 'climb':
        final dx = anchorX - body.x, dy = anchorY - body.y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < 3) {
          body.x = anchorX;
          body.y = anchorY;
          phase = 'idle';
        } else {
          body.x += dx / d * climbSpeed * dt;
          body.y += dy / d * climbSpeed * dt;
        }
        facing = dx >= 0 ? 1 : -1;
    }
  }
}

/// Pyre Wisp (Stage 2) — a glowing spirit flyer with a real hunting brain:
/// bobs near its anchor until the player enters its aggro bubble, then
/// drifts straight at them (kinematic, passes through terrain like the
/// Ashbat precedent); breaks off and floats home when the player escapes.
/// Fragile — the counterplay is one confident swing, not evasion.
class PyreWispCore extends EnemyCore {
  static const double aggroRange = 7 * kTileSize;
  static const double chaseSpeed = 46;
  static const double returnSpeed = 30;

  final double anchorX, anchorY;
  double t = 0;

  PyreWispCore({required super.x, required super.y})
      : anchorX = x,
        anchorY = y,
        super(kind: EnemyKind.pyreWisp, w: 26, h: 22, hp: 3);

  /// Render hint: actively chasing (brighter glow).
  bool chasing = false;

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    t += dt;
    final dx = playerX - centerX, dy = playerY - centerY;
    final dist = math.sqrt(dx * dx + dy * dy);
    double vx = 0, vy = 0;
    chasing = dist <= aggroRange * mods.aggro && dist > 1;
    if (chasing) {
      final sp = chaseSpeed * mods.speed;
      vx = dx / dist * sp;
      vy = dy / dist * sp;
    } else {
      final hx = anchorX - body.x, hy = anchorY - body.y;
      final hd = math.sqrt(hx * hx + hy * hy);
      if (hd > 2) {
        vx = hx / hd * returnSpeed;
        vy = hy / hd * returnSpeed;
      }
    }
    body.x += vx * dt;
    body.y += (vy + math.sin(t * 3) * 8) * dt;
    if (vx.abs() > 1) facing = vx >= 0 ? 1 : -1;
  }
}

/// Slag Hound (Stage 2) — patrols like a Thornling, but when the player is
/// near on similar footing it stops, telegraphs (crouch pose, reaction
/// window scales with difficulty), then CHARGES until it hits a wall,
/// reaches a ledge, or times out; then it must cool down. The telegraph is
/// the tell — dash through or jump it, never trade.
class SlagHoundCore extends EnemyCore {
  static const double patrolSpeed = 26;
  static const double chargeSpeed = 105;
  static const double aggroRange = 6 * kTileSize;
  static const double telegraphTime = 0.35;
  static const double maxChargeTime = 1.2;
  static const double chargeCooldown = 1.1;

  double _telegraph = 0, _chargeLeft = 0, _cooldown = 0;
  bool get telegraphing => _telegraph > 0;
  bool get charging => _chargeLeft > 0;

  SlagHoundCore({required super.x, required super.y})
      : super(kind: EnemyKind.slagHound, w: 26, h: 22, hp: 5);

  bool _ledgeAhead(TileQuery tileAt) {
    final aheadX = facing > 0 ? body.right + 1 : body.left - 1;
    final tx = (aheadX / kTileSize).floor();
    final ty = ((body.bottom + 1) / kTileSize).floor();
    final below = tileAt(tx, ty);
    return below != TileKind.solid &&
        below != TileKind.crackedWall &&
        below != TileKind.platform;
  }

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    _cooldown = (_cooldown - dt).clamp(0, 10);

    if (_telegraph > 0) {
      // Locked crouch: face the target, give the reaction window.
      _telegraph -= dt;
      body.vx = 0;
      if (_telegraph <= 0) _chargeLeft = maxChargeTime;
    } else if (_chargeLeft > 0) {
      _chargeLeft -= dt;
      body.vx = facing * chargeSpeed * mods.speed;
    } else {
      // Patrol; consider a new charge.
      body.vx = facing * patrolSpeed * mods.speed;
      final dx = playerX - centerX;
      if (_cooldown <= 0 &&
          body.onGround &&
          dx.abs() <= aggroRange * mods.aggro &&
          (playerY - centerY).abs() < 48) {
        facing = dx >= 0 ? 1 : -1;
        _telegraph = telegraphTime * mods.telegraph;
        body.vx = 0;
      }
    }

    body.vy += kGravity * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt);

    // Walls and ledges end a charge (hounds never suicide off edges).
    if (body.hitWall || (body.onGround && _ledgeAhead(tileAt))) {
      if (_chargeLeft > 0) {
        _chargeLeft = 0;
        _cooldown = chargeCooldown * mods.telegraph;
      }
      facing = -facing;
    }
  }
}
