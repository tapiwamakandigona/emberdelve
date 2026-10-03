// test/blade_trail_test.dart — C0-13 "the trail is the blade's path".
//
// The critic (round 0, rescoped in round 2) saw the cut's trail drawn as a
// crescent around the FOE that lived ~280 ms, far from the blade tip, so it
// read as a sticker on the victim. These tests pin the fix in a real fight
// (seed 1, Kindler, Ember Brand = a cut):
//  1. the blade itself still carries its smear 60 ms after contact, and
//     that smear is gone within 120 ms of contact;
//  2. the foe-side contact for a cut is a flash of at most 120 ms;
//  3. the foe-side cut mark no longer draws an arc over the top of the
//     victim (measured on real pixels of the ImpactSlash painter).
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is EmberButton && w.label == label && w.onTap != null,
);

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<GameController> _fight(WidgetTester tester) async {
  Motion.instance.update(setting: 'off');
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.meta.tipsSeen.addAll(ContextTips.all);
  c.tipDirector = TipDirector(c.meta.tipsSeen);
  c.meta.tourSeenVersion = tourVersion;
  c.tour = TourDirector(seenVersion: tourVersion);
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
  );
  await tester.runAsync(warmSpriteSheets);
  c.startRun(character: 'kindler', boons: true, seed: 1, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  await _pumpFor(tester, 2600);
  expect(c.phase, 'player_turn');
  await tester.tap(_button('Roll'));
  await _pumpFor(tester, 2600);
  return c;
}

/// The live smear the combat figure reports to its weapon painter.
double _bladeSmear(WidgetTester tester) {
  final weapon = tester.widget<WeaponView>(
    find.byKey(const ValueKey('combat-weapon')),
  );
  return weapon.articulation!.value.smear;
}

void main() {
  testWidgets('the blade carries its trail at contact, gone within 120 ms', (
    tester,
  ) async {
    await _fight(tester);
    final dice = find.byWidgetPredicate((w) => w is DieChip && w.value != null);
    await tester.tap(dice.at(0)); // the 5
    await tester.pump();
    await tester.tap(_button('Attack'));
    int? contactAt;
    var smearAtContact = 0.0;
    var smearAfter60 = 0.0;
    final lateSmear = <int>[];
    for (var t = 10; t <= 900; t += 10) {
      await tester.pump(const Duration(milliseconds: 10));
      final slash = find.byType(ImpactSlash).evaluate().isNotEmpty;
      final smear = _bladeSmear(tester);
      if (contactAt == null && slash) {
        contactAt = t;
        smearAtContact = smear;
      }
      if (contactAt != null && t == contactAt + 60) smearAfter60 = smear;
      if (contactAt != null && t > contactAt + 120 && smear > 0) {
        lateSmear.add(t - contactAt);
      }
    }
    expect(contactAt, isNotNull, reason: 'the blow must land');
    expect(
      smearAtContact,
      greaterThan(0),
      reason: 'at contact the trail should still be on the blade',
    );
    // The critic's frames 052-054: the trail is still on the blade for
    // the next two 40 ms frames, not only the instant of contact.
    expect(
      smearAfter60,
      greaterThan(0),
      reason: 'the trail should linger on the blade ~60 ms after contact',
    );
    expect(
      lateSmear,
      isEmpty,
      reason: 'blade trail still alive this many ms after contact',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the foe-side cut contact is a flash of at most 120 ms', (
    tester,
  ) async {
    await _fight(tester);
    final dice = find.byWidgetPredicate((w) => w is DieChip && w.value != null);
    await tester.tap(dice.at(0));
    await tester.pump();
    await tester.tap(_button('Attack'));
    ImpactSlash? seen;
    for (var t = 0; t < 900 && seen == null; t += 10) {
      await tester.pump(const Duration(milliseconds: 10));
      final f = find.byType(ImpactSlash);
      if (f.evaluate().isNotEmpty) seen = tester.widget<ImpactSlash>(f.first);
    }
    expect(seen, isNotNull);
    expect(seen!.resolvedShape, ContactShape.cut);
    expect(seen.duration.inMilliseconds, lessThanOrEqualTo(120));
    // It reports done and leaves the stage.
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byType(ImpactSlash), findsNothing);
    await _pumpFor(tester, 3000); // let the turn's choreography finish
  });

  testWidgets('the cut mark draws no arc over the top of the victim', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 120,
              height: 120,
              child: ImpactSlash(
                shape: ContactShape.cut,
                duration: const Duration(milliseconds: 340),
                onDone: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // Sample the mark fully drawn (grow completes at 40% of its life).
    var longestTopRun = 0;
    var painted = 0;
    for (final ms in [150, 200]) {
      await tester.pump(Duration(milliseconds: ms == 150 ? 150 : 50));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      });
      for (var y = 0; y < 120; y++) {
        var run = 0;
        for (var x = 0; x < 120; x++) {
          final a = bytes!.getUint8((y * 120 + x) * 4 + 3);
          if (a > 40) {
            painted++;
            run++;
            // Top quarter: where the old crescent crossed over the body.
            if (y < 30 && run > longestTopRun) longestTopRun = run;
          } else {
            run = 0;
          }
        }
      }
    }
    expect(painted, greaterThan(0), reason: 'the contact must still read');
    // Spark dots are a few px wide; a stroke across the top is an arc.
    expect(longestTopRun, lessThanOrEqualTo(8));
  });
}
