// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/pictured_satchel_visual_test.dart — manual visual-critique plates for
// v0.93.0 "The Pictured Satchel". Not part of CI.
//
//   flutter test tool/pictured_satchel_visual_test.dart
//
// Plates (build/pictured_satchel_visual/):
//   • pictured_satchel_360x640 — the inventory dialog, five relics with
//     icons, starting relic tagged.
//   • pictured_satchel_320x568 — restraint plate: same satchel at the
//     narrowest width (longest effect texts must wrap cleanly).
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

const outDir = 'build/pictured_satchel_visual';

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

GameController atShop({int seed = 7}) {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'shop' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  assert(c.phase == 'shop');
  return c;
}

GameController atSatchel() {
  final c = atShop(); // live sim; kindler starts with the whetstone
  c.sim!.run!['relics'] = <String>[
    'whetstone',
    'bedroll',
    'fire_salve',
    'cairn_stone',
    'choir_censer',
  ];
  return c;
}

Future<void> captureSatchel(
  WidgetTester tester,
  Size logical,
  String name,
) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final c = atSatchel();
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
  await tester.tap(find.byKey(const ValueKey('topbar-relics')));
  // Build the dialog FIRST so its Image widgets start decoding, THEN give
  // the decoder real time off the fake clock, then repaint. Cold-cache
  // rows print blank leads if the delay comes before the build.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pictured satchel plates', (tester) async {
    await loadRealFonts();
    await captureSatchel(
      tester,
      const Size(360, 640),
      'pictured_satchel_360x640',
    );
    await captureSatchel(
      tester,
      const Size(320, 568),
      'pictured_satchel_320x568',
    );
  });
}
