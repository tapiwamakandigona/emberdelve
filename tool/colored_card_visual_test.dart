// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/colored_card_visual_test.dart — manual visual-critique plates for
// v0.99.0 "The Colored Card". Not part of CI.
//
//   flutter test tool/colored_card_visual_test.dart
//
// Plates (build/colored_card_visual/): the exported 3x card wearing each
// vista family against the Emberlight control — the wash must read as the
// delve's light without costing any line its legibility:
//   • card_emberlight_3x — identity control (must match pre-v0.99.0).
//   • card_moonveil_3x — the cool blue wash on a win card.
//   • card_hearthgold_3x — the v0.98.0 gilded wash on a win card.
//   • card_deepshale_3x — the desaturating wash on a LOSS card.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/colored_card_visual';

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

Future<void> save(
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

Future<void> cardPlate(
  WidgetTester tester,
  DelverCardFacts facts,
  String name,
) async {
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
  // Sprite decodes asynchronously — real async time before the snap.
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await save(tester, key, name, 3);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

DelverCardFacts factsFor(String vista, {int seed = 1}) {
  final c = GameController();
  c.meta.selectedVista = vista; // gate bypassed: pure facts for the plate
  c.startRun(character: 'kindler', seed: seed, boons: true, difficulty: 'easy');
  driveToTerminal(c);
  return DelverCardFacts.fromController(c);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('colored card plates', (tester) async {
    await loadRealFonts();
    await cardPlate(tester, factsFor('emberlight'), 'card_emberlight_3x');
    await cardPlate(tester, factsFor('moonveil'), 'card_moonveil_3x');
    await cardPlate(tester, factsFor('hearthgold'), 'card_hearthgold_3x');
    // Loss card (seed 18 loses) under the desaturating deep grade.
    await cardPlate(
      tester,
      factsFor('deepshale', seed: 18),
      'card_deepshale_3x',
    );
  });
}
