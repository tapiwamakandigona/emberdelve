// Regression exposed by the whole-roster phone captures: custom_N was
// incorrectly parsed as d6 by presentation, even when the sim knew its base.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as fixture;

void _notify(GameController c) {
  // Controlled presentation fixture; no new application mutation path.
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
}

void main() {
  tearDown(() => Motion.instance.reset());

  for (final sides in [4, 6, 8, 10, 12]) {
    for (final tier in DieTier.values) {
      testWidgets('tempered d$sides $tier keeps its own heat and strike tier',
          (tester) async {
        final c = await fixture.intoFight(tester);
        final face = switch (tier) {
          DieTier.low => 1,
          DieTier.mid => sides ~/ 2,
          DieTier.high => sides - 1,
          DieTier.max => sides,
        };
        (c.sim!.run!['custom_dice'] as Map)['custom_991'] = {
          'base': 'd$sides', 'face': 1, 'rune': 'mend',
        };
        (c.sim!.player['dice'] as List)[0] = 'custom_991';
        c.sim!.enemy!['hp'] = c.sim!.enemy!['max_hp'] = 999;
        _notify(c);
        await tester.pump();
        await tester.tap(fixture.button('Roll'));
        await fixture.pumpFor(tester, 2000);
        (c.sim!.player['rolled'] as List)[0] = face;
        (c.sim!.player['rolled_face'] as List)[0] = face;
        (c.sim!.player['rolled_max'] as List)[0] = face == sides;
        _notify(c);
        await tester.pump();
        final chips = find.byWidgetPredicate(
            (w) => w is DieChip && w.value != null);
        await tester.tap(chips.first);
        await tester.pump();
        expect(fixture.weapon(tester).charge,
            closeTo(heatFor(face, sides), 1e-10),
            reason: 'custom d$sides face $face must not use a d6 denominator');
        await tester.tap(fixture.button('Attack'));
        await fixture.pumpFor(tester, 200);
        final weapon = fixture.weapon(tester);
        expect(weapon.plan!.tier, tier);
        expect(weapon.phase, WeaponPhase.swing);
        expect(weapon.charge, closeTo(heatFor(face, sides), 1e-10));
        await fixture.pumpFor(tester, 2600);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await fixture.pumpFor(tester, 2200);
      });
    }
  }
}
