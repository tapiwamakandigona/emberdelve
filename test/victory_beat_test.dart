// test/victory_beat_test.dart — experimental polish loop, critic round 2
// issue C2-02 (+ the tray part of C1-01): the final-boss kill had no
// victory beat, and the round-3 critic read the tray dice as still lit.
//
// Lands a real run-ending blow on a boss (FIXTURE: node + foe marked boss,
// foe HP set so the die kills; same fixture as boss_kill_moment_test.dart)
// through the production controls at 320x568, 360x800 and 412x915, then at
// +600 ms and +1200 ms asserts:
//   • the "VICTORY!" banner is on screen, ≥ 22 logical px, fully inside the
//     stage box;
//   • every tray die sits under an ignoring pointer gate with an effective
//     opacity ≤ 0.5, and its pixels' mean luma is ≤ 50% of the same die's
//     live value (measured on a rasterised frame, not by eye);
//   • rising embers paint under normal motion; under reduced motion the
//     banner still shows but there are no embers.
// Nothing in lib/sim is touched.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/victory_beat.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boss_kill_moment_test.dart' show trayInert;
import 'kill_readout_test.dart'
    show alphaOf, button, loadRealFonts, makeController, toFight;

const _ratio = 1.0;

Future<ui.Image> _grab(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return boundary.toImage(pixelRatio: _ratio);
    }))!;

Future<double> _meanLuma(WidgetTester tester, ui.Image img, Rect r) async {
  final data = (await tester.runAsync(() => img.toByteData()))!;
  final bytes = Uint8List.sublistView(data);
  var sum = 0.0;
  var n = 0;
  final x0 = (r.left * _ratio).floor().clamp(0, img.width - 1);
  final x1 = (r.right * _ratio).ceil().clamp(1, img.width);
  final y0 = (r.top * _ratio).floor().clamp(0, img.height - 1);
  final y1 = (r.bottom * _ratio).ceil().clamp(1, img.height);
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * img.width + x) * 4;
      sum += 0.299 * bytes[i] + 0.587 * bytes[i + 1] + 0.114 * bytes[i + 2];
      n++;
    }
  }
  return n == 0 ? 0 : sum / n;
}

List<Rect> _dieRects(WidgetTester tester) => [
  for (final e in find.byType(DieChip).evaluate())
    tester.getRect(find.byWidget(e.widget)),
];

