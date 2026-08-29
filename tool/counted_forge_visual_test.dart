// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/counted_forge_visual_test.dart — manual visual-critique plates for
// v0.97.0 "The Counted Forge". Not part of CI.
//
//   flutter test tool/counted_forge_visual_test.dart
//
// Plates (build/counted_forge_visual/):
//   • counted_forge_360x800 — the hollow on a tall phone: forge rows
//     printing before → after dieFacts under the die names; the plain
//     d6 row stays quiet (restraint rule).
//   • counted_forge_320x568 — restraint plate: narrowest width, forge
//     list dragged into view; the facts line must wrap, not clip.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/counted_forge_visual';

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

GameController atRest({bool bonus = false}) {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: 3, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'rest' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  assert(c.phase == 'rest');
  // Force a readable mid-hurt state; the restraint plate stacks bedroll for
  // the longest wording ('Rest — heal 13 HP (10 → 23)').
  c.sim!.player['max_hp'] = 30;
  c.sim!.player['hp'] = bonus ? 10 : 21;
  c.sim!.run!['relics'] = <String>[if (bonus) 'bedroll'];
  // Mixed pool: a modded die (facts line), the longest facts wording
  // (ward → aegis, block only), and a plain d6 (quiet row — restraint).
  c.sim!.player['dice'] = <String>['d6_keen', 'd6_ward', 'd6'];
  (c.sim!.run!['custom_dice'] as Map?)?.clear();
  return c;
}

Future<void> captureRest(
  WidgetTester tester,
  Size logical,
  String name, {
  bool bonus = false,
  bool drag = false,
}) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final c = atRest(bonus: bonus);
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
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (drag) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('counted forge plates', (tester) async {
    await loadRealFonts();
    await captureRest(tester, const Size(360, 800), 'counted_forge_360x800');
    await captureRest(
      tester,
      const Size(320, 568),
      'counted_forge_320x568',
      drag: true,
    );
  });
}
