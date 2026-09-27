// Ashfall (2026-09-24): a slain foe crumbles into its own art pixels inside
// the unchanged death beat. Presentation only — the sealed sim resolves the
// kill synchronously as before and `_deathTime` is untouched; these tests
// pin the crumble's own timing contract, its wiring into combat and the
// reduce-motion fallback.
import 'dart:io';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/ashfall.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as fixture;

AshfallModel _model({int away = 1, bool still = false, int seed = 7}) =>
    AshfallModel(
      cols: 16,
      rows: 23,
      cell: 4.0,
      away: away,
      still: still,
      seed: seed,
    );

Iterable<(int, int)> _cells(AshfallModel m) sync* {
  for (var gy = 0; gy < m.rows; gy++) {
    for (var sx = 0; sx < m.cols; sx++) {
      yield (sx, gy);
    }
  }
}

double _meanBreak(AshfallModel m, bool Function(int sx) inBand) {
  var sum = 0.0;
  var n = 0;
  for (final (sx, gy) in _cells(m)) {
    if (!inBand(sx)) continue;
    sum += m.breakAt(sx, gy);
    n++;
  }
  return sum / n;
}

void _notify(GameController c) {
  // Explicit fixture state, not an app mutation path (mirrors the
  // contact-timeline test's helper).
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
}

/// Rolls, makes the foe die to the first attack-capable die, and attacks.
Future<void> _lethalBlow(WidgetTester tester, GameController c) async {
  await tester.tap(fixture.button('Roll'));
  await fixture.pumpFor(tester, 1800);
  final n = (c.sim!.player['rolled'] as List).length;
  var die = 0;
  for (var d = 1; d <= n && die == 0; d++) {
    final r = resolveAssignment(
      player: c.sim!.player,
      enemy: c.sim!.enemy!,
      run: c.sim!.run,
      die: d,
      action: 'attack',
    );
    if (r.allowed && r.value > 0) die = d;
  }
  expect(die, greaterThan(0), reason: 'need an attack-capable die');
  c.sim!.enemy!['hp'] = 1;
  c.sim!.enemy!['block'] = 0;
  _notify(c);
  await tester.pump();
  await tester.tap(
    find.byWidgetPredicate((w) => w is DieChip && w.value != null).at(die - 1),
  );
  await tester.pump();
  await tester.tap(fixture.button('Attack'));
  expect(c.phase, isNot('player_turn'), reason: 'the blow is lethal');
}

Future<bool> _saw(WidgetTester tester, Finder f, int ms) async {
  var seen = false;
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
    if (f.evaluate().isNotEmpty) seen = true;
  }
  return seen;
}

Future<void> _cleanup(WidgetTester tester) async {
  await fixture.pumpFor(tester, 2600);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await fixture.pumpFor(tester, 2200);
}

