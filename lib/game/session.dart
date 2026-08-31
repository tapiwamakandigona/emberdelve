// game/session.dart — headless level runtime: everything that happens inside
// a level run, with ZERO Flame/Flutter imports. The Flame layer
// (ember_game.dart) renders this state and forwards events to sfx/fx.
//
// Owns: mutable tile grid (cracked walls break), player core, enemy cores,
// pickups (coins/apples/feathers), chests + coin bursts, apple projectiles,
// melee hit resolution (crit/burn/hit-pause), signs, exit door, level timer,
// death + results. Unit-tested headlessly (combat/pickup/session tests).

import 'dart:math' as math;

import 'core_loadout.dart';
import '../core/rng.dart';
import 'difficulty.dart';
import '../meta/catalog.dart' show SpellEffect, WeaponSpecial;
import 'enemies/boss_core.dart';
import 'enemies/enemy_core.dart';
import 'input_intent.dart';
import 'level/level_data.dart';
import 'physics.dart' show TileQuery;
import 'player/player_core.dart';
import 'tuning.dart';

/// Session-level events (sfx/fx hooks for the render layer).
enum SessionEventKind {
  coin, // +data: x,y
  applePickup,
  heartPickup, // data: x,y — heart eaten, 1 heart restored
  feather,
  chestOpen,
  secretFound,
  enemyHit, // data: x,y crit
  enemyDeath, // data: x,y
  wallHit,
  wallBreak, // data: tile x,y
  appleThrown,
  appleBroke, // data: x,y
  attackBlocked, // data: x,y — Rotshield shield ate a hit ('block' sfx)
  bossPhase, // boss crossed a phase threshold (x = new phase)
  bossDefeated, // data: x,y — big burst + the exit unlocks
  emberShot, // data: x,y — Ember Totem fired
  emberShotBroke, // data: x,y — ember hit terrain / player / limits
  checkpointLit, // data: x,y — campfire lit, respawn point moved
  respawned, // data: x,y — died with lives left, back at the checkpoint
  levelComplete,
  levelFailed,
  spellCast, // AKP-4d: data x,y = player centre; one cast per run
}

class SessionEvent {
  final SessionEventKind kind;
  final double x, y;
  final bool crit;

  /// Damage dealt, for enemyHit events (AKP-3c floating damage numbers).
  final int amount;
  const SessionEvent(this.kind,
      {this.x = 0, this.y = 0, this.crit = false, this.amount = 0});
}

class CoinEntity {
  double x, y; // center px
  double vx, vy;
  bool physical; // chest-burst coins fly and settle before collection
  double settleTime = 0;
  bool collected = false;

  /// Spin phase in cycles [0,1), derived from the spawn position so
  /// neighbouring coins twinkle out of step instead of the whole level
  /// hitting the edge-on frame on the same tick (looked like candles in
  /// screenshots). Deterministic — no RNG, stable across restarts.
  final double spinPhase;

  CoinEntity(this.x, this.y, {this.vx = 0, this.vy = 0, this.physical = false})
      : spinPhase = ((x * 0.37 + y * 0.23) % 1.0 + 1.0) % 1.0;
}

class PickupEntity {
  final SpawnKind kind; // apple / feather / heart
  final double x, y;
  bool collected = false;
  PickupEntity(this.kind, this.x, this.y);
}

class ChestEntity {
  final double x, y; // center px
  final bool secret;
  bool opened = false;
  ChestEntity(this.x, this.y, {required this.secret});
}

/// A campfire checkpoint: lights on touch and becomes the respawn point.
class CheckpointEntity {
  final double x, y; // centre px
  bool lit = false;
  CheckpointEntity(this.x, this.y);
}

class SignEntity {
  final double x, y; // center px
  final String text;
  SignEntity(this.x, this.y, this.text);
}

class AppleProjectile {
  double x = 0, y = 0, vx = 0, vy = 0;
  bool active = false;
}

/// Ember Totem projectile: straight-line spit, breaks on terrain/player.
class EmberShot {
  double x = 0, y = 0, vx = 0, vy = 0;
  bool active = false;
}

class CrackedWall {
  final int tx, ty;
  int hp;
  CrackedWall(this.tx, this.ty, this.hp);
}

