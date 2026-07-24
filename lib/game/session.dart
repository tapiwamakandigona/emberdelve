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
import 'enemies/enemy_core.dart';
import 'input_intent.dart';
import 'level/level_data.dart';
import 'player/player_core.dart';
import 'tuning.dart';

/// Session-level events (sfx/fx hooks for the render layer).
enum SessionEventKind {
  coin, // +data: x,y
  applePickup,
  feather,
  chestOpen,
  enemyHit, // data: x,y crit
  enemyDeath, // data: x,y
  wallHit,
  wallBreak, // data: tile x,y
  appleThrown,
  appleBroke, // data: x,y
  attackBlocked, // data: x,y — Rotshield shield ate a hit ('block' sfx)
  emberShot, // data: x,y — Ember Totem fired
  emberShotBroke, // data: x,y — ember hit terrain / player / limits
  levelComplete,
  levelFailed,
}

class SessionEvent {
  final SessionEventKind kind;
  final double x, y;
  final bool crit;
  const SessionEvent(this.kind, {this.x = 0, this.y = 0, this.crit = false});
}

class CoinEntity {
  double x, y; // center px
  double vx, vy;
  bool physical; // chest-burst coins fly and settle before collection
  double settleTime = 0;
  bool collected = false;
  CoinEntity(this.x, this.y, {this.vx = 0, this.vy = 0, this.physical = false});
}

class PickupEntity {
  final SpawnKind kind; // apple / feather
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
}

class LevelSession {
  final LevelData level;
  final Loadout loadout;
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
  int coinsCollected = 0;
  int applesHeld = 0;
  int feathersCollected = 0;
  int hitsTaken = 0;
  int kills = 0;
  int secretsFound = 0;
  double hitPause = 0;
  bool completed = false;
  bool failed = false;
  bool get over => completed || failed;
  LevelResults? results;

  /// Camera center x (px), fed by the render layer for enemy sleeping.
  double cameraX = 0;

  // Melee swing bookkeeping: one damage application per enemy per swing.
  final Set<EnemyCore> _swingVictims = {};
  final Set<CrackedWall> _swingWalls = {};

  final List<SessionEvent> _events = [];
  final List<PlayerEvent> _playerEvents = [];

  LevelSession(this.level, this.loadout, {int seed = 0})
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
      maxHearts: loadout.maxHearts,
      weaponDamage: loadout.weapon.damage,
      weaponRange: loadout.weapon.range,
      extraAirJumps: loadout.extraAirJumps,
      meleePower: loadout.meleePower,
    );
    cameraX = player.body.centerX;

    var signIndex = 0;
    for (final s in level.spawns) {
      final cx = s.x * kTileSize + kTileSize / 2;
      final cy = s.y * kTileSize + kTileSize / 2;
      switch (s.kind) {
        case SpawnKind.coin:
          coins.add(CoinEntity(cx, cy));
        case SpawnKind.apple:
        case SpawnKind.feather:
          pickups.add(PickupEntity(s.kind, cx, cy));
        case SpawnKind.chest:
          chests.add(ChestEntity(cx, cy, secret: false));
        case SpawnKind.secretChest:
          chests.add(ChestEntity(cx, cy, secret: true));
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
          // TODO(M5-boss): Grove Golem lands in the boss commit.
          break;
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
  }

  /// Spawn a hopper explicitly (used by tests and, later, level scripting).
  void addHopper(double x, double y) => enemies.add(HopperCore(x: x, y: y));

  TileKind tileAt(int tx, int ty) {
    if (tx < 0 || tx >= level.width) return TileKind.solid;
    if (ty < 0 || ty >= level.height) return TileKind.empty;
    return grid[ty][tx];
  }

  List<SessionEvent> takeEvents() {
    final out = List<SessionEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// Player events forwarded from the core (jumped/landed/hurt/died...).
  List<PlayerEvent> takePlayerEvents() {
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
      final p = _applePool.cast<AppleProjectile?>().firstWhere(
          (a) => !a!.active,
          orElse: () => null);
      if (p != null) {
        applesHeld--;
        p.active = true;
        p.x = player.facing > 0 ? player.body.right : player.body.left;
        p.y = player.body.top + 4;
        // ~40 degrees up in the facing direction.
        p.vx = player.facing * kAppleThrowSpeed * 0.766;
        p.vy = -kAppleThrowSpeed * 0.643;
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
      _fail();
      return;
    }
    if (pev.contains(PlayerEvent.hurt)) hitsTaken++;

    // Fall-out death: below level bottom + 3 tiles.
    if (player.body.top > (level.height + 3) * kTileSize) {
      player.kill();
      _playerEvents.addAll(player.takeEvents());
      _fail();
      return;
    }

    // --- enemies
    final sleepDist = 1.5 * 480; // 1.5 screens at 480px view width
    for (final e in enemies) {
      if (!e.alive) continue;
      e.sleeping = (e.centerX - cameraX).abs() > sleepDist;
      final burnKilled = e.update(dt, tileAt,
          playerX: player.body.centerX, playerY: player.body.centerY);
      if (burnKilled) {
        _onEnemyDeath(e);
        continue;
      }
      // Totems request aimed shots; the session owns the projectile pool.
      if (e is EmberTotemCore && !e.sleeping) {
        final req = e.takeShotRequest();
        if (req != null) {
          final shot = _emberPool
              .cast<EmberShot?>()
              .firstWhere((s) => !s!.active, orElse: () => null);
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
      // Contact damage: 1 heart.
      if (!e.sleeping && e.overlapsBody(player.body)) {
        if (player.damage(1, from: e.centerX)) {
          hitsTaken++;
          final dpev = player.takeEvents();
          _playerEvents.addAll(dpev);
          if (dpev.contains(PlayerEvent.died)) {
            _fail();
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
              x: e.centerX, y: e.centerY, crit: crit));
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
            x: e.centerX, y: e.centerY));
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
            _fail();
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
        if (ch.secret) secretsFound++;
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

  void _onEnemyDeath(EnemyCore e) {
    kills++;
    _events.add(
        SessionEvent(SessionEventKind.enemyDeath, x: e.centerX, y: e.centerY));
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

  void _fail() {
    if (over) return;
    failed = true;
    _events.add(const SessionEvent(SessionEventKind.levelFailed));
  }
}
