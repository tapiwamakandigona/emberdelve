import 'dart:ui' show Tristate;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(320, 568)]) {
    testWidgets('Codex readable navigation at $size and 1.3x text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Disposed explicitly at the end: the tester verifies handles before tearDowns run.
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEmberTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: CodexScreen(GameController()),
          ),
        ),
      );
      await tester.pump();
      final world = find.byKey(const ValueKey('codex-lane-world'));
      expect(tester.getSize(world).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(world).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      // The card list is lazy: on a 320x568 view at 1.3x the first sealed entry
      // sits below the initial build range, so scroll it into existence first.
      final sealed = find.text('Sealed — tap to unseal.');
      for (var i = 0; i < 30 && sealed.evaluate().isEmpty; i++) {
        // The first Scrollable is the horizontal lane-chip row; the list is the vertical one.
        await tester.drag(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
          const Offset(0, -120),
        );
        await tester.pump();
      }
      expect(sealed, findsWidgets);
      expect(
        tester.widget<Text>(sealed.first).style!.fontSize,
        greaterThanOrEqualTo(13),
      );
      final company = find.byKey(const ValueKey('codex-lane-company'));
      await tester.ensureVisible(company);
      await tester.tap(company);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.getSemantics(company).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        tester.getSemantics(world).flagsCollection.isSelected,
        Tristate.isFalse,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  test('Codex text treatments retain AA contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    expect(
      contrast(EmberColors.bg, EmberColors.ember),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(EmberColors.textDim, EmberColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(EmberColors.textPrimary, EmberColors.raised),
      greaterThanOrEqualTo(4.5),
    );
  });
}
