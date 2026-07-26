// game/enemies/boss_core.dart — the world bosses. Pure Dart.
//
// Shared machinery lives in [BossCore]: a telegraphed state machine
// (idle -> telegraph -> attack -> recover), a self-owned hazard list, and
// phase thresholds at 2/3 and 1/3 hp. Every attack is telegraphed
// (BossState.telegraph) so the render layer can flash/animate a warning
// before any hazard exists. The session collides hazards with the player and
// locks the exit door until the boss is dead.
//
// Grove Golem (World 1): slow guardian.
//   P1: ground slam — a shockwave races along the floor.
//   P2: + root spikes — warning marks under the player, then eruption.
//   P3: faster everything + lobbed rock arcs.
//
// Kiln Golem (World 2): fired in the first kiln — fights with fire, not
// roots. A distinct moveset (it was a GroveGolemCore reskin until 2026-07-26):
//   P1: ember mortar — lobbed embers that ignite lingering fire patches
//       where they land (area denial: the floor itself becomes unsafe).
//   P2: + vent wall — a wall of flame pillars marches from the golem toward
//       the player, each pillar warning before it erupts (jump the wave).
//   P3: faster everything + ember volley (3 embers bracketing the player)
//       and the vent wall marches BOTH directions — no free safe lane.

import 'dart:math' as math;

import '../level/level_data.dart';
import '../physics.dart';
import '../tuning.dart';
import 'enemy_core.dart';

enum BossState { idle, telegraph, attack, recover }

enum BossAttack {
  // Grove Golem
  slam,
  rootSpikes,
  rockLob,
  // Kiln Golem
  emberMortar,
  ventWall,
  emberVolley,
}

enum BossHazardKind {
  // Grove Golem
  shockwave,
  rootSpike,
  rock,
  // Kiln Golem
  emberBomb, // arcing ember; ignites a firePatch where it lands
  firePatch, // lingering ground fire left by a landed ember
  flamePillar, // vent eruption: harmless warning mark, then a flame column
}

class BossHazard {
  final BossHazardKind kind;
  double x, y; // anchor: bottom-center on the ground
  double vx, vy;
  double life; // seconds left (projectiles/patches) or eruption time (pillar)
  double warning; // rootSpike/flamePillar: harmless warning seconds remaining
  bool active = true;

  BossHazard(this.kind, this.x, this.y,
      {this.vx = 0, this.vy = 0, this.life = 3, this.warning = 0});

  bool get harmful => active && warning <= 0;

  /// AABB (px) used for player collision while harmful.
  ({double x, double y, double w, double h}) get rect => switch (kind) {
        BossHazardKind.shockwave => (x: x - 8, y: y - 10, w: 16.0, h: 10.0),
        BossHazardKind.rootSpike => (x: x - 5, y: y - 15, w: 10.0, h: 15.0),
        BossHazardKind.rock => (x: x - 5, y: y - 10, w: 10.0, h: 10.0),
        BossHazardKind.emberBomb => (x: x - 4, y: y - 8, w: 8.0, h: 8.0),
        BossHazardKind.firePatch => (x: x - 10, y: y - 9, w: 20.0, h: 9.0),
        BossHazardKind.flamePillar => (x: x - 6, y: y - 30, w: 12.0, h: 30.0),
      };
}

/// Shared boss brain: telegraphed attack cycle + self-owned hazards.
/// Subclasses supply pacing numbers and the attack table.
abstract class BossCore extends EnemyCore {
  BossState bossState = BossState.idle;
  BossAttack pendingAttack;
  double _stateTimer = 1.2; // opening grace before the first telegraph
  int _attackCycle = 0;
  final List<BossHazard> hazards = [];

  BossCore({
    required super.kind,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    required super.hp,
    required this.pendingAttack,
  }) : maxHpTotal = hp;

  /// Full hp at spawn — the HUD bar and phase math key off this.
  final int maxHpTotal;

  /// 1, 2 or 3 (phase thresholds at 2/3 and 1/3 hp).
  int get phase {
    if (hp * 3 > maxHpTotal * 2) return 1;
    if (hp * 3 > maxHpTotal) return 2;
    return 3;
  }

  // Pacing knobs (subclass-tuned).
  double get walkSpeed;
  double get speedMul;
  double get telegraphTime;
  double get idleTime;
  double get recoverTime;

  /// Next attack for the current phase/cycle.
  BossAttack chooseAttack(int cycle);

  /// Spawn this attack's hazards (bossState just left telegraph).
  void executeAttack(double playerX, double playerY, TileQuery tileAt);

