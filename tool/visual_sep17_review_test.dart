// Actual-render evidence, not a device-FPS or human-art-approval gate.
// Before clips: #104 using unchanged tool/art_depth_review_test.dart.
// This probe: final source, three phone widths and deterministic fixtures.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/blood_effects.dart';
import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/combat_figure.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'build/visual_sep17';

Future<void> _fonts() async {
  for (final font in {
    'Cinzel': 'assets/fonts/Cinzel-Variable.ttf',
    'Inter': 'assets/fonts/Inter-Regular.ttf',
    'MaterialIcons':
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(font.key)..addFont(
          Future.value(
            ByteData.sublistView(File(font.value).readAsBytesSync()),
          ),
        ))
        .load();
  }
}

Future<void> _pump(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(Duration(milliseconds: (ms - t).clamp(0, 20)));
  }
}

Future<void> _png(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is EmberButton && w.label == label && w.onTap != null,
);
Finder _dice() =>
    find.byWidgetPredicate((w) => w is DieChip && w.value != null);

Map<String, Object?> _observe(
  WidgetTester tester,
  String id,
  GameController c,
) {
  final sprite = tester
      .widgetList<SpriteView>(
        find.byWidgetPredicate((w) => w is SpriteView && w.spriteId == id),
      )
      .last;
  final weapon = tester.widgetList<WeaponView>(find.byType(WeaponView)).last;
  expect(identical(sprite.articulation, weapon.articulation), isTrue);
  final sample = sprite.articulation!.value;
  final painted =
      sample.part(RigPart.hand).map(sample.rig.wrist) * (sprite.height / 40);
  final held = sample.weaponGrip(sprite.height);
  final error = (painted - held).distance;
  expect(error, lessThan(1e-7));
  final bars = tester.widgetList<StatBar>(find.byType(StatBar)).toList();
  return {
    'player_hp_sim': c.sim!.player['hp'],
    'enemy_hp_sim': c.sim!.enemy?['hp'],
    'display_bars': [
      for (final b in bars) {'value': b.value, 'max': b.max, 'block': b.block},
    ],
    'phase': weapon.phase.name,
    'native_wrist': [sample.wrist.dx, sample.wrist.dy],
    'native_elbow': [sample.elbow.dx, sample.elbow.dy],
    'weapon_angle': sample.weaponAngle,
    'source_pixel_grip_error_logical': error,
    'sprite_height': sprite.height,
    'blood': BloodEffects.enabled.value,
    'reduced': Motion.instance.reduced,
  };
}

