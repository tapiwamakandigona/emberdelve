// game/enemies/boss_core.dart — the bosses. Pure Dart, headless-testable.
//
// [BossCore] holds what every boss shares: the telegraph -> attack -> recover
// state machine, the hazard list the session collides with the player, and the
// exit-door lock. Each boss subclass owns its own moveset.
//
// World 2's boss used to BE the Grove Golem with a different tint (the arena
// was even a byte-for-byte copy, fixed in alpha.5) — owner-reported. The Kiln
// Golem below now has its own vocabulary: floor-level heat waves you jump, a
// marching geyser cascade you outrun, a committed charge with a punish window,
// and (enraged) magma bombs that leave burning pools shrinking the safe floor.
//
// A big, slow guardian fought in a fixed arena. Three phases by hp:
//   P1 (hp > 2/3): ground slam — a shockwave races along the floor.
//   P2 (hp > 1/3): + root spikes — warning marks under the player, then
//                  spikes erupt after a beat.
//   P3:            faster everything + lobbed rock arcs.
// Every attack is telegraphed (BossState.telegraph) so the render layer can
// flash/animate a warning before any hazard exists. The core owns its hazard
// entities; the session collides them with the player and locks the exit
// door until the golem is dead.

import 'dart:math' as math;

import '../level/level_data.dart';
import '../physics.dart';
import '../tuning.dart';
import 'enemy_core.dart';

enum BossState { idle, telegraph, attack, recover }

enum BossAttack {
  // Grove Golem (World 1)
  slam,
  rootSpikes,
  rockLob,
  // Kiln Golem (World 2)
  heatWave,
  geyserCascade,
  charge,
  magmaBombs,
}

enum BossHazardKind {
  shockwave,
  rootSpike,
  rock,
  /// Kiln: a wall of flame that races along the floor — too tall to walk or
  /// roll through, low enough to jump.
  heatWave,
  /// Kiln: a floor vent that marks the ground, then erupts in a tall column.
  geyser,
  /// Kiln: a lobbed bomb; leaves a [magmaPool] where it lands.
  magmaBomb,
  /// Kiln: a burning patch of floor that lingers and denies ground.
  magmaPool,
}

class BossHazard {
  final BossHazardKind kind;
  double x, y; // anchor: bottom-center on the ground
  double vx, vy;
  double life; // seconds left (shockwave/rock) or rise-time left (spike)
  double warning; // rootSpike: seconds of harmless warning mark remaining
  bool active = true;

  BossHazard(this.kind, this.x, this.y,
      {this.vx = 0, this.vy = 0, this.life = 3, this.warning = 0});

  bool get harmful => active && warning <= 0;

  /// AABB (px) used for player collision while harmful.
  ({double x, double y, double w, double h}) get rect => switch (kind) {
        BossHazardKind.shockwave => (x: x - 8, y: y - 10, w: 16.0, h: 10.0),
        BossHazardKind.rootSpike => (x: x - 5, y: y - 15, w: 10.0, h: 15.0),
        BossHazardKind.rock => (x: x - 5, y: y - 10, w: 10.0, h: 10.0),
        // 22px tall: a 2-tile jump (kJumpSpeed clears 2.3 tiles) clears it,
        // a roll (kRollIFrames aside) does not.
        BossHazardKind.heatWave => (x: x - 9, y: y - 22, w: 18.0, h: 22.0),
        BossHazardKind.geyser => (x: x - 7, y: y - 34, w: 14.0, h: 34.0),
        BossHazardKind.magmaBomb => (x: x - 5, y: y - 10, w: 10.0, h: 10.0),
        BossHazardKind.magmaPool => (x: x - 13, y: y - 7, w: 26.0, h: 7.0),
      };
}

/// What every boss shares: the telegraphed state machine, its hazard list, and
/// the collision helpers the session uses to hurt the player and to keep the
/// exit door locked. Subclasses choose their attacks and how the hazards move.
abstract class BossCore extends EnemyCore {
  BossState bossState = BossState.idle;
  double stateTimer = 1.2; // opening grace before the first telegraph
  int attackCycle = 0;
  final List<BossHazard> hazards = [];
  /// Hazards spawned by other hazards (a bomb landing becomes a pool) — kept
  /// separate so [updateHazards] never mutates the list it is iterating.
  final List<BossHazard> _pending = [];

