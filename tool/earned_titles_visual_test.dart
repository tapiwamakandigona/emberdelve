// tool/earned_titles_visual_test.dart — manual visual-critique plates for
// v0.129.0 "The Earned Titles". Not part of CI.
//
//   flutter test tool/earned_titles_visual_test.dart
//
// Plates (build/earned_titles_visual/):
//   • titles_360x640 — the epithet shelf: the Tempered WORN (earned at
//     tempersSet 12), the Weathered LOCKED with its unlock line.
//   • titles_320x568 — restraint plate at the narrowest width.
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

const outDir = 'build/earned_titles_visual';

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
    ..ownedDyes.addAll(['emberwash'])
    ..tempersSet = 12
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
  c.meta.charEpithet['kindler'] = 'the_tempered';

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
    find.byKey(const ValueKey('skin-tempered')),
    400,
    scrollable: scrollable,
    maxScrolls: 300,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final rowTop = tester
      .getTopLeft(find.byKey(const ValueKey('skin-tempered')))
      .dy;
  await tester.drag(scrollable, Offset(0, 120 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('earned titles plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      deepMeta(),
      const Size(360, 640),
      'titles_360x640',
      scrollTo: const ValueKey('epithet-the_tempered'),
    );
    await capture(
      tester,
      deepMeta(),
      const Size(320, 568),
      'titles_320x568',
      scrollTo: const ValueKey('epithet-the_tempered'),
    );
    final skins = deepMeta();
    skins.meta.ownedDieSkins.add('tempered');
    skins.meta.activeDieSkin = 'tempered';
    await captureLedger(tester, skins, const Size(360, 640), 'skins_360x640');
  });
}
