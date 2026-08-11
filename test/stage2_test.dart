// Stage 2 acceptance (owner-directed 2026-07-25): difficulty modes, smarter
// enemy AI, two new enemies (Pyre Wisp, Slag Hound), per-level lore lines.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/save.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/difficulty.dart';
import 'package:emberwood/game/enemies/enemy_core.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';
import 'package:emberwood/meta/progress_state.dart';

const dt = 1 / 60;

void stepCore(EnemyCore e, LevelData l, double seconds,
    {required double px, required double py}) {
  final frames = (seconds / dt).round();
  for (var i = 0; i < frames; i++) {
    e.update(dt, l.tileAt, playerX: px, playerY: py);
  }
}

final flat = LevelData.parse('''
............................
............................
............................
P..........................E
############################
''');

// A 6-tile platform with air on both sides, floor far below.
final ledged = LevelData.parse('''
............................
............................
..........######............
............................
............................
P..........................E
############################
''');

void main() {
  group('difficulty', () {
    test('ids round-trip and unknown values fall back to medium', () {
      expect(difficultyFromId('easy'), Difficulty.easy);
      expect(difficultyFromId('hard'), Difficulty.hard);
      expect(difficultyFromId('medium'), Difficulty.medium);
      expect(difficultyFromId('garbage'), Difficulty.medium);
      for (final d in Difficulty.values) {
        expect(difficultyFromId(difficultyId(d)), d);
      }
    });

    test('save persists difficulty, defaults to medium', () {
      expect(SaveData().difficulty, 'medium');
      final s = SaveData(difficulty: 'hard');
      final back = SaveData.fromJson(
          s.toJson().map((k, v) => MapEntry(k, v as dynamic)));
      expect(back.difficulty, 'hard');
    });

    test('easy grants one heart of slack; enemy hp is never scaled', () {
      final easy = LevelSession(flat, Loadout.starter(),
          seed: 3, difficulty: Difficulty.easy);
      final hard = LevelSession(flat, Loadout.starter(),
          seed: 3, difficulty: Difficulty.hard);
      expect(easy.player.maxHearts, hard.player.maxHearts + 1);
      final e1 = ThornlingCore(x: 100, y: 40)
        ..mods = DifficultyMods.easy;
      final e2 = ThornlingCore(x: 100, y: 40)
        ..mods = DifficultyMods.hard;
      expect(e1.hp, e2.hp, reason: 'no cheap stat walls');
    });

    test('session stamps its mods onto every spawned enemy', () {
      final l = LevelData.parse('''
............................
............................
....T....W....H.............
P..........................E
############################
''');
      final s = LevelSession(l, Loadout.starter(),
          seed: 3, difficulty: Difficulty.hard);
      expect(s.enemies, isNotEmpty);
      for (final e in s.enemies) {
        expect(e.mods, DifficultyMods.hard);
      }
      expect(s.enemies.whereType<PyreWispCore>().length, 1);
      expect(s.enemies.whereType<SlagHoundCore>().length, 1);
    });

    test('hard enemies genuinely move faster than easy', () {
      double runSpeed(DifficultyMods mods) {
        final e = ThornlingCore(x: 200, y: 40)..mods = mods;
        stepCore(e, flat, 0.5, px: 0, py: 0); // player far: patrol speed
        return e.body.vx.abs();
      }

      expect(runSpeed(DifficultyMods.hard),
          greaterThan(runSpeed(DifficultyMods.easy)));
    });
  });

  group('smarter AI', () {
    test('thornling breaks into a hunting burst when stalked', () {
      final e = ThornlingCore(x: 200, y: 40);
      stepCore(e, flat, 0.2, px: 0, py: 400); // far player: patrol
      final patrolVx = e.body.vx.abs();
      // Player close, ahead (in facing direction), same height.
      final aheadX = e.centerX + e.facing * 40;
      stepCore(e, flat, 0.2, px: aheadX, py: e.centerY);
      expect(e.hunting, isTrue);
      expect(e.body.vx.abs(), greaterThan(patrolVx * 1.3));
    });

    test('hopper leads a moving target', () {
      // Player slightly LEFT of the hopper but sprinting RIGHT: the old AI
      // aimed at the current position (left); the leading AI must hop
      // right, where the target is going.
      final e = HopperCore(x: 200, y: 42); // bottom flush with the floor
      // Prime the velocity estimate out of aggro range, then sprint in.
      e.update(dt, flat.tileAt, playerX: 100, playerY: 56);
      e.update(dt, flat.tileAt, playerX: 206, playerY: 56);
      expect(e.airborne, isTrue, reason: 'in range: the hop must fire');
      expect(e.body.vx.sign, 1.0,
          reason: 'hop must lead the rightward sprinter, not chase behind');
    });

    test('rotshield turns to face a lingering backstabber', () {
      final e = RotshieldCore(x: 200, y: 40);
      e.facing = 1; // shield right
      // Player standing close BEHIND (left of) it.
      final behindX = e.centerX - 30;
      expect(
          e.blocksHit(fromX: behindX, fromY: e.centerY), isFalse,
          reason: 'backstab is open at first');
      stepCore(e, flat, 1.2, px: behindX, py: e.centerY);
      expect(e.facing, -1,
          reason: 'guard turn: shield swings to the lingering player');
    });
  });

  group('new enemies', () {
    test('pyre wisp chases in range and drifts home after', () {
      final e = PyreWispCore(x: 200, y: 30);
      final homeX = e.body.x;
      // Player inside aggro: closes distance.
      final d0 = (e.centerX - 120).abs();
      stepCore(e, flat, 1.0, px: 120, py: 40);
      expect(e.chasing, isTrue);
      expect((e.centerX - 120).abs(), lessThan(d0));
      // Player leaves: wisp returns toward its anchor.
      stepCore(e, flat, 3.0, px: 5000, py: 5000);
      expect(e.chasing, isFalse);
      expect((e.body.x - homeX).abs(), lessThan(24),
          reason: 'wisp floats home when the player escapes');
    });

    test('slag hound telegraphs then charges much faster than patrol', () {
      final e = SlagHoundCore(x: 200, y: 40);
      stepCore(e, flat, 0.3, px: 0, py: 400); // far: patrol
      final patrolVx = e.body.vx.abs();
      // Player near, same height -> telegraph (stopped), then charge.
      final px = e.centerX + 60;
      stepCore(e, flat, dt * 4, px: px, py: e.centerY);
      expect(e.telegraphing, isTrue);
      expect(e.body.vx.abs(), 0, reason: 'telegraph is a full stop tell');
      stepCore(e, flat, SlagHoundCore.telegraphTime + 0.1,
          px: px, py: e.centerY);
      expect(e.charging, isTrue);
      expect(e.body.vx.abs(), greaterThan(patrolVx * 2.5));
    });

    test('slag hound never charges off a ledge', () {
      // Standing on the floating platform (tiles x=10..15, row y=2; top of
      // the platform surface = 32px). Bait charges toward the right edge.
      final e = SlagHoundCore(x: 12 * kTileSize, y: 2 * kTileSize - 22);
      stepCore(e, ledged, 3.0, px: 15 * kTileSize, py: e.centerY);
      expect(e.body.bottom, lessThanOrEqualTo(2 * kTileSize + 1),
          reason: 'hound must still be on the platform, not the floor');
    });
  });

  group('lore', () {
    test('every shipped level has a short lore line', () {
      for (final entry in [...kWorld1, ...kWorld2]) {
        final l = LevelData.parse(
            File('assets/levels/${entry.id}.txt').readAsStringSync());
        final lore = l.meta['lore'];
        expect(lore, isNotNull, reason: '${entry.id} missing lore');
        expect(lore!.trim(), isNotEmpty);
        expect(lore.length, lessThanOrEqualTo(58),
            reason: '${entry.id} lore too long for the HUD intro');
      }
    });
  });
}
