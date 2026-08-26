// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/sounding_line_visual_test.dart — manual visual-critique plates for
// v0.77.0 "The Sounding Line". Not part of CI.
//
//   flutter test tool/sounding_line_visual_test.dart
//
// Plates (build/sounding_line_visual/):
//   • sounding_360x640 — the depth chart over a varied 14-run history
//     (wins, losses, an abandoned run, a legacy floorless record).
//   • sounding_320x568 — restraint plate at the narrowest width.
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

const outDir = 'build/sounding_line_visual';

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
  // Oldest banked first (addRunRecord prepends). A varied, plausible arc:
  // early shallow losses, a legacy floorless record, deepening middle,
  // an abandoned run, wins late.
  final arc = <(String, int, int)>[
    ('lost', 2, 11),
    ('lost', 0, 0), // legacy record: floor key stripped below
    ('lost', 4, 12),
    ('lost', 3, 13),
    ('lost', 5, 14),
    ('abandoned', 2, 15),
    ('lost', 6, 16),
    ('lost', 7, 17),
    ('won', 9, 18),
    ('lost', 5, 19),
    ('lost', 8, 20),
    ('won', 10, 21),
    ('won', 9, 22),
    ('won', 12, 23),
  ];
  for (final (result, floor, seed) in arc) {
    final r = <String, Object?>{
      'date': '2026-08-${10 + seed % 15}',
      'character': 'kindler',
      'difficulty': 'normal',
      'ascension': 0,
      'result': result,
      'floor': floor,
      'floors': 12,
      'seed': seed,
      'embers': 20,
    };
    if (seed == 0) r.remove('floor'); // the legacy stub
    c.meta.addRunRecord(r);
  }
  c.meta
    ..runsPlayed = 14
    ..runsWon = 4;
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
    find.byKey(const ValueKey('sounding-line')),
    400,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final rowTop = tester
      .getTopLeft(find.byKey(const ValueKey('sounding-line')))
      .dy;
  await tester.drag(scrollable, Offset(0, 120 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sounding line plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      historyMeta(),
      const Size(360, 640),
      'sounding_360x640',
    );
    await capture(
      tester,
      historyMeta(),
      const Size(320, 568),
      'sounding_320x568',
    );
  });
}
