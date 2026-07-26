// AKP-3 (docs/ak-parity-plan.md §3) — the juice rules that must not drift:
// the camera-shake budget, heavy vs light hit-pause, and damage amounts on
// the events the render layer turns into floating numbers.
import 'package:emberdelve/core/rng.dart';
import 'package:emberdelve/game/camera_shake.dart';
import 'package:emberdelve/game/core_loadout.dart';
import 'package:emberdelve/game/input_intent.dart';
import 'package:emberdelve/game/level/level_data.dart';
import 'package:emberdelve/game/session.dart';
import 'package:emberdelve/game/tuning.dart';
import 'package:emberdelve/meta/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const dt = 1 / 120;

LevelSession _session(String ascii, {int seed = 7}) =>
    LevelSession(LevelData.parse(ascii), Loadout.starter(), seed: seed);

/// Whether the FIRST swing of the seeded run crits (mirrors session logic).
bool _firstSwingCrits(int seed, Weapon w) =>
    Rng.create(seed, 'combat').range(1, 100) <= w.critPercent;

void main() {
  group('camera shake budget (AKP-3e)', () {
    test('starts at rest and offsets nothing', () {
      final s = CameraShake();
      expect(s.active, isFalse);
      expect(s.magnitude, 0);
      expect(s.offsetX, 0);
      expect(s.offsetY, 0);
      s.update(1 / 60);
      expect(s.offsetX, 0);
      expect(s.offsetY, 0);
    });

    test('a bump moves both axes, X more gently than Y', () {
      final s = CameraShake(seed: 7);
      s.bump(kShakeHurt);
      var maxX = 0.0, maxY = 0.0;
      for (var i = 0; i < 12; i++) {
        s.update(1 / 60);
        maxX = maxX > s.offsetX.abs() ? maxX : s.offsetX.abs();
        maxY = maxY > s.offsetY.abs() ? maxY : s.offsetY.abs();
      }
      expect(maxY, greaterThan(0));
      expect(maxX, greaterThan(0));
      // X is damped to 60% of the amplitude, so it can never exceed Y's cap.
      expect(maxX, lessThanOrEqualTo(kShakeHurt * 0.6 + 1e-9));
      expect(maxY, lessThanOrEqualTo(kShakeHurt + 1e-9));
    });

    test('never exceeds the hard cap, however much is asked for', () {
      final s = CameraShake();
      s.bump(999);
      expect(s.magnitude, kShakeMax);
      for (var i = 0; i < 30; i++) {
        s.update(1 / 60);
        expect(s.offsetX.abs(), lessThanOrEqualTo(kShakeMax));
        expect(s.offsetY.abs(), lessThanOrEqualTo(kShakeMax));
      }
    });

    test('a weaker bump cannot cut a stronger shake short', () {
      final s = CameraShake();
      s.bump(kShakeBossDeath);
      s.bump(kShakeWallBreak);
      expect(s.magnitude, kShakeBossDeath);
    });

    test('decays to rest at kShakeDecay and stops there', () {
      final s = CameraShake();
      s.bump(kShakeHurt);
      final expected = kShakeHurt / kShakeDecay; // seconds to zero
      var t = 0.0;
      while (s.active && t < 5) {
        s.update(1 / 240);
        t += 1 / 240;
      }
      expect(t, closeTo(expected, 0.02));
      expect(s.magnitude, 0);
      expect(s.offsetX, 0);
      expect(s.offsetY, 0);
    });

    test('reset stops instantly (respawn snaps the camera)', () {
      final s = CameraShake();
      s.bump(kShakeMax);
      s.update(1 / 60);
      s.reset();
      expect(s.active, isFalse);
      expect(s.offsetY, 0);
    });

    test('deterministic for a given seed (same trace twice)', () {
      List<double> trace(int seed) {
        final s = CameraShake(seed: seed)..bump(kShakeHurt);
        return [
          for (var i = 0; i < 8; i++) ...[
            (s..update(1 / 60)).offsetX,
            s.offsetY,
          ]
        ];
      }

      expect(trace(1234), trace(1234));
      expect(trace(1234), isNot(trace(4321)));
    });
  });

  group('combat juice in the session (AKP-3c/3d)', () {
    // Player on flat ground with a thornling a sword-length to the right.
    const arena = '''
....................
....................
.P.T...............E
####################
''';

    SessionEvent? swingUntilHit(LevelSession s) {
      final intent = InputIntent();
      for (var frame = 0; frame < 2000; frame++) {
        intent
          ..dirX = 0
          ..down = false
          ..jumpHeld = false;
        intent.clearEdges();
        if (frame == 0) intent.attackPressed = true;
        s.update(dt, intent);
        for (final e in s.takeEvents()) {
          if (e.kind == SessionEventKind.enemyHit) return e;
        }
      }
      return null;
    }

    test('enemyHit carries the damage dealt (floating numbers need it)', () {
      final s = _session(arena);
      final hit = swingUntilHit(s);
      expect(hit, isNotNull);
      expect(hit!.amount, greaterThan(0));
      final w = s.loadout.weapon;
      final crit = _firstSwingCrits(7, w);
      expect(hit.crit, crit);
      expect(hit.amount,
          crit ? (w.damage * w.critMultiplier).round() : w.damage,
          reason: 'first swing is not the finisher: base weapon damage, '
              'scaled only by a crit');
    });

    test('a connect always freezes the frame, and heavy beats freeze longer',
        () {
      final s = _session(arena);
      final hit = swingUntilHit(s);
      expect(hit, isNotNull);
      expect(s.hitPause, greaterThan(0));
      expect(s.hitPause,
          closeTo(hit!.crit ? kHitPauseHeavy : kHitPause, 1e-9));
      expect(kHitPauseHeavy, greaterThan(kHitPause));
    });

    test('the combo finisher freezes the frame harder than the first hit', () {
      // The boss has 60 hp, so it survives long enough for the chain to reach
      // its third swing (a 6-hp thornling dies first).
      final s = _session('''
....................
....................
.P..G..............E
####################
''');
      final intent = InputIntent();
      final pauses = <int, double>{};
      for (var frame = 0; frame < 2000; frame++) {
        intent
          ..dirX = 0
          ..down = false
          ..jumpHeld = false;
        intent.clearEdges();
        // Re-press inside the combo window so the chain advances 0 -> 1 -> 2.
        if (frame % 30 == 0) intent.attackPressed = true;
        final combo = s.player.comboIndex;
        s.update(dt, intent);
        for (final e in s.takeEvents()) {
          if (e.kind == SessionEventKind.enemyHit && !e.crit) {
            pauses.putIfAbsent(combo, () => s.hitPause);
          }
        }
        if (pauses.containsKey(kComboHits - 1)) break;
      }
      expect(pauses[kComboHits - 1], isNotNull,
          reason: 'the finisher must land at least once in 16s of combo');
      expect(pauses[kComboHits - 1], closeTo(kHitPauseHeavy, 1e-9));
      if (pauses[0] != null) {
        expect(pauses[0], closeTo(kHitPause, 1e-9));
      }
    });

    test('apple hits report their own damage amount and never crit', () {
      final s = _session('''
....................
....................
.P.T...............E
####################
''');
      s.applesHeld = 9;
      final intent = InputIntent();
      SessionEvent? hit;
      for (var frame = 0; frame < 2000 && hit == null; frame++) {
        intent
          ..dirX = 0
          ..down = false
          ..jumpHeld = false;
        intent.clearEdges();
        if (frame % 60 == 0) intent.throwPressed = true;
        s.update(dt, intent);
        for (final e in s.takeEvents()) {
          if (e.kind == SessionEventKind.enemyHit) hit = e;
        }
      }
      expect(hit, isNotNull);
      expect(hit!.amount, kAppleDamage);
      expect(hit.crit, isFalse);
    });

    test('a blocked swing produces no damage number', () {
      final s = _session('''
....................
.....R.P...........E
####################
####################
''');
      final rot = s.enemies.single;
      final intent = InputIntent();
      var blocked = 0, hits = 0;
      for (var frame = 0; frame < 600; frame++) {
        intent
          ..dirX = frame < 12 ? -1.0 : 0.0 // turn to face the shield
          ..down = false
          ..jumpHeld = false;
        intent.clearEdges();
        if (frame > 12 && frame % 40 == 0) intent.attackPressed = true;
        rot.facing = 1; // shield always toward the player
        s.update(dt, intent);
        for (final e in s.takeEvents()) {
          if (e.kind == SessionEventKind.attackBlocked) blocked++;
          if (e.kind == SessionEventKind.enemyHit) hits++;
        }
        if (blocked > 0) break;
      }
      expect(blocked, greaterThan(0));
      // A block is not a hit: nothing should float a number for it.
      expect(hits, 0);
    });
  });

  group('juice constants stay inside the phone budget', () {
    test('shake amplitudes are small and capped', () {
      for (final v in [
        kShakeHurt,
        kShakeHeavyHit,
        kShakeBossSlam,
        kShakeBossDeath,
        kShakeWallBreak,
      ]) {
        expect(v, greaterThan(0));
        expect(v, lessThanOrEqualTo(kShakeMax));
      }
      expect(kShakeMax, lessThanOrEqualTo(5.0),
          reason: 'more than ~5px of shake at a 352x198 viewport is nausea');
    });

    test('fx lifetimes stay short and the number cap respects the particle '
        'budget', () {
      expect(kSwingArcLife, lessThanOrEqualTo(0.25));
      expect(kLandSquashTime, lessThanOrEqualTo(0.15));
      expect(kPlayerHurtFlash, lessThanOrEqualTo(0.25));
      expect(kDamageNumberLife, lessThanOrEqualTo(0.8));
      expect(kMaxDamageNumbers, lessThan(kMaxLiveParticles));
    });
  });
}
