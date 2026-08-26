// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/old_foe_visual_test.dart — manual visual-critique plates for
// v0.78.0 "The Old Foe". Not part of CI.
//
//   flutter test tool/old_foe_visual_test.dart
//
// Plates (build/old_foe_visual/):
//   • old_foe_360x640 — the LIFETIME panel with the old-foe row present.
//   • old_foe_320x568 — restraint plate: longest enemy name at the
//     narrowest width.
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

const outDir = 'build/old_foe_visual';

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

GameController foeMeta(String foeId, int falls) {
  final c = GameController();
  c.meta
    ..lifetimeEmbers = 128401
    ..runsPlayed = 120
    ..runsWon = 60
    ..bestAscension = 12
    ..exactKills = 214
    ..bestExactStreak = 9;
  c.meta.enemyFellTo.addAll({foeId: falls, 'ash_rat': 2, 'cinder_wisp': 1});
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
    find.byKey(const ValueKey('old-foe')),
    400,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final rowTop = tester.getTopLeft(find.byKey(const ValueKey('old-foe'))).dy;
  await tester.drag(scrollable, Offset(0, 120 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('old foe plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      foeMeta('wick_widow', 7),
      const Size(360, 640),
      'old_foe_360x640',
    );
    await capture(
      tester,
      foeMeta('smoke_stalker', 23),
      const Size(320, 568),
      'old_foe_320x568',
    );
  });
}
