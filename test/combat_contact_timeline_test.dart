// Contact is presentation-only: the sealed sim must still resolve at tap time.
// Existing tests are untouched; these regressions intentionally fail on #104.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/blood_effects.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as fixture;

Finder _dice() =>
    find.byWidgetPredicate((w) => w is DieChip && w.value != null);

StatBar _bar(WidgetTester tester, String label) => tester
    .widgetList<StatBar>(find.byType(StatBar))
    .firstWhere((w) => w.label.startsWith(label));

SpriteView _body(WidgetTester tester, String id) => tester
    .widgetList<SpriteView>(
      find.byWidgetPredicate((w) => w is SpriteView && w.spriteId == id),
    )
    .last;

Future<void> _ticks(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 10) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _cleanup(WidgetTester tester) async {
  await fixture.pumpFor(tester, 2600);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await fixture.pumpFor(tester, 2200);
}

void _notify(GameController c) {
  // Explicit fixture state, not a mutation path in the application.
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
}

Future<void> _roll(WidgetTester tester) async {
  await tester.tap(fixture.button('Roll'));
  await fixture.pumpFor(tester, 1800);
}

void main() {
  tearDown(() {
    Motion.instance.reset();
    BloodEffects.enabled.value = true;
  });

  for (final character in ['kindler', 'warden', 'gambler', 'runesmith']) {
    testWidgets('$character: HP and wounds wait for player contact', (
      tester,
    ) async {
      final c = await fixture.intoFight(tester, character: character);
      await _roll(tester);
      final before = c.sim!.enemy!['hp'] as int;
      final maxHp = c.sim!.enemy!['max_hp'] as int;
      await tester.tap(_dice().at(0)); // face 5
      await tester.pump();
      await tester.tap(fixture.button('Attack'));
      final resolved = c.sim!.enemy!['hp'] as int;
      expect(resolved, lessThan(before), reason: 'sim resolves immediately');
      await _ticks(tester, 100);
      expect(_bar(tester, 'ENEMY HP').value, before);
      expect(_body(tester, 'flue_crawler').condition.vitality, before / maxHp);
      await _ticks(tester, 230); // total 330ms, before 340ms contact
      expect(_bar(tester, 'ENEMY HP').value, before);
      await _ticks(tester, 20);
      expect(_bar(tester, 'ENEMY HP').value, resolved);
      expect(
        _body(tester, 'flue_crawler').condition.vitality,
        resolved / maxHp,
      );
      await _cleanup(tester);
    });
  }

  for (final block in [0, 2, 20]) {
    testWidgets('incoming hit retains HP and $block guard until impact', (
      tester,
    ) async {
      final c = await fixture.intoFight(tester);
      await _roll(tester);
      c.sim!.player['block'] = block;
      c.sim!.enemy!['intent'] = <String, Object?>{
        'kind': 'attack',
        'amount': 7,
      };
      _notify(c);
      await tester.pump();
      final before = c.sim!.player['hp'] as int;
      await tester.tap(fixture.button('End turn'));
      final resolved = c.sim!.player['hp'] as int;
      await _ticks(tester, 200);
      expect(_bar(tester, 'YOUR HP').value, before);
      expect(_bar(tester, 'YOUR HP').block, block);
      if (block > 0) {
        expect(fixture.weapon(tester).phase, WeaponPhase.guard);
      }
      await _ticks(tester, 230); // 430ms: still before enemy contact
      expect(_bar(tester, 'YOUR HP').value, before);
      expect(_bar(tester, 'YOUR HP').block, block);
      await _ticks(tester, 30);
      expect(_bar(tester, 'YOUR HP').value, resolved);
      expect(
        _body(tester, 'kindler').condition.vitality,
        resolved / (c.sim!.player['max_hp'] as int),
      );
      expect(_bar(tester, 'YOUR HP').block, block > 7 ? block - 7 : 0);
      await _cleanup(tester);
      expect(c.phase, 'player_turn');
    });
  }

  testWidgets('riposte HP and guard wait for their own contact beat', (
    tester,
  ) async {
    final c = await fixture.intoFight(tester);
    await _roll(tester);
    c.sim!.player['block'] = 2;
    c.sim!.enemy!['intent'] = <String, Object?>{
      'kind': 'counter',
      'amount': 7,
    };
    _notify(c);
    await tester.pump();
    final before = c.sim!.player['hp'] as int;
    await tester.tap(_dice().at(1)); // low hit avoids a big-hit hold
    await tester.pump();
    await tester.tap(fixture.button('Attack'));
    final resolved = c.sim!.player['hp'] as int;
    expect(resolved, lessThan(before));
    await _ticks(tester, 350); // player's hit, not the later riposte
    expect(_bar(tester, 'YOUR HP').value, before);
    expect(_bar(tester, 'YOUR HP').block, 2);
    await _ticks(tester, 150);
    expect(_bar(tester, 'YOUR HP').value, resolved);
    expect(_bar(tester, 'YOUR HP').block, 0);
    await _cleanup(tester);
  });

  testWidgets('burn condition advances at burn beat, after incoming hit', (
    tester,
  ) async {
    final c = await fixture.intoFight(tester);
    await _roll(tester);
    c.sim!.enemy!['burn'] = 4;
    _notify(c);
    await tester.pump();
    final before = c.sim!.enemy!['hp'] as int;
    await tester.tap(fixture.button('End turn'));
    final resolved = c.sim!.enemy!['hp'] as int;
    expect(resolved, before - 4);
    await _ticks(tester, 460);
    expect(_bar(tester, 'ENEMY HP').value, before);
    await _ticks(tester, 400);
    expect(_bar(tester, 'ENEMY HP').value, resolved);
    await _cleanup(tester);
  });

  testWidgets('lethal contact keeps corpse at zero until held route exits', (
    tester,
  ) async {
    final c = await fixture.intoFight(tester);
    await _roll(tester);
    c.sim!.enemy!['hp'] = 1;
    _notify(c);
    await tester.pump();
    await tester.tap(_dice().at(0));
    await tester.pump();
    await tester.tap(fixture.button('Attack'));
    expect(c.phase, isNot('player_turn'));
    await _ticks(tester, 100);
    expect(find.byType(CombatScreen), findsOneWidget);
    expect(_bar(tester, 'ENEMY HP').value, 1);
    await _ticks(tester, 250);
    expect(_bar(tester, 'ENEMY HP').value, 0);
    expect(_body(tester, 'flue_crawler').condition.vitality, 0);
    await _ticks(tester, 350);
    expect(_bar(tester, 'ENEMY HP').value, 0);
    await _cleanup(tester);
  });

  for (final reduced in [false, true]) {
    testWidgets('fast-forward preserves final contact state; reduce=$reduced', (
      tester,
    ) async {
      final c = await fixture.intoFight(tester);
      await _roll(tester);
      Motion.instance.update(setting: reduced ? 'on' : 'off');
      BloodEffects.enabled.value = false;
      c.sim!.player['block'] = 2;
      _notify(c);
      await tester.pump();
      final before = c.sim!.player['hp'] as int;
      await tester.tap(fixture.button('End turn'));
      await _ticks(tester, 50);
      expect(_bar(tester, 'YOUR HP').value, before);
      // Unclaimed stage taps use the existing 2x / skip-to-state control.
      await tester.tapAt(tester.getCenter(find.byType(CombatScreen)));
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(CombatScreen)));
      await _ticks(tester, 300);
      expect(_bar(tester, 'YOUR HP').value, c.sim!.player['hp']);
      expect(_bar(tester, 'YOUR HP').block, c.sim!.player['block']);
      expect(_body(tester, 'kindler').showWounds, isFalse);
      await _cleanup(tester);
    });
  }
}
