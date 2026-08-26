// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/earned_name_visual_test.dart — manual visual-critique plates for
// v0.61.0 "The Deepest Mark". Not part of CI.
//
//   flutter test tool/earned_name_visual_test.dart
//
// Plates (build/earned_name_visual/):
//   • deepest_win_360x640 — a record-setting WIN summary: the gold line
//     sits among the other quiet lines without shouting.
//   • deepest_loss_320x568 — the dignity plate: a record-setting LOSS on
//     the narrowest supported width. The line must not clip or wrap ugly.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/earned_name_visual';

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

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

Future<void> captureSummary(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name, {
  required String lineKey,
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
          // Material host like GameRoot provides in-game — without it every
          // Text paints the yellow missing-DefaultTextStyle underline.
          child: Material(color: EmberColors.bg, child: SummaryScreen(c)),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  // The line sits below the fold — bring it into view before the snap.
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(lineKey)),
    -200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('earned name plates', (tester) async {
    await loadRealFonts();

    // First-ever win earns the Delver: the line rides with the other
    // quiet lines (achievements, rank) on the summary.
    final win = GameController();
    win.startRun(
      character: 'kindler',
      seed: 1,
      boons: true,
      difficulty: 'easy',
    );
    driveToTerminal(win);
    assert(win.phase == 'run_won');
    assert(win.pendingEpithets.contains('the_delver'));
    await captureSummary(
      tester,
      win,
      const Size(360, 640),
      'earned_win_360x640',
      lineKey: 'earned-name-the_delver',
    );

    // A LOSS that earns the Thorough, on the narrowest width.
    final loss = GameController();
    loss.meta.runsPlayed = 9; // this loss is the tenth ended run
    loss.startRun(
      character: 'kindler',
      seed: 18,
      boons: true,
      difficulty: 'easy',
    );
    driveToTerminal(loss);
    assert(loss.phase == 'run_lost');
    assert(loss.pendingEpithets.contains('the_thorough'));
    await captureSummary(
      tester,
      loss,
      const Size(320, 568),
      'earned_loss_320x568',
      lineKey: 'earned-name-the_thorough',
    );
  });
}
