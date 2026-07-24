// test/weapons_test.dart — the combat-weapons pass: every character has a
// signature weapon, the held weapon renders and transitions through its
// choreography phases, and the contact FX / guard flash one-shots complete
// and call onDone. Bounded pumps throughout (WeaponView runs an idle-sway
// loop that would hang pumpAndSettle, same as the other ambient layers).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/ui/weapons.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  test('every character (and unknown ids) resolves to a weapon', () {
    final seen = <String>{};
    for (final id in charactersOrder) {
      final def = weaponFor(id);
      expect(def.name, isNotEmpty);
      expect(def.reach, greaterThan(0));
      // Swing must cross the idle pose or the arc reads backwards.
      expect(def.swingAngle, greaterThan(def.raiseAngle));
      seen.add(def.id);
    }
    // Signature means signature: no two delvers share a weapon.
    expect(seen.length, charactersOrder.length);
    // A future/unknown character never renders empty-handed.
    expect(weaponFor('someone_new').id, weaponFor('kindler').id);
  });

  testWidgets('WeaponView renders each weapon and survives phase choreography',
      (tester) async {
    for (final id in charactersOrder) {
      var phase = WeaponPhase.idle;
      late StateSetter setPhase;
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: StatefulBuilder(builder: (context, setState) {
            setPhase = setState;
            return WeaponView(id, height: 96, phase: phase);
          }),
        ),
      ));
      await pumpFor(tester, 200);
      expect(find.byType(WeaponView), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Full attack arc: idle -> raise (anticipation) -> swing (smear) -> idle.
      setPhase(() => phase = WeaponPhase.raise);
      await pumpFor(tester, 120);
      setPhase(() => phase = WeaponPhase.swing);
      await pumpFor(tester, 300);
      setPhase(() => phase = WeaponPhase.idle);
      await pumpFor(tester, 350);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('WeaponView renders charged (die pips heat the blade)',
      (tester) async {
    for (final id in charactersOrder) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: WeaponView(id,
              key: ValueKey('charged-$id'), height: 96, charge: 1.0),
        ),
      ));
      // Cover the charge tween plus a stretch of spark animation.
      await pumpFor(tester, 500);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ImpactSlash (smear and claws) plays once and reports done',
      (tester) async {
    for (final claws in [false, true]) {
      var done = false;
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 120,
          height: 120,
          child: ImpactSlash(
              key: ValueKey('slash-$claws'), // fresh State per variant
              claws: claws,
              onDone: () => done = true),
        ),
      ));
      await pumpFor(tester, 500);
      expect(done, isTrue, reason: 'claws=$claws should complete');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('GuardFlash plays once for both facings and reports done',
      (tester) async {
    for (final facing in [1, -1]) {
      var done = false;
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 120,
          height: 120,
          child: GuardFlash(
              key: ValueKey('guard-$facing'), // fresh State per variant
              facing: facing,
              onDone: () => done = true),
        ),
      ));
      await pumpFor(tester, 650);
      expect(done, isTrue, reason: 'facing=$facing should complete');
      expect(tester.takeException(), isNull);
    }
  });
}
