// test/shorter_scroll_test.dart — v0.180.0 "The Shorter Scroll".
//
// On 320×568-class screens the event glyph shrinks and the top gap tightens
// so the longest room prose sits whole above the pinned choices (the prose
// used to scroll 43 px). Taller screens keep the 96 px glyph.
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

// Scroll extents are measured with the shipped fonts — Ahem wraps differently.
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

Future<GameController> openEvent(
  WidgetTester tester,
  Size size,
  String id,
) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final c = GameController();
  c.meta
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEmberTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: GameRoot(c),
      ),
    ),
  );
  await pumpFor(tester, 300);
  c.startRun(character: 'kindler', seed: 5, boons: false);
  await pumpFor(tester, 300);
  final map = c.state!['map'] as Map;
  final position = map['position'] as int;
  final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
  final nodes = (map['nodes'] as Map).cast<String, Map>();
  final ev = edges.firstWhere((e) => nodes['$e']!['kind'] == 'event');
  c.apply({'type': 'choose_node', 'node': ev});
  expect(c.phase, 'event');
  c.sim!.event = id;
  // ignore: invalid_use_of_protected_member
  c.notifyListeners();
  await pumpFor(tester, 900);
  return c;
}

double proseScroll(WidgetTester tester) {
  for (final e in find.byType(Scrollable).evaluate()) {
    final st = (e as StatefulElement).state as ScrollableState;
    if (st.position.hasContentDimensions && st.position.axis == Axis.vertical) {
      return st.position.maxScrollExtent;
    }
  }
  return 0;
}

Image glyph(WidgetTester tester) => tester.widget<Image>(
  find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Image),
  ),
);

void main() {
  setUpAll(loadRealFonts);
  testWidgets('320×568: the longest room fits whole; glyph is small', (
    tester,
  ) async {
    await openEvent(tester, const Size(320, 568), 'the_first_lantern');
    expect(proseScroll(tester), 0);
    expect(glyph(tester).width, 56);
    expect(find.text('Leave it burning'), findsOneWidget);
    await pumpFor(tester, 1200);
  });

  testWidgets('360×800 keeps the full glyph', (tester) async {
    await openEvent(tester, const Size(360, 800), 'the_first_lantern');
    expect(proseScroll(tester), 0);
    expect(glyph(tester).width, 96);
    await pumpFor(tester, 1200);
  });
}