  BossCore({
    required super.kind,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    required super.hp,
  });

  /// Full health, per boss (the HUD bar needs it without a type switch).
  int get maxHpValue;

  /// The attack the boss is winding up. Subclasses set it at telegraph time.
  BossAttack get pendingAttack;

  /// 1, 2 or 3 (phase thresholds at 2/3 and 1/3 hp).
  int get phase {
    final max = maxHpValue;
    if (hp * 3 > max * 2) return 1;
    if (hp * 3 > max) return 2;
    return 3;
  }

  /// Queue a hazard from inside a hazard update (bomb -> pool).
  void spawnHazard(BossHazard h) => _pending.add(h);

  /// Shared hazard integration for the kinds every boss can use, plus the
  /// per-kind hooks. Subclasses call this from [behave].
  void updateHazards(double dt, TileQuery tileAt) {
    for (final h in hazards) {
      if (!h.active) continue;
      if (h.warning > 0) {
        // A warning mark is harmless and does not move.
        h.warning -= dt;
        continue;
      }
      advanceHazard(h, dt, tileAt);
    }
    if (_pending.isNotEmpty) {
      hazards.addAll(_pending);
      _pending.clear();
    }
    hazards.removeWhere((h) => !h.active);
  }

  /// Move/expire one harmful hazard. Overridden per boss.
  void advanceHazard(BossHazard h, double dt, TileQuery tileAt);

  /// True if any harmful hazard overlaps the given AABB.
  bool hazardHits(Body b) {
    for (final h in hazards) {
      if (!h.harmful) continue;
      final r = h.rect;
      if (b.left < r.x + r.w &&
          b.right > r.x &&
          b.top < r.y + r.h &&
          b.bottom > r.y) {
        return true;
      }
    }
    return false;
  }

  /// Nearest harmful hazard x (used as knockback source), else own center.
  double hazardSourceX(Body b) {
    for (final h in hazards) {
      if (!h.harmful) continue;
      final r = h.rect;
      if (b.left < r.x + r.w &&
          b.right > r.x &&
          b.top < r.y + r.h &&
          b.bottom > r.y) {
        return h.x == b.centerX ? h.x + 1 : h.x;
      }
    }
    return centerX;
  }

  /// Telegraph pulse hook for the renderer (0..1 while winding up).
  double get telegraphPulse => bossState == BossState.telegraph
      ? 0.5 + 0.5 * math.sin(stateTimer * 24)
      : 0;
}

class GroveGolemCore extends BossCore {
  static const int maxHp = 60;
  static const double walkSpeed = 20;

  @override
  int get maxHpValue => maxHp;

  @override
  BossAttack pendingAttack = BossAttack.slam;

  GroveGolemCore({required super.x, required super.y})
      : super(kind: EnemyKind.groveGolem, w: 44, h: 52, hp: maxHp);

  double get _speedMul => phase == 3 ? 1.6 : 1.0;
  double get _telegraphTime => phase == 3 ? 0.55 : 0.85;
  double get _idleTime => phase == 3 ? 1.1 : 1.9;

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    updateHazards(dt, tileAt);
    stateTimer -= dt;

