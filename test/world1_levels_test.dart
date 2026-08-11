// World 1 content acceptance: every level in assets/levels parses + lints
// clean, meets the spec content quotas (>=2 secrets, 2-7 chests, 1-3
// feathers, fair par) and passes a beatable-path sanity check: required
// entities present, progressive enemy introduction honored, and no
// horizontal gap wider than the double-jump budget from the physics tuning.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/enemies/boss_core.dart';
import 'package:emberwood/game/enemies/enemy_core.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';
import 'package:emberwood/meta/progress_state.dart';

LevelData load(String id) =>
    LevelData.parse(File('assets/levels/$id.txt').readAsStringSync());

/// Max horizontal gap (in tiles) a double jump comfortably clears. Run speed
/// 118 px/s, double-jump airtime ~0.9s => >170px; we demand gaps <= 7 tiles
/// (112px) so every crossing has slack. (Physics tests pin the jump itself.)
const maxGapTiles = 7;

/// Widest contiguous run of columns with no standable tile anywhere (bottom
/// half of the level) — a crude but effective "no impossible gap" check.
int widestGap(LevelData l) {
  var widest = 0, run = 0;
  for (var x = 0; x < l.width; x++) {
    var standable = false;
    for (var y = 0; y < l.height; y++) {
      final t = l.tiles[y][x];
      if (t == TileKind.solid || t == TileKind.platform) {
        standable = true;
        break;
      }
    }
    if (standable) {
      run = 0;
    } else {
      run++;
      if (run > widest) widest = run;
    }
  }
  return widest;
}

void main() {
  test('registry and files agree (every kWorld1 level exists)', () {
    for (final e in kWorld1) {
      expect(File('assets/levels/${e.id}.txt').existsSync(), isTrue,
          reason: '${e.id}.txt missing');
    }
  });

  for (final entry in kWorld1) {
    group(entry.id, () {
      test('parses + lints clean', () {
        final l = load(entry.id); // parse() throws on any lint violation
        expect(l.playerSpawn, isNotNull);
        expect(l.exit, isNotNull);
        expect(l.name, entry.title);
      });

      test('door is reachable: no gap wider than the double-jump budget', () {
        final l = load(entry.id);
        expect(widestGap(l), lessThanOrEqualTo(maxGapTiles));
        // Exit must have ground under it.
        final e = l.exit;
        var grounded = false;
        for (var y = e.y + 1; y < l.height; y++) {
          final t = l.tiles[y][e.x];
          if (t == TileKind.solid || t == TileKind.platform) {
            grounded = true;
            break;
          }
        }
        expect(grounded, isTrue, reason: 'exit door floats');
      });

      if (!entry.isBoss) {
        test('content quotas: chests 2-7, secrets >=2, feathers 1-3', () {
          final l = load(entry.id);
          expect(l.chestCount, inInclusiveRange(2, 7));
          expect(l.secretCount, greaterThanOrEqualTo(2));
          expect(l.featherCount, inInclusiveRange(1, 3));
        });

        test('every secret chest sits behind a cracked wall or in a vault',
            () {
          final l = load(entry.id);
          // Each secret chest must have at least one cracked wall within 5
          // tiles — the way in is hidden, not open floor.
          final walls = <(int, int)>[];
          for (var y = 0; y < l.height; y++) {
            for (var x = 0; x < l.width; x++) {
              if (l.tiles[y][x] == TileKind.crackedWall) walls.add((x, y));
            }
          }
          for (final s
              in l.spawns.where((s) => s.kind == SpawnKind.secretChest)) {
            final near = walls.any((w) =>
                (w.$1 - s.x).abs() <= 5 && (w.$2 - s.y).abs() <= 3);
            expect(near, isTrue,
                reason: 'secret chest at (${s.x},${s.y}) has no hidden way in');
          }
        });

        test('par time is a fair speedrun estimate for the level length', () {
          final l = load(entry.id);
          // Walking the level end-to-end at run speed takes width*16/118 s;
          // par must be at least 2x that (combat/platforming) and below 300s.
          final walkSeconds = l.width * 16 / 118;
          expect(l.parSeconds, greaterThanOrEqualTo((walkSeconds * 2).ceil()));
          expect(l.parSeconds, lessThanOrEqualTo(300));
        });
      }

      if (!entry.isBoss) {
        test('scripted runner bot reaches the door (completable)', () {
          expect(botCanFinish(entry.id), isTrue,
              reason: '${entry.id}: door-seeking runner bot never reached the exit');
        });
      }

      test('spawns all required entities in a live session', () {
        final l = load(entry.id);
        final s = LevelSession(l, Loadout.starter(), seed: 7);
        switch (entry.id) {
          case 'w1_l1':
            expect(s.enemies.whereType<ThornlingCore>(), isNotEmpty);
          case 'w1_l2': // + hoppers (via meta) — thornlings/ashbats persist
            expect(s.enemies.whereType<HopperCore>().length,
                greaterThanOrEqualTo(2));
            expect(s.enemies.whereType<ThornlingCore>(), isNotEmpty);
            expect(s.enemies.whereType<AshbatCore>(), isNotEmpty);
            expect(s.enemies.whereType<EmberTotemCore>(), isEmpty,
                reason: 'totems introduced in l3');
          case 'w1_l3': // + ember totems
            expect(s.enemies.whereType<EmberTotemCore>().length,
                greaterThanOrEqualTo(2));
            expect(s.enemies.whereType<RotshieldCore>(), isEmpty,
                reason: 'rotshields introduced in l4');
          case 'w1_l4': // + rotshields
            expect(s.enemies.whereType<RotshieldCore>().length,
                greaterThanOrEqualTo(2));
          case 'w1_l5': // the full mix
            expect(s.enemies.whereType<EmberTotemCore>(), isNotEmpty);
            expect(s.enemies.whereType<RotshieldCore>(), isNotEmpty);
            expect(s.enemies.whereType<HopperCore>(), isNotEmpty);
            expect(s.enemies.whereType<AshbatCore>(), isNotEmpty);
            expect(s.enemies.whereType<ThornlingCore>(), isNotEmpty);
          case 'w1_boss':
            expect(s.enemies.whereType<GroveGolemCore>().length, 1);
            expect(s.exitLocked, isTrue);
        }
      });
    });
  }
}

