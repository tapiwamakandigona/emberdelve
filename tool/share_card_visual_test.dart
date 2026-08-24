// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/share_card_visual_test.dart — manual visual-critique plates for the
// v0.34.0 Delver's Card. Not part of CI.
//
//   flutter test tool/share_card_visual_test.dart
//
// Plates (build/share_card_visual/): the exported card at 3x for a win and a
// loss (exactly the PNG a player shares), plus the preview sheet over the
// summary at 360x640 and 412x915.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/share_card_visual';

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

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Future<void> save(WidgetTester tester, GlobalKey key, String name,
    double ratio) async {
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

Future<void> cardPlate(
    WidgetTester tester, DelverCardFacts facts, String name) async {
  tester.view.physicalSize = const Size(360, 440) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: Material(
        color: const Color(0xFF222222),
        child: Center(
          child: RepaintBoundary(key: key, child: DelverCard(facts)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await save(tester, key, name, 3);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> sheetPlate(
    WidgetTester tester, Size logical, String name, int seed) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final c = GameController();
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
  c.startRun(character: 'kindler', seed: seed, boons: true, difficulty: 'easy');
  driveToTerminal(c);
  await pumpFor(tester, 2500);
  await tester.scrollUntilVisible(
      find.byKey(const ValueKey('share-delve-card')), 200,
      maxScrolls: 200);
  await tester.tap(find.byKey(const ValueKey('share-delve-card')));
  await pumpFor(tester, 800);
  await save(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('delver card plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);

    // The exported artifact itself, win and loss, real drives.
    final win = GameController();
    win.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(win);
    await cardPlate(tester, DelverCardFacts.fromController(win), 'card_win_3x');

    final loss = GameController();
    loss.startRun(
        character: 'kindler', seed: 13, boons: true, difficulty: 'easy');
    driveToTerminal(loss);
    await cardPlate(
        tester, DelverCardFacts.fromController(loss), 'card_loss_3x');

    // The preview sheet over the summary.
    await sheetPlate(tester, const Size(360, 640), 'sheet_win_360x640', 1);
    await sheetPlate(tester, const Size(412, 915), 'sheet_loss_412x915', 13);
    debugPrint('STAGE: share card plates done');
  });
}
