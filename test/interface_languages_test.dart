import 'dart:io';

import 'package:emberdelve/audio/settings.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/l10n/catalog.dart';
import 'package:emberdelve/l10n/strings.dart';
import 'package:emberdelve/meta/keeper.dart';
import 'package:emberdelve/ui/keeper.dart';
import 'package:emberdelve/ui/language_picker.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _fonts() async {
  for (final entry in {
    'Cinzel': 'Cinzel-Variable.ttf',
    'Inter': 'Inter-Regular.ttf',
  }.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/${entry.value}').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
  }
}

Widget _app(String lang, Widget home) => MaterialApp(
  locale: GameLanguage.localeFor(lang),
  supportedLocales: gameLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildEmberTheme(),
  home: home,
);

Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(_fonts);
  tearDown(() {
    GameLanguage.choice.value = 'system';
    KeeperService.instance?.dispose();
    KeeperService.instance = null;
  });

  test(
    'catalog keys/placeholders match; unknown strings and names are safe',
    () {
      final keys = interfaceCatalog['fr']!.keys.toSet();
      expect(keys.length, greaterThanOrEqualTo(90));
      for (final lang in ['fr', 'es', 'pt']) {
        expect(interfaceCatalog[lang]!.keys.toSet(), keys);
        for (final entry in interfaceCatalog[lang]!.entries) {
          Set<String> fields(String s) =>
              RegExp(r'\{[a-zA-Z]+\}').allMatches(s).map((m) => m[0]!).toSet();
          expect(fields(entry.value), fields(entry.key));
        }
        expect(translated('Untouched lore', lang), 'Untouched lore');
        expect(
          translated(
            'The flame burns brighter thanks to {name}.',
            lang,
            args: {'name': 'Łukasz 🔥 {name}'},
          ),
          contains('Łukasz 🔥 {name}'),
        );
      }
      expect(translated('Roll', 'ar'), 'Roll');
      expect(translated('Roll', 'en'), 'Roll');
    },
  );

  test(
    'old/corrupt preferences default to device; every manual locale persists',
    () {
      for (final value in [
        null,
        '',
        'xx',
        42,
        ['fr'],
      ]) {
        expect(AudioSettings.fromJson({'language': value}).language, 'system');
        expect(GameLanguage.validChoice(value), 'system');
      }
      for (final code in languageChoices.keys) {
        final settings = AudioSettings(language: code);
        expect(AudioSettings.fromJson(settings.toJson()).language, code);
      }
    },
  );

  testWidgets(
    'device French-Canada resolves French; unknown locale falls back',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'CA')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        _app('system', Scaffold(body: EmberButton('Roll', onTap: () {}))),
      );
      await _pump(tester);
      expect(find.text('Lancer'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = const [Locale('zz')];
      await _pump(tester);
      expect(find.text('Roll'), findsOneWidget);
    },
  );

  for (final lang in ['fr', 'es', 'pt']) {
    testWidgets('$lang title and core actions fit 320px at 1.3x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = GameController();
      c.meta
        ..tourSeenVersion = tourVersion
        ..tutorialSeen = true
        ..tipsSeen.addAll(ContextTips.all)
        ..lastSeenNewsVersion = currentAppVersion;
      await tester.pumpWidget(_app(lang, GameRoot(c)));
      await _pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(translated('Delve', lang)), findsOneWidget);
      expect(find.text(translated('Choose a delver', lang)), findsOneWidget);
      await tester.pumpWidget(
        _app(
          lang,
          Scaffold(
            body: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: EmberButton('Attack', dense: true, onTap: () {}),
                    ),
                    Expanded(
                      child: EmberButton('Block', dense: true, onTap: () {}),
                    ),
                  ],
                ),
                EmberButton('End turn', onTap: () {}),
              ],
            ),
          ),
        ),
      );
      await _pump(tester);
      expect(find.text(translated('Attack', lang)), findsOneWidget);
      expect(find.text(translated('End turn', lang)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('$lang five-page manual is translated and scroll-safe', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_app(lang, const PrimerScreen()));
      await _pump(tester);
      const headings = [
        "WHAT'S A DELVE?",
        'THE DARK FIGHTS FAIR',
        'ROLL, THEN SPEND',
        'MATCHING FACES PAY',
        'BLOCK FADES FAST',
      ];
      for (var i = 0; i < headings.length; i++) {
        expect(find.text(translated(headings[i], lang)), findsOneWidget);
        expect(find.text(headings[i]), findsNothing);
        expect(tester.takeException(), isNull);
        if (i < headings.length - 1) {
          final next = find.text(translated('Next', lang));
          await tester.ensureVisible(next);
          await _pump(tester);
          await tester.tap(next);
          await _pump(tester);
        }
      }
    });

    testWidgets(
      '$lang Keeper privacy/editor preserves personal name at 320px',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final service = KeeperService(
          alreadyOwned: () => true,
          loadData: () async => {},
          saveData: (_) async {},
        );
        KeeperService.instance = service;
        await service.load();
        await tester.pumpWidget(
          _app(
            lang,
            const Scaffold(body: SingleChildScrollView(child: KeeperTitle())),
          ),
        );
        await _pump(tester);
        await tester.tap(find.byKey(const ValueKey('keeper-personalise')));
        await _pump(tester);
        expect(
          find.text(translated('Keepers of the Flame', lang)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const ValueKey('keeper-name')));
        await tester.enterText(
          find.byKey(const ValueKey('keeper-name')),
          'Chipo 🌻',
        );
        await tester.tap(find.byKey(const ValueKey('keeper-save')));
        await _pump(tester);
        expect(service.profile.name, 'Chipo 🌻');
        expect(find.textContaining('Chipo 🌻'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('manual selector changes locale, labels and coverage notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      ValueListenableBuilder<String>(
        valueListenable: GameLanguage.choice,
        builder: (context, code, _) => _app(
          code,
          Scaffold(
            body: SingleChildScrollView(
              child: LanguagePicker(
                onChanged: (value) => GameLanguage.choice.value = value,
              ),
            ),
          ),
        ),
      ),
    );
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('game-language')));
    await _pump(tester);
    await tester.tap(find.text('Français').last);
    await _pump(tester);
    expect(GameLanguage.choice.value, 'fr');
    expect(find.text('Langue'), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-coverage')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
