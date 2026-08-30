// tool/waymark_line_visual_test.dart — manual visual-critique plates for
// v0.121.0 "The Waymark Line". Not part of CI.
//
//   flutter test tool/waymark_line_visual_test.dart
//
// Plates (build/waymark_line_visual/):
//   • waymark_360x640 — the title's quiet lines: the waymark line sits
//     with the provings count and 'Delve a seed' (played profile).
//   • waymark_320x568 — restraint plate at the narrowest width.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/news.dart' show currentAppVersion;
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/waymark_line_visual';

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

Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

GameController playedWeekMeta() {
  final c = GameController();
  final thisWeek = weekIndexForDate(DateTime.now());
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..lastSeenNewsVersion = currentAppVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..heardTracks.addAll([for (final t in gramophoneTracks) t.key])
    ..lastWeeklyKey = weeklyKey(thisWeek)
    ..lastWeeklyWon = false
    ..lastWeeklyFloor = 4
    ..lastWeeklyFloors = 9
    ..runsPlayed = 12
    ..runsWon = 2;
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
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: logical),
          child: GameRoot(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('waymark-line')),
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('waymark line plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    addTearDown(tester.view.reset);
    await capture(
      tester,
      playedWeekMeta(),
      const Size(360, 640),
      'waymark_360x640',
    );
    await capture(
      tester,
      playedWeekMeta(),
      const Size(320, 568),
      'waymark_320x568',
    );
  });
}