void main() {
  tearDown(() => Motion.instance.reset());

  group('AshfallModel timing contract', () {
    test(
      'the body is whole at t=0 and completely gone before the beat ends',
      () {
        expect(
          AshfallModel.lastBreak + AshfallModel.flight,
          lessThan(1.0),
          reason: 'every mote must finish inside the death beat',
        );
        final m = _model();
        for (final (sx, gy) in _cells(m)) {
          final start = m.sample(sx, gy, 0);
          expect(start.loose, isFalse);
          expect(start.dx, 0);
          expect(start.dy, 0);
          expect(start.alpha, 1);
          expect(start.heat, 0);
          expect(
            m.breakAt(sx, gy),
            inInclusiveRange(0.0, AshfallModel.lastBreak),
          );
          expect(m.sample(sx, gy, AshfallModel.lastBreak + 1e-6).loose, isTrue);
          expect(m.sample(sx, gy, 1.0).alpha, 0);
        }
      },
    );

    test('heat runs in from the side the blow came from', () {
      final right = _model(away: 1);
      final nearR = _meanBreak(right, (sx) => sx < right.cols ~/ 3);
      final farR = _meanBreak(right, (sx) => sx >= right.cols * 2 ~/ 3);
      expect(nearR, lessThan(farR - 0.1));
      final left = _model(away: -1);
      final nearL = _meanBreak(left, (sx) => sx >= left.cols * 2 ~/ 3);
      final farL = _meanBreak(left, (sx) => sx < left.cols ~/ 3);
      expect(nearL, lessThan(farL - 0.1));
    });

    test('pixels glow before they tear loose', () {
      final m = _model();
      for (final (sx, gy) in _cells(m)) {
        final b = m.breakAt(sx, gy);
        final pre = m.sample(sx, gy, b - 1e-4);
        expect(pre.loose, isFalse);
        expect(pre.heat, greaterThan(0.9), reason: 'white-hot at the break');
      }
    });

    test('loose ash drifts away from the attacker and rises', () {
      for (final away in [1, -1]) {
        final m = _model(away: away);
        for (final (sx, gy) in _cells(m)) {
          final mid = m.sample(
            sx,
            gy,
            m.breakAt(sx, gy) + AshfallModel.flight * 0.5,
          );
          expect(mid.loose, isTrue);
          expect(mid.dx * away, greaterThan(0), reason: 'away from the blow');
          expect(mid.dy, lessThan(0), reason: 'ash rises');
          expect(mid.cool, greaterThan(0.5), reason: 'cooling toward ash');
        }
      }
    });

    test('still mode burns through in the same order without moving', () {
      final moving = _model();
      final still = _model(still: true);
      for (final (sx, gy) in _cells(still)) {
        expect(still.breakAt(sx, gy), moving.breakAt(sx, gy));
        for (final t in [0.1, 0.3, 0.5, 0.7, 0.9]) {
          final s = still.sample(sx, gy, t);
          expect(s.dx, 0);
          expect(s.dy, 0);
          expect(s.rotation, 0);
          expect(s.alpha, moving.sample(sx, gy, t).alpha);
        }
      }
    });

    test('deterministic for the same inputs', () {
      final a = _model(seed: 3);
      final b = _model(seed: 3);
      for (final (sx, gy) in _cells(a)) {
        final x = a.sample(sx, gy, 0.47);
        final y = b.sample(sx, gy, 0.47);
        expect(
          [x.dx, x.dy, x.rotation, x.heat, x.alpha],
          [y.dx, y.dy, y.rotation, y.heat, y.alpha],
        );
      }
    });

    test('heat ramp climbs ember -> gold -> white-hot', () {
      final cold = HSVColor.fromColor(ashHeatColor(0));
      final hot = HSVColor.fromColor(ashHeatColor(1));
      expect(hot.value, greaterThanOrEqualTo(cold.value));
      expect(hot.saturation, lessThan(cold.saturation));
    });
  });

  test('sprite_meta art-pixel scale is parsed (enemy sheets are upscaled)', () {
    final meta = SpriteMeta.parse(
      File('assets/images/sprite_meta.json').readAsStringSync(),
    );
    for (final def in meta.enemies.values) {
      expect(def.pixelScale, inInclusiveRange(2, 3), reason: def.id);
      expect(def.frameW % def.pixelScale, 0, reason: def.id);
      expect(def.frameH % def.pixelScale, 0, reason: def.id);
    }
    expect(meta.sheet('flue_crawler')!.pixelScale, 3);
    expect(meta.sheet('kiln_golem')!.pixelScale, 2);
    expect(meta.sheet('kindler')!.pixelScale, 1);
  });

  testWidgets('SpriteAshfall plays once, reports done and stops painting', (
    tester,
  ) async {
    await tester.runAsync(warmSpriteSheets);
    expect(SpriteAshfall.ready('flue_crawler'), isTrue);
    expect(SpriteAshfall.ready('no_such_sprite'), isFalse);
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SpriteAshfall(
            'flue_crawler',
            height: 96,
            flipX: true,
            onDone: () => done = true,
          ),
        ),
      ),
    );
    // Same box as the SpriteView it replaces: height x frame aspect.
    expect(tester.getSize(find.byType(SpriteAshfall)), const Size(96, 96));
    await tester.pump(const Duration(milliseconds: 300));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 450));
    expect(done, isTrue);
    var paints = 0;
    debugOnProfilePaint = (ro) {
      if (ro is RenderCustomPaint) paints++;
    };
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnProfilePaint = null;
    expect(paints, 0, reason: 'a finished crumble must not keep repainting');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a slain foe crumbles into Ashfall', (tester) async {
    final c = await fixture.intoFight(tester);
    final foe = find.byKey(const ValueKey('enemy-flue_crawler'));
    expect(foe, findsOneWidget);
    await _lethalBlow(tester, c);
    expect(
      await _saw(tester, find.byType(SpriteAshfall), 1400),
      isTrue,
      reason: 'the death beat swaps the sprite for its crumble',
    );
    await _cleanup(tester);
  });

  testWidgets('reduce motion keeps the legacy fade (no Ashfall)', (
    tester,
  ) async {
    final c = await fixture.intoFight(tester);
    Motion.instance.update(setting: 'on');
    await tester.pump();
    await _lethalBlow(tester, c);
    expect(
      await _saw(tester, find.byType(SpriteAshfall), 1400),
      isFalse,
      reason: 'reduce motion must not add a displacement effect',
    );
    await _cleanup(tester);
  });
}
