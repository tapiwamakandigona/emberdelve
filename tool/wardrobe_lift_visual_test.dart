// tool/wardrobe_lift_visual_test.dart — manual visual-critique plates for
// the Wardrobe Lift: the picker app bar with the new WARDROBE action, at
// phone and narrow widths, before and after the lift. Not part of CI.
//
//   flutter test tool/wardrobe_lift_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/wardrobe_lift_visual';

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

GameController fullRoster() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.addAll(charactersOrder)
    ..embers = 1200;
  return c;
}

Future<void> capture(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name, {
  bool lift = false,
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
  // Sprite warmup (sheets decode async).
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 900)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  if (lift) {
    await tester.tap(find.byKey(const ValueKey('wardrobe-jump')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plates: the lift at phone and narrow widths', (tester) async {
    await loadRealFonts();
    await capture(tester, fullRoster(), const Size(390, 844), 'top_phone');
    await capture(
      tester,
      fullRoster(),
      const Size(390, 844),
      'landed_phone',
      lift: true,
    );
    await capture(tester, fullRoster(), const Size(320, 568), 'top_narrow');
    await capture(
      tester,
      fullRoster(),
      const Size(320, 568),
      'landed_narrow',
      lift: true,
    );
  });
}
