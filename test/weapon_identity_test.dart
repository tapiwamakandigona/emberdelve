// AKP-4 weapon identity: every catalog weapon ships a complete overlay
// sheet set that visibly differs from the others (4a); the Skypiercer lunge
// special actually moves the player (4b — the specialText has promised it
// since P-M4); the apple lob launches at the flattened 22.5° angle and the
// held-button arc preview matches the projectile's real flight (4c).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';
import 'package:emberwood/meta/catalog.dart';

const dt = 1 / 120;

const _anims = [
  'idle', 'run', 'jump', 'fall', 'hit', 'roll',
  'attack1', 'attack2', 'attack3',
];

(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int be32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (be32(16), be32(20));
}

LevelSession session(String ascii, {Loadout? loadout}) =>
    LevelSession(LevelData.parse(ascii), loadout ?? Loadout.starter(),
        seed: 3);

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

const _arena = '''
....................
....................
....................
....................
.P.................E
####################
''';

void main() {
  group('AKP-4a weapon overlay sheets', () {
    test('every catalog weapon has all 9 overlay sheets bundled', () {
      final missing = <String>[];
      for (final w in kWeapons) {
        for (final anim in _anims) {
          final f = File('assets/images/player/weapons/${w.id}/$anim.png');
          if (!f.existsSync()) missing.add('${w.id}/$anim.png');
        }
      }
      expect(missing, isEmpty,
          reason: 'weapons without complete overlay sheets: $missing');
    });

    test('bladeless body sheets exist and match base sheet dimensions', () {
      for (final anim in _anims) {
        final base = pngSize(File('assets/images/player/$anim.png'));
        final body = pngSize(File('assets/images/player/body/$anim.png'));
        expect(body, base, reason: 'body/$anim.png frame grid mismatch');
      }
    });

    test('overlay sheets match base dimensions and differ per weapon', () {
      for (final anim in _anims) {
        final base = pngSize(File('assets/images/player/$anim.png'));
        final seen = <String, String>{};
        for (final w in kWeapons) {
          final f = File('assets/images/player/weapons/${w.id}/$anim.png');
          expect(pngSize(f), base,
              reason: '${w.id}/$anim.png frame grid mismatch');
          // "Switching weapons visibly changes idle + swing": every weapon's
          // overlay must be pixel-different from every other weapon's.
          final bytes = String.fromCharCodes(f.readAsBytesSync());
          for (final other in seen.entries) {
            expect(bytes == other.value, isFalse,
                reason: '${w.id}/$anim.png identical to ${other.key}');
          }
          seen[w.id] = bytes;
        }
      }
    });
  });

  group('AKP-4b lunge special (Skypiercer)', () {
    test('swinging the Skypiercer steps the player forward', () {
      final lunger = session(_arena,
          loadout: Loadout.starter(weapon: weaponById('skypiercer')));
      final control = session(_arena);
      final x0 = lunger.player.body.x;
      expect(control.player.body.x, x0); // same spawn
      stepSession(lunger, 0.5, (i) => i.attackPressed = true);
      stepSession(control, 0.5, (i) => i.attackPressed = true);
      final lungeDx = lunger.player.body.x - x0;
      final controlDx = control.player.body.x - x0;
      expect(controlDx.abs(), lessThan(0.5),
          reason: 'non-lunge weapons must not move the player');
      expect(lungeDx, greaterThan(4),
          reason: 'lunge should step ~7px forward per swing phrase');
    });

    test('lunge never clips through a wall', () {
      final s = session('''
....................
....................
....................
....................
.P#................E
####################
''', loadout: Loadout.starter(weapon: weaponById('skypiercer')));
      stepSession(s, 1.0, (i) => i.attackPressed = true);
      // Wall column at tile x=2 -> px 32; body right edge must stop at it.
      expect(s.player.body.right, lessThanOrEqualTo(32.001));
    });
  });

  group('AKP-4c apple lob', () {
    test('apple launches at the flattened 22.5-degree arc', () {
      final s = session(_arena);
      s.applesHeld = 1;
      final intent = InputIntent()..throwPressed = true;
      s.update(dt, intent);
      final a = s.appleProjectiles.first;
      expect(a.active, isTrue);
      expect(a.vx, closeTo(kAppleThrowSpeed * kAppleThrowCos, 0.001));
      // One frame of gravity has already applied to vy.
      expect(a.vy,
          closeTo(-kAppleThrowSpeed * kAppleThrowSin + kGravity * dt, 0.001));
    });

    test('arc preview matches the projectile\'s real flight', () {
      final s = session(_arena);
      s.applesHeld = 1;
      // Preview BEFORE throwing (same player state).
      final xs = List<double>.filled(kApplePreviewDots, 0);
      final ys = List<double>.filled(kApplePreviewDots, 0);
      final n = s.appleArcPreview(xs, ys);
      expect(n, greaterThanOrEqualTo(4),
          reason: 'open arena should fit several preview dots');
      // Throw for real and sample the projectile at every preview timestamp.
      final intent = InputIntent()..throwPressed = true;
      s.update(dt, intent); // throw frame = first integration step
      final a = s.appleProjectiles.first;
      final stepsPerDot = (kApplePreviewStep / dt).round();
      var done = 1; // the throw frame already integrated one step
      for (var i = 0; i < n; i++) {
        // Dot i lands after (i+1)*stepsPerDot integration steps.
        final target = (i + 1) * stepsPerDot;
        while (done < target && a.active) {
          s.update(dt, InputIntent());
          done++;
        }
        expect(a.active, isTrue, reason: 'apple died before dot $i');
        expect(a.x, closeTo(xs[i], 0.01), reason: 'dot $i x drift');
        expect(a.y, closeTo(ys[i], 0.01), reason: 'dot $i y drift');
      }
    });
  });
}
