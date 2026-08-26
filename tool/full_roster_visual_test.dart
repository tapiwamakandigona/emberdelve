// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/full_roster_visual_test.dart — manual visual-critique plates for
// v0.74.0 "The Full Roster". Not part of CI.
//
//   flutter test tool/full_roster_visual_test.dart
//
// Plates (build/full_roster_visual/):
//   • roster_360x640 — the DELVERS panel: six delvers, mixed named/dressed/
//     charted/locked rows.
//   • roster_320x568 — restraint plate: longest name+title+tally at the
//     narrowest width.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/full_roster_visual';

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

GameController rosterMeta() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.addAll(['warden', 'gambler'])
    ..runsWon = 60
    ..runsPlayed = 120
    ..selectedEpithet = 'the_delver';
  c.meta.charName.addAll({'kindler': 'Ashka Emberborn', 'warden': 'Brick'});
  c.meta.charEpithet.addAll({
    'kindler': 'the_well_oiled',
    'warden': 'the_thorough',
  });
  c.meta.charDye.addAll({'kindler': 'goldthread', 'warden': 'mosscloak'});
  c.meta.ownedDyes.addAll({'goldthread', 'mosscloak'});
  c.meta.charRuns.addAll({'kindler': 80, 'warden': 40, 'gambler': 3});
  c.meta.charWins.addAll({'kindler': 45, 'warden': 15, 'gambler': 1});
  c.meta.charBestFloor.addAll({'kindler': 12, 'warden': 9});
  return c;
}

Future<void> capture(
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
    find.byKey(const ValueKey('roster-delver-kindler')),
    400,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final rowTop = tester
      .getTopLeft(find.byKey(const ValueKey('roster-delver-kindler')))
      .dy;
  await tester.drag(scrollable, Offset(0, 120 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full roster plates', (tester) async {
    await loadRealFonts();
    await capture(tester, rosterMeta(), const Size(360, 640), 'roster_360x640');
    await capture(tester, rosterMeta(), const Size(320, 568), 'roster_320x568');
  });
}
