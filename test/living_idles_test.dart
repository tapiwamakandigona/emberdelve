// Living idles (2026-09-24): each foe idles with its own body personality —
// wisps hover clear of their shadow, brutes and every boss/elite heave, small
// crawlers scuttle — layered on the original breathing bob. Presentation
// only; the default IdleStyle.breathe keeps every other SpriteView call site
// pixel-identical, and reduce motion still stops the life ticker entirely.
import 'dart:math' as math;

import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as fixture;

List<double> _samples(double Function(double t) f) => [
  for (var i = 0; i < 720; i++) f(i / 720 * 2 * math.pi),
];

double _span(List<double> v) => v.reduce(math.max) - v.reduce(math.min);

Future<int> _census(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  var paints = 0;
  debugOnProfilePaint = (ro) {
    if (ro is RenderCustomPaint) paints++;
  };
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  debugOnProfilePaint = null;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  return paints;
}

void main() {
  tearDown(() => Motion.instance.reset());

  group('idleLife envelopes', () {
    test('breathe adds nothing (legacy call sites stay pixel-identical)', () {
      for (var i = 0; i < 64; i++) {
        final p = idleLife(IdleStyle.breathe, i * 0.1);
        expect([p.dx, p.dy, p.rot, p.scaleY], [0.0, 0.0, 0.0, 1.0]);
      }
    });

    test('every style loops without a seam', () {
      for (final style in IdleStyle.values) {
        for (var i = 0; i < 32; i++) {
          final t = i * 0.37;
          final a = idleLife(style, t);
          final b = idleLife(style, t + 2 * math.pi);
          expect(b.dx, closeTo(a.dx, 1e-9), reason: '$style dx');
          expect(b.dy, closeTo(a.dy, 1e-9), reason: '$style dy');
          expect(b.rot, closeTo(a.rot, 1e-9), reason: '$style rot');
          expect(b.scaleY, closeTo(a.scaleY, 1e-9), reason: '$style scale');
        }
      }
    });

    test('hover floats clear of the floor the whole loop, and drifts', () {
      final dy = _samples((t) => idleLife(IdleStyle.hover, t).dy);
      expect(dy.reduce(math.max), lessThanOrEqualTo(-1.0), reason: 'lifted');
      expect(_span(dy), greaterThanOrEqualTo(5.0), reason: 'rise and fall');
      final dx = _samples((t) => idleLife(IdleStyle.hover, t).dx);
      expect(_span(dx), greaterThanOrEqualTo(2.5));
      final rot = _samples((t) => idleLife(IdleStyle.hover, t).rot);
      expect(_span(rot), greaterThan(0.04));
    });

    test('heave takes one deep breath about the feet, never shrinking', () {
      final s = _samples((t) => idleLife(IdleStyle.heave, t).scaleY);
      expect(s.reduce(math.min), greaterThanOrEqualTo(1.0));
      expect(_span(s), greaterThanOrEqualTo(0.025));
    });

    test('scuttle side-steps low to the ground', () {
      final dx = _samples((t) => idleLife(IdleStyle.scuttle, t).dx);
      expect(_span(dx), greaterThanOrEqualTo(2.5));
      final dy = _samples((t) => idleLife(IdleStyle.scuttle, t).dy);
      expect(dy.reduce(math.max), lessThanOrEqualTo(0.0));
      expect(dy.reduce(math.min), greaterThanOrEqualTo(-0.6 - 1e-9));
    });
  });

  group('enemyIdleFor', () {
    test('bodies get the idle their anatomy suggests', () {
      const hover = [
        'cinder_wisp',
        'soot_shade',
        'ash_wraith',
        'ember_moth',
        'char_sprite',
        'wick_widow',
        'quench_hag',
        'tinder_mote',
      ];
      const scuttle = [
        'ash_rat',
        'ember_beetle',
        'cinder_crawler',
        'scoria_tick',
        'flue_crawler',
        'slag_snail',
        'vent_serpent',
        'coal_seam_wyrm',
        'cinder_urchin',
      ];
      for (final id in hover) {
        expect(enemyIdleFor(id), IdleStyle.hover, reason: id);
      }
      for (final id in scuttle) {
        expect(enemyIdleFor(id), IdleStyle.scuttle, reason: id);
      }
      for (final id in [
        'slag_brute',
        'kiln_golem',
        'pumice_hulk',
        'vent_ram',
      ]) {
        expect(enemyIdleFor(id), IdleStyle.heave, reason: id);
      }
      expect(enemyIdleFor('soot_hound'), IdleStyle.breathe);
    });

    test('every catalogued boss and elite carries weight (floaters float)', () {
      expect(enemies.length, enemiesOrder.length);
      for (final id in enemiesOrder) {
        final def = enemies[id]!;
        final style = enemyIdleFor(id, boss: def.boss, elite: def.elite);
        if (def.boss || def.elite) {
          expect(
            style,
            anyOf(IdleStyle.heave, IdleStyle.hover),
            reason: '$id is a boss/elite',
          );
        }
      }
    });

    test('matches whole id words, never substrings', () {
      expect(enemyIdleFor('pirate'), IdleStyle.breathe); // not "rat"
      expect(enemyIdleFor('candlestick_golem'), IdleStyle.heave); // not "tick"
      expect(enemyIdleFor('unknown_thing'), IdleStyle.breathe);
    });
  });

  testWidgets('hover idle is alive without reduce motion and still under it', (
    tester,
  ) async {
    await tester.runAsync(warmSpriteSheets);
    const wisp = SpriteView(
      'cinder_wisp',
      height: 96,
      bob: true,
      idle: IdleStyle.hover,
    );
    Motion.instance.update(setting: 'off');
    expect(await _census(tester, wisp), greaterThan(30));
    Motion.instance.update(setting: 'on');
    expect(await _census(tester, wisp), 0);
  });

  testWidgets('the painter really lifts a hovering body off its mark', (
    tester,
  ) async {
    await tester.runAsync(warmSpriteSheets);
    Motion.instance.update(setting: 'off');
    Future<List<int>> shot(IdleStyle style) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: SpriteView(
                    'cinder_wisp',
                    key: ValueKey(style), // fresh clocks per shot
                    height: 96,
                    bob: true,
                    idle: style,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      late List<int> bytes;
      await tester.runAsync(() async {
        final ro =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await ro.toImage();
        final data = await image.toByteData();
        bytes = data!.buffer.asUint8List().toList();
        image.dispose();
      });
      return bytes;
    }

    final breathe = await shot(IdleStyle.breathe);
    final again = await shot(IdleStyle.breathe);
    final hover = await shot(IdleStyle.hover);
    expect(again, equals(breathe), reason: 'same clock, same pixels');
    expect(hover, isNot(equals(breathe)), reason: 'hover moves the body');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the combat foe idles with its own personality', (tester) async {
    await fixture.intoFight(tester);
    final foe = tester.widget<SpriteView>(
      find.byKey(const ValueKey('enemy-flue_crawler')),
    );
    expect(foe.idle, IdleStyle.scuttle);
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.pumpFor(tester, 2200);
  });
}