void _layout(WidgetTester tester) {
  final viewport =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  for (final finder in [
    find.byType(StatBar),
    _dice(),
    _button('Attack'),
    _button('Block'),
  ]) {
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(
        find.byElementPredicate((e) => identical(e, element)),
      );
      expect(rect.left, greaterThanOrEqualTo(viewport.left - 0.1));
      expect(rect.right, lessThanOrEqualTo(viewport.right + 0.1));
      expect(rect.top, greaterThanOrEqualTo(viewport.top - 0.1));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.1));
    }
  }
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);
  tearDown(() {
    BloodEffects.enabled.value = true;
    Motion.instance.update(setting: 'system', systemFlag: false);
  });
  for (final id in ['kindler', 'warden']) {
    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(412, 892),
    ]) {
      testWidgets('phone render $id ${size.width.toInt()}', (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        Motion.instance.update(setting: 'off');
        final c = GameController();
        c.meta
          ..tutorialSeen = true
          ..tourSeenVersion = tourVersion
          ..tipsSeen.addAll(ContextTips.all);
        c.tipDirector = TipDirector(c.meta.tipsSeen);
        c.tour = TourDirector(seenVersion: tourVersion);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildEmberTheme(),
              home: GameRoot(c),
            ),
          ),
        );
        await tester.runAsync(() async {
          await warmSpriteSheets();
          final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
          final context = tester.element(find.byType(MaterialApp));
          for (final asset in manifest.listAssets().where(
            (a) => a.endsWith('.png'),
          )) {
            await precacheImage(AssetImage(asset), context);
          }
        });
        c.startRun(character: id, boons: true, seed: 1, difficulty: 'easy');
        c.apply({'type': 'choose_boon', 'index': 0});
        c.apply({'type': 'choose_node', 'node': 2});
        await _pump(tester, 2600);
        expect(c.sim!.enemy!['id'], 'flue_crawler');
        await tester.tap(_button('Roll'));
        await _pump(tester, 2600);
        final roll = List<int>.from(c.sim!.player['rolled'] as List);
        expect(roll[0], 5);
        expect(roll[1], 1);
        final dir = '$id-${size.width.toInt()}';
        final observations = <Map<String, Object?>>[];
        var frame = 0;
        Future<void> frames(int count, String label) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 40));
            final observation = _observe(tester, id, c);
            final name = '$dir/${frame.toString().padLeft(3, '0')}-$label';
            _layout(tester);
            observations.add({
              'frame': frame,
              'ms': frame * 40,
              'label': label,
              'file': '$name.png',
              ...observation,
            });
            // Keep every frame of 360px clips; representative frames for
            // narrow/wide plates still have all state/geometry samples.
            if (size.width == 360 ||
                i == 0 ||
                i == 3 ||
                i == 7 ||
                i == count - 1) {
              await _png(tester, key, name);
            }
            frame++;
          }
        }

        await frames(10, 'idle');
        await tester.tap(_dice().at(1));
        await frames(10, 'selected-low');
        await tester.tap(_button('Attack'));
        await frames(30, 'low-attack');
        await tester.tap(_dice().at(0));
        await frames(10, 'selected-high');
        await tester.tap(_button('Attack'));
        await frames(30, 'high-attack');
        await tester.tap(_dice().at(2));
        await tester.pump();
        await tester.tap(_button('Block'));
        await frames(15, 'guard');
        await tester.tap(_button('End turn'));
        await frames(70, 'enemy-turn');
        expect(c.phase, 'player_turn');

        // Explicitly forced fixtures, separate from naturally earned clips.
        c.sim!.player['hp'] = (c.sim!.player['max_hp'] as int) ~/ 5;
        c.sim!.enemy!['hp'] = (c.sim!.enemy!['max_hp'] as int) ~/ 5;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        c.notifyListeners();
        await _pump(tester, 800);
        await _png(tester, key, '$dir-forced-wounded-blood-on');
        BloodEffects.enabled.value = false;
        await tester.pump();
        await _png(tester, key, '$dir-forced-wounded-blood-off');
        Motion.instance.update(setting: 'on');
        await _pump(tester, 400);
        await _png(tester, key, '$dir-forced-wounded-reduced');
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, 400);
        _layout(tester);
        await _png(tester, key, '$dir-text-1.3');
        tester.platformDispatcher.clearTextScaleFactorTestValue();

        // Full/partial block: fixture controls only, real end-turn UI.
        for (final block in [2, 20]) {
          c.sim!.player['hp'] = c.sim!.player['max_hp'];
          c.sim!.enemy!['hp'] = c.sim!.enemy!['max_hp'];
          c.sim!.enemy!['intent'] = {'kind': 'attack', 'amount': 7};
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          c.notifyListeners();
          await tester.tap(_button('Roll'));
          await _pump(tester, 2600);
          c.sim!.player['block'] = block;
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          c.notifyListeners();
          await _pump(tester, 240);
          await tester.tap(_button('End turn'));
          await _pump(tester, 200);
          _observe(tester, id, c);
          _layout(tester);
          await _png(tester, key, '$dir-forced-guard-$block-before');
          await _pump(tester, 280);
          _observe(tester, id, c);
          _layout(tester);
          await _png(tester, key, '$dir-forced-guard-$block-contact');
          await _pump(tester, 3500);
          expect(c.phase, 'player_turn');
        }
        File('$_out/$dir/observations.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'character': id,
            'seed': 1,
            'difficulty': 'easy',
            'viewport': [size.width, size.height],
            'roll': roll,
            'interval_ms': 40,
            'frames': observations,
            'fixtures':
                'wounds 20% HP; guard 2/20 versus attack 7; forced not run-earned',
            'device_fps': 'NOT MEASURED',
          }),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, 2200);
      });
    }
  }

  testWidgets('redesigned native portraits and independent joint pose plate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1120);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(warmSpriteSheets);
    Motion.instance.update(setting: 'on');
    final key = GlobalKey();
    var phase = WeaponPhase.idle;
    late StateSetter update;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text('EMBERDELVE / FORGE & ASH', style: EmberText.h2),
                    const SizedBox(height: 16),
                    for (final rig in [CombatRig.kindler, CombatRig.warden])
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SpriteView(rig.id, height: 120, animate: false),
                                Text(
                                  '${rig.id.toUpperCase()} / SOURCE',
                                  style: EmberText.micro,
                                ),
                              ],
                            ),
                            for (final tier in [DieTier.low, DieTier.high])
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CombatFigure(
                                    rig: rig,
                                    height: 144,
                                    phase: phase,
                                    plan: planStrike(
                                      rig.id == 'warden'
                                          ? StrikeFamily.crush
                                          : StrikeFamily.cut,
                                      tier,
                                    ),
                                    condition: Condition.fresh,
                                    showWounds: false,
                                  ),
                                  Text(
                                    '${tier.name.toUpperCase()} / ${phase.name.toUpperCase()}',
                                    style: EmberText.micro,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await _pump(tester, 400);
    await _png(tester, key, 'characters-ready');
    for (final next in [
      WeaponPhase.raise,
      WeaponPhase.swing,
      WeaponPhase.guard,
      WeaponPhase.idle,
    ]) {
      update(() => phase = next);
      await _pump(tester, 380);
      await _png(tester, key, 'characters-${next.name}');
    }
    expect(tester.takeException(), isNull);
  });
}
