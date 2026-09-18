// Blood-off is presentation only. Original combat, motion and settings
// regressions remain unchanged; these tests cover the added preference.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/audio/settings.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/l10n/strings.dart';
import 'package:emberdelve/ui/blood_effects.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/gore.dart';
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

const _toggle = ValueKey('blood-effects-toggle');
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is EmberButton && w.label == label && w.onTap != null,
);
Finder _dice() =>
    find.byWidgetPredicate((w) => w is DieChip && w.value != null);
Finder _stains() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is FloorStainsPainter,
);

Future<void> _pump(WidgetTester tester, int ms) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<GameController> _fight(WidgetTester tester) async {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.tipDirector = TipDirector(c.meta.tipsSeen);
  c.tour = TourDirector(seenVersion: tourVersion);
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
  );
  await tester.runAsync(warmSpriteSheets);
  c.startRun(character: 'kindler', boons: true, seed: 1, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  await _pump(tester, 2600);
  expect(c.sim!.enemy!['id'], 'flue_crawler');
  await tester.tap(_button('Roll'));
  await _pump(tester, 2600);
  expect(c.sim!.player['rolled'], [5, 1, 3]);
  return c;
}

Future<void> _attack(WidgetTester tester, int index) async {
  await tester.tap(_dice().at(index));
  await tester.pump();
  await tester.tap(_button('Attack'));
}

