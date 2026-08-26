// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/farthest_lantern_visual_test.dart — manual visual-critique plates for
// v0.82.0 "The Farthest Lantern". Not part of CI.
//
//   flutter test tool/farthest_lantern_visual_test.dart
//
// Plates (build/farthest_lantern_visual/):
//   • lantern_360x640 — the map with the gold record rule and caption in
//     the opening viewport.
//   • lantern_320x568 — restraint plate at the narrowest width.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/farthest_lantern_visual';

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

GameController lanternRun() {
  final c = GameController();
  // Suppress the tour/tutorial/tips so the map plate is clean.
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.bestFloor = 4;
  c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
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
          child: GameRoot(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  for (var t = 0; t < 1200; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('farthest lantern plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      lanternRun(),
      const Size(360, 640),
      'lantern_360x640',
    );
    await capture(
      tester,
      lanternRun(),
      const Size(320, 568),
      'lantern_320x568',
    );
  });
}
