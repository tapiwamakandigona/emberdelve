// test/shorter_title_test.dart — v0.180.0 "The Shorter Title".
//
// The title is the game's one decision screen, and the scroll doctrine says
// decision screens fit. Measured with the shipped fonts (Ahem would wrap
// differently): a returning profile's title has NO scroll at 412×915 and at
// most ~130 logical px at 360×800 (was 251). Regressions here are the whole
// point of the pin — every added line on the title costs a phone a scroll.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
}

Future<double> titleScrollExtent(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final c = GameController();
  c.meta
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion
    ..runsPlayed = 3
    ..difficultyChosen = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEmberTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: GameRoot(c),
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final s = tester.state<ScrollableState>(find.byType(Scrollable).first);
  return s.position.maxScrollExtent;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('412×915: the whole title fits without scrolling', (
    tester,
  ) async {
    expect(await titleScrollExtent(tester, const Size(412, 915)), 0);
  });

  testWidgets('360×800: at most ~130 logical px of scroll', (tester) async {
    expect(
      await titleScrollExtent(tester, const Size(360, 800)),
      lessThanOrEqualTo(130),
    );
  });

  testWidgets('the footer links share one row and keep their keys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.meta
      ..tourSeenVersion = tourVersion
      ..tutorialSeen = true
      ..tipsSeen.addAll(ContextTips.all)
      ..lastSeenNewsVersion = currentAppVersion;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final provings = find.byKey(const ValueKey('provings-button'));
    final seed = find.byKey(const ValueKey('seeded-delve'));
    await tester.scrollUntilVisible(seed, 200);
    await tester.pump(const Duration(milliseconds: 100));
    expect(provings, findsOneWidget);
    expect(seed, findsOneWidget);
    expect(
      (tester.getCenter(provings).dy - tester.getCenter(seed).dy).abs(),
      lessThan(1),
      reason: 'same row',
    );
    expect(find.textContaining('Weekly — '), findsOneWidget);
  });
}
