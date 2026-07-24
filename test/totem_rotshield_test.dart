// Headless tests for the two M5 World-1 enemies: Ember Totem (stationary
// ranged spitter with LOS + cooldown) and Rotshield (slow patroller whose
// front shield blocks melee AND apples; vulnerable from behind/above).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/enemies/enemy_core.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';

const dt = 1 / 120;

void stepSession(LevelSession s, double seconds,
    [void Function(InputIntent)? config]) {
  final frames = (seconds / dt).round();
  final intent = InputIntent();
  for (var i = 0; i < frames; i++) {
    intent
      ..dirX = 0
      ..down = false
      ..jumpHeld = false;
    intent.clearEdges();
    config?.call(intent);
    s.update(dt, intent);
  }
}

LevelSession session(String ascii, {int seed = 3, Loadout? loadout}) =>
    LevelSession(LevelData.parse(ascii), loadout ?? Loadout.starter(),
        seed: seed);

void main() {
  group('Ember Totem', () {
    test('spawns from legend O with hp 5 and never moves', () {
      final s = session('''
....................
.P........O........E
####################
''');
      final totem = s.enemies.whereType<EmberTotemCore>().single;
      expect(totem.hp, 5);
      final x0 = totem.body.x, y0 = totem.body.y;
      stepSession(s, 2.0);
      expect(totem.body.x, x0);
      expect(totem.body.y, y0);
    });

    test('fires at player in range with LOS, honors cooldown', () {
      final s = session('''
....................
.P........O........E
####################
''');
      // Player idles in range (~9 tiles wide level, totem 10 tiles away? no:
      // player at x=1, totem x=11 → 10 tiles ≈ 160px > 8-tile range. Walk in.
      stepSession(s, 0.8, (i) => i.dirX = 1);
      var shots = 0;
      final t0 = s.time;
      var firstShot = -1.0, secondShot = -1.0;
      final intent = InputIntent();
      for (var i = 0; i < (6.0 / dt).round(); i++) {
        intent.clearEdges();
        intent.dirX = 0;
        s.update(dt, intent);
        for (final e in s.takeEvents()) {
          if (e.kind == SessionEventKind.emberShot) {
            shots++;
            if (firstShot < 0) {
              firstShot = s.time;
            } else if (secondShot < 0) {
              secondShot = s.time;
            }
          }
        }
        if (s.over) break;
      }
      expect(shots, greaterThanOrEqualTo(2),
          reason: 'totem in range should keep firing');
      expect(secondShot - firstShot, greaterThanOrEqualTo(2.0),
          reason: 'cooldown between shots');
      expect(s.time - t0, greaterThan(0));
    });

    test('does not fire without line of sight', () {
      final s = session('''
....................
.....#..............
.P...#..O..........E
####################
''');
      final events = <SessionEventKind>[];
      final intent = InputIntent();
      for (var i = 0; i < (4.0 / dt).round(); i++) {
        intent.clearEdges();
        s.update(dt, intent);
        events.addAll(s.takeEvents().map((e) => e.kind));
      }
      expect(events, isNot(contains(SessionEventKind.emberShot)));
    });

    test('shot breaks on terrain and damages the player on contact', () {
      final s = session('''
....................
.P.........O.......E
####################
''');
      // Stand still just inside range; take the hit.
      stepSession(s, 0.9, (i) => i.dirX = 1);
      final heartsBefore = s.player.hearts;
      var shotBroke = false;
      final intent = InputIntent();
      for (var i = 0; i < (6.0 / dt).round(); i++) {
        intent.clearEdges();
        s.update(dt, intent);
        for (final e in s.takeEvents()) {
          if (e.kind == SessionEventKind.emberShotBroke) shotBroke = true;
        }
        if (s.player.hearts < heartsBefore) break;
      }
      expect(s.player.hearts, lessThan(heartsBefore));
      expect(shotBroke, isTrue);
      expect(s.hitsTaken, greaterThanOrEqualTo(1));
    });

    test('dies to melee like any enemy', () {
      final s = session('''
....................
.P.O...............E
####################
''');
      final totem = s.enemies.whereType<EmberTotemCore>().single;
      var died = false;
      final intent = InputIntent();
      for (var i = 0; i < (8.0 / dt).round() && !died; i++) {
        intent.clearEdges();
        intent.dirX =
            (totem.centerX - s.player.body.centerX) > 24 ? 1.0 : 0.0;
        if (i % 30 == 0) intent.attackPressed = true;
        s.update(dt, intent);
        died = !totem.alive;
      }
      expect(died, isTrue);
      expect(s.kills, greaterThanOrEqualTo(1));
    });
  });

  group('Rotshield', () {
    test('spawns from legend R with hp 6 and patrols slowly', () {
      final s = session('''
....................
....................
.P.......R.........E
####################
''');
      final rot = s.enemies.whereType<RotshieldCore>().single;
      expect(rot.hp, 6);
      final x0 = rot.centerX;
      stepSession(s, 1.0);
      expect((rot.centerX - x0).abs(), greaterThan(4)); // moving
      expect((rot.centerX - x0).abs(), lessThan(30)); // ...but slow
    });

    test('front shield blocks melee (no damage, block event)', () {
      final rot = RotshieldCore(x: 100, y: 100);
      rot.facing = -1; // shield faces left
      expect(rot.blocksHit(fromX: 80, fromY: 110), isTrue); // front
      expect(rot.blocksHit(fromX: 140, fromY: 110), isFalse); // behind
      expect(rot.blocksHit(fromX: 80, fromY: 60), isFalse); // above
    });

    test('melee into the shield emits attackBlocked and deals no damage', () {
      final s = session('''
....................
.....R.P...........E
####################
''');
      final rot = s.enemies.whereType<RotshieldCore>().single;
      rot.facing = 1; // face the player (shield toward player)
      final events = <SessionEventKind>[];
      final intent = InputIntent();
      // Hold position pressed up against the shield, swinging.
      for (var i = 0; i < (1.2 / dt).round(); i++) {
        intent.clearEdges();
        intent.dirX = i < 8 ? -1.0 : 0.0; // face the rotshield (left)
        if (i % 40 == 0 && i > 10) intent.attackPressed = true;
        // Keep the rotshield facing the player each frame (it patrols).
        rot.facing = s.player.body.centerX >= rot.centerX ? 1 : -1;
        s.update(dt, intent);
        events.addAll(s.takeEvents().map((e) => e.kind));
      }
      expect(events, contains(SessionEventKind.attackBlocked));
      expect(rot.hp, 6, reason: 'shielded front takes no melee damage');
    });

    test('vulnerable from behind: melee damages normally', () {
      final s = session('''
....................
.....R.P...........E
####################
''');
      final rot = s.enemies.whereType<RotshieldCore>().single;
      final intent = InputIntent();
      for (var i = 0; i < (1.2 / dt).round(); i++) {
        intent.clearEdges();
        intent.dirX = i < 8 ? -1.0 : 0.0; // face the rotshield (left)
        if (i % 40 == 0 && i > 10) intent.attackPressed = true;
        rot.facing = -1; // always facing away from the player
        s.update(dt, intent);
        s.takeEvents();
        if (rot.hp < 6) break;
      }
      expect(rot.hp, lessThan(6));
    });

    test('shield blocks apples too (block + appleBroke, no damage)', () {
      final s = session('''
....................
.........R.........E
.P..................
####################
''');
      final rot = s.enemies.whereType<RotshieldCore>().single;
      stepSession(s, 0.5); // let the patroller settle onto the ground
      // Drive an in-flight apple straight into the shielded front
      // (deterministic: the pool is the session contract for projectiles).
      final a = s.appleProjectiles.first;
      a
        ..active = true
        ..x = rot.centerX - 16
        ..y = rot.centerY
        ..vx = 120
        ..vy = 0;
      final events = <SessionEventKind>[];
      final intent = InputIntent();
      for (var i = 0; i < (1.0 / dt).round() && a.active; i++) {
        intent.clearEdges();
        rot.facing = -1; // shield toward the incoming apple
        s.update(dt, intent);
        events.addAll(s.takeEvents().map((e) => e.kind));
      }
      expect(events, contains(SessionEventKind.attackBlocked));
      expect(events, contains(SessionEventKind.appleBroke));
      expect(rot.hp, 6);
      expect(rot.alive, isTrue);
    });

    test('apples from behind damage normally', () {
      final s = session('''
....................
.........R.........E
.P..................
####################
''');
      final rot = s.enemies.whereType<RotshieldCore>().single;
      stepSession(s, 0.5); // settle
      final a = s.appleProjectiles.first;
      a
        ..active = true
        ..x = rot.centerX + 16
        ..y = rot.centerY
        ..vx = -120
        ..vy = 0;
      final intent = InputIntent();
      for (var i = 0; i < (1.0 / dt).round() && a.active; i++) {
        intent.clearEdges();
        rot.facing = -1; // shield away from the incoming apple
        s.update(dt, intent);
        s.takeEvents();
      }
      expect(rot.hp, 6 - kAppleDamage);
    });
  });

  group('hopper meta spawning', () {
    test('meta hopperN=tx,ty spawns hoppers without a legend char', () {
      final level = LevelData.parse('''
meta: hopper1=5,1
meta: hopper2=9,1
....................
.P.................E
####################
''');
      final s = LevelSession(level, Loadout.starter(), seed: 1);
      final hoppers = s.enemies.whereType<HopperCore>().toList();
      expect(hoppers.length, 2);
      expect(hoppers[0].centerX, closeTo(5 * kTileSize + 14, 16));
    });

    test('malformed hopper meta is ignored', () {
      final level = LevelData.parse('''
meta: hopper1=oops
....................
.P.................E
####################
''');
      final s = LevelSession(level, Loadout.starter(), seed: 1);
      expect(s.enemies.whereType<HopperCore>(), isEmpty);
    });
  });
}
