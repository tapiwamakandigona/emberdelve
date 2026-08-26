// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/dressed_delver_visual_test.dart — manual visual-critique plates for
// v0.66.0 "The Dressed Delver". Not part of CI.
//
//   flutter test tool/dressed_delver_visual_test.dart
//
// Plates (build/dressed_delver_visual/):
//   • wardrobe_360x640 — THE EPITHET section with the chip row, six delvers
//     unlocked, target wearing the longest title ("the Well-Oiled").
//   • wardrobe_320x568 — the restraint plate: narrowest supported width,
//     same chip row and shelf.
//   • dressed_picker_360x640 — picker top with two delvers wearing
//     DIFFERENT titles under their names.
//   • dressed_fresh_360x640 — fresh install: one delver, no chip row.
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

const outDir = 'build/dressed_delver_visual';

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
  bool scrollToWardrobe = false,
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
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  if (scrollToWardrobe) {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dress-kindler')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Place the chip row just under the app bar with the shelf below it.
    final chipTop = tester
        .getTopLeft(find.byKey(const ValueKey('dress-kindler')))
        .dy;
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, 140 - chipTop),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Six delvers, everything on the shelf earned, mixed dresses:
/// kindler wears the longest title, warden a different one, the rest
/// fall back to the legacy profile-wide title.
GameController dressedMeta() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.addAll([
      'warden',
      'gambler',
      'ascetic',
      'peddler',
      'tinker',
    ])
    ..runsWon = 60
    ..runsPlayed = 120
    ..selectedEpithet = 'the_delver';
  c.meta.charEpithet.addAll({
    'kindler': 'the_well_oiled',
    'warden': 'the_thorough',
  });
  c.meta.charRuns.addAll({'kindler': 80, 'warden': 40, 'tinker': 2});
  c.meta.charWins.addAll({'kindler': 45, 'warden': 15, 'tinker': 1});
  c.meta.charBestFloor.addAll({'kindler': 9, 'warden': 6});
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dressed delver plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      dressedMeta(),
      const Size(360, 640),
      'wardrobe_360x640',
      scrollToWardrobe: true,
    );
    await capture(
      tester,
      dressedMeta(),
      const Size(320, 568),
      'wardrobe_320x568',
      scrollToWardrobe: true,
    );
    await capture(
      tester,
      dressedMeta(),
      const Size(360, 640),
      'dressed_picker_360x640',
    );
    await capture(
      tester,
      GameController(),
      const Size(360, 640),
      'dressed_fresh_360x640',
    );
  });
}
