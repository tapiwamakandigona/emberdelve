// Experimental loop C4-04 (critic round 4): the hit shake moved the whole
// screen — the gold/embers bar, the enemy panel and the dice tray jumped up
// to ~6 dp with every blow, and on a boss kill the right edge of the top bar
// pulled away from the screen edge, showing a dark sliver. After: the shake
// lives on the stage (fighters + cavern backdrop) only; the HUD holds still.
//
// Real path: a foe's blow lands through End turn (no fixture on the hit),
// every 20 ms frame of the enemy turn is sampled, and the HUD anchors above
// the stage (top-bar pip, enemy name) must keep their rest positions. The
// HP bar and the buttons below the stage re-lay out when the turn passes, so
// for them the test checks they sit outside the shaken subtree. It also
// proves the shake still plays over several frames and still carries the
// fighters, so deleting the shake cannot pass it.
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart' show button, makeController, toFight;

const _frame = Duration(milliseconds: 20);

/// How far the ShakeBox currently displaces its child (logical px).
Offset _shakeOffset(WidgetTester tester) {
  final box = find.byType(ShakeBox).first;
  final inner = find
      .descendant(of: box, matching: find.byType(RepaintBoundary))
      .first;
  return tester.getTopLeft(inner) - tester.getTopLeft(box);
}

Future<void> _case(WidgetTester tester, Size size) async {
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
  expect(find.byType(ShakeBox), findsOneWidget);

  final name = c.sim!.enemy!['name'] as String;
  final hud = <String, Finder>{
    'top-bar pip': find.byType(ResourcePip).first,
    'enemy name': find.text(name).first,
  };
  // Pin the exact render boxes now: a finder re-evaluated later could
  // land on a different widget of the same type once the turn changes.
  final boxes = {
    for (final e in hud.entries)
      e.key: e.value.evaluate().first.renderObject! as RenderBox,
  };
  Offset at(String k) => boxes[k]!.localToGlobal(Offset.zero);
  final rest = {for (final k in boxes.keys) k: at(k)};
  final hero = find.byKey(const ValueKey('hero-kindler'));
  expect(hero, findsWidgets);
  expect(
    find.descendant(of: find.byType(ShakeBox), matching: hero),
    findsWidgets,
    reason: 'the fighters must stay inside the shaken stage',
  );

  final hpBefore = c.sim!.player['hp'] as int;
  await tester.tap(button('End turn'));
  var maxShake = 0.0;
  var shakenFrames = 0;
  final drift = <String>[];
  for (var f = 0; f < 90; f++) {
    await tester.pump(_frame);
    final shake = _shakeOffset(tester).distance;
    if (shake > 0.5) shakenFrames++;
    if (shake > maxShake) maxShake = shake;
    for (final k in boxes.keys) {
      expect(boxes[k]!.attached, isTrue, reason: '$k left the screen');
      final d = (at(k) - rest[k]!).distance;
      if (d > 0.01) {
        drift.add('t=${(f + 1) * 20}ms $k moved ${d.toStringAsFixed(2)}');
      }
    }
  }
  expect(
    c.sim!.player['hp'] as int,
    lessThan(hpBefore),
    reason: 'seed 1: the foe\'s blow must land so the hit shake fires',
  );
  expect(
    maxShake,
    greaterThan(2.0),
    reason: 'the hit must still shake the stage',
  );
  expect(
    shakenFrames,
    greaterThanOrEqualTo(5),
    reason: 'the shake must play over several frames',
  );
  expect(drift, isEmpty, reason: 'HUD must hold still during the shake');
  // The bands under the stage legitimately re-lay out when the turn passes
  // (the tray and action zone change size), so their pixels are not a fair
  // probe; structurally they must sit outside the shaken subtree.
  for (final band in [find.byType(StatBar), find.byType(EmberButton)]) {
    expect(band, findsWidgets);
    expect(
      find.descendant(of: find.byType(ShakeBox), matching: band),
      findsNothing,
      reason: 'HP bar and buttons must not shake',
    );
  }
}

void main() {
  for (final size in const [Size(360, 800), Size(412, 915)]) {
    testWidgets(
      'a landed hit shakes the stage, not the HUD (${size.width.toInt()}x'
      '${size.height.toInt()})',
      (tester) => _case(tester, size),
    );
  }
}
