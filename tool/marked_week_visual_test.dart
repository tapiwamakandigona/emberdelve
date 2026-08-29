// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/marked_week_visual_test.dart — manual visual-critique plates for
// v0.103.0 "The Marked Week". Not part of CI.
//
//   flutter test tool/marked_week_visual_test.dart
//
// Plates (build/marked_week_visual/):
//   • week_360x640 — RECENT DELVES with a weekly (rule named, no code/
//     retrace), a daily, and a plain run (code + retrace intact).
//   • week_320x568 — restraint plate: the longest micro line the row can
//     produce (weekly · Flint Week · …) at the narrowest width.
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

const outDir = 'build/marked_week_visual';

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

GameController weekMeta() {
  final c = GameController();
  c.meta.addRunRecord({
    'date': '2026-08-20',
    'character': 'kindler',
    'difficulty': 'normal',
    'ascension': 0,
    'result': 'won',
    'floor': 8,
    'floors': 8,
    'seed': 11,
    'embers': 60,
    'fights': 6,
  });
  c.meta.addRunRecord({
    'date': '2026-08-22',
    'character': 'warden',
    'difficulty': 'normal',
    'ascension': 0,
    'result': 'lost',
    'floor': 5,
    'floors': 8,
    'seed': 21,
    'embers': 20,
    'fights': 4,
    'killed_by': 'quench_hag',
    'daily': true,
  });
  c.meta.addRunRecord({
    'date': '2026-08-24',
    'character': 'kindler',
    'difficulty': 'normal',
    'ascension': 0,
    'result': 'won',
    'floor': 8,
    'floors': 8,
    'seed': 42,
    'embers': 70,
    'fights': 7,
    'weekly': true,
    'mutators': ['all_d4'],
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
    find.byKey(const ValueKey('recent-delves')),
    400,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final rowTop = tester
      .getTopLeft(find.byKey(const ValueKey('recent-delves')))
      .dy;
  await tester.drag(scrollable, Offset(0, 90 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('marked week plates', (tester) async {
    await loadRealFonts();
    await capture(tester, weekMeta(), const Size(360, 640), 'week_360x640');
    await capture(tester, weekMeta(), const Size(320, 568), 'week_320x568');
  });
}
