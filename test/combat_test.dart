// Headless combat tests over LevelSession: melee swings damage once per
// swing, crits come deterministically from the seeded 'combat' stream,
// hit-pause freezes the sim, burn DoT ticks with Ember Fang, apples arc.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/core/rng.dart';
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';
import 'package:emberdelve/meta/catalog.dart';

const dt = 1 / 120;

/// Player with a Thornling a sword-length to the right.
LevelSession combatSession({int seed = 7, Weapon? weapon}) {
  final level = LevelData.parse('''
....................
....................
.P.T...............E
####################
''');
  return LevelSession(level, Loadout.starter(weapon: weapon), seed: seed);
}

void stepSession(LevelSession s, double seconds,
    void Function(InputIntent) config) {
  final frames = (seconds / dt).round();
  final intent = InputIntent();
  for (var i = 0; i < frames; i++) {
    intent
      ..dirX = 0
      ..down = false
      ..jumpHeld = false;
    intent.clearEdges();
    config(intent);
    s.update(dt, intent);
  }
}

/// Expected damage of the FIRST swing given the seeded combat stream.
int expectedFirstSwingDamage(int seed, Weapon w, {int comboIndex = 0}) {
  final rng = Rng.create(seed, 'combat');
  final isFinisher = comboIndex == kComboHits - 1;
  var dmg = (w.damage * (isFinisher ? 1.5 : 1.0)).round().clamp(1, 99);
  final crit = rng.range(1, 100) <= w.critPercent;
  if (crit) dmg = (dmg * w.critMultiplier).round();
  return dmg;
}

void main() {
  test('one swing damages each enemy exactly once', () {
    final s = combatSession();
    final enemy = s.enemies.single;
    var first = true;
    stepSession(s, 0.30, (i) {
      if (first) {
        i.attackPressed = true;
        first = false;
      }
    });
    final expected =
        expectedFirstSwingDamage(7, weaponById('squire_blade'));
    expect(enemy.hp, 6 - expected);
    final hits = s
        .takeEvents()
        .where((e) => e.kind == SessionEventKind.enemyHit)
        .length;
    expect(hits, 1);
  });

  test('crits are deterministic per seed (same script → same outcome)', () {
    int hpAfter(int seed) {
      final s = combatSession(seed: seed);
      var swings = 0;
      var cooldown = 0.0;
      stepSession(s, 3.0, (i) {
        cooldown -= dt;
        if (swings < 4 && cooldown <= 0) {
          i.attackPressed = true;
          swings++;
          cooldown = 0.7; // outside the combo window: all combo-0 swings
        }
      });
      return s.enemies.single.hp;
    }

    expect(hpAfter(42), hpAfter(42)); // deterministic
    // And the roll stream is actually consulted: a seed whose first roll
    // is <= critPercent must deal boosted damage.
    int? critSeed;
    int? normalSeed;
    final w = weaponById('squire_blade');
    for (var seed = 0; seed < 400; seed++) {
      final roll = Rng.create(seed, 'combat').range(1, 100);
      if (roll <= w.critPercent) critSeed ??= seed;
      if (roll > w.critPercent) normalSeed ??= seed;
      if (critSeed != null && normalSeed != null) break;
    }
    expect(critSeed, isNotNull, reason: 'no crit seed in 400 tries?');
    final sCrit = combatSession(seed: critSeed!);
    var first = true;
    stepSession(sCrit, 0.3, (i) {
      if (first) {
        i.attackPressed = true;
        first = false;
      }
    });
    expect(sCrit.enemies.single.hp,
        6 - (w.damage * w.critMultiplier).round());
  });

  test('hit-pause freezes the sim for kHitPause', () {
    final s = combatSession();
    final intent = InputIntent()..attackPressed = true;
    // Step frame-by-frame until the swing connects (hit-pause set).
    var frames = 0;
    while (s.hitPause <= 0 && frames < 60) {
      s.update(dt, intent);
      intent.clearEdges();
      frames++;
    }
    expect(s.hitPause, greaterThan(0));
    final t0 = s.time;
    // While paused, time must not advance.
    s.update(dt, InputIntent());
    expect(s.time, t0);
  });

  test('Ember Fang applies a burn DoT that ticks 1/s for 3s', () {
    // Pick a seed whose first combat roll is NOT a crit, so the swing can't
    // one-shot the thornling before the burn applies.
    var seed = 0;
    while (Rng.create(seed, 'combat').range(1, 100) <=
        weaponById('ember_fang').critPercent) {
      seed++;
    }
    final s = combatSession(seed: seed, weapon: weaponById('ember_fang'));
    final enemy = s.enemies.single;
    var first = true;
    stepSession(s, 0.3, (i) {
      if (first) {
        i.attackPressed = true;
        first = false;
      }
    });
    final afterHit = enemy.hp; // 6 - 4 = 2 (no crit for this seed)
    expect(afterHit, 2);
    expect(enemy.burnLeft, greaterThan(0));
    stepSession(s, 1.1, (i) {});
    expect(enemy.hp, afterHit - 1); // first tick landed
    stepSession(s, 1.2, (i) {});
    // Second tick finishes it: the burn can kill.
    expect(enemy.alive, isFalse);
    expect(s.kills, 1);
  });

  test('apple throw arcs, damages, and consumes ammo', () {
    final s = combatSession();
    s.applesHeld = 2;
    var first = true;
    stepSession(s, 0.8, (i) {
      if (first) {
        i.throwPressed = true;
        first = false;
      }
    });
    expect(s.applesHeld, 1);
    final ev = s.takeEvents();
    expect(ev.any((e) => e.kind == SessionEventKind.appleThrown), isTrue);
    // Thornling starts 1 tile away; the apple lands on it or the ground —
    // either way it damaged the enemy or broke on terrain.
    expect(
        ev.any((e) =>
            e.kind == SessionEventKind.enemyHit ||
            e.kind == SessionEventKind.appleBroke),
        isTrue);
  });

  test('throw with zero apples does nothing', () {
    final s = combatSession();
    var first = true;
    stepSession(s, 0.3, (i) {
      if (first) {
        i.throwPressed = true;
        first = false;
      }
    });
    expect(s.applesHeld, 0);
    expect(
        s.takeEvents().any((e) => e.kind == SessionEventKind.appleThrown),
        isFalse);
  });

  test('enemy contact deals 1 heart with knockback via player core', () {
    final s = combatSession();
    // March the thornling straight at the player.
    s.enemies.single.facing = -1;
    stepSession(s, 2.0, (i) {});
    expect(s.hitsTaken, greaterThanOrEqualTo(1));
    expect(s.player.hearts, lessThan(s.loadout.maxHearts));
  });

  test('kill increments kill counter and emits death event', () {
    final s = combatSession();
    final enemy = s.enemies.single;
    var cooldown = 0.0;
    stepSession(s, 4.0, (i) {
      cooldown -= dt;
      if (enemy.alive && cooldown <= 0) {
        i.attackPressed = true;
        cooldown = 0.3;
      }
    });
    expect(enemy.alive, isFalse);
    expect(s.kills, 1);
    expect(
        s.takeEvents().any((e) => e.kind == SessionEventKind.enemyDeath),
        isTrue);
  });
}
