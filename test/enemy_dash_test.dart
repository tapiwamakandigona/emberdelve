// Experimental loop C0-01 + C0-05 (critic rank 1 since round 0, pinned in
// round 4). Before: a foe struck from where it stood - its slide stopped
// mid-floor, ~150 px short of the delver - and the delver's hit reaction
// was a ~300 ms frozen white silhouette. After: the foe dashes to a strike
// mark beside the delver (no dash under Reduce Motion) and the delver gets
// one short white beat, an 8 px jolt back and a red hurt tint.
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart' show alphaOf, button, makeController, toFight;

const _frame = Duration(milliseconds: 20);

class _Trace {
  double foeRestX = 0, heroRestX = 0, heroRestLeft = 0;
  final foeX = <double>[]; // foe body centre per frame, shake removed
  final heroLeft = <double>[]; // delver's left edge per frame, shake removed
  final white = <bool>[];
  final hurt = <bool>[];

  int get contact => white.indexOf(true);
}

/// The whole-screen shake offset (ShakeBox translates its child).
double _shakeDx(WidgetTester tester) {
  final box = find.byType(ShakeBox).first;
  final inner = find
      .descendant(of: box, matching: find.byType(RepaintBoundary))
      .first;
  return tester.getTopLeft(inner).dx - tester.getTopLeft(box).dx;
}

/// True when a mostly-opaque copy of [body] sits under the tint keyed [key].
bool _shows(Finder body, String key) {
  for (final e in body.evaluate()) {
    var under = false;
    e.visitAncestorElements((a) {
      if (a.widget.key == ValueKey(key)) {
        under = true;
        return false;
      }
      return true;
    });
    if (under && alphaOf(e) > 0.5) return true;
  }
  return false;
}

Future<_Trace> _enemyTurn(
  WidgetTester tester,
  String foe, {
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: reduced ? 'on' : 'off');
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
  // Fixture only: swap the body on screen; the fight itself is unchanged.
  c.sim!.enemy!['id'] = foe;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tap(button('Roll'));
  for (var t = 0; t < 2000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final foeBody = find.byKey(ValueKey('enemy-$foe'));
  final heroBody = find.byKey(const ValueKey('hero-kindler'));
  expect(foeBody, findsWidgets);
  expect(heroBody, findsWidgets);
  final trace = _Trace()
    ..foeRestX = tester.getRect(foeBody.first).center.dx
    ..heroRestX = tester.getRect(heroBody.first).center.dx
    ..heroRestLeft = tester.getRect(heroBody.first).left;
  await tester.tap(button('End turn'));
  for (var f = 0; f < 45; f++) {
    await tester.pump(_frame);
    final shake = _shakeDx(tester);
    trace.foeX.add(tester.getRect(foeBody.first).center.dx - shake);
    trace.heroLeft.add(tester.getRect(heroBody.first).left - shake);
    trace.white.add(_shows(heroBody, 'flash'));
    trace.hurt.add(_shows(heroBody, 'hurt'));
  }
  for (var t = 0; t < 4000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  return trace;
}

void main() {
  test('C0-01: dashes take 120-160 ms; brutes hop in, maws lunge low', () {
    for (final style in EnemyStrikeStyle.values) {
      final p = planEnemyStrike(style);
      expect(p.travelMs, inInclusiveRange(120, 160), reason: '$style');
    }
    expect(enemyStyleFor('slag_brute'), EnemyStrikeStyle.slam);
    expect(planEnemyStrike(EnemyStrikeStyle.slam).hop, greaterThan(0.18));
    expect(enemyStyleFor('molten_maw'), EnemyStrikeStyle.swipe);
    expect(planEnemyStrike(EnemyStrikeStyle.swipe).hop, 0);
  });

  for (final foe in [
    'flue_crawler',
    'cinder_wisp',
    'slag_brute',
    'molten_maw',
  ]) {
    testWidgets('C0-01/C0-05: $foe dashes in; the delver flinches red', (
      tester,
    ) async {
      final t = await _enemyTurn(tester, foe);
      final hit = t.contact;
      expect(hit, greaterThan(0), reason: 'the blow must land');
      final closest = t.foeX.reduce((a, b) => a < b ? a : b);
      // Crosses the floor (critic: centroid >= 90 px @2x closer)...
      expect(t.foeRestX - closest, greaterThanOrEqualTo(45));
      // ...to a strike mark beside the delver, not mid-floor, and never
      // into the delver's body.
      final gap = t.foeX[hit] - t.heroRestX;
      expect(gap, lessThanOrEqualTo(80), reason: 'contact gap $gap');
      expect(gap, greaterThanOrEqualTo(40), reason: 'contact gap $gap');
      expect(t.foeX[hit] - closest, lessThan(4), reason: 'lands at contact');
      // One short white beat (was ~300 ms), then the red hurt tint.
      final whiteMs = t.white.where((w) => w).length * _frame.inMilliseconds;
      expect(whiteMs, lessThanOrEqualTo(100), reason: 'white $whiteMs ms');
      expect(t.hurt.sublist(hit).contains(true), isTrue);
      // The blow moves the delver: >= 6 px back within 100 ms of contact.
      final back = [
        for (var f = hit; f < hit + 5 && f < t.heroLeft.length; f++)
          t.heroRestLeft - t.heroLeft[f],
      ].reduce((a, b) => a > b ? a : b);
      expect(back, greaterThanOrEqualTo(6), reason: 'knockback $back px');
    });
  }

  testWidgets('C0-01: Reduce Motion keeps the strike a lean in place', (
    tester,
  ) async {
    final t = await _enemyTurn(tester, 'slag_brute', reduced: true);
    expect(t.contact, greaterThan(0), reason: 'the blow must land');
    final closest = t.foeX.reduce((a, b) => a < b ? a : b);
    // The lean tips the body's centre ~10 px; a dash would be 100+.
    expect(t.foeRestX - closest, lessThan(16));
  });
}
