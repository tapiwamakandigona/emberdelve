// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/coming_vista_visual_test.dart — manual visual-critique plates for
// v0.76.0 "The New Song". Not part of CI.
//
//   flutter test tool/coming_vista_visual_test.dart
//
// Plates (build/coming_vista_visual/):
//   • coming_vista_360x640 — a first win: the collapsed '"…" and N more join
//     the Gramophone' line sits with the firsts-line, quiet and unclipped.
//   • coming_vista_320x568 — the restraint plate: narrowest supported width,
//     the line must not clip or wrap ugly.
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

const outDir = 'build/coming_vista_visual';

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
          child: Material(color: EmberColors.bg, child: SummaryScreen(c)),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('coming-vista')),
    -200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Loss with a new depth record: the Deepshale line (seed 22 — felled 2,
/// deepest floor 7 of 9).
GameController depthLoss() {
  final c = GameController();
  c.meta.bestFloor = 1;
  c.startRun(character: 'kindler', seed: 22, difficulty: 'easy');
  driveToTerminal(c);
  assert(c.phase == 'run_lost');
  return c;
}

/// Win with the Verdigris line — the longest wording this feature can emit
/// ('The Verdigris vista waits — NN of 15 different foes felled.').
GameController felledWin() {
  final c = GameController();
  c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
  driveToTerminal(c);
  assert(c.phase == 'run_won');
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coming vista plates', (tester) async {
    await loadRealFonts();
    await captureSummary(
      tester,
      depthLoss(),
      const Size(360, 640),
      'coming_vista_depth_360x640',
    );
    await captureSummary(
      tester,
      felledWin(),
      const Size(320, 568),
      'coming_vista_felled_320x568',
    );
  });
}
