// game/enemies/boss_core.dart — Grove Golem, the World 1 boss. Pure Dart.
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

enum BossAttack { slam, rootSpikes, rockLob }

enum BossHazardKind { shockwave, rootSpike, rock }

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
      };
}

class GroveGolemCore extends EnemyCore {
  static const int maxHp = 60;
  static const double walkSpeed = 20;

  BossState bossState = BossState.idle;
  BossAttack pendingAttack = BossAttack.slam;
  double _stateTimer = 1.2; // opening grace before the first telegraph
  int _attackCycle = 0;
  final List<BossHazard> hazards = [];

  GroveGolemCore({required super.x, required super.y})
      : super(kind: EnemyKind.groveGolem, w: 44, h: 52, hp: maxHp);

  /// 1, 2 or 3 (phase thresholds at 2/3 and 1/3 hp).
  int get phase {
    if (hp * 3 > maxHp * 2) return 1;
    if (hp * 3 > maxHp) return 2;
    return 3;
  }

  double get _speedMul => phase == 3 ? 1.6 : 1.0;
  double get _telegraphTime => phase == 3 ? 0.55 : 0.85;
  double get _idleTime => phase == 3 ? 1.1 : 1.9;

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    _updateHazards(dt, tileAt);
    _stateTimer -= dt;

    switch (bossState) {
      case BossState.idle:
        // Lumber toward the player.
        facing = playerX >= centerX ? 1 : -1;
        body.vx = facing * walkSpeed * _speedMul;
        body.vy += kGravity * dt;
        if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
        integrate(body, dt, tileAt);
        if (_stateTimer <= 0) {
          pendingAttack = _chooseAttack();
          bossState = BossState.telegraph;
          _stateTimer = _telegraphTime;
        }
      case BossState.telegraph:
        body.vx = 0;
        body.vy += kGravity * dt;
        integrate(body, dt, tileAt);
        if (_stateTimer <= 0) {
          _executeAttack(playerX, playerY, tileAt);
          bossState = BossState.attack;
          _stateTimer = 0.25;
        }
      case BossState.attack:
        if (_stateTimer <= 0) {
          bossState = BossState.recover;
          _stateTimer = phase == 3 ? 0.35 : 0.6;
        }
      case BossState.recover:
        if (_stateTimer <= 0) {
          bossState = BossState.idle;
          _stateTimer = _idleTime;
        }
    }
  }

  BossAttack _chooseAttack() {
    _attackCycle++;
    return switch (phase) {
      1 => BossAttack.slam,
      2 => _attackCycle.isEven ? BossAttack.rootSpikes : BossAttack.slam,
      _ => switch (_attackCycle % 3) {
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
    }
  }

  void _updateHazards(double dt, TileQuery tileAt) {
    for (final h in hazards) {
      if (!h.active) continue;
      switch (h.kind) {
        case BossHazardKind.shockwave:
          h.x += h.vx * dt;
          h.life -= dt;
          final tx = ((h.x + h.vx.sign * 8) / kTileSize).floor();
          final ty = ((h.y - 4) / kTileSize).floor();
          final t = tileAt(tx, ty);
          if (h.life <= 0 ||
              t == TileKind.solid ||
              t == TileKind.crackedWall) {
            h.active = false;
          }
        case BossHazardKind.rootSpike:
          if (h.warning > 0) {
            h.warning -= dt;
          } else {
            h.life -= dt;
            if (h.life <= 0) h.active = false;
          }
        case BossHazardKind.rock:
          h.vy += kGravity * dt;
          h.x += h.vx * dt;
          h.y += h.vy * dt;
          h.life -= dt;
          final tx = (h.x / kTileSize).floor();
          final ty = (h.y / kTileSize).floor();
          final t = tileAt(tx, ty);
          if (h.life <= 0 ||
              (h.vy > 0 &&
                  (t == TileKind.solid || t == TileKind.crackedWall))) {
            h.active = false;
          }
      }
    }
    hazards.removeWhere((h) => !h.active);
  }

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

  // Give telegraphs a little math-based pulse hook for the renderer.
  double get telegraphPulse => bossState == BossState.telegraph
      ? 0.5 + 0.5 * math.sin(_stateTimer * 24)
      : 0;
}
