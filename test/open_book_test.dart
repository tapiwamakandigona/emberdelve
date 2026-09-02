// test/open_book_test.dart — v0.180.0 The Open Book.
//
// The how-to-play deck existed since v0.3.10, but its only door was a small
// "?" inside a fight; every tester who left words asked for a manual. The
// title's top row now carries a '?' (the fight's own glyph) that opens the
// same deck, centered, before the first delve — costing the fold nothing. Pins: the link renders on a fresh
// profile; tapping it shows card 1 ('WHAT'S A DELVE?'); Next walks every card
// and returns to the title; Skip returns at once; reading it changes no
// saved state (tutorialSeen stays false, tour stays unseen).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<GameController> pumpTitle(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 2;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final c = GameController();
  c.meta.lastSeenNewsVersion = currentAppVersion;
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
  );
  await pumpFor(tester, 400);
  return c;
}

Future<void> open(WidgetTester tester) async {
  final link = find.byKey(const ValueKey('how-to-play'));
  await tester.ensureVisible(link);
  await tester.pump();
  await tester.tap(link);
  await pumpFor(tester, 600);
}

void main() {
  testWidgets('a fresh title carries the link and it opens card one', (
    tester,
  ) async {
    final c = await pumpTitle(tester);
    expect(find.byKey(const ValueKey('how-to-play')), findsOneWidget);
    await open(tester);
    expect(find.byType(PrimerScreen), findsOneWidget);
    expect(find.text('WHAT\'S A DELVE?'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(c.meta.tutorialSeen, isFalse);
  });

  testWidgets('Next walks every card and Got it returns to the title', (
    tester,
  ) async {
    final c = await pumpTitle(tester);
    await open(tester);
    var guard = 0;
    while (find.text('Next').evaluate().isNotEmpty && guard++ < 12) {
      await tester.tap(find.text('Next'));
      await pumpFor(tester, 200);
    }
    expect(find.text('Got it'), findsOneWidget);
    expect(guard, greaterThanOrEqualTo(2), reason: 'more than two cards');
    await tester.tap(find.text('Got it'));
    await pumpFor(tester, 600);
    expect(find.byType(PrimerScreen), findsNothing);
    expect(find.byKey(const ValueKey('how-to-play')), findsOneWidget);
    // Reading the manual is not the tutorial, and not the tour.
    expect(c.meta.tutorialSeen, isFalse);
    expect(c.meta.tourSeenVersion, 0);
  });

  testWidgets('Skip returns at once', (tester) async {
    await pumpTitle(tester);
    await open(tester);
    await tester.tap(find.text('Skip'));
    await pumpFor(tester, 600);
    expect(find.byType(PrimerScreen), findsNothing);
  });

  testWidgets('card two names the charge and counter the data carries', (
    tester,
  ) async {
    // The Read Page: the primer must not promise "always attack, block or
    // both" while enemies.dart declares charge and counter intents.
    final kinds = {
      for (final e in enemies.values)
        for (final i in e.pattern) i.kind,
    };
    expect(kinds, containsAll(['charge', 'counter']));
    await pumpTitle(tester);
    await open(tester);
    await tester.tap(find.text('Next'));
    await pumpFor(tester, 200);
    expect(find.text('THE DARK FIGHTS FAIR'), findsOneWidget);
    expect(find.textContaining('wind up a charge'), findsOneWidget);
    expect(find.textContaining('set a counter'), findsOneWidget);
  });
}
