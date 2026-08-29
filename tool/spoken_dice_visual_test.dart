// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/spoken_dice_visual_test.dart — manual visual-critique plates for
// v0.116.0 "The Spoken Dice". Not part of CI.
//
//   flutter test tool/spoken_dice_visual_test.dart
//
// Plates (build/spoken_dice_visual/):
//   • dice_360x640 — THE DICE section closing the book: the Ember Die's
//     story unsealed, the other cuts still priced.
//   • dice_320x568 — restraint plate at the narrowest width.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/spoken_dice_visual';

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

GameController diceMeta() {
  final c = GameController();
  c.meta.embers = 42;
  c.meta.ownedCodex.add('die:d6');
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
          child: CodexScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  // THE DICE closes a 97-entry book — give the scroll a real budget.
  await tester.scrollUntilVisible(
    find.text('THE DICE'),
    600,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 400,
  );
  await tester.pump(const Duration(milliseconds: 100));
  // Pin the section header near the top so the plate shows the header, the
  // unsealed kindler story, and the priced cards below it.
  final headerTop = tester.getTopLeft(find.text('THE DICE')).dy;
  await tester.drag(
    find.byType(Scrollable).first,
    Offset(0, 90 - headerTop),
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('spoken dice plates', (tester) async {
    await loadRealFonts();
    await capture(tester, diceMeta(), const Size(360, 640), 'dice_360x640');
    await capture(tester, diceMeta(), const Size(320, 568), 'dice_320x568');
  });
}