class LevelResults {
  final int timeMs;
  final int parSeconds;
  final int coinsEarned;
  final int chestsOpened;
  final int chestTotal;
  final int secretsFound;
  final bool finished;
  final bool allChests;
  final bool lowDamage;
  const LevelResults({
    required this.timeMs,
    required this.parSeconds,
    required this.coinsEarned,
    required this.chestsOpened,
    required this.chestTotal,
    required this.secretsFound,
    required this.finished,
    required this.allChests,
    required this.lowDamage,
  });
  int get medals => (finished ? 1 : 0) + (allChests ? 1 : 0) + (lowDamage ? 1 : 0);

  /// Extra coins for a 3-medal run (see kPerfectClearBonus in tuning.dart).
  int get perfectBonus => medals == 3 ? kPerfectClearBonus : 0;

  /// What the wallet actually receives for this run.
  int get totalCoins => coinsEarned + perfectBonus;
}

class LevelSession {
  final LevelData level;
  final Loadout loadout;
  final Difficulty difficulty; // Stage 2: scales enemy behaviour only
  DifficultyMods get mods => DifficultyMods.of(difficulty);
  late final PlayerCore player;
  final Rng combatRng;
  final Rng dropsRng;

  // Mutable tile grid (cracked walls become empty when broken).
  late final List<List<TileKind>> grid;
  final List<CrackedWall> walls = [];
  bool wallsDirty = false; // render layer rebuilds the tile batch when set

  final List<EnemyCore> enemies = [];
  final List<CoinEntity> coins = [];
  final List<PickupEntity> pickups = [];
  final List<ChestEntity> chests = [];
  final List<CheckpointEntity> checkpoints = [];
  final List<SignEntity> signs = [];
  final List<AppleProjectile> _applePool =
      List.generate(kMaxPooledProjectiles, (_) => AppleProjectile());

  /// Read-only view for the render layer.
  List<AppleProjectile> get appleProjectiles => _applePool;

  final List<EmberShot> _emberPool =
      List.generate(kMaxPooledProjectiles, (_) => EmberShot());

  /// Read-only view for the render layer.
  List<EmberShot> get emberShots => _emberPool;

  late final double exitX, exitY; // door center px

  // Run state.
  double time = 0;
  /// Attempts left in this run. A death with lives to spare costs one life
  /// and rewinds to the last lit campfire instead of ending the level.
  int lives = kStartingLives;
  int deaths = 0;
  double respawnX = 0, respawnY = 0;
  int coinsCollected = 0;
  int applesHeld = 0;
  int feathersCollected = 0;
  int hitsTaken = 0;
  int kills = 0;
  int secretsFound = 0;
  double hitPause = 0;
  bool spellUsed = false; // AKP-4d: the equipped spell's single run charge
  bool completed = false;
  bool failed = false;
  bool get over => completed || failed;
  LevelResults? results;

  /// Camera center x (px), fed by the render layer for enemy sleeping.
  double cameraX = 0;

  /// Boss bookkeeping: the exit stays locked while a Grove Golem lives.
  int _bossPhaseSeen = 1;
  BossCore? get boss =>
      enemies.whereType<BossCore>().where((b) => b.alive).firstOrNull;
  bool get bossPresent => enemies.whereType<BossCore>().isNotEmpty;
  bool get exitLocked => boss != null;

  // Melee swing bookkeeping: one damage application per enemy per swing.
  final Set<EnemyCore> _swingVictims = {};
  final Set<CrackedWall> _swingWalls = {};

  final List<SessionEvent> _events = [];
  final List<PlayerEvent> _playerEvents = [];