  @override
  void behave(double dt, TileQuery tileAt,
      {required double playerX, required double playerY}) {
    updateHazards(dt, tileAt);
    _stateTimer -= dt;

    switch (bossState) {
      case BossState.idle:
        // Lumber toward the player.
        facing = playerX >= centerX ? 1 : -1;
        body.vx = facing * walkSpeed * speedMul;
        body.vy += kGravity * dt;
        if (body.vy > kMaxFallSpeed) body.vy = kMaxFallSpeed;
        integrate(body, dt, tileAt);
        if (_stateTimer <= 0) {
          _attackCycle++;
          pendingAttack = chooseAttack(_attackCycle);
          bossState = BossState.telegraph;
          _stateTimer = telegraphTime;
        }
      case BossState.telegraph:
        body.vx = 0;
        body.vy += kGravity * dt;
        integrate(body, dt, tileAt);
        if (_stateTimer <= 0) {
          executeAttack(playerX, playerY, tileAt);
          bossState = BossState.attack;
          _stateTimer = 0.25;
        }
      case BossState.attack:
        if (_stateTimer <= 0) {
          bossState = BossState.recover;
          _stateTimer = recoverTime;
        }
      case BossState.recover:
        if (_stateTimer <= 0) {
          bossState = BossState.idle;
          _stateTimer = idleTime;
        }
    }
  }

  /// Advance every live hazard; subclass hooks handle its own kinds.
  void updateHazards(double dt, TileQuery tileAt) {
    // New hazards may be appended mid-loop (ember -> fire patch), so index.
    for (var i = 0; i < hazards.length; i++) {
      final h = hazards[i];
      if (!h.active) continue;
      updateHazard(h, dt, tileAt);
    }
    hazards.removeWhere((h) => !h.active);
  }

  void updateHazard(BossHazard h, double dt, TileQuery tileAt);

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

  /// True when a solid tile sits at pixel (px, py) — hazard ground checks.
  bool solidAt(TileQuery tileAt, double px, double py) {
    final t = tileAt((px / kTileSize).floor(), (py / kTileSize).floor());
    return t == TileKind.solid || t == TileKind.crackedWall;
  }
}

/// World 1 boss: the Grove Golem.
class GroveGolemCore extends BossCore {
  static const int maxHp = 60;

  GroveGolemCore({required super.x, required super.y})
      : super(
            kind: EnemyKind.groveGolem,
            w: 44,
            h: 52,
            hp: maxHp,
            pendingAttack: BossAttack.slam);

  @override
  double get walkSpeed => 20;
  @override
  double get speedMul => phase == 3 ? 1.6 : 1.0;
  @override
  double get telegraphTime => phase == 3 ? 0.55 : 0.85;
  @override
  double get idleTime => phase == 3 ? 1.1 : 1.9;
  @override
  double get recoverTime => phase == 3 ? 0.35 : 0.6;

  @override
  BossAttack chooseAttack(int cycle) => switch (phase) {
        1 => BossAttack.slam,
        2 => cycle.isEven ? BossAttack.rootSpikes : BossAttack.slam,
        _ => switch (cycle % 3) {
            0 => BossAttack.rockLob,
            1 => BossAttack.slam,
            _ => BossAttack.rootSpikes,
          },
      };

