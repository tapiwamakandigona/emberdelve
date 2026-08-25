// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/delver_tally_visual_test.dart — manual visual-critique plates for
// v0.60.0 "The Delver's Tally". Not part of CI.
//
//   flutter test tool/delver_tally_visual_test.dart
//
// Plates (build/delver_tally_visual/):
//   • tally_360x640 — picker top, veteran meta (all six delvers with mixed
//     records, worn epithet, big counts).
//   • tally_320x568 — the restraint plate: narrowest supported width with
//     the longest epithet ("the Well-Oiled") + four-digit tally.
//   • tally_fresh_360x640 — fresh install: no tally lines anywhere.
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

const outDir = 'build/delver_tally_visual';

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
      'tally_360x640',
    );
    await capturePicker(
      tester,
      veteranMeta(),
      const Size(320, 568),
      'tally_320x568',
    );
    await capturePicker(
      tester,
      GameController(),
      const Size(360, 640),
      'tally_fresh_360x640',
    );
  });
}
