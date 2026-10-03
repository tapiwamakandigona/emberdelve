// test/hero_pop_clearance_test.dart — experimental polish loop, critic round 1
// issue C1-06: the player's damage number must land ABOVE the delver, not on
// the delver's face.
//
// Round-1 enemy-turn strips (C_*_enemy-turn 032-036, all four foes) showed
// the "-9" sitting over the hero's head and white hit silhouette. In round 0
// it had risen clear above the head; the C0-03 re-layout moved the planned
// hero zone onto the chest, so the hit number and the hit reaction collided.
//
// This test plays a real enemy turn (seed-1 fight, no block, so the shown
// attack lands) through the production controls at three phone sizes and
// samples every 20 ms frame. For every frame where the hero's damage number
// is visible it asserts the number's painted glyphs do not intersect the
// delver's sprite box. Nothing about the simulation is touched.
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart'
    show alphaOf, button, loadRealFonts, makeController, paintedRect, toFight;

/// The delver's sprite on screen (plain sheet or articulated rig).
Finder heroSprite() {
  final plain = find.byKey(const ValueKey('hero-kindler'));
  if (plain.evaluate().isNotEmpty) return plain;
  return find.byKey(const ValueKey('figure-kindler'));
}

/// Union of the visible glyph boxes of every hero-side damage number.
List<Rect> heroNumberRects() {
  final out = <Rect>[];
  for (final pop in find.byType(DamagePop).evaluate()) {
    if (!(pop.widget as DamagePop).onPlayer) continue;
    Rect? ink;
    for (final t in find
        .descendant(
          of: find.byElementPredicate((e) => identical(e, pop)),
          matching: find.byType(RichText),
        )
        .evaluate()) {
      final ro = t.renderObject;
      if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
      if (ro.size.isEmpty || alphaOf(t) < 0.05) continue;
      if (ro.text.toPlainText().trim().isEmpty) continue;
      final r = paintedRect(ro);
      ink = ink == null ? r : ink.expandToInclude(r);
    }
    if (ink != null) out.add(ink);
  }
  return out;
}

Future<void> heroHitCase(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: 'off');
  await tester.runAsync(warmSpriteSheets);
  final c = makeController();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ),
  );
  await toFight(tester, c);
  await tester.tap(button('Roll'));
  for (var t = 0; t < 2000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(heroSprite(), findsWidgets);
  // No die assigned to Block, so the foe's shown attack lands on the delver.
  await tester.tap(button('End turn'));

  var sawNumber = false;
  final problems = <String>[];
  for (var ms = 20; ms <= 3000; ms += 20) {
    await tester.pump(const Duration(milliseconds: 20));
    final hero = heroSprite();
    if (hero.evaluate().isEmpty) break;
    final body = tester.getRect(hero.first);
    for (final ink in heroNumberRects()) {
      sawNumber = true;
      final o = ink.intersect(body);
      if (o.width > 1.0 && o.height > 1.0) {
        problems.add('t=${ms}ms  number $ink  on delver $body');
      }
    }
  }
  expect(sawNumber, isTrue, reason: "the foe's blow must show a -N number");
  expect(problems, isEmpty, reason: problems.take(8).join('\n'));
}

void main() {
  setUpAll(loadRealFonts);
  const sizes = {
    '320x568': Size(320, 568),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };
  for (final entry in sizes.entries) {
    testWidgets('the hero damage number clears the delver at ${entry.key}', (
      t,
    ) async {
      await heroHitCase(t, size: entry.value);
    });
  }
}