    switch (bossState) {
      case BossState.idle:
        // Lumber toward the player.
        facing = playerX >= centerX ? 1 : -1;
        body.vx = facing * walkSpeed * _speedMul;
        body.vy += kGravity * dt;
        if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
        integrate(body, dt, tileAt);
        if (stateTimer <= 0) {
          pendingAttack = _chooseAttack();
          bossState = BossState.telegraph;
          stateTimer = _telegraphTime;
        }
      case BossState.telegraph:
        body.vx = 0;
        body.vy += kGravity * dt;
        integrate(body, dt, tileAt);
        if (stateTimer <= 0) {
          _executeAttack(playerX, playerY, tileAt);
          bossState = BossState.attack;
          stateTimer = 0.25;
        }
      case BossState.attack:
        if (stateTimer <= 0) {
          bossState = BossState.recover;
          stateTimer = phase == 3 ? 0.35 : 0.6;
        }
      case BossState.recover:
        if (stateTimer <= 0) {
          bossState = BossState.idle;
          stateTimer = _idleTime;
        }
    }
  }

  BossAttack _chooseAttack() {
    attackCycle++;
    return switch (phase) {
      1 => BossAttack.slam,
      2 => attackCycle.isEven ? BossAttack.rootSpikes : BossAttack.slam,
      _ => switch (attackCycle % 3) {
          0 => BossAttack.rockLob,
          1 => BossAttack.slam,
          _ => BossAttack.rootSpikes,
        },
    };
  }

  void _executeAttack(double playerX, double playerY, TileQuery tileAt) {
    final groundY = body.bottom;
    switch (pendingAttack) {
      case BossAttack.slam:
        // Shockwave races along the floor toward the player.
        final dir = playerX >= centerX ? 1 : -1;
        hazards.add(BossHazard(BossHazardKind.shockwave, centerX + dir * 26,
            groundY,
            vx: dir * 120 * _speedMul, life: 2.6));
        if (phase == 3) {
          // Faster phase also sends one backwards — no safe lane for free.
          hazards.add(BossHazard(BossHazardKind.shockwave,
              centerX - dir * 26, groundY,
              vx: -dir * 120 * _speedMul, life: 2.6));
        }
      case BossAttack.rootSpikes:
        // Warning marks under (and flanking) the player, then eruption.
        for (final off in const [-24.0, 0.0, 24.0]) {
          hazards.add(BossHazard(
              BossHazardKind.rootSpike, playerX + off, groundY,
              warning: phase == 3 ? 0.45 : 0.65, life: 0.7));
        }
      case BossAttack.rockLob:
        // Three arcing rocks bracketing the player's position.
        final dx = playerX - centerX;
        for (final k in const [0.75, 1.0, 1.25]) {
          hazards.add(BossHazard(
              BossHazardKind.rock, centerX, body.top + 8,
              vx: dx * k / 1.1, vy: -240, life: 4.0));
        }
      case BossAttack.heatWave:
      case BossAttack.geyserCascade:
      case BossAttack.charge:
      case BossAttack.magmaBombs:
        // Kiln Golem moveset — never chosen by _chooseAttack() here.
        break;
    }
  }

  @override
  void advanceHazard(BossHazard h, double dt, TileQuery tileAt) {
    switch (h.kind) {
      case BossHazardKind.shockwave:
        h.x += h.vx * dt;
        h.life -= dt;
        final tx = ((h.x + h.vx.sign * 8) / kTileSize).floor();
        final ty = ((h.y - 4) / kTileSize).floor();
        final t = tileAt(tx, ty);
        if (h.life <= 0 || t == TileKind.solid || t == TileKind.crackedWall) {
          h.active = false;
        }
      case BossHazardKind.rootSpike:
        h.life -= dt;
        if (h.life <= 0) h.active = false;
      case BossHazardKind.rock:
        h.vy += kGravity * dt;
        h.x += h.vx * dt;
        h.y += h.vy * dt;
        h.life -= dt;
        final tx = (h.x / kTileSize).floor();
        final ty = (h.y / kTileSize).floor();
        final t = tileAt(tx, ty);
        if (h.life <= 0 ||
            (h.vy > 0 && (t == TileKind.solid || t == TileKind.crackedWall))) {
          h.active = false;
        }
      case BossHazardKind.heatWave:
      case BossHazardKind.geyser:
      case BossHazardKind.magmaBomb:
      case BossHazardKind.magmaPool:
        // Kiln Golem hazards; the Grove Golem never spawns them.
        h.active = false;
    }
  }
}

