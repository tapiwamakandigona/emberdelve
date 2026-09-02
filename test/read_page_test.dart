// test/read_page_test.dart — v0.180.0 The Read Page.
//
// The in-fight how-to-play deck leaned its first card down 120 px and its
// second card up 210 px with fixed padding. Measured: card one overflowed by
// 241 px at 320×568 and 73 px at 360×640; card two by 123 px at 360×800.
// The lean is now flex spacers that yield when the card needs the room.
// This opens the deck from the fight's own "?" at the three sizes and walks
// every card with no layout exception. Real fonts: the test font's square
// glyphs run the body twice as long and would fail even a correct layout.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<bool> walkToFight(WidgetTester tester, GameController c) async {
  c.startRun(character: 'kindler', seed: 1);
  await pumpFor(tester, 700);
  final map = c.state!['map'] as Map;
  final edges = (map['edges'] as Map).cast<String, List>();
  var guard = 0;
  while (c.phase == 'map' && guard++ < 10) {
    final position = (c.state!['map'] as Map)['position'] as int;
    final next = (edges['$position'] as List).cast<int>().first;
    c.apply({'type': 'choose_node', 'node': next});
    await pumpFor(tester, 700);
    if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
    if (c.phase == 'rest') c.apply({'type': 'rest'});
    if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
    if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
    await pumpFor(tester, 700);
  }
  return c.phase == 'player_turn';
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(320, 568), Size(360, 640), Size(360, 800)]) {
    testWidgets('the fight\'s deck fits every card at $size', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final c = GameController();
      c.meta
        ..tourSeenVersion = tourVersion
        ..tutorialSeen = true
        ..tipsSeen.addAll(ContextTips.all)
        ..lastSeenNewsVersion = currentAppVersion
        ..runsPlayed = 3;
      c.tour = TourDirector(seenVersion: tourVersion);
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      expect(await walkToFight(tester, c), isTrue, reason: 'seed 1 fights');
      await pumpFor(tester, 400);
      await tester.tap(find.bySemanticsLabel('How to play'));
      await pumpFor(tester, 300);
      var cards = 0;
      while (find.text('Next').evaluate().isNotEmpty && cards++ < 12) {
        expect(tester.takeException(), isNull, reason: 'card ${cards} $size');
        await tester.tap(find.text('Next'));
        await pumpFor(tester, 200);
      }
      expect(find.text('Got it'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'last card $size');
      expect(cards, 4, reason: 'five cards');
    });
  }
}