/// Scripted "runner bot" completability evidence: hold right, jump whenever
/// blocked/falling, swing constantly, with god-mode hearts (completability is
/// about geometry, not combat skill). Boss level is exempt (door locked by
/// design until the boss dies — covered in boss_core_test).
bool botCanFinish(String id) {
  final l = load(id);
  final s = LevelSession(l, Loadout.starter(), seed: 11);
  const dt = 1 / 60;
  final intent = InputIntent();
  var airJumped = false;
  const frames = 240 * 60;
  for (var i = 0; i < frames; i++) {
    final b = s.player.body;
    // Steer toward the door (a runner that overshoots walks back).
    final dir = s.exitX >= b.centerX ? 1.0 : -1.0;
    intent
      ..dirX = dir
      ..down = false
      ..jumpHeld = true;
    intent.clearEdges();
    s.player.hearts = 3; // god mode: geometry-only check
    bool solidish(TileKind t) =>
        t == TileKind.solid ||
        t == TileKind.platform ||
        t == TileKind.crackedWall;
    if (b.onGround) {
      airJumped = false;
      final tx = dir > 0
          ? ((b.right + 6) / kTileSize).floor()
          : ((b.left - 6) / kTileSize).floor();
      final footTy = ((b.bottom + 1) / kTileSize).floor();
      // Gap ahead: nothing to stand on within 2 tiles below the lip.
      final gapAhead = !solidish(s.tileAt(tx, footTy)) &&
          !solidish(s.tileAt(tx, footTy + 1));
      // Wall ahead at body height.
      final wallAhead = solidish(
              s.tileAt(tx, ((b.top + 2) / kTileSize).floor())) ||
          solidish(s.tileAt(tx, ((b.bottom - 2) / kTileSize).floor()));
      if (gapAhead || wallAhead) intent.jumpPressed = true;
    } else if (b.vy > 30 && !airJumped) {
      intent.jumpPressed = true; // double jump on the way down
      airJumped = true;
    }
    if (i % 12 == 0) intent.attackPressed = true;
    s.update(dt, intent);
    if (s.completed) return true;
    if (s.failed) return false; // fell out of the level
  }
  return false;
}
