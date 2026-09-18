// Joint/source-pixel invariants and actual stage consumer wiring. These are
// executable contracts, not a claim that the animation is artist-approved.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/combat_figure.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combat_bodies_test.dart' as helpers;

StrikePlan _plan(CombatRig rig, DieTier tier) => planStrike(
  rig.id == 'warden' ? StrikeFamily.crush : StrikeFamily.cut,
  tier,
);

void _near(Offset a, Offset b, [String? reason]) {
  expect((a - b).distance, lessThan(1e-7), reason: reason);
}

void _joints(CombatRigSample s) {
  final rig = s.rig;
  _near(
    s.part(RigPart.upperArm).map(rig.shoulder),
    s.shoulder,
    'shoulder seam',
  );
  _near(s.part(RigPart.upperArm).map(rig.elbow), s.elbow, 'upper elbow seam');
  _near(s.part(RigPart.forearm).map(rig.elbow), s.elbow, 'lower elbow seam');
  _near(s.part(RigPart.forearm).map(rig.wrist), s.wrist, 'forearm wrist');
  _near(s.part(RigPart.hand).map(rig.wrist), s.wrist, 'painted grip');
  _near(s.part(RigPart.rearFoot).map(rig.rearFoot), s.rearFoot, 'back boot');
  _near(
    s.part(RigPart.frontFoot).map(rig.frontFoot),
    s.frontFoot,
    'front boot',
  );
  expect(s.rearFoot.dy, 37.5);
  expect(s.frontFoot.dy, 37.5);
  for (final height in [72.0, 96.0, 104.0]) {
    _near(
      s.weaponGrip(height),
      s.part(RigPart.hand).map(rig.wrist) * (height / 40),
    );
  }
  for (final part in s.parts) {
    expect(part.matrix.every((x) => x.isFinite), isTrue);
    expect(part.a * part.d - part.b * part.c, greaterThan(0));
  }
}

