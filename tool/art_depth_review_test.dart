// Actual current UI review evidence, NOT a phone-performance/quality gate.
// flutter test tool/art_depth_review_test.dart --reporter expanded
//
// 360x640 logical, 25fps simulated-time samples; real fonts, warmed art,
// actual hit-tested controls. Does not alter combat source or timings.
// Four normal-health fights are followed by an explicitly forced injury
// fixture. Settings is exercised separately at 320px/1.3x in all locales.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/audio/settings.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/l10n/strings.dart';
import 'package:emberdelve/ui/blood_effects.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'build/art_depth_review';

Future<void> _fonts() async {
  for (final entry in {
    'Cinzel': 'assets/fonts/Cinzel-Variable.ttf',
    'Inter': 'assets/fonts/Inter-Regular.ttf',
    'MaterialIcons':
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(entry.key)..addFont(
          Future.value(
            ByteData.sublistView(File(entry.value).readAsBytesSync()),
          ),
        ))
        .load();
  }
}

Future<void> _pump(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);
  tearDown(() {
    BloodEffects.enabled.value = true;
    Motion.instance.update(setting: 'system', systemFlag: false);
    AudioService.instance = null;
  });

  for (final character in ['kindler', 'warden', 'gambler', 'runesmith']) {
    testWidgets('current combat review: $character', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Motion.instance.update(setting: 'off');
      BloodEffects.enabled.value = true;
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
      c.startRun(
        character: character,
        boons: true,
        seed: 1,
        difficulty: 'easy',
      );
      c.apply({'type': 'choose_boon', 'index': 0});
      c.apply({'type': 'choose_node', 'node': 2});
      await _pump(tester, 2600);
      expect(c.phase, 'player_turn');
      expect(c.sim!.enemy!['id'], 'flue_crawler');
      await tester.tap(_button('Roll'));
      await _pump(tester, 2600);
      final rolled = List<int>.from(c.sim!.player['rolled'] as List);
      final observations = <Map<String, Object?>>[];
      var frame = 0;
      Future<void> frames(int count, String label) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          final name = '$character/${frame.toString().padLeft(3, '0')}-$label';
          await _png(tester, key, name);
          // Hit-flash AnimatedSwitcher briefly retains incoming+outgoing
          // combatants. Capture both; never assume one widget during contact.
          final weapons = tester
              .widgetList<WeaponView>(find.byType(WeaponView))
              .toList();
          expect(weapons, isNotEmpty);
          final foe = tester
              .widgetList<SpriteView>(
                find.byWidgetPredicate(
                  (w) => w is SpriteView && w.spriteId == 'flue_crawler',
                ),
              )
              .first;
          observations.add({
            'frame': frame,
            'clip_ms': frame * 40,
            'label': label,
            'file': '$name.png',
            'player_hp': c.sim!.player['hp'],
            'enemy_hp': c.sim!.enemy!['hp'],
            'weapon_phases': weapons.map((w) => w.phase.name).toList(),
            'weapon_charges': weapons.map((w) => w.charge).toList(),
            'foe_wounds': foe.condition.wounds,
            'foe_hurt': foe.condition.hurt,
          });
          frame++;
        }
      }

      await frames(10, 'idle');
      // All four selected characters roll face 1 at index 1, face 5 at 0.
      expect(rolled[1], 1);
      expect(rolled[0], 5);
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
      File('$_out/$character/observations.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'character': character,
          'seed': 1,
          'difficulty': 'easy',
          'rolled': rolled,
          'natural_health': true,
          'frames': observations,
        }),
      );

      // This separate fixture shows injuries; it is NOT run-earned health.
      c.sim!.player['hp'] = (c.sim!.player['max_hp'] as int) ~/ 5;
      c.sim!.enemy!['hp'] = (c.sim!.enemy!['max_hp'] as int) ~/ 5;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await _pump(tester, 1200);
      await _png(tester, key, '$character-wounded-blood-on');
      BloodEffects.enabled.value = false;
      await tester.pump(); // same simulation, next frame
      await _png(tester, key, '$character-wounded-blood-off');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, 2200);
    });
  }

  testWidgets('entire delver roster native-size plate', (tester) async {
    tester.view.physicalSize = const Size(1120, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(warmSpriteSheets);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: Scaffold(
            body: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 1.12,
              children: [
                for (final id in charactersOrder)
                  Column(
                    children: [
                      SpriteView(id, height: 72, animate: false),
                      Text(characters[id]!.name, style: EmberText.label),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await _pump(tester, 400);
    await _png(tester, key, 'roster');
    expect(tester.takeException(), isNull);
  });

  for (final lang in ['en', 'fr', 'es', 'pt']) {
    testWidgets('blood setting actual-font $lang narrow plate', (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      AudioService.instance = AudioService(AudioSettings(sfxMuted: true));
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            locale: GameLanguage.localeFor(lang),
            supportedLocales: gameLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('blood-effects-toggle'));
      await tester.scrollUntilVisible(
        toggle,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible aligns the SWITCH, which is vertically centred
      // in a tall panel. Frame the entire panel so a viewport crop is not
      // mistaken for clipped helper text.
      final panel = find.ancestor(of: toggle, matching: find.byType(Panel));
      await Scrollable.ensureVisible(tester.element(panel), alignment: 0.25);
      await tester.pumpAndSettle();
      final helper = find.text(
        translated(
          'Off hides blood, ichor and wound marks. Damage and fatigue stay visible.',
          lang,
        ),
      );
      final body = tester.getRect(find.byType(ListView).first);
      final panelRect = tester.getRect(panel);
      final helperRect = tester.getRect(helper);
      expect(body.contains(panelRect.topLeft), isTrue);
      expect(body.contains(panelRect.bottomRight), isTrue);
      expect(panelRect.contains(helperRect.topLeft), isTrue);
      expect(panelRect.contains(helperRect.bottomRight), isTrue);
      File('$_out/settings-$lang-geometry.json').writeAsStringSync(
        jsonEncode({
          'logical_viewport': [320, 568],
          'text_scale': 1.3,
          'list_body': body.toString(),
          'panel': panelRect.toString(),
          'helper': helperRect.toString(),
          'helper_inside_panel_inside_viewport': true,
        }),
      );
      await _png(tester, key, 'settings-$lang-on');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await _png(tester, key, 'settings-$lang-off');
      expect(AudioService.instance!.settings.bloodEffects, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
