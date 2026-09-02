// test/named_lock_test.dart — v0.180.0 "The Named Lock" (R5 stage D).
//
// Pins: a profile without the Forge sees one dim line under the difficulty
// segments naming what the HARD lock holds; a Forge owner never does; the
// line is copy only (no button, no sheet opened by it).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void quietTitle(GameController c) {
  c.meta
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
}

void main() {
  testWidgets('locked HARD is named on the title; the Forge removes the line', (
    tester,
  ) async {
    final c = GameController();
    quietTitle(c);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    final hint = find.byKey(const ValueKey('forge-hint'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('difficulty-hard')),
      120,
    );
    await pumpFor(tester, 200);
    expect(hint, findsOneWidget);
    expect(
      find.text('The Ember Forge opens HARD and Ascension.'),
      findsOneWidget,
    );
    // Copy, not a control: tapping the line opens nothing.
    await tester.tap(hint);
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('forge-hint')), findsOneWidget);

    // A Forge owner never sees it.
    c.meta.forgeUnlocked = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    c.notifyListeners();
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('forge-hint')), findsNothing);
    await pumpFor(tester, 800); // drain animations before teardown
  });
}
