// Charging foes (2026-09-24): an attacking enemy plays its sheet's authored
// run cycle for the lunge instead of sliding its idle pose across the stage.
// Presentation only — the strike's windup/travel/contact timing, the sealed
// sim and the contact timeline are unchanged; only which sheet row the foe's
// SpriteView draws (and how fast) changes while `_enemyLunge` is up.
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as fixture;

const _foeKey = ValueKey('enemy-flue_crawler');

void main() {
  tearDown(() => Motion.instance.reset());

  testWidgets('a charging foe runs its authored run cycle into the strike', (
    tester,
  ) async {
    final c = await fixture.intoFight(tester);
    await tester.tap(fixture.button('Roll'));
    await fixture.pumpFor(tester, 1800);
    SpriteView foe() => tester.widget<SpriteView>(find.byKey(_foeKey));
    expect(foe().state, 'idle');
    expect(foe().fps, isNull, reason: 'idle plays at the sheet fps');
    final meta = await tester.runAsync(SpriteMeta.load);
    expect(
      meta!.sheet('flue_crawler')!.row('run'),
      isNotNull,
      reason: 'fixture foe has an authored run row',
    );

    await tester.tap(fixture.button('End turn'));
    var ran = false;
    for (var t = 0; t < 1500; t += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      final f = find.byKey(_foeKey);
      if (f.evaluate().isEmpty) continue;
      final body = tester.widget<SpriteView>(f);
      if (body.state == 'run') {
        ran = true;
        expect(body.fps, 14, reason: 'the charge runs faster than idle');
      }
    }
    expect(ran, isTrue, reason: 'the lunge plays the run row');
    expect(
      c.sim!.player['hp'],
      lessThan(c.sim!.player['max_hp'] as int),
      reason: 'the foe really attacked this turn',
    );

    await fixture.pumpFor(tester, 2600);
    expect(foe().state, 'idle', reason: 'recovers into its idle loop');
    expect(foe().fps, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.pumpFor(tester, 2200);
  });
}
