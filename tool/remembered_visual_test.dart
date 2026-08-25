// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/remembered_visual_test.dart — manual visual-critique plates for the
// v0.43.0 Remembered Delves rows in the Ledger. Not part of CI.
//
//   flutter test tool/remembered_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/remembered_visual';

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
  testWidgets('remembered delves plates: mixed rows, phone sizes', (
    tester,
  ) async {
    await tester.binding.runAsync(loadRealFonts);

    GameController seedController() {
      final c = GameController();
      c.meta.addRunRecord({
        'date': '2026-08-01',
        'character': 'kindler',
        'difficulty': 'normal',
        'ascension': 0,
        'result': 'lost',
        'floor': 3,
        'floors': 8,
        'seed': 0, // legacy record: no code affordance
        'embers': 10,
      });
      c.meta.addRunRecord({
        'date': '2026-08-20',
        'character': 'warden',
        'difficulty': 'easy',
        'ascension': 0,
        'result': 'abandoned',
        'floor': 2,
        'floors': 8,
        'seed': 7,
        'embers': 0,
      });
      c.meta.addRunRecord({
        'date': '2026-08-24',
        'character': 'gambler',
        'difficulty': 'hard',
        'ascension': 2,
        'result': 'won',
        'floor': 8,
        'floors': 8,
        'seed': 42,
        'embers': 90,
        'daily': true,
      });
      return c;
    }

    Future<void> plate(Size logical, String name) async {
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
              child: LedgerScreen(seedController()),
            ),
          ),
        ),
      );
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('recent-delves')),
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, key, name);
    }

    await plate(const Size(360, 640), 'remembered_360');
    await plate(const Size(412, 915), 'remembered_412');
    await plate(const Size(320, 568), 'remembered_320');
  });
}
