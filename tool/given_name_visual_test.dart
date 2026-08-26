// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/given_name_visual_test.dart — manual visual-critique plates for
// v0.72.0 "The Given Name". Not part of CI.
//
//   flutter test tool/given_name_visual_test.dart
//
// Plates (build/given_name_visual/):
//   • named_picker_360x640 — picker top: kindler given a name (with worn
//     title beneath), warden keeping the roster name; pencil affordance
//     quiet beside each unlocked name.
//   • named_picker_320x568 — restraint plate: narrowest width with the
//     full 16-char name + the longest epithet; must ellipsize, never clip.
//   • name_dialog_360x640 — the dialog itself, field filled.
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

const outDir = 'build/given_name_visual';

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

GameController namedMeta() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.add('warden')
    ..runsWon = 20
    ..runsPlayed = 40
    ..selectedEpithet = 'the_delver';
  c.meta.charName['kindler'] = 'Ashka Emberborn';
  c.meta.charEpithet['kindler'] = 'the_well_oiled';
  c.meta.charRuns.addAll({'kindler': 30, 'warden': 10});
  c.meta.charWins.addAll({'kindler': 15, 'warden': 5});
  return c;
}

Future<void> capture(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name, {
  bool openDialog = false,
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
  if (openDialog) {
    await tester.tap(find.byKey(const ValueKey('name-edit-kindler')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('given name plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      namedMeta(),
      const Size(360, 640),
      'named_picker_360x640',
    );
    await capture(
      tester,
      namedMeta(),
      const Size(320, 568),
      'named_picker_320x568',
    );
    await capture(
      tester,
      namedMeta(),
      const Size(360, 640),
      'name_dialog_360x640',
      openDialog: true,
    );
  });
}
