// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/hearth_visual_test.dart — manual visual-critique plates for the
// v0.42.0 Gathered Hearth title scene. Not part of CI.
//
//   flutter test tool/hearth_visual_test.dart
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

const outDir = 'build/hearth_visual';

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

Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
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
  debugPrint('PLATE-OK: $name');
}

void main() {
  testWidgets('hearth plates: 1 / 2 / 3 / 5 delvers, phone sizes', (
    tester,
  ) async {
    await tester.binding.runAsync(loadRealFonts);

    Future<void> plate(Size logical, int unlockedCount, String name) async {
      tester.view.physicalSize = logical * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = GameController(); // no boot(): title screen
      c.meta.unlockedCharacters.addAll(
        charactersOrder.take(unlockedCount),
      );
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
      // Sprite sheets decode off the fake-async clock.
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shoot(tester, key, name);
    }

    await plate(const Size(360, 640), 1, 'hearth_1_360');
    await plate(const Size(360, 640), 2, 'hearth_2_360');
    await plate(const Size(412, 915), 3, 'hearth_3_412');
    await plate(const Size(412, 915), 5, 'hearth_5_412');
    await plate(const Size(320, 568), 5, 'hearth_5_320');
  });
}