ValueListenable<CombatRigSample> _shared(WidgetTester tester, String id) {
  final sprite = tester
      .widgetList<SpriteView>(
        find.byWidgetPredicate((w) => w is SpriteView && w.spriteId == id),
      )
      .last;
  final weapon = tester.widgetList<WeaponView>(find.byType(WeaponView)).last;
  final hand = tester
      .widgetList<SpriteGripOverlay>(find.byType(SpriteGripOverlay))
      .last;
  expect(sprite.articulation, isNotNull);
  expect(identical(sprite.articulation, weapon.articulation), isTrue);
  expect(identical(sprite.articulation, hand.articulation), isTrue);
  final source = sprite.articulation!;
  _joints(source.value);
  return source;
}

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final box =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await box.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = Uint8List.fromList(bytes.buffer.asUint8List());
    image.dispose();
    return result;
  }))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Motion.instance.update(setting: 'system', systemFlag: false));

  test(
    'only the two authored delvers opt in; roster/portrait fallback stays',
    () {
      expect(CombatRig.forId('kindler'), same(CombatRig.kindler));
      expect(CombatRig.forId('warden'), same(CombatRig.warden));
      expect(CombatRig.forId('gambler'), isNull);
      expect(CombatRig.forId('not-a-delver'), isNull);
      expect(const SpriteView('kindler', height: 96).articulation, isNull);
      expect(const WeaponView('kindler', height: 96).articulation, isNull);
    },
  );

  for (final rig in [CombatRig.kindler, CombatRig.warden]) {
    test(
      '${rig.id}: solved anatomy/grip stays connected at every sampled transition',
      () {
        for (final tier in DieTier.values) {
          final plan = _plan(rig, tier);
          for (final beat in RigBeat.values) {
            final a = RigPose.at(rig, RigBeat.ready, plan);
            final b = RigPose.at(rig, beat, plan);
            for (final vitality in [1.0, 0.5, 0.2]) {
              for (var i = 0; i <= 24; i++) {
                final sample = CombatRigSample.solve(
                  rig: rig,
                  pose: RigPose.lerp(a, b, i / 24),
                  condition: Condition(vitality),
                  life: i / 24,
                  weaponAngle: 0.7,
                );
                _joints(sample);
              }
            }
          }
        }
      },
    );

    test(
      '${rig.id}: upper/lower limbs are not one affine sprite transform',
      () {
        final plan = _plan(rig, DieTier.high);
        final sample = CombatRigSample.solve(
          rig: rig,
          pose: RigPose.at(rig, RigBeat.windup, plan),
          condition: Condition.fresh,
          life: 0,
          weaponAngle: -1,
        );
        final torsoWrist = sample.part(RigPart.torso).map(rig.wrist);
        expect((torsoWrist - sample.wrist).distance, greaterThan(3));
        expect(
          sample.part(RigPart.head).b,
          isNot(sample.part(RigPart.torso).b),
        );
        expect(
          sample.part(RigPart.frontLeg).x,
          isNot(sample.part(RigPart.torso).x),
        );
        expect(sample.part(RigPart.rearFoot).b, 0);
      },
    );

    test('${rig.id}: a high die visibly commits more than a low die', () {
      final low = RigPose.at(rig, RigBeat.windup, _plan(rig, DieTier.low));
      final high = RigPose.at(rig, RigBeat.windup, _plan(rig, DieTier.high));
      expect(high.hips.distance, greaterThan(low.hips.distance));
      expect(high.chest.abs(), greaterThan(low.chest.abs()));
      expect(high.handFromShoulder.dy, lessThan(low.handFromShoulder.dy));
      final hit = RigPose.at(rig, RigBeat.strike, _plan(rig, DieTier.high));
      expect(hit.spread, greaterThan(high.spread));
    });

    testWidgets(
      '${rig.id}: shared wrist is wired throughout a real attack/guard',
      (tester) async {
        await helpers.intoFight(tester, character: rig.id);
        final idle = _shared(tester, rig.id);
        final before = idle.value.wrist;
        await helpers.pumpFor(tester, 200);
        expect((idle.value.wrist - before).distance, greaterThan(0.01));
        await tester.tap(helpers.button('Roll'));
        await helpers.pumpFor(tester, 2600);
        final dice = find.byWidgetPredicate(
          (w) => w is DieChip && w.value != null,
        );
        await tester.tap(dice.at(0));
        await tester.pump();
        await tester.tap(helpers.button('Attack'));
        for (var i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          _shared(tester, rig.id);
        }
        await tester.tap(dice.at(1));
        await tester.pump();
        await tester.tap(helpers.button('Block'));
        await helpers.pumpFor(tester, 300);
        expect(
          tester.widget<WeaponView>(find.byType(WeaponView)).phase,
          WeaponPhase.guard,
        );
        _shared(tester, rig.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '${rig.id}: blood-off keeps fatigue, reduced idle is still, layers paint',
      (tester) async {
        await tester.runAsync(warmSpriteSheets);
        Motion.instance.update(setting: 'on');
        final key = GlobalKey();
        var condition = Condition.fresh;
        var wounds = false;
        var phase = WeaponPhase.idle;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: StatefulBuilder(
                  builder: (context, set) {
                    update = set;
                    return SizedBox(
                      width: 160,
                      height: 160,
                      child: Center(
                        child: CombatFigure(
                          rig: rig,
                          height: 120,
                          phase: phase,
                          plan: _plan(rig, DieTier.high),
                          condition: condition,
                          showWounds: wounds,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await helpers.pumpFor(tester, 400);
        final fresh = await _pixels(tester, key);
        update(() => condition = const Condition(0.2));
        await helpers.pumpFor(tester, 400);
        final hurtOff = await _pixels(tester, key);
        expect(
          hurtOff,
          isNot(orderedEquals(fresh)),
          reason: 'fatigue silhouette stays with blood off',
        );
        final sample = _shared(tester, rig.id);
        final wrist = sample.value.wrist;
        final still = await _pixels(tester, key);
        var paints = 0;
        debugOnProfilePaint = (object) {
          if (object is RenderCustomPaint) paints++;
        };
        await helpers.pumpFor(tester, 800);
        debugOnProfilePaint = null;
        _near(sample.value.wrist, wrist);
        expect(
          paints,
          0,
          reason: 'shared idle ticker must park under reduce motion',
        );
        expect(await _pixels(tester, key), orderedEquals(still));
        update(() => wounds = true);
        await tester.pump();
        expect(await _pixels(tester, key), isNot(orderedEquals(hurtOff)));
        update(() => wounds = false);
        await tester.pump();
        expect(await _pixels(tester, key), orderedEquals(hurtOff));
        update(() => phase = WeaponPhase.raise);
        await helpers.pumpFor(tester, 200);
        final raised = await _pixels(tester, key);
        expect(
          raised,
          isNot(orderedEquals(hurtOff)),
          reason: 'information-bearing joint action stays under reduce',
        );
        _shared(tester, rig.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'Warden overhead and Kindler cut use different weight and wrist paths',
    () {
      final k = RigPose.at(
        CombatRig.kindler,
        RigBeat.strike,
        _plan(CombatRig.kindler, DieTier.high),
      );
      final w = RigPose.at(
        CombatRig.warden,
        RigBeat.strike,
        _plan(CombatRig.warden, DieTier.high),
      );
      expect(k.hips.dy, lessThan(0));
      expect(w.hips.dy, greaterThan(1));
      expect(w.handFromShoulder.dy, greaterThan(k.handFromShoulder.dy));
      final guard = RigPose.at(
        CombatRig.warden,
        RigBeat.guard,
        _plan(CombatRig.warden, DieTier.high),
      );
      expect(guard.shield, lessThan(-0.1));
    },
  );
}
