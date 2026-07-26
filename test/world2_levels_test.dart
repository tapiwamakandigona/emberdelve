// World 2 content acceptance (P-M9): every Cinder Depths level parses +
// lints clean, meets the spec quotas, uses the cave environment, spawns the
// new enemies, is bot-completable, and the world unlocks only after the
// World 1 boss falls.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/core/save.dart';
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/enemies/boss_core.dart';
import 'package:emberdelve/game/enemies/enemy_core.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';
import 'package:emberdelve/meta/progress_state.dart';

LevelData load(String id) =>
    LevelData.parse(File('assets/levels/$id.txt').readAsStringSync());

const maxGapTiles = 7;

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
  test('registry and files agree (every kWorld2 level exists)', () {
    for (final e in kWorld2) {
      expect(File('assets/levels/${e.id}.txt').existsSync(), isTrue,
          reason: '${e.id} missing');
    }
  });

  test('world 2 unlocks only after the World 1 boss', () {
    final fresh = SaveData();
    expect(isWorld2Unlocked(fresh), isFalse);
    expect(isLevelUnlocked(fresh, 0, world: kWorld2), isFalse);
    fresh.levels['w1_boss'] = LevelRecord()..finished = true;
    expect(isWorld2Unlocked(fresh), isTrue);
    expect(isLevelUnlocked(fresh, 0, world: kWorld2), isTrue);
    // ...but only the first level; the rest still chain-unlock.
    expect(isLevelUnlocked(fresh, 1, world: kWorld2), isFalse);
  });

  for (final entry in kWorld2) {
    group(entry.id, () {
      test('parses + lints clean, cave environment', () {
        final l = load(entry.id);
        expect(l.name, entry.title);
        expect(l.environment, 'cave');
      });

      test('door reachable: no gap wider than the double-jump budget', () {
        expect(widestGap(load(entry.id)), lessThanOrEqualTo(maxGapTiles));
      });

      if (!entry.isBoss) {
        test('content quotas: chests 2-7, secrets >=2, feathers 1-3', () {
          final l = load(entry.id);
          expect(l.chestCount, inInclusiveRange(2, 7));
          expect(l.secretCount, greaterThanOrEqualTo(2));
          expect(l.featherCount, inInclusiveRange(1, 3));
        });

        test('every secret chest sits behind cracked walls', () {
          final l = load(entry.id);
          for (final s
              in l.spawns.where((s) => s.kind == SpawnKind.secretChest)) {
            expect(_crackedNear(l, s.x, s.y), isTrue,
                reason: 'secret at (${s.x},${s.y}) unguarded');
          }
        });

        test('scripted runner bot reaches the door (completable)', () {
          expect(botCanFinish(entry.id), isTrue,
              reason: '${entry.id} not completable by the runner bot');
        });
      }

      test('spawns the expected entities in a live session', () {
        final l = load(entry.id);
        final s = LevelSession(l, Loadout.starter(), seed: 7);
        if (entry.isBoss) {
          // Contract change (2026-07-26): W2's boss is the Kiln Golem with its
          // own moveset, no longer a re-tinted GroveGolemCore. Same intent —
          // "the boss level spawns exactly one boss and locks the exit".
          expect(s.enemies.whereType<KilnGolemCore>().length, 1);
          expect(s.enemies.whereType<GroveGolemCore>(), isEmpty);
          expect(s.exitLocked, isTrue);
        } else {
          expect(s.enemies.whereType<SootCreeperCore>(), isNotEmpty,
              reason: 'W2 signature walker missing in ${entry.id}');
        }
      });
    });
  }

  test('divers appear from w2_l2 onward (progressive introduction)', () {
    for (final id in ['w2_l2', 'w2_l3', 'w2_l4', 'w2_l5']) {
      final s = LevelSession(load(id), Loadout.starter(), seed: 7);
      expect(s.enemies.whereType<CinderDiverCore>(), isNotEmpty,
          reason: '$id should field Cinder Divers');
    }
  });
}

bool _crackedNear(LevelData l, int x, int y) {
  for (var dy = -2; dy <= 2; dy++) {
    for (var dx = -3; dx <= 3; dx++) {
      final tx = x + dx, ty = y + dy;
      if (tx < 0 || tx >= l.width || ty < 0 || ty >= l.height) continue;
      if (l.tiles[ty][tx] == TileKind.crackedWall) return true;
    }
  }
  return false;
}

/// Same scripted runner bot as world1_levels_test (geometry-only check).
bool botCanFinish(String id) {
  final l = load(id);
  final s = LevelSession(l, Loadout.starter(), seed: 11);
  const dt = 1 / 60;
  final intent = InputIntent();
  var airJumped = false;
  const frames = 240 * 60;
  for (var i = 0; i < frames; i++) {
    final b = s.player.body;
    final dir = s.exitX >= b.centerX ? 1.0 : -1.0;
    intent
      ..dirX = dir
      ..down = false
      ..jumpHeld = true;
    intent.clearEdges();
    s.player.hearts = 3;
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
      final gapAhead = !solidish(s.tileAt(tx, footTy)) &&
          !solidish(s.tileAt(tx, footTy + 1));
      final wallAhead = solidish(
              s.tileAt(tx, ((b.top + 2) / kTileSize).floor())) ||
          solidish(s.tileAt(tx, ((b.bottom - 2) / kTileSize).floor()));
      if (gapAhead || wallAhead) intent.jumpPressed = true;
    } else if (b.vy > 30 && !airJumped) {
      intent.jumpPressed = true;
      airJumped = true;
    }
    if (i % 12 == 0) intent.attackPressed = true;
    s.update(dt, intent);
    if (s.completed) return true;
    if (s.failed) return false;
  }
  return false;
}