void _notify(GameController c) {
  // Fixture damage only; the production renderer must observe both bodies.
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
}

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = Uint8List.fromList(data!.buffer.asUint8List());
    image.dispose();
    return result;
  }))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    BloodEffects.enabled.value = true;
    Motion.instance.update(setting: 'off');
  });
  tearDown(() {
    BloodEffects.enabled.value = true;
    Motion.instance.reset();
    AudioService.instance = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, null);
  });

  test('old settings preserve blood on; invalid values cannot break load', () {
    expect(AudioSettings().bloodEffects, isTrue);
    for (final value in [null, '', 'false', 0, 1, [], {}]) {
      final loaded = AudioSettings.fromJson({
        'bloodEffects': value,
        'musicVolume': 0.35,
        'language': 'fr',
      });
      expect(loaded.bloodEffects, isTrue, reason: '$value');
      expect(loaded.musicVolume, 0.35);
      expect(loaded.language, 'fr');
    }
  });

  test('both blood choices round-trip without losing other preferences', () {
    for (final enabled in [true, false]) {
      final settings = AudioSettings(
        bloodEffects: enabled,
        musicVolume: 0.25,
        sfxMuted: true,
        haptics: false,
        reduceMotion: 'on',
        language: 'es',
      );
      final loaded = AudioSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
      expect(loaded.toJson(), settings.toJson());
    }
  });

  test(
    'the real settings file persists off and a subsequent on across loads',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'ember-blood-settings-',
      );
      addTearDown(() => dir.delete(recursive: true));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathChannel, (call) async {
            expect(call.method, 'getApplicationSupportDirectory');
            return dir.path;
          });
      final settings = AudioSettings(bloodEffects: false, language: 'pt');
      await SettingsStore.save(settings);
      final loaded = await SettingsStore.load();
      expect(loaded.bloodEffects, isFalse);
      expect(loaded.language, 'pt');
      // A separate load has no access to the in-memory settings object.
      expect(identical(loaded, settings), isFalse);
      loaded.bloodEffects = true;
      await SettingsStore.save(loaded);
      expect((await SettingsStore.load()).bloodEffects, isTrue);
      expect(
        File('${dir.path}/emberdelve_settings.json.tmp').existsSync(),
        isFalse,
      );
    },
  );

  test('preference listeners only fire on a real value change', () {
    var calls = 0;
    void listener() => calls++;
    BloodEffects.enabled.addListener(listener);
    addTearDown(() => BloodEffects.enabled.removeListener(listener));
    BloodEffects.enabled.value = true;
    expect(calls, 0);
    BloodEffects.enabled.value = false;
    BloodEffects.enabled.value = false;
    expect(calls, 1);
    BloodEffects.enabled.value = true;
    expect(calls, 2);
  });

  for (final lang in ['en', 'fr', 'es', 'pt']) {
    testWidgets(
      '$lang blood setting fits 320px/1.3x and has toggle semantics',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        try {
          final settings = AudioSettings(sfxMuted: true);
          AudioService.instance = AudioService(settings);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildEmberTheme(),
              locale: GameLanguage.localeFor(lang),
              supportedLocales: gameLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const SettingsScreen(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(_toggle),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final label = translated('Blood effects', lang);
          final node = tester.getSemantics(find.byKey(_toggle));
          expect(
            node,
            matchesSemantics(
              label: label,
              hasEnabledState: true,
              isEnabled: true,
              hasToggledState: true,
              isToggled: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
          expect(
            tester.getSize(find.byKey(_toggle)).height,
            greaterThanOrEqualTo(48),
          );
          await tester.tap(find.byKey(_toggle));
          await tester.pumpAndSettle();
          expect(settings.bloodEffects, isFalse);
          expect(BloodEffects.enabled.value, isFalse);
          expect(
            tester.getSemantics(find.byKey(_toggle)).flagsCollection.isToggled,
            ui.Tristate.isFalse,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(_toggle));
          await tester.pumpAndSettle();
          expect(settings.bloodEffects, isTrue);
          expect(BloodEffects.enabled.value, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          // Flutter verifies this handle before addTearDown callbacks run.
          semantics.dispose();
        }
      },
    );
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'blood off preserves damage and hit feedback (reduced=$reduced)',
      (tester) async {
        BloodEffects.enabled.value = false;
        final c = await _fight(tester);
        Motion.instance.update(setting: reduced ? 'on' : 'off');
        final hp = c.sim!.enemy!['hp'] as int;
        await _attack(tester, 0);
        var contactSeen = false;
        var numberSeen = false;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(find.byType(BloodBurst), findsNothing);
          expect(_stains(), findsNothing);
          contactSeen |= find.byType(ImpactSlash).evaluate().isNotEmpty;
          numberSeen |= find.byType(DamagePop).evaluate().isNotEmpty;
        }
        expect(contactSeen, isTrue);
        expect(numberSeen, isTrue);
        expect(c.sim!.enemy!['hp'], hp - 5);
        // The low die still blocks and changes the weapon's guard phase.
        await tester.tap(_dice().at(1));
        await tester.pump();
        await tester.tap(_button('Block'));
        await _pump(tester, 200);
        expect(c.sim!.player['block'], 1);
        expect(
          tester.widget<WeaponView>(find.byType(WeaponView)).phase,
          WeaponPhase.guard,
        );
        expect(find.byType(GuardFlash), findsOneWidget);
        await _pump(tester, 2200);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'off removes active bursts immediately and they cannot stain later',
    (tester) async {
      await _fight(tester);
      await _attack(tester, 0);
      await _pump(tester, 400);
      expect(find.byType(BloodBurst), findsOneWidget);
      BloodEffects.enabled.value = false;
      await tester.pump();
      expect(find.byType(BloodBurst), findsNothing);
      expect(_stains(), findsNothing);
      // Even a quick re-enable cannot revive an old burst's callback.
      BloodEffects.enabled.value = true;
      await _pump(tester, 1600);
      expect(_stains(), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('off clears old floor stains; on only stains from future hits', (
    tester,
  ) async {
    await _fight(tester);
    await _attack(tester, 0);
    await _pump(tester, 1600);
    expect(_stains(), findsOneWidget);
    BloodEffects.enabled.value = false;
    await tester.pump();
    expect(_stains(), findsNothing);
    BloodEffects.enabled.value = true;
    await tester.pump();
    expect(_stains(), findsNothing);
    await _attack(tester, 2);
    await _pump(tester, 400);
    expect(find.byType(BloodBurst), findsOneWidget);
    await _pump(tester, 1600);
    expect(_stains(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'both wounded bodies keep fatigue and pallor while blood is off',
    (tester) async {
      final c = await _fight(tester);
      c.sim!.player['hp'] = 6;
      c.sim!.enemy!['hp'] = 4;
      _notify(c);
      await _pump(tester, 300);
      final before = jsonEncode(c.state);
      final pallorCount = find.byType(ColorFiltered).evaluate().length;
      BloodEffects.enabled.value = false;
      await tester.pump();
      for (final id in ['kindler', 'flue_crawler']) {
        final sprites = tester.widgetList<SpriteView>(
          find.byWidgetPredicate((w) => w is SpriteView && w.spriteId == id),
        );
        expect(sprites, isNotEmpty);
        for (final sprite in sprites) {
          expect(sprite.showWounds, isFalse, reason: id);
          expect(sprite.condition.wounds, greaterThan(0), reason: id);
          expect(sprite.condition.slump, greaterThan(0), reason: id);
          expect(sprite.condition.pallor, greaterThan(0), reason: id);
          expect(sprite.condition.breathAmp, greaterThan(1), reason: id);
        }
      }
      expect(find.byType(ColorFiltered).evaluate().length, pallorCount);
      expect(jsonEncode(c.state), before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final ichor in Ichor.values) {
    testWidgets(
      '$ichor hidden wound pixels equal a clean sprite; on restores them',
      (tester) async {
        await tester.runAsync(warmSpriteSheets);
        final key = GlobalKey();
        Future<Uint8List> render(Condition condition, bool showWounds) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SpriteView(
                    'kindler',
                    height: 96,
                    animate: false,
                    condition: condition,
                    showWounds: showWounds,
                    ichor: ichor,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          return _pixels(tester, key);
        }

        final clean = await render(Condition.fresh, true);
        final hidden = await render(const Condition(0.1), false);
        final bloody = await render(const Condition(0.1), true);
        expect(hidden, orderedEquals(clean));
        expect(bloody, isNot(orderedEquals(clean)));
        expect(await render(const Condition(0.1), false), orderedEquals(clean));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'enemy landed hit remains bloodless; simulator result is unchanged',
    (tester) async {
      BloodEffects.enabled.value = false;
      final c = await _fight(tester);
      final hp = c.sim!.player['hp'] as int;
      await tester.tap(_button('End turn'));
      var sawNumber = false;
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.byType(BloodBurst), findsNothing);
        expect(_stains(), findsNothing);
        sawNumber |= find.byType(DamagePop).evaluate().isNotEmpty;
      }
      expect(sawNumber, isTrue);
      expect(c.sim!.player['hp'], lessThan(hp));
      expect(c.phase, 'player_turn');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
