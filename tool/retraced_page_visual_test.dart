// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/retraced_page_visual_test.dart — manual visual-critique plates for
// v0.81.0 "The Retraced Page". Not part of CI.
//
//   flutter test tool/retraced_page_visual_test.dart
//
// Plates (build/retraced_page_visual/):
//   • retraced_360x640 — RECENT DELVES rows with card + retrace + copy
//     marks; a legacy seed-0 row shows neither retrace nor copy.
//   • retraced_320x568 — restraint plate: the fullest row (epithet +
//     fights + daily) at the narrowest width.
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

const outDir = 'build/retraced_page_visual';

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

GameController historyMeta() {
  final c = GameController();
  c.meta.charName['kindler'] = 'Ashka Emberborn';
  c.meta.addRunRecord({
    'date': '2026-08-01',
    'character': 'kindler',
    'difficulty': 'normal',
    'ascension': 0,
    'result': 'lost',
    'floor': 3,
    'floors': 12,
    'seed': 0, // legacy: no code, no retrace
    'embers': 4,
  });
  c.meta.addRunRecord({
    'date': '2026-08-19',
    'character': 'kindler',
    'difficulty': 'hard',
    'ascension': 2,
    'result': 'lost',
    'floor': 7,
    'floors': 12,
    'seed': 41,
    'embers': 18,
    'killed_by': 'wick_widow',
    'epithet': 'the_well_oiled',
    'fights': 11,
    'daily': true,
  });
  c.meta.addRunRecord({
    'date': '2026-08-22',
    'character': 'kindler',
    'difficulty': 'easy',
    'ascension': 0,
    'result': 'won',
    'floor': 8,
    'floors': 8,
    'seed': 6,
    'embers': 30,
    'epithet': 'the_exact',
    'fights': 9,
    'short': true,
  });
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
          child: LedgerScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  final scrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('history-retrace-6-2026-08-22')),
    400,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final rowTop = tester
      .getTopLeft(find.byKey(const ValueKey('history-retrace-6-2026-08-22')))
      .dy;
  await tester.drag(scrollable, Offset(0, 120 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('retraced page plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      historyMeta(),
      const Size(360, 640),
      'retraced_360x640',
    );
    await capture(
      tester,
      historyMeta(),
      const Size(320, 568),
      'retraced_320x568',
    );
  });
}
