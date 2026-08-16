// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/rank_visual_test.dart — manual visual-critique plates for the
// v0.13.0 Delver's Rank surfaces. Not part of CI.
//
//   flutter test tool/rank_visual_test.dart
//
// Plates:
//   rank_ledger_360x640 — mid-ladder profile (Sparktender, 49 marks) on
//     the Ledger header.
//   rank_ledger_320x568_1p3x — same, worst-case small screen at 1.3x.
//   rank_summary_360x640 — a real fresh-profile bot run (seed 11, boons)
//     ending on the summary, scrolled to the rank-up line.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/rank_visual';

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

Future<void> capture(
  WidgetTester tester,
  Widget screen,
  String name,
  Size logical,
  double textScale, {
  String? scrollToKey,
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
          data: MediaQueryData(
            size: logical,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  if (scrollToKey != null) {
    await tester.ensureVisible(find.byKey(ValueKey(scrollToKey)));
    await tester.pump(const Duration(milliseconds: 400));
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  Directory(outDir).createSync(recursive: true);
  File(
    '$outDir/$name.png',
  ).writeAsBytesSync(bytes!.buffer.asUint8List(), flush: true);
  debugPrint('wrote $outDir/$name.png');
}

GameController midLadder() {
  final c = GameController();
  c.meta.runsWon = 5;
  c.meta.bossesBeaten.add('ashen_colossus');
  for (var i = 0; i < 10; i++) {
    c.meta.enemyMet['foe_$i'] = 1;
    if (i < 8) c.meta.enemyFelled['foe_$i'] = 1;
  }
  c.meta.ownedCodex.addAll({'enemy:a', 'enemy:b', 'relic:c'});
  return c;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('rank ledger plates', (tester) async {
    await capture(
      tester,
      LedgerScreen(midLadder()),
      'rank_ledger_360x640',
      const Size(360, 640),
      1.0,
    );
    await capture(
      tester,
      LedgerScreen(midLadder()),
      'rank_ledger_320x568_1p3x',
      const Size(320, 568),
      1.3,
    );
  });

  testWidgets('rank summary plate', (tester) async {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 11, boons: true);
    var guard = 0;
    while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'run_won');
    await capture(
      tester,
      GameRoot(c),
      'rank_summary_360x640',
      const Size(360, 640),
      1.0,
      scrollToKey: 'rank-up-line',
    );
  });
}
