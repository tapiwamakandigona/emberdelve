// tool/peddlers_shelf_visual_test.dart — manual visual-critique plates for
// v0.128.0 "The Smith's Shelf". Not part of CI.
//
//   flutter test tool/peddlers_shelf_visual_test.dart
//
// Plates (build/peddlers_shelf_visual/):
//   • forgesoot_360x640 — the wardrobe scrolled to Forgesoot WORN on the
//     kindler (the dark-dye gap closed; sprite must stay legible).
//   • forgesoot_320x568 — restraint plate at the narrowest width.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart' show ContextTips;
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/peddlers_shelf_visual';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await icons.load();
    }
  }
}

Future<void> snap(
  WidgetTester tester,
  GlobalKey key,
  String name,
  double ratio,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: ratio),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> capture(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name, {
  required Key scrollTo,
}) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: logical),
          child: CharacterScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.scrollUntilVisible(
    find.byKey(scrollTo),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 100));
  // Place the target card near the top so the cards after it show too.
  final top = tester.getTopLeft(find.byKey(scrollTo)).dy;
  await tester.drag(
    find.byType(Scrollable).first,
    Offset(0, 120 - top),
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// A veteran profile: rich enough that the new dyes show real prices and
/// the three new epithets sit in every state — deepdrawn WORN (bestFloor
/// 10), measured unlocked (streak of 6), six-handed LOCKED (five of six
/// delvers have wins).
GameController deepMeta() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.addAll([
      'warden',
      'gambler',
      'ascetic',
      'peddler',
      'tinker',
    ])
    ..embers = 700
    ..runsWon = 12
    ..runsPlayed = 30
    ..bestFloor = 10
    ..bestExactStreak = 6
    ..ownedDyes.addAll(['emberwash', 'emberheart', 'forgesoot'])
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  c.meta.charWins.addAll({
    'kindler': 4,
    'warden': 2,
    'gambler': 1,
    'ascetic': 1,
    'peddler': 1,
  });
  c.meta.charDye['kindler'] = 'forgesoot';
  c.meta.charEpithet['kindler'] = 'the_deepdrawn';
  return c;
}

Future<void> captureLedger(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name,
) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: logical),
          child: LedgerScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  final scrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('skin-verdigris')),
    400,
    scrollable: scrollable,
    maxScrolls: 300,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final rowTop = tester
      .getTopLeft(find.byKey(const ValueKey('skin-verdigris')))
      .dy;
  await tester.drag(scrollable, Offset(0, 120 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('peddlers shelf plates', (tester) async {
    await loadRealFonts();
    final warm = deepMeta();
    warm.meta.ownedDieSkins.add('verdigris');
    warm.meta.activeDieSkin = 'verdigris';
    // WARMUP: first-capture DieChips render dim (cold decode cache) —
    // judge the plates below, never this one.
    await captureLedger(tester, warm, const Size(360, 640), 'warmup');
    final skins = deepMeta();
    skins.meta.ownedDieSkins.add('verdigris');
    skins.meta.activeDieSkin = 'verdigris';
    await captureLedger(
      tester,
      skins,
      const Size(360, 640),
      'peddlers_360x640',
    );
    final skins2 = deepMeta();
    skins2.meta.ownedDieSkins.add('verdigris');
    skins2.meta.activeDieSkin = 'verdigris';
    await captureLedger(
      tester,
      skins2,
      const Size(320, 568),
      'peddlers_320x568',
    );
  });
}
