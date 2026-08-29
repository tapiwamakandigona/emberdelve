// tool/doubled_week_visual_test.dart — manual visual-critique plates for
// v0.111.0 "The Doubled Week".
//
// Run: flutter test tool/doubled_week_visual_test.dart
// Plates (build/doubled_week_visual/):
//   • week_360x640 — mid-run map on a doubled week: top bar reads
//     'WEEKLY · Cold Quarter', the map holds no shop and no rest nodes.
//   • week_320x568 — restraint plate at the narrowest width.
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

const outDir = 'build/doubled_week_visual';

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

/// The first doubled-week Monday at or after 2026-01-05.
DateTime doubledMonday() {
  var idx = weekIndexForDate(DateTime(2026, 1, 5));
  while (weeklyRuleFor(idx).mutators.length < 2) {
    idx++;
  }
  final md = mondayOfWeek(idx);
  return DateTime(md[0], md[1], md[2]);
}

GameController doubledWeekRun() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..lastSeenNewsVersion = currentAppVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startWeeklyRun(clock: doubledMonday());
  // Skip the boon pick so the plate lands on the map with the weekly badge.
  if (c.phase == 'boon') {
    c.apply({'type': 'choose_boon', 'index': 1});
  }
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
  await snap(tester, key, name);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('doubled week plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    addTearDown(tester.view.reset);
    await capture(
      tester,
      doubledWeekRun(),
      const Size(360, 640),
      'week_360x640',
    );
    await capture(
      tester,
      doubledWeekRun(),
      const Size(320, 568),
      'week_320x568',
    );
  });
}
