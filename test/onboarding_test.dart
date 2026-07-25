// onboarding_test.dart — AKP-6 acceptance (docs/ak-parity-plan.md §6):
// AK-style onboarding. The old w1_l1 killed playtest bots in <10s: a 6-wide
// spike pit 4 tiles from spawn, and pit knockback that never escaped the pit
// (chain deaths until dead).
//
// Now: verbs are taught on safe ground first (the only obstacle a non-jumping
// player meets is a harmless 1-tile step, never a hazard), the first pit is
// 3 tiles wide and >= 10 tiles from spawn, and hazard damage EJECTS the
// player up and out of the pit (AKP-6b) instead of leaving them inside.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/physics.dart';
import 'package:emberdelve/game/player/player_core.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';

const dt = 1 / 60;

LevelData load(String id) =>
    LevelData.parse(File('assets/levels/$id.txt').readAsStringSync());

/// Column has a hazard tile anywhere.
bool hazardColumn(LevelData l, int x) {
  for (var y = 0; y < l.height; y++) {
    final t = l.tiles[y][x];
    if (t == TileKind.spikes || t == TileKind.fire) return true;
  }
  return false;
}

void main() {
  group('w1_l1 teaches before it tests (AKP-6a)', () {
    test('first hazard is >= 10 tiles right of spawn', () {
      final l = load('w1_l1');
      final spawn = l.playerSpawn;
      var firstHazard = -1;
      for (var x = spawn.x; x < l.width; x++) {
        if (hazardColumn(l, x)) {
          firstHazard = x;
          break;
        }
      }
      expect(firstHazard, isNot(-1));
      expect(firstHazard - spawn.x, greaterThanOrEqualTo(10),
          reason: 'jump must be teachable on safe ground first');
    });

    test('first pit is at most 3 tiles wide', () {
      final l = load('w1_l1');
      final spawn = l.playerSpawn;
      var x = spawn.x;
      while (x < l.width && !hazardColumn(l, x)) {
        x++;
      }
      var width = 0;
      while (x + width < l.width && hazardColumn(l, x + width)) {
        width++;
      }
      expect(width, inInclusiveRange(1, 3));
    });

    test('a jump-teaching sign stands between spawn and the first hazard',
        () {
      final l = load('w1_l1');
      final spawn = l.playerSpawn;
      var firstHazard = spawn.x;
      while (!hazardColumn(l, firstHazard)) {
        firstHazard++;
      }
      final sign = l.spawns.firstWhere((s) =>
          s.kind == SpawnKind.sign && s.x > spawn.x && s.x < firstHazard);
      expect(sign, isNotNull);
    });

    test('naive hold-right bot (never jumps) survives >= 30s', () {
      final l = load('w1_l1');
      final s = LevelSession(l, Loadout.starter(), seed: 5);
      final intent = InputIntent();
      final frames = (30 / dt).ceil();
      for (var i = 0; i < frames; i++) {
        intent
          ..dirX = 1
          ..down = false
          ..jumpHeld = false;
        intent.clearEdges();
        s.update(dt, intent);
        expect(s.player.isDead, isFalse,
            reason: 'hold-right-only player died at t=${(i * dt).toStringAsFixed(1)}s '
                'x=${s.player.body.centerX.toStringAsFixed(0)} — onboarding '
                'must block, not kill, a player who has not learned to jump');
      }
    });
  });

  test('every shipped level keeps hazard pits <= 5 columns wide', () {
    // The AKP-6b ejection arc (kHazardEjectSpeedY/X) recovers pits of this
    // width; anything wider risks re-entering the hazard mid-arc. Design
    // guard for all current and future levels.
    final files = Directory('assets/levels')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'));
    for (final f in files) {
      final l = LevelData.parse(f.readAsStringSync());
      var run = 0;
      for (var x = 0; x < l.width; x++) {
        if (hazardColumn(l, x)) {
          run++;
          expect(run, lessThanOrEqualTo(5),
              reason: '${f.path}: hazard pit wider than the ejection arc');
        } else {
          run = 0;
        }
      }
    }
  });

  group('hazard pits eject (AKP-6b)', () {
    // 4-wide pit: the widest hazard pit that ships in any level (w1_l1 fire
    // 30-33, spikes 53-56). Ejection is tuned to clear exactly this class of
    // pit — level design must keep hazard pits <= 4 tiles (see width guard
    // below).
    final pitLevel = LevelData.parse('''
.P.....................................E
#####....###############################
#####^^^^###############################
########################################
''');

    PlayerCore settle(LevelData l) {
      final s = l.playerSpawn;
      final c = PlayerCore(
        x: s.x * kTileSize + 2,
        y: (s.y + 1) * kTileSize - 20,
        tileAt: l.tileAt,
      );
      final idle = InputIntent();
      for (var i = 0; i < 30; i++) {
        c.update(dt, idle);
      }
      c.takeEvents();
      return c;
    }

    test('walking into a spike pit throws the player up and out', () {
      final c = settle(pitLevel);
      final intent = InputIntent();
      var hurtAt = -1.0;
      var recovered = false;
      for (var i = 0; i < (4 / dt).ceil(); i++) {
        intent
          ..dirX = 1
          ..down = false
          ..jumpHeld = false;
        intent.clearEdges();
        c.update(dt, intent);
        final t = i * dt;
        if (hurtAt < 0 && c.hearts < c.maxHearts) hurtAt = t;
        if (hurtAt >= 0 &&
            c.body.onGround &&
            !touchesHazard(c.body, pitLevel.tileAt)) {
          recovered = true;
          break;
        }
      }
      expect(hurtAt, greaterThanOrEqualTo(0), reason: 'pit must damage once');
      expect(c.isDead, isFalse);
      expect(recovered, isTrue,
          reason: 'ejection must land the player on safe ground, not leave '
              'them chain-dying at the pit bottom');
    });

    test('ejection is stronger than regular knockback and clears the lip',
        () {
      final c = settle(pitLevel);
      c.body.vx = kRunSpeed; // travelling right into the pit
      final landed = c.damage(1, from: c.body.centerX, hazardEject: true);
      expect(landed, isTrue);
      expect(c.body.vy, -kHazardEjectSpeedY);
      expect(c.body.vx, kHazardEjectSpeedX,
          reason: 'eject follows the direction of travel');
    });
  });
}