  @override
  void executeAttack(double playerX, double playerY, TileQuery tileAt) {
    final groundY = body.bottom;
    switch (pendingAttack) {
      case BossAttack.slam:
        // Shockwave races along the floor toward the player.
        final dir = playerX >= centerX ? 1 : -1;
        hazards.add(BossHazard(BossHazardKind.shockwave, centerX + dir * 26,
            groundY,
            vx: dir * 120 * speedMul, life: 2.6));
        if (phase == 3) {
          // Faster phase also sends one backwards — no safe lane for free.
          hazards.add(BossHazard(BossHazardKind.shockwave,
              centerX - dir * 26, groundY,
              vx: -dir * 120 * speedMul, life: 2.6));
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
      default:
        assert(false, 'GroveGolem cannot execute $pendingAttack');
    }
  }

  @override
  void updateHazard(BossHazard h, double dt, TileQuery tileAt) {
    switch (h.kind) {
      case BossHazardKind.shockwave:
        h.x += h.vx * dt;
        h.life -= dt;
        if (h.life <= 0 || solidAt(tileAt, h.x + h.vx.sign * 8, h.y - 4)) {
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
        if (h.life <= 0 || (h.vy > 0 && solidAt(tileAt, h.x, h.y))) {
          h.active = false;
        }
      default:
        h.active = false; // not a grove hazard
    }
  }
}

/// World 2 boss: the Kiln Golem. Fights with fire — mortar embers that leave
/// burning ground, and marching walls of vent flame. See the header comment.
class KilnGolemCore extends BossCore {
  static const int maxHp = 60;

  KilnGolemCore({required super.x, required super.y})
      : super(
            kind: EnemyKind.kilnGolem,
            w: 44,
            h: 52,
            hp: maxHp,
            pendingAttack: BossAttack.emberMortar);

  // Heavier and slower on foot than the Grove Golem, but its attacks deny
  // ground: the pressure comes from fire, not from the body.
  @override
  double get walkSpeed => 14;
  @override
  double get speedMul => phase == 3 ? 1.5 : 1.0;
  @override
  double get telegraphTime => phase == 3 ? 0.5 : 0.9;
  @override
  double get idleTime => phase == 3 ? 1.0 : 1.8;
  @override
  double get recoverTime => phase == 3 ? 0.4 : 0.7;

  /// Seconds a landed ember keeps the ground burning.
  static const double patchLife = 1.5;

  @override
  BossAttack chooseAttack(int cycle) => switch (phase) {
        1 => BossAttack.emberMortar,
        2 => cycle.isEven ? BossAttack.ventWall : BossAttack.emberMortar,
        _ => switch (cycle % 3) {
            0 => BossAttack.emberVolley,
            1 => BossAttack.ventWall,
            _ => BossAttack.emberMortar,
          },
      };

  @override
  void executeAttack(double playerX, double playerY, TileQuery tileAt) {
    final groundY = body.bottom;
    switch (pendingAttack) {
      case BossAttack.emberMortar:
        _lobEmbers(playerX, const [0.85, 1.15]);
      case BossAttack.emberVolley:
        // Phase 3: a wider 3-ember bracket — greed for a fixed dodge spot
        // gets punished, but each landing zone is readable in the air.
        _lobEmbers(playerX, const [0.7, 1.0, 1.3]);
      case BossAttack.ventWall:
        // A wall of flame pillars marches away from the golem toward the
        // player: each pillar warns, then erupts slightly after the one
        // before it — read the wave, jump it. In phase 3 a second wall
        // marches the OTHER way too (mirror of the grove slam rule).
        final dir = playerX >= centerX ? 1 : -1;
        _marchPillars(dir, groundY);
        if (phase == 3) _marchPillars(-dir, groundY);
      default:
        assert(false, 'KilnGolem cannot execute $pendingAttack');
    }
  }

  void _lobEmbers(double playerX, List<double> spread) {
    // Aimed mortar: 0.58 s is the real flight time of a -260 px/s launch
    // from the golem's shoulder back to floor level under kGravity, so an
    // ember with spread k lands at ~k of the way to the player — the
    // bracket genuinely straddles where you were standing.
    final dx = playerX - centerX;
    for (final k in spread) {
      hazards.add(BossHazard(BossHazardKind.emberBomb, centerX, body.top + 8,
          vx: dx * k / 0.58, vy: -260, life: 4.0));
    }
  }

  void _marchPillars(int dir, double groundY) {
    const count = 4;
    for (var i = 0; i < count; i++) {
      final delay = phase == 3 ? 0.40 + i * 0.10 : 0.55 + i * 0.14;
      hazards.add(BossHazard(
          BossHazardKind.flamePillar, centerX + dir * (34.0 + i * 22.0),
          groundY,
          warning: delay, life: 0.45));
    }
  }

  @override
  void updateHazard(BossHazard h, double dt, TileQuery tileAt) {
    switch (h.kind) {
      case BossHazardKind.emberBomb:
        h.vy += kGravity * dt;
        h.x += h.vx * dt;
        h.y += h.vy * dt;
        h.life -= dt;
        if (h.vy > 0 && solidAt(tileAt, h.x, h.y)) {
          // Landed: snap to the tile top and ignite the ground.
          h.active = false;
          final tileTop = (h.y / kTileSize).floorToDouble() * kTileSize;
          hazards.add(BossHazard(BossHazardKind.firePatch, h.x, tileTop,
              life: patchLife));
        } else if (h.life <= 0) {
          h.active = false; // fell out of the arena — no patch
        }
      case BossHazardKind.firePatch:
        h.life -= dt;
        if (h.life <= 0) h.active = false;
      case BossHazardKind.flamePillar:
        if (h.warning > 0) {
          h.warning -= dt;
        } else {
          h.life -= dt;
          if (h.life <= 0) h.active = false;
        }
      default:
        h.active = false; // not a kiln hazard
    }
  }
}
