import 'package:emberdelve/l10n/strings.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'compact language action opens, translates and dismisses safely',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => GameLanguage.choice.value = 'system');
      await tester.pumpWidget(
        ValueListenableBuilder<String>(
          valueListenable: GameLanguage.choice,
          builder: (context, code, _) => MaterialApp(
            locale: GameLanguage.localeFor(code),
            supportedLocales: gameLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: buildEmberTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-picker')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-language-picker')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('translation-coverage')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('game-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();
      expect(find.text('Langue'), findsOneWidget);
      expect(GameLanguage.choice.value, 'fr');
      expect(tester.takeException(), isNull);
      final context = tester.element(
        find.byKey(const ValueKey('game-language')),
      );
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-picker')), findsNothing);
      expect(find.text('Paramètres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
