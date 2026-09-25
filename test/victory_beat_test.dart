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
    expect(VictoryBeat.text.split(' ').length, 1);
    expect(VictoryBeat.intro, const Duration(milliseconds: 250));
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