/// Kiln Golem — the World 2 boss. Same silhouette family as the Grove Golem,
/// completely different fight. Built from the Apple Knight boss grammar the
/// alpha.5 comparison called out: every attack is a telegraph, a commit, and a
/// punish window, and each one asks a different question of the player.
///
///   heat wave     (P1+) — a flame wall races along the floor: JUMP it.
///   geyser cascade(P1+) — marked vents erupt in sequence marching toward the
///                         player: MOVE, one dodge is not enough.
///   charge        (P2+) — it commits to a dash across the arena and is stuck
///                         in a long recover afterwards: BAIT it, then punish.
///   magma bombs   (P3)  — lobbed bombs leave burning pools: the safe floor
///                         shrinks as the fight goes on.
///
/// Phase 3 is a real enrage, not just a speed multiplier: waves come in pairs
/// from both sides, cascades are longer, and the charge recovery shortens.
class KilnGolemCore extends BossCore {
  static const int maxHp = 72;
  static const double walkSpeed = 24;
  static const double chargeSpeed = 165;
  static const double waveSpeed = 108;

  @override
  int get maxHpValue => maxHp;

  @override
  BossAttack pendingAttack = BossAttack.heatWave;

  /// True while the body itself is the attack (the charge).
  bool charging = false;
  int _chargeDir = 1;
  double _chargeLeft = 0;

  KilnGolemCore({required super.x, required super.y})
      : super(kind: EnemyKind.kilnGolem, w: 44, h: 52, hp: maxHp);

  double get _speedMul => switch (phase) { 1 => 1.0, 2 => 1.2, _ => 1.45 };
  double get _telegraphTime => switch (phase) { 1 => 0.9, 2 => 0.75, _ => 0.6 };
  double get _idleTime => switch (phase) { 1 => 1.8, 2 => 1.5, _ => 1.05 };

  /// The window after a charge in which the golem is helpless. This is the
  /// fight's answer to "how do I ever hit it?" — long on purpose in P1/P2.
  double get _chargeRecover => phase == 3 ? 0.9 : 1.4;

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    updateHazards(dt, tileAt);
    stateTimer -= dt;