  LevelSession(this.level, this.loadout,
      {int seed = 0, this.difficulty = Difficulty.medium})
      : combatRng = Rng.create(seed, 'combat'),
        dropsRng = Rng.create(seed, 'drops') {
    grid = [
      for (final row in level.tiles) List<TileKind>.of(row),
    ];
    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        if (grid[y][x] == TileKind.crackedWall) {
          walls.add(CrackedWall(x, y, 3));
        }
      }
    }

    final p = level.playerSpawn;
    player = PlayerCore(
      x: p.x * kTileSize + 2,
      y: (p.y + 1) * kTileSize - 20,
      tileAt: tileAt,
      // Easy grants one heart of slack (difficulty.dart); enemy stats are
      // never scaled, so this is the only stat knob difficulty touches.
      maxHearts: loadout.maxHearts + mods.bonusHearts,
      weaponDamage: loadout.weapon.damage,
      weaponRange: loadout.weapon.range,
      extraAirJumps: loadout.extraAirJumps,
      meleePower: loadout.meleePower,
      hasLunge: loadout.weapon.special == WeaponSpecial.lunge,
    );
    cameraX = player.body.centerX;
    respawnX = player.body.x;
    respawnY = player.body.y;

    var signIndex = 0;
    for (final s in level.spawns) {
      final cx = s.x * kTileSize + kTileSize / 2;
      final cy = s.y * kTileSize + kTileSize / 2;
      switch (s.kind) {
        case SpawnKind.coin:
          coins.add(CoinEntity(cx, cy));
        case SpawnKind.apple:
        case SpawnKind.feather:
        case SpawnKind.heart:
          pickups.add(PickupEntity(s.kind, cx, cy));
        case SpawnKind.chest:
          chests.add(ChestEntity(cx, cy, secret: false));
        case SpawnKind.secretChest:
          chests.add(ChestEntity(cx, cy, secret: true));
        case SpawnKind.checkpoint:
          checkpoints.add(CheckpointEntity(cx, (s.y + 1) * kTileSize - 8));
        case SpawnKind.sign:
          signIndex++;
          signs.add(SignEntity(cx, cy, level.meta['sign$signIndex'] ?? ''));
        case SpawnKind.thornling:
          enemies.add(ThornlingCore(
              x: cx - 12, y: (s.y + 1) * kTileSize - 22));
        case SpawnKind.ashbat:
          enemies.add(AshbatCore(x: cx - 14, y: cy - 12));
        case SpawnKind.emberTotem:
          enemies.add(EmberTotemCore(
              x: cx - 10, y: (s.y + 1) * kTileSize - 30));
        case SpawnKind.rotshield:
          enemies.add(RotshieldCore(
              x: cx - 13, y: (s.y + 1) * kTileSize - 24));
        case SpawnKind.groveGolem:
          enemies.add(GroveGolemCore(
              x: cx - 22, y: (s.y + 1) * kTileSize - 52));
        case SpawnKind.kilnGolem:
          enemies.add(KilnGolemCore(
              x: cx - 22, y: (s.y + 1) * kTileSize - 52));
        case SpawnKind.sootCreeper:
          enemies.add(SootCreeperCore(
              x: cx - 12, y: (s.y + 1) * kTileSize - 22));
        case SpawnKind.cinderDiver:
          enemies.add(CinderDiverCore(x: cx - 14, y: cy - 12));
        case SpawnKind.pyreWisp:
          enemies.add(PyreWispCore(x: cx - 13, y: cy - 11));
        case SpawnKind.slagHound:
          enemies.add(SlagHoundCore(x: cx - 13, y: cy - 11));
        case SpawnKind.player:
          break;
        case SpawnKind.exit:
          break;
      }
    }
    final e = level.exit;
    exitX = e.x * kTileSize + kTileSize / 2;
    exitY = (e.y + 1) * kTileSize; // door base sits on the tile bottom

    // Hoppers have no legend char (frozen legend): levels place them via
    // "meta: hopperN=tx,ty" (tile coords), consumed here.
    for (var i = 1;; i++) {
      final v = level.meta['hopper$i'];
      if (v == null) break;
      final parts = v.split(',');
      if (parts.length != 2) continue;
      final tx = int.tryParse(parts[0].trim());
      final ty = int.tryParse(parts[1].trim());
      if (tx == null || ty == null) continue;
      addHopper(tx * kTileSize + 2, (ty + 1) * kTileSize - 22);
    }

    // Stage 2 difficulty: stamp the behaviour mods onto every enemy once.
    for (final e in enemies) {
      e.mods = mods;
      _enemyHome[e] = (x: e.body.x, y: e.body.y);
    }
  }

  /// Where each enemy started, so a checkpoint respawn can clear the space
  /// the player is coming back into (see [_onDeath]).
  final Map<EnemyCore, ({double x, double y})> _enemyHome = {};

  /// Spawn a hopper explicitly (used by tests and, later, level scripting).
  void addHopper(double x, double y) =>
      enemies.add(HopperCore(x: x, y: y)..mods = mods);

  TileKind tileAt(int tx, int ty) {
    if (tx < 0 || tx >= level.width) return TileKind.solid;
    if (ty < 0 || ty >= level.height) return TileKind.empty;
    return grid[ty][tx];
  }

  /// Cached tear-off: instance-method tear-offs allocate a fresh closure at
  /// every evaluation, and update() passes this per enemy per frame (perf.md).
  late final TileQuery _tileQuery = tileAt;

  List<SessionEvent> takeEvents() {
    if (_events.isEmpty) return const []; // hot path: no per-frame copy
    final out = List<SessionEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// Player events forwarded from the core (jumped/landed/hurt/died...).
  List<PlayerEvent> takePlayerEvents() {
    if (_playerEvents.isEmpty) return const []; // hot path: no per-frame copy
    final out = List<PlayerEvent>.of(_playerEvents);
    _playerEvents.clear();
    return out;
  }

  double get coinPickupRadius =>
      loadout.coinMagnet ? 2 * _baseCoinRadius : _baseCoinRadius;
  static const double _baseCoinRadius = 14;

  void update(double dt, InputIntent input) {
    if (over) return;
    if (hitPause > 0) {
      // Hit-pause freezes both parties (spec §3).
      hitPause -= dt;
      return;
    }
    time += dt;

    // --- apple throw (before player.update consumes edges elsewhere)
    if (input.throwPressed && applesHeld > 0 && !player.isDead) {
      AppleProjectile? p;
      for (final a in _applePool) {
        if (!a.active) {
          p = a;
          break;
        }
      }
      if (p != null) {
        applesHeld--;
        p.active = true;
        p.x = player.facing > 0 ? player.body.right : player.body.left;
        p.y = player.body.top + 4;
        // AKP-4c: ~22.5° up in the facing direction (flat AK-style lob).
        p.vx = player.facing * kAppleThrowSpeed * kAppleThrowCos;
        p.vy = -kAppleThrowSpeed * kAppleThrowSin;
        _events.add(SessionEvent(SessionEventKind.appleThrown, x: p.x, y: p.y));
      }
    }

    // --- player
    final wasAttacking = player.attacking;
    player.update(dt, input);
    final pev = player.takeEvents();
    _playerEvents.addAll(pev);
    if (pev.contains(PlayerEvent.attacked) ||
        (!wasAttacking && player.attacking)) {
      _swingVictims.clear();
      _swingWalls.clear();
    }
    if (pev.contains(PlayerEvent.died)) {
      _onDeath();
      return;
    }
    if (pev.contains(PlayerEvent.hurt)) hitsTaken++;

    // Fall-out death: below level bottom + 3 tiles.
    if (player.body.top > (level.height + 3) * kTileSize) {
      player.kill();
      _playerEvents.addAll(player.takeEvents());
      _onDeath();
      return;
    }

    // --- checkpoints: light the campfire you walk into
    for (final c in checkpoints) {
      if (c.lit) continue;
      if ((player.body.centerX - c.x).abs() < kCheckpointRadius &&
          (player.body.centerY - c.y).abs() < kCheckpointRadius + 8) {
        c.lit = true;
        respawnX = c.x - player.body.w / 2;
        respawnY = c.y - player.body.h + 8;
        _events.add(SessionEvent(SessionEventKind.checkpointLit,
            x: c.x, y: c.y));
      }
    }

    // --- enemies
    final sleepDist = 1.5 * 480; // 1.5 screens at 480px view width
    for (final e in enemies) {
      if (!e.alive) continue;
      e.sleeping = (e.centerX - cameraX).abs() > sleepDist;
      final burnKilled = e.update(dt, _tileQuery,
          playerX: player.body.centerX, playerY: player.body.centerY);
      if (burnKilled) {
        _onEnemyDeath(e);
        continue;
      }
      // Totems request aimed shots; the session owns the projectile pool.
      if (e is EmberTotemCore && !e.sleeping) {
        final req = e.takeShotRequest();
        if (req != null) {
          EmberShot? shot;
          for (final s in _emberPool) {
            if (!s.active) {
              shot = s;
              break;
            }
          }
          if (shot != null) {
            shot.active = true;
            shot.x = e.centerX + e.facing * 8;
            shot.y = e.body.top + 6;
            shot.vx = req.dx * kEmberShotSpeed;
            shot.vy = req.dy * kEmberShotSpeed;
            _events.add(SessionEvent(SessionEventKind.emberShot,
                x: shot.x, y: shot.y));
          }
        }
      }
      // Boss extras: phase-change events + hazard collision.
      if (e is BossCore && !e.sleeping) {
        if (e.phase != _bossPhaseSeen) {
          _bossPhaseSeen = e.phase;
          _events.add(SessionEvent(SessionEventKind.bossPhase,
              x: e.phase.toDouble(), y: 0));
        }
        if (e.hazardHits(player.body) &&
            player.damage(1, from: e.hazardSourceX(player.body))) {
          hitsTaken++;
          final dpev = player.takeEvents();
          _playerEvents.addAll(dpev);
          if (dpev.contains(PlayerEvent.died)) {
            _onDeath();
            return;
          }
        }
      }
      // Contact damage: 1 heart.
      if (!e.sleeping && e.overlapsBody(player.body)) {
        if (player.damage(1, from: e.centerX)) {
          hitsTaken++;
          final dpev = player.takeEvents();
          _playerEvents.addAll(dpev);
          if (dpev.contains(PlayerEvent.died)) {
            _onDeath();
            return;
          }
        }
      }
    }

    // --- melee vs enemies + cracked walls
    final hb = player.attackHitbox;
    if (hb != null) {
      for (final e in enemies) {
        if (!e.alive || e.sleeping || _swingVictims.contains(e)) continue;
        if (e.overlaps(hb.x, hb.y, hb.w, hb.h)) {
          _swingVictims.add(e);
          if (e.blocksHit(
              fromX: player.body.centerX, fromY: player.body.centerY)) {
            _events.add(SessionEvent(SessionEventKind.attackBlocked,
                x: e.centerX, y: e.centerY));
            continue;
          }
          var dmg = hb.damage;
          final crit = combatRng.range(1, 100) <= loadout.weapon.critPercent;
          if (crit) dmg = (dmg * loadout.weapon.critMultiplier).round();
          e.damage(dmg);
          if (loadout.burnOnHit && e.alive) e.burnLeft = 3.0;
          hitPause = kHitPause;
          _events.add(SessionEvent(SessionEventKind.enemyHit,
              x: e.centerX, y: e.centerY, crit: crit, amount: dmg));
          if (!e.alive) _onEnemyDeath(e);
        }
      }
      for (final w in walls) {
        if (w.hp <= 0 || _swingWalls.contains(w)) continue;
        final wx = w.tx * kTileSize, wy = w.ty * kTileSize;
        final hit = hb.x < wx + kTileSize &&
            hb.x + hb.w > wx &&
            hb.y < wy + kTileSize &&
            hb.y + hb.h > wy;
        if (hit) {
          _swingWalls.add(w);
          w.hp -= loadout.wallBreaker ? w.hp : 1;
          if (w.hp <= 0) {
            grid[w.ty][w.tx] = TileKind.empty;
            wallsDirty = true;
            _events.add(SessionEvent(SessionEventKind.wallBreak,
                x: wx + kTileSize / 2, y: wy + kTileSize / 2));
          } else {
            _events.add(SessionEvent(SessionEventKind.wallHit,
                x: wx + kTileSize / 2, y: wy + kTileSize / 2));
          }
        }
      }
    }

    // --- apple projectiles
    for (final a in _applePool) {
      if (!a.active) continue;
      a.vy += kGravity * dt;
      a.x += a.vx * dt;
      a.y += a.vy * dt;
      final tx = (a.x / kTileSize).floor(), ty = (a.y / kTileSize).floor();
      final t = tileAt(tx, ty);
      if (t == TileKind.solid || t == TileKind.crackedWall) {
        a.active = false;
        _events.add(SessionEvent(SessionEventKind.appleBroke, x: a.x, y: a.y));
        continue;
      }
      if (a.y > (level.height + 4) * kTileSize) {
        a.active = false;
        continue;
      }
      for (final e in enemies) {
        if (!e.alive || !e.overlaps(a.x - 4, a.y - 4, 8, 8)) continue;
        a.active = false;
        // Rotshield fronts eat apples too (approach side from velocity).
        if (e.blocksHit(fromX: a.x - a.vx.sign * 6, fromY: a.y)) {
          _events.add(SessionEvent(SessionEventKind.attackBlocked,
              x: e.centerX, y: e.centerY));
          _events
              .add(SessionEvent(SessionEventKind.appleBroke, x: a.x, y: a.y));
          break;
        }
        e.damage(kAppleDamage);
        _events.add(SessionEvent(SessionEventKind.enemyHit,
            x: e.centerX, y: e.centerY, amount: kAppleDamage));
        _events.add(SessionEvent(SessionEventKind.appleBroke, x: a.x, y: a.y));
        if (!e.alive) _onEnemyDeath(e);
        break;
      }
    }

    // --- ember shots (totem projectiles) vs terrain + player
    for (final sh in _emberPool) {
      if (!sh.active) continue;
      sh.x += sh.vx * dt;
      sh.y += sh.vy * dt;
      final tx = (sh.x / kTileSize).floor(), ty = (sh.y / kTileSize).floor();
      final t = tileAt(tx, ty);
      if (t == TileKind.solid || t == TileKind.crackedWall) {
        sh.active = false;
        _events.add(
            SessionEvent(SessionEventKind.emberShotBroke, x: sh.x, y: sh.y));
        continue;
      }
      if (sh.x < -32 ||
          sh.x > (level.width + 2) * kTileSize ||
          sh.y < -64 ||
          sh.y > (level.height + 4) * kTileSize) {
        sh.active = false;
        continue;
      }
      final b = player.body;
      if (!player.isDead &&
          sh.x > b.left - 3 &&
          sh.x < b.right + 3 &&
          sh.y > b.top - 3 &&
          sh.y < b.bottom + 3) {
        sh.active = false;
        _events.add(
            SessionEvent(SessionEventKind.emberShotBroke, x: sh.x, y: sh.y));
        if (player.damage(1, from: sh.x - sh.vx.sign * 8)) {
          hitsTaken++;
          final dpev = player.takeEvents();
          _playerEvents.addAll(dpev);
          if (dpev.contains(PlayerEvent.died)) {
            _onDeath();
            return;
          }
        }
      }
    }

    // --- coins
    final r = coinPickupRadius;
    for (final c in coins) {
      if (c.collected) continue;
      if (c.physical) {
        if (c.settleTime < 0.25) {
          // Spray physics: fly, bounce once on solid ground, then settle.
          c.vy += kGravity * dt;
          c.x += c.vx * dt;
          c.y += c.vy * dt;
          final ty = ((c.y + 4) / kTileSize).floor();
          final tx = (c.x / kTileSize).floor();
          final t = tileAt(tx, ty);
          if ((t == TileKind.solid ||
                  t == TileKind.crackedWall ||
                  t == TileKind.platform) &&
              c.vy > 0) {
            c.y = ty * kTileSize - 4;
            c.vy = -c.vy * 0.35;
            c.vx *= 0.6;
            if (c.vy.abs() < 30) c.settleTime = 0.25; // settled
          }
        }
      }
      final dx = c.x - player.body.centerX, dy = c.y - player.body.centerY;
      if (dx * dx + dy * dy <= r * r) {
        c.collected = true;
        coinsCollected += kCoinValue;
        _events.add(SessionEvent(SessionEventKind.coin, x: c.x, y: c.y));
      }
    }

    // --- apples + feathers
    for (final p in pickups) {
      if (p.collected) continue;
      final dx = p.x - player.body.centerX, dy = p.y - player.body.centerY;
      if (dx * dx + dy * dy <= 14 * 14) {
        if (p.kind == SpawnKind.apple) {
          if (applesHeld >= loadout.appleCapacity) continue; // pouch full
          p.collected = true;
          applesHeld = (applesHeld + 3).clamp(0, loadout.appleCapacity);
          _events.add(
              SessionEvent(SessionEventKind.applePickup, x: p.x, y: p.y));
        } else if (p.kind == SpawnKind.heart) {
          // AKP-7a: hearts are the answer to the measured attrition wipes
          // (w1_l5 colonnade, w2_l4 kiln road: 3 hits per life with zero
          // mid-run healing = a guaranteed loop until the lives run out).
          // At full health the heart stays put — come back for it hurt.
          if (player.hearts >= player.maxHearts) continue;
          p.collected = true;
          player.hearts++;
          _events.add(
              SessionEvent(SessionEventKind.heartPickup, x: p.x, y: p.y));
        } else {
          p.collected = true;
          feathersCollected++;
          _events.add(SessionEvent(SessionEventKind.feather, x: p.x, y: p.y));
        }
      }
    }

    // --- chests
    for (final ch in chests) {
      if (ch.opened) continue;
      final dx = ch.x - player.body.centerX, dy = ch.y - player.body.centerY;
      if (dx * dx + dy * dy <= 18 * 18) {
        ch.opened = true;
        if (ch.secret) {
          secretsFound++;
          _events.add(
              SessionEvent(SessionEventKind.secretFound, x: ch.x, y: ch.y));
        }
        final n = dropsRng.range(kChestCoinsMin, kChestCoinsMax);
        for (var i = 0; i < n; i++) {
          final ang = dropsRng.range(-70, 70) * 3.14159 / 180;
          final spd = dropsRng.range(60, 140).toDouble();
          coins.add(CoinEntity(ch.x, ch.y - 8,
              vx: spd * 0.9 * math.sin(ang),
              vy: -spd,
              physical: true));
        }
        _events.add(SessionEvent(SessionEventKind.chestOpen, x: ch.x, y: ch.y));
      }
    }

    // --- exit door
    final doorLeft = exitX - 8, doorTop = exitY - 30;
    final b = player.body;
    if (b.right > doorLeft &&
        b.left < doorLeft + 16 &&
        b.bottom > doorTop &&
        b.top < exitY) {
      _complete();
    }
  }

  /// AKP-4d: whether the spell button should show (spell equipped, charge
  /// unspent, run still live).
  bool get spellReady => loadout.spell != null && !spellUsed && !over;

  /// Cast the equipped spell (AKP-4d). One charge per run. Returns true if
  /// the cast happened. Spells ignore Rotshield block — magic pierces
  /// shields, which is the slot's identity vs the sword.
  bool castSpell() {
    if (!spellReady || player.state == PlayerState.dead) return false;
    spellUsed = true;
    final p = player.body;
    switch (loadout.spell!.effect) {
      case SpellEffect.emberBurst:
        for (final e in enemies) {
          if (!e.alive || e.sleeping) continue;
          final dx = e.centerX - p.centerX;
          final dy = e.centerY - p.centerY;
          if (dx * dx + dy * dy <=
              kSpellBurstRadius * kSpellBurstRadius) {
            e.damage(kSpellBurstDamage);
            if (e.alive) e.burnLeft = 3.0;
            _events.add(SessionEvent(SessionEventKind.enemyHit,
                x: e.centerX, y: e.centerY, amount: kSpellBurstDamage));
            if (!e.alive) _onEnemyDeath(e);
          }
        }
      case SpellEffect.stoneVeil:
        if (player.iFrames < kSpellVeilSeconds) {
          player.iFrames = kSpellVeilSeconds;
        }
      case SpellEffect.hearthLight:
        player.hearts =
            math.min(player.maxHearts, player.hearts + kSpellHealHearts);
    }
    _events.add(SessionEvent(SessionEventKind.spellCast,
        x: p.centerX, y: p.centerY));
    return true;
  }

  /// AKP-4c: fills [xs]/[ys] with up to [kApplePreviewDots] points along the
  /// trajectory an apple thrown RIGHT NOW would follow — same launch point,
  /// velocity and gravity as the projectile integrator (fine-stepped Euler,
  /// one dot every [kApplePreviewStep] s), stopping at the first solid or
  /// cracked tile. Returns the dot count. Buffers are caller-owned so the
  /// render layer can preallocate; an honest preview or none at all.
  int appleArcPreview(List<double> xs, List<double> ys) {
    var x = player.facing > 0 ? player.body.right : player.body.left;
    var y = player.body.top + 4;
    final vx = player.facing * kAppleThrowSpeed * kAppleThrowCos;
    var vy = -kAppleThrowSpeed * kAppleThrowSin;
    const dt = 1 / 120;
    // Integer step counting (never float time accumulation): a dot lands
    // exactly every stepsPerDot integration steps, so the preview and a
    // 120Hz-stepped projectile agree to the float ulp.
    final stepsPerDot = (kApplePreviewStep / dt).round();
    var n = 0;
    var step = 0;
    while (n < kApplePreviewDots && n < xs.length) {
      vy += kGravity * dt;
      x += vx * dt;
      y += vy * dt;
      step++;
      final tile = tileAt((x / kTileSize).floor(), (y / kTileSize).floor());
      if (tile == TileKind.solid || tile == TileKind.crackedWall) break;
      if (y > (level.height + 4) * kTileSize) break;
      if (step % stepsPerDot == 0) {
        xs[n] = x;
        ys[n] = y;
        n++;
      }
    }
    return n;
  }

  void _onEnemyDeath(EnemyCore e) {
    kills++;
    _events.add(
        SessionEvent(SessionEventKind.enemyDeath, x: e.centerX, y: e.centerY));
    if (e is BossCore) {
      // Victory burst: a shower of coins + feathers, then the door opens.
      final n = dropsRng.range(45, 60);
      for (var i = 0; i < n; i++) {
        final ang = dropsRng.range(-80, 80) * 3.14159 / 180;
        final spd = dropsRng.range(80, 200).toDouble();
        coins.add(CoinEntity(e.centerX, e.centerY - 8,
            vx: spd * 0.9 * math.sin(ang), vy: -spd, physical: true));
      }
      for (final off in const [-14.0, 0.0, 14.0]) {
        pickups.add(
            PickupEntity(SpawnKind.feather, e.centerX + off, e.centerY - 16));
      }
      _events.add(SessionEvent(SessionEventKind.bossDefeated,
          x: e.centerX, y: e.centerY));
    }
  }

  /// Sign text to show, or null (player within 1.5 tiles of a sign).
  SignEntity? get activeSign {
    const r = 1.5 * kTileSize;
    for (final s in signs) {
      final dx = s.x - player.body.centerX, dy = s.y - player.body.centerY;
      if (dx * dx + dy * dy <= r * r) return s;
    }
    return null;
  }

  int get chestsOpened => chests.where((c) => c.opened).length;
  int get chestTotal => chests.length;

  void _complete() {
    if (over) return;
    if (exitLocked) return; // boss arenas: door opens only when the boss dies
    completed = true;
    results = LevelResults(
      timeMs: (time * 1000).round(),
      parSeconds: level.parSeconds,
      coinsEarned: coinsCollected,
      chestsOpened: chestsOpened,
      chestTotal: chestTotal,
      secretsFound: secretsFound,
      finished: true,
      allChests: chestTotal > 0 ? chestsOpened == chestTotal : true,
      lowDamage: hitsTaken <= 1,
    );
    _events.add(const SessionEvent(SessionEventKind.levelComplete));
  }

  /// A death costs a life and rewinds to the last lit campfire (or the level
  /// spawn). Only running out of lives ends the run — the measured alpha
  /// behaviour, one hit-chain and the whole level restarts, is what made the
  /// game read as unfair next to Apple Knight.
  void _onDeath() {
    if (over) return;
    deaths++;
    if (lives <= 1) {
      lives = 0;
      _fail();
      return;
    }
    lives--;
    player.reviveAt(respawnX, respawnY, iFrames: kRespawnIFrames);
    cameraX = player.body.centerX;
    // Clear the landing zone. Without this a campfire next to a patrol route
    // means respawning straight back into the thing that just killed you —
    // measured: three lives gone at one spot in under 15 s. Enemies that were
    // crowding the respawn go home; nothing dead is resurrected.
    for (final e in enemies) {
      if (!e.alive) continue;
      if ((e.centerX - player.body.centerX).abs() > kRespawnClearRadius) {
        continue;
      }
      final home = _enemyHome[e];
      if (home == null) continue;
      e.body
        ..x = home.x
        ..y = home.y
        ..vx = 0
        ..vy = 0;
    }
    _events.add(SessionEvent(SessionEventKind.respawned,
        x: player.body.centerX, y: player.body.centerY));
  }

  void _fail() {
    if (over) return;
    failed = true;
    _events.add(const SessionEvent(SessionEventKind.levelFailed));
  }
}
