import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/combat_figure.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _families = <String, StrikeFamily>{
  'kindler': StrikeFamily.cut,
  'warden': StrikeFamily.crush,
  'gambler': StrikeFamily.stab,
  'ascetic': StrikeFamily.stab,
  'peddler': StrikeFamily.hook,
  'tinker': StrikeFamily.crush,
  'flintwright': StrikeFamily.pick,
  'runesmith': StrikeFamily.stamp,
  'bearer': StrikeFamily.crush,
  'mender': StrikeFamily.stab,
  'shieldwright': StrikeFamily.crush,
  'gilder': StrikeFamily.stamp,
  'cutler': StrikeFamily.stab,
  'collier': StrikeFamily.hook,
  'stoker': StrikeFamily.stab,
  'hearthkeeper': StrikeFamily.hook,
  'hedger': StrikeFamily.cut,
  'miller': StrikeFamily.crush,
  'brewster': StrikeFamily.crush,
  'lamplighter': StrikeFamily.hook,
  'farrier': StrikeFamily.pick,
  'glover': StrikeFamily.stab,
};

void _near(Offset a, Offset b) =>
    expect((a - b).distance, lessThan(1e-7));

void _jointContract(CombatRigSample s) {
  final r = s.rig;
  _near(s.part(RigPart.upperArm).map(r.shoulder), s.shoulder);
  _near(s.part(RigPart.upperArm).map(r.elbow), s.elbow);
  _near(s.part(RigPart.forearm).map(r.elbow), s.elbow);
  _near(s.part(RigPart.forearm).map(r.wrist), s.wrist);
  _near(s.part(RigPart.hand).map(r.wrist), s.wrist);
  _near(s.part(RigPart.rearFoot).map(r.rearFoot), s.rearFoot);
  _near(s.part(RigPart.frontFoot).map(r.frontFoot), s.frontFoot);
  expect(s.rearFoot.dy, r.rearFoot.dy);
  expect(s.frontFoot.dy, r.frontFoot.dy);
  for (final height in [72.0, 96.0, 104.0]) {
    _near(s.weaponGrip(height),
        s.part(RigPart.hand).map(r.wrist) * (height / 40));
  }
  for (final part in s.parts) {
    expect(part.matrix.every((x) => x.isFinite), isTrue);
    expect(part.a * part.d - part.b * part.c, greaterThan(0));
  }
}

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final result = Uint8List.fromList(bytes.buffer.asUint8List());
      image.dispose();
      return result;
    }))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Motion.instance.reset());
  test('every signature tool has an intentional family, not a default cut', () {
    expect(_families.keys, orderedEquals(charactersOrder));
    expect(_families.values.toSet(), StrikeFamily.values.toSet());
    for (final entry in _families.entries) {
      expect(familyForWeapon(weaponFor(entry.key).id), entry.value,
          reason: entry.key);
    }
    expect(familyForWeapon('unknown'), StrikeFamily.cut);
  });

  test('six body paths carry different tool mechanics', () {
    final rig = CombatRig.forId('gambler')!;
    final signatures = <String>{};
    for (final family in StrikeFamily.values) {
      final plan = planStrike(family, DieTier.high);
      final up = RigPose.at(rig, RigBeat.windup, plan);
      final hit = RigPose.at(rig, RigBeat.strike, plan);
      signatures.add('${up.hips}/${up.handFromShoulder}/${hit.handFromShoulder}');
      if (family == StrikeFamily.hook) {
        expect(hit.handFromShoulder.dx, lessThan(up.handFromShoulder.dx));
      } else {
        expect(hit.handFromShoulder.dx, greaterThan(up.handFromShoulder.dx));
      }
      if (family == StrikeFamily.stab) {
        expect(hit.handFromShoulder.dx, greaterThan(7));
        expect(up.handFromShoulder.dy, greaterThan(0));
      }
      if (family == StrikeFamily.crush) {
        expect(up.handFromShoulder.dy, lessThan(-4));
        expect(hit.hips.dy, greaterThan(1));
      }
      if (family == StrikeFamily.pick) {
        expect(up.handFromShoulder.dy, lessThan(-3));
        expect(hit.handFromShoulder.dx, lessThan(6));
      }
    }
    expect(signatures.length, 6);
  });

  for (final id in charactersOrder) {
    test('$id joints, source grip and grounded feet across all tiers/transitions', () {
      final rig = CombatRig.forId(id)!;
      final family = _families[id]!;
      for (final tier in DieTier.values) {
        final plan = planStrike(family, tier);
        for (final beat in RigBeat.values) {
          final from = RigPose.at(rig, RigBeat.ready, plan);
          final to = RigPose.at(rig, beat, plan);
          for (final health in [1.0, 0.5, 0.2]) {
            for (var tick = 0; tick <= 24; tick++) {
              _jointContract(CombatRigSample.solve(
                rig: rig,
                pose: RigPose.lerp(from, to, tick / 24),
                condition: Condition(health), life: tick / 24,
                weaponAngle: plan.swingAngle,
              ));
            }
          }
        }
      }
      final low = RigPose.at(rig, RigBeat.windup, planStrike(family, DieTier.low));
      final high = RigPose.at(rig, RigBeat.windup, planStrike(family, DieTier.high));
      expect(high.hips.distance, greaterThan(low.hips.distance));
      expect(high.chest.abs(), greaterThan(low.chest.abs()));
      expect(high.handFromShoulder.dy, lessThan(low.handFromShoulder.dy));
    });

    testWidgets('$id shared consumers, distinct layers, fatigue and parked idle', (tester) async {
      await tester.runAsync(warmSpriteSheets);
      Motion.instance.update(setting: 'on');
      final rig = CombatRig.forId(id)!;
      final plan = planStrike(_families[id]!, DieTier.high);
      final key = GlobalKey();
      var phase = WeaponPhase.idle;
      var health = 1.0;
      var wounds = false;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(
        home: Center(child: RepaintBoundary(
          key: key,
          child: SizedBox(width: 180, height: 180,
            child: StatefulBuilder(builder: (context, set) {
              update = set;
              return Center(child: CombatFigure(
                rig: rig, height: 96, phase: phase, plan: plan,
                condition: Condition(health), showWounds: wounds,
              ));
            }),
          ),
        )),
      ));
      Future<void> settle() async {
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(tester.takeException(), isNull);
      }
      CombatRigSample shared() {
        final body = tester.widget<SpriteView>(find.byType(SpriteView));
        final tool = tester.widget<WeaponView>(find.byType(WeaponView));
        final hand = tester.widget<SpriteGripOverlay>(find.byType(SpriteGripOverlay));
        expect(body.articulation, isNotNull);
        expect(identical(body.articulation, tool.articulation), isTrue);
        expect(identical(body.articulation, hand.articulation), isTrue);
        _jointContract(body.articulation!.value);
        return body.articulation!.value;
      }
      await settle();
      final fresh = await _pixels(tester, key);
      shared();
      update(() => health = 0.2);
      await settle();
      final hurt = await _pixels(tester, key);
      expect(hurt, isNot(orderedEquals(fresh)), reason: 'fatigue with blood off');
      final stillWrist = shared().wrist;
      var paints = 0;
      debugOnProfilePaint = (o) { if (o is RenderCustomPaint) paints++; };
      await settle();
      debugOnProfilePaint = null;
      expect(paints, 0, reason: 'reduced idle does not repaint');
      _near(shared().wrist, stillWrist);
      expect(await _pixels(tester, key), orderedEquals(hurt));
      update(() => wounds = true);
      await tester.pump();
      expect(await _pixels(tester, key), isNot(orderedEquals(hurt)));
      update(() => wounds = false);
      await tester.pump();
      expect(await _pixels(tester, key), orderedEquals(hurt));
      for (final p in [WeaponPhase.raise, WeaponPhase.swing, WeaponPhase.guard]) {
        update(() => phase = p);
        await settle();
        final s = shared();
        expect(await _pixels(tester, key), isNot(orderedEquals(hurt)));
        expect((s.part(RigPart.torso).map(rig.wrist) - s.wrist).distance,
            greaterThan(0.1), reason: '$id $p not a whole-sprite transform');
      }
      expect(debugCombatRigCacheBytes, 22 * 11 * 32 * 40 * 4);
      expect(debugCombatRigCacheBytes, lessThan(1.25 * 1024 * 1024));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
