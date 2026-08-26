// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/guttering_foe_visual_test.dart — manual visual-critique plates for
// v0.87.0 "The Guttering Foe". Not part of CI.
//
//   flutter test tool/guttering_foe_visual_test.dart
//
// Plates (build/guttering_foe_visual/):
//   • guttering_foe_360x640 — the enemy bar guttering gold, NEARLY SPENT
//     caption, mid-fight.
//   • guttering_foe_320x568 — restraint plate: narrowest width, caption
//     with a two-digit turn count must not clip.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/guttering_foe_visual';

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

GameController atFight() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'player_turn' && guard++ < 20) {
    final map = c.state!['map'] as Map;
    final pos = map['position'] as int;
    final edges = ((map['edges'] as Map)['$pos'] as List).cast<int>();
    c.apply({'type': 'choose_node', 'node': edges.first});
    if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
    if (c.phase == 'rest') c.apply({'type': 'rest'});
    if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
    if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
  }
  assert(c.phase == 'player_turn');
  // Force the gutter so the plate shows the tell; two-digit turn for the
  // restraint plate's longest caption.
  c.sim!.enemy!['max_hp'] = 30;
  c.sim!.enemy!['hp'] = 9;
  c.sim!.turn = 12;
  return c;
}

Future<void> captureFight(
  WidgetTester tester,
  Size logical,
  String name,
) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final c = atFight();
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
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guttering foe plates', (tester) async {
    await loadRealFonts();
    await captureFight(tester, const Size(360, 640), 'guttering_foe_360x640');
    await captureFight(tester, const Size(320, 568), 'guttering_foe_320x568');
  });
}
