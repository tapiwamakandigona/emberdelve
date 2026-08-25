// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/kept_fire_visual_test.dart — manual visual-critique plates for
// v0.62.0 "The Kept Fire". Not part of CI.
//
//   flutter test tool/kept_fire_visual_test.dart
//
// Plates (build/kept_fire_visual/):
//   • kept_fire_360x640 — a 23-days-away veteran: the line sits under the
//     gathered hearth without crowding the selector.
//   • kept_fire_320x568 — restraint plate: narrowest width with the widest
//     honest count (365 days) — must wrap clean, never clip.
//   • kept_fire_fresh_360x640 — fresh install: no line anywhere.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/kept_fire_visual';

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

GameController quietController() {
  final c = GameController();
  c.meta
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  return c;
}

Map<String, Object?> record(String date) => {
  'date': date,
  'character': 'kindler',
  'difficulty': 'easy',
  'ascension': 0,
  'result': 'lost',
  'floor': 3,
  'floors': 9,
  'seed': 7,
  'embers': 12,
};

Future<void> captureTitle(
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
          child: Material(color: EmberColors.bg, child: TitleScreen(c)),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kept fire plates', (tester) async {
    await loadRealFonts();

    final away = quietController();
    away.meta.runsPlayed = 40;
    away.meta.runsWon = 12;
    away.meta.embers = 310;
    away.meta.runHistory.insert(
      0,
      record(dailyKey(DateTime.now().subtract(const Duration(days: 23)))),
    );
    await captureTitle(tester, away, const Size(360, 640), 'kept_fire_360x640');

    final long = quietController();
    long.meta.runsPlayed = 40;
    long.meta.runHistory.insert(
      0,
      record(dailyKey(DateTime.now().subtract(const Duration(days: 365)))),
    );
    await captureTitle(tester, long, const Size(320, 568), 'kept_fire_320x568');

    await captureTitle(
      tester,
      quietController(),
      const Size(360, 640),
      'kept_fire_fresh_360x640',
    );
  });
}