Future<void> _victory(
  WidgetTester tester, {
  required Size size,
  required bool reduced,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: reduced ? 'on' : 'off');
  await tester.runAsync(warmSpriteSheets);
  final c = makeController();
  final shot = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    ),
  );
  await toFight(tester, c);
  await tester.tap(button('Roll'));
  for (var t = 0; t < 2000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final rolled = (c.sim!.player['rolled'] as List).length;
  var die = 0, value = 0;
  for (var d = 1; d <= rolled; d++) {
    final r = resolveAssignment(
      player: c.sim!.player,
      enemy: c.sim!.enemy!,
      run: c.sim!.run,
      die: d,
      action: 'attack',
    );
    if (r.allowed && r.value >= 2) {
      die = d;
      value = r.value;
      break;
    }
  }
  expect(die, greaterThan(0), reason: 'seed 1 must roll an attack die ≥ 2');

  // Live tray luma, per die, before anything is selected. Give the die art
  // real time to decode first: an undecoded asset paints nothing, which
  // made the first case's "live" dice read dark (a harness artefact).
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pump(const Duration(milliseconds: 40));
  final liveRects = _dieRects(tester);
  final liveImg = await _grab(tester, shot);
  final live = <double>[
    for (final r in liveRects) await _meanLuma(tester, liveImg, r),
  ];
  liveImg.dispose();

  // FIXTURE: the run-ending blow on a boss (as boss_kill_moment_test).
  final map = c.sim!.map!;
  ((map['nodes'] as Map)['${map['position']}'] as Map)['kind'] = 'boss';
  c.sim!.enemy!['boss'] = true;
  c.sim!.enemy!['hp'] = value;
  c.sim!.enemy!['block'] = 0;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();
  final dice = find.byWidgetPredicate((w) => w is DieChip && w.value != null);
  await tester.tap(dice.at(die - 1));
  await tester.pump();
  await tester.tap(button('Attack'));

  final problems = <String>[];
  var checked = 0;
  for (var ms = 40; ms <= 1200; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    if (ms != 600 && ms != 1200) continue;
    expect(
      find.byType(CombatScreen),
      findsOneWidget,
      reason: 'the kill moment is still on screen at +$ms ms',
    );
    checked++;
    final banner = find.byKey(const ValueKey('victory-banner'));
    if (banner.evaluate().isEmpty) {
      problems.add('+$ms ms: no victory banner');
    } else {
      final stage = tester.getRect(find.byKey(const ValueKey('victory-beat')));
      final b = tester.getRect(banner);
      if (b.left < stage.left - 0.5 ||
          b.right > stage.right + 0.5 ||
          b.top < stage.top - 0.5 ||
          b.bottom > stage.bottom + 0.5) {
        problems.add('+$ms ms: banner $b leaves the stage $stage');
      }
      final text = tester.widget<Text>(banner);
      if ((text.style?.fontSize ?? 0) < 22) {
        problems.add('+$ms ms: banner font ${text.style?.fontSize} < 22');
      }
    }
    final embers = find.byKey(const ValueKey('victory-embers'));
    if (reduced && embers.evaluate().isNotEmpty) {
      problems.add('+$ms ms: embers under reduced motion');
    }
    if (!reduced && ms == 600 && embers.evaluate().isEmpty) {
      problems.add('+$ms ms: no rising embers');
    }
    if (!trayInert(tester)) problems.add('+$ms ms: tray still takes taps');
    for (final e in find.byType(DieChip).evaluate()) {
      final a = alphaOf(e);
      if (a > 0.5) problems.add('+$ms ms: a tray die at opacity $a');
    }
    if (ms == 1200) {
      final img = await _grab(tester, shot);
      for (var i = 0; i < liveRects.length; i++) {
        final now = await _meanLuma(tester, img, liveRects[i]);
        if (now > 0.5 * live[i]) {
          problems.add(
            '+$ms ms: die ${i + 1} luma ${now.toStringAsFixed(1)} > 50% of '
            'live ${live[i].toStringAsFixed(1)}',
          );
        }
      }
      img.dispose();
    }
  }
  expect(c.phase, 'run_won', reason: 'the fixture blow ends the run');
  expect(checked, 2);
  expect(problems, isEmpty, reason: problems.join('\n'));
  // Let the held phase switch and every timer run out.
  for (var t = 0; t < 4000; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRealFonts);

  test('the banner is big, plain and short', () {
    expect(VictoryBeat.fontSize, greaterThanOrEqualTo(22));
    expect(VictoryBeat.minFontSize, greaterThanOrEqualTo(22));
    expect(VictoryBeat.text.split(' ').length, 1);
    expect(VictoryBeat.intro, const Duration(milliseconds: 250));
  });

  // C4-01: the banner is placed by rect (critic round 4). A stand-in for
  // its measured box keeps these font-free: it matches the real one at 34
  // and 22 sp (205x58 and 145x40 with the shipped Inter);
  // test/victory_moment_test.dart measures for real on the live screen.
  group('C4-01 banner placement', () {
    Size box(double sp) => Size(5 * sp + 35, 1.5 * sp + 7);
    void inside(Rect r, Size stage) {
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(stage.width));
      expect(r.bottom, lessThanOrEqualTo(stage.height));
    }

    test('a stage with room: full size, centred above both heads', () {
      // 412x915: stage 364x365, delver 104 tall, boss 128 tall.
      const stage = Size(364, 365);
      final hero = VictoryBeat.heroEnvelope(floorY: 357, heroH: 104);
      const foe = Rect.fromLTWH(236, 229, 128, 128);
      final at = VictoryBeat.place(
        stage: stage,
        hero: hero,
        foe: foe,
        measure: box,
      );
      expect(at.area, 'above');
      expect(at.fontSize, VictoryBeat.fontSize);
      expect(at.rect.overlaps(hero), isFalse);
      expect(at.rect.overlaps(foe), isFalse);
      expect(at.rect.top, greaterThanOrEqualTo(VictoryBeat.inset));
      expect(at.rect.center.dx, closeTo(stage.width / 2, 0.01));
      inside(at.rect, stage);
    });

    test('a short band above the heads: the font steps down to fit', () {
      // The band above both heads is 50 dp: 34-30 sp are too tall, 28 fits.
      const stage = Size(364, 190);
      final hero = VictoryBeat.heroEnvelope(floorY: 182, heroH: 104);
      const foe = Rect.fromLTWH(244, 62, 120, 120);
      final at = VictoryBeat.place(
        stage: stage,
        hero: hero,
        foe: foe,
        measure: box,
      );
      expect(at.area, 'above');
      expect(at.fontSize, 28);
      expect(at.rect.overlaps(hero), isFalse);
      expect(at.rect.overlaps(foe), isFalse);
    });

    test('a tall boss: above the delver only, short of the boss', () {
      const stage = Size(364, 150);
      final hero = VictoryBeat.heroEnvelope(floorY: 142, heroH: 72);
      const foe = Rect.fromLTWH(224, 2, 140, 140);
      final at = VictoryBeat.place(
        stage: stage,
        hero: hero,
        foe: foe,
        measure: box,
      );
      expect(at.area, 'above-hero');
      expect(at.fontSize, 24);
      expect(at.rect.overlaps(hero), isFalse);
      expect(at.rect.right, lessThanOrEqualTo(foe.left));
    });

    test('the rolled 320x568 stage: beside the delver, never on it', () {
      // 272x86 with a 72 dp delver and a 96 dp boss standing in all of it:
      // there is no band above the heads, so the banner takes the boss's
      // (dissolving) spot beside the delver, at >= 22 sp.
      const stage = Size(272, 86);
      final hero = VictoryBeat.heroEnvelope(floorY: 78, heroH: 72);
      const foe = Rect.fromLTWH(176, -18, 96, 96);
      final at = VictoryBeat.place(
        stage: stage,
        hero: hero,
        foe: foe,
        measure: box,
      );
      expect(at.area, 'beside');
      expect(at.fontSize, inInclusiveRange(22, 34));
      expect(at.rect.left, greaterThanOrEqualTo(hero.right + VictoryBeat.gap));
      inside(at.rect, stage);
    });

    test('a stage too short for the inset: beside the delver at 22 sp', () {
      // The gambler's rolled 320x568 stage is 40 dp, not 86 (0.186.0
      // review): no area holds the banner at 22 sp inside the 8 dp inset.
      // The band beside the delver is wide enough, so the banner goes there
      // at 22 sp, centred in the stage's full height (the 22 sp minimum wins
      // over the inset; about 2 dp above and below, as for the gambler), and
      // never on the delver. The old fallback centred it on the delver.
      const stage = Size(272, 44);
      final hero = VictoryBeat.heroEnvelope(floorY: 36, heroH: 72);
      const foe = Rect.fromLTWH(176, -60, 96, 96);
      final min = box(VictoryBeat.minFontSize);
      expect(
        min.height,
        greaterThan(stage.height - 2 * VictoryBeat.inset),
        reason: 'the stage is too short for the banner plus both insets',
      );
      final at = VictoryBeat.place(
        stage: stage,
        hero: hero,
        foe: foe,
        measure: box,
      );
      expect(at.area, 'beside');
      expect(at.fontSize, VictoryBeat.minFontSize);
      expect(at.rect.size, min);
      expect(at.rect.left, greaterThanOrEqualTo(hero.right + VictoryBeat.gap));
      expect(at.rect.overlaps(hero), isFalse);
      expect(at.rect.center.dy, closeTo(stage.height / 2, 0.01));
      inside(at.rect, stage);
    });

    test('nowhere clear: 22 sp in the middle, never smaller', () {
      const stage = Size(150, 40);
      final hero = VictoryBeat.heroEnvelope(floorY: 32, heroH: 30);
      const foe = Rect.fromLTWH(100, 2, 50, 30);
      final at = VictoryBeat.place(
        stage: stage,
        hero: hero,
        foe: foe,
        measure: box,
      );
      expect(at.area, 'centre');
      expect(at.fontSize, VictoryBeat.minFontSize);
    });

    test(
      'the delver keep-out covers the pose and the last of the step back',
      () {
        final r = VictoryBeat.heroEnvelope(floorY: 242, heroH: 104);
        // Measured on the shipped delver at 360x800 (stage coordinates): the
        // pose's figure + weapon box spans x -8.7..103.8, top 122.4.
        expect(r.left, lessThanOrEqualTo(-8.7));
        expect(r.right, greaterThanOrEqualTo(103.8 + 0.1 * 104));
        expect(r.top, lessThanOrEqualTo(122.4));
        expect(r.bottom, 242);
      },
    );
  });

  for (final size in const [Size(320, 568), Size(360, 800), Size(412, 915)]) {
    testWidgets(
      'boss kill at ${size.width.toInt()}x${size.height.toInt()}: '
      'victory banner in the stage, tray dimmed and inert, embers rise',
      (t) => _victory(t, size: size, reduced: false),
    );
  }
  testWidgets('reduced motion: the banner fades in, no embers', (t) async {
    await _victory(t, size: const Size(360, 800), reduced: true);
  });
}