    switch (bossState) {
      case BossState.idle:
        facing = playerX >= centerX ? 1 : -1;
        body.vx = facing * walkSpeed * _speedMul;
        _fall(dt, tileAt);
        if (stateTimer <= 0) {
          pendingAttack = _chooseAttack();
          bossState = BossState.telegraph;
          stateTimer = _telegraphTime;
        }
      case BossState.telegraph:
        // Plants its feet and glows before every attack (render hook:
        // telegraphPulse). The charge aims itself at telegraph time, so a
        // sidestep during the wind-up beats it.
        facing = playerX >= centerX ? 1 : -1;
        body.vx = 0;
        _fall(dt, tileAt);
        if (stateTimer <= 0) {
          _executeAttack(playerX, playerY);
          bossState = BossState.attack;
          stateTimer = pendingAttack == BossAttack.charge ? 1.35 : 0.28;
        }
      case BossState.attack:
        if (charging) {
          _advanceCharge(dt, tileAt);
        } else {
          body.vx = 0;
          _fall(dt, tileAt);
        }
        if (stateTimer <= 0 || (charging && _chargeLeft <= 0)) {
          final wasCharging = charging;
          charging = false;
          body.vx = 0;
          bossState = BossState.recover;
          stateTimer = wasCharging ? _chargeRecover : (phase == 3 ? 0.4 : 0.7);
        }
      case BossState.recover:
        body.vx = 0;
        _fall(dt, tileAt);
        if (stateTimer <= 0) {
          bossState = BossState.idle;
          stateTimer = _idleTime;
        }
    }
  }

  void _fall(double dt, TileQuery tileAt) {
    body.vy += kGravity * dt;
    if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
    integrate(body, dt, tileAt);
  }

  void _advanceCharge(double dt, TileQuery tileAt) {
    _chargeLeft -= dt;
    body.vx = _chargeDir * chargeSpeed * _speedMul;
    final beforeX = body.x;
    _fall(dt, tileAt);
    // Ran into the arena wall: the charge ends early (and the recover window
    // starts early too, which is exactly the opening the player wants).
    if ((body.x - beforeX).abs() < 0.5) _chargeLeft = 0;
  }

  BossAttack _chooseAttack() {
    attackCycle++;
    return switch (phase) {
      // P1 teaches the two ranged answers: jump the wave, move off the vents.
      1 => attackCycle.isEven ? BossAttack.geyserCascade : BossAttack.heatWave,
      // P2 introduces the charge on every third beat.
      2 => switch (attackCycle % 3) {
          0 => BossAttack.charge,
          1 => BossAttack.heatWave,
          _ => BossAttack.geyserCascade,
        },
      // P3 enrage: bombs join the rotation and the charge comes twice as often.
      _ => switch (attackCycle % 4) {
          0 => BossAttack.magmaBombs,
          1 => BossAttack.charge,
          2 => BossAttack.heatWave,
          _ => BossAttack.geyserCascade,
        },
    };
  }

  void _executeAttack(double playerX, double playerY) {
    final groundY = body.bottom;
    switch (pendingAttack) {
      case BossAttack.heatWave:
        final dir = playerX >= centerX ? 1 : -1;
        hazards.add(BossHazard(
            BossHazardKind.heatWave, centerX + dir * 28, groundY,
            vx: dir * waveSpeed * _speedMul, life: 3.2));
        if (phase == 3) {
          // Enrage: a second wall the other way, so standing behind it is not
          // a free answer any more.
          hazards.add(BossHazard(
              BossHazardKind.heatWave, centerX - dir * 28, groundY,
              vx: -dir * waveSpeed * _speedMul, life: 3.2));
        }
      case BossAttack.geyserCascade:
        // Vents mark the floor, then erupt in sequence, marching from the
        // golem toward (and past) the player: the ground under you becomes
        // unsafe on a beat you can read.
        final dir = playerX >= centerX ? 1 : -1;
        final count = phase == 3 ? 6 : 4;
        for (var i = 0; i < count; i++) {
          hazards.add(BossHazard(
            BossHazardKind.geyser,
            centerX + dir * (26 + i * 26),
            groundY,
            warning: (phase == 3 ? 0.4 : 0.6) + i * 0.16,
            life: 0.65,
          ));
        }
      case BossAttack.charge:
        charging = true;
        _chargeDir = playerX >= centerX ? 1 : -1;
        facing = _chargeDir;
        _chargeLeft = 1.35;
      case BossAttack.magmaBombs:
        final dx = playerX - centerX;
        for (final k in const [0.7, 1.0, 1.3]) {
          hazards.add(BossHazard(
              BossHazardKind.magmaBomb, centerX, body.top + 8,
              vx: dx * k / 1.05, vy: -230, life: 4.0));
        }
      // Grove Golem attacks — never chosen here.
      case BossAttack.slam:
      case BossAttack.rootSpikes:
      case BossAttack.rockLob:
        break;
    }
  }

  @override
  void advanceHazard(BossHazard h, double dt, TileQuery tileAt) {
    switch (h.kind) {
      case BossHazardKind.heatWave:
        h.x += h.vx * dt;
        h.life -= dt;
        final tx = ((h.x + h.vx.sign * 9) / kTileSize).floor();
        final ty = ((h.y - 6) / kTileSize).floor();
        final t = tileAt(tx, ty);
        if (h.life <= 0 || t == TileKind.solid || t == TileKind.crackedWall) {
          h.active = false;
        }
      case BossHazardKind.geyser:
        h.life -= dt;
        if (h.life <= 0) h.active = false;
      case BossHazardKind.magmaBomb:
        h.vy += kGravity * dt;
        h.x += h.vx * dt;
        h.y += h.vy * dt;
        h.life -= dt;
        final tx = (h.x / kTileSize).floor();
        final ty = (h.y / kTileSize).floor();
        final t = tileAt(tx, ty);
        final landed = h.vy > 0 &&
            (t == TileKind.solid || t == TileKind.crackedWall);
        if (landed) {
          // Snap the pool to the top of the tile it hit, so burning floor is
          // always ON the floor.
          spawnHazard(BossHazard(
              BossHazardKind.magmaPool, h.x, ty * kTileSize,
              life: phase == 3 ? 3.2 : 2.4));
        }
        if (h.life <= 0 || landed) h.active = false;
      case BossHazardKind.magmaPool:
        h.life -= dt;
        if (h.life <= 0) h.active = false;
      case BossHazardKind.shockwave:
      case BossHazardKind.rootSpike:
      case BossHazardKind.rock:
        // Grove Golem hazards; the Kiln Golem never spawns them.
        h.active = false;
    }
  }
}
