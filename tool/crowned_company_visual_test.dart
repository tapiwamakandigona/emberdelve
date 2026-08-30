// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/crowned_company_visual_test.dart — manual visual-critique plates for
// v0.123.0 "The Crowned Company". Not part of CI.
//
//   flutter test tool/crowned_company_visual_test.dart
//
// Plates (build/crowned_company_visual/):
//   • crowned_360x640 — picker top, veteran meta: kindler/warden tallies
//     carry the hard count between wins and floor; gambler (0 hard) shows
//     the old tally untouched.
//   • crowned_320x568 — restraint plate: narrowest width, longest epithet
//     AND the full four-part tally (wins · delves · hard · floor).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/crowned_company_visual';

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

Future<void> capturePicker(
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
          child: CharacterScreen(c),
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

GameController veteranMeta() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.addAll([
      'warden',
      'gambler',
      'ascetic',
      'peddler',
      'tinker',
    ])
    ..selectedEpithet = 'the_well_oiled';
  c.meta.charRuns.addAll({
    'kindler': 1204,
    'warden': 87,
    'gambler': 41,
    'ascetic': 1,
    'peddler': 12,
  });
  c.meta.charWins.addAll({
    'kindler': 999,
    'warden': 30,
    'gambler': 0,
    'ascetic': 1,
    'peddler': 7,
  });
  c.meta.charHardWins.addAll({'kindler': 41, 'warden': 3});
  c.meta.charBestFloor.addAll({
    'kindler': 9,
    'warden': 6,
    'gambler': 3,
    'ascetic': 1,
  });
  // peddler has runs but NO charted depth (pre-ledger save) — plain tally.
  // tinker unlocked but never delved — must show NO tally line.
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delver tally plates', (tester) async {
    await loadRealFonts();
    await capturePicker(
      tester,
      veteranMeta(),
      const Size(360, 640),
      'crowned_360x640',
    );
    await capturePicker(
      tester,
      veteranMeta(),
      const Size(320, 568),
      'crowned_320x568',
    );
  });
}
