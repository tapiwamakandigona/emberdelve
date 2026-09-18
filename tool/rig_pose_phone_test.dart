// Particle-free, actual native combat sizes. Separate from whole-phone UI
// captures and not a physical-device performance or human-approval claim.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/combat_figure.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Cinzel': 'assets/fonts/Cinzel-Variable.ttf',
      'Inter': 'assets/fonts/Inter-Regular.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(
            Future.value(
              ByteData.sublistView(File(font.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
  });
  tearDown(() => Motion.instance.update(setting: 'system', systemFlag: false));
  for (final spec in [
    (const Size(320, 568), 72.0),
    (const Size(412, 892), 104.0),
  ]) {
    testWidgets('particle-free native pose ${spec.$1.width.toInt()}', (
      tester,
    ) async {
      tester.view.physicalSize = spec.$1 * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(warmSpriteSheets);
      Motion.instance.update(setting: 'on');
      final key = GlobalKey();
      var phase = WeaponPhase.idle;
      var vitality = 1.0;
      var recoil = false;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: Scaffold(
              body: SafeArea(
                child: StatefulBuilder(
                  builder: (context, set) {
                    update = set;
                    return Column(
                      children: [
                        const SizedBox(height: 24),
                        const Text('EMBERDELVE', style: EmberText.h2),
                        Text(
                          'NATIVE ${spec.$2.toInt()}px / NO HIT EFFECTS',
                          style: EmberText.micro,
                        ),
                        for (final rig in [CombatRig.kindler, CombatRig.warden])
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  rig.id.toUpperCase(),
                                  style: EmberText.label,
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    for (final tier in [
                                      DieTier.low,
                                      DieTier.high,
                                    ])
                                      Column(
                                        children: [
                                          CombatFigure(
                                            rig: rig,
                                            height: spec.$2,
                                            phase: phase,
                                            plan: planStrike(
                                              rig.id == 'warden'
                                                  ? StrikeFamily.crush
                                                  : StrikeFamily.cut,
                                              tier,
                                            ),
                                            condition: Condition(vitality),
                                            showWounds: false,
                                            knock: recoil,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            '${tier.name.toUpperCase()} / '
                                            '${recoil ? 'RECOIL' : phase.name.toUpperCase()}',
                                            style: EmberText.micro,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        Text(
                          vitality == 1
                              ? 'HEALTHY'
                              : 'FORCED 20% HP / BLOOD OFF',
                          style: EmberText.micro,
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> capture(String label) async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(tester.takeException(), isNull);
        final bodies = tester.widgetList<CombatFigure>(
          find.byType(CombatFigure),
        );
        expect(bodies.length, 4);
        expect(bodies.every((b) => b.height == spec.$2), isTrue);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          File('build/visual_sep17/native-${spec.$1.width.toInt()}-$label.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('ready');
      for (final next in [
        WeaponPhase.raise,
        WeaponPhase.swing,
        WeaponPhase.guard,
      ]) {
        update(() => phase = next);
        await capture(next.name);
      }
      update(() {
        phase = WeaponPhase.idle;
        recoil = true;
      });
      await capture('recoil');
      update(() {
        recoil = false;
        vitality = 0.2;
      });
      await capture('fatigue');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
