// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/tips_visual_test.dart — manual visual-critique plates for the
// v0.10.0 First Delve contextual tip cards. Not part of CI.
//
//   flutter test tool/tips_visual_test.dart
//
// Plates (build/tips_visual/):
//   tip_<id>_360x640      — each of the four cards over a live first fight
//   tip_block_fades_320x568_1p3x — the longest card at the smallest
//     supported screen with 1.3x text (short-screen anchor padding path)
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/tips_visual';

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
  GameController c,
  String name,
  Size logical,
  double textScale,
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
          data: MediaQueryData(
            size: logical,
            textScaler: TextScaler.linear(textScale),
          ),
          child: GameRoot(c),
        ),
      ),
    ),
  );
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Walk seed 1's map into its first fight (same walk as widget_test).
void walkToFight(GameController c) {
  c.startRun(character: 'kindler', seed: 1);
  final map = c.state!['map'] as Map;
  final edges = (map['edges'] as Map).cast<String, List>();
  var guard = 0;
  while (c.phase == 'map' && guard++ < 10) {
    final position = (c.state!['map'] as Map)['position'] as int;
    final next = (edges['$position'] as List).cast<int>().first;
    c.apply({'type': 'choose_node', 'node': next});
    if (c.phase == 'reward') c.apply({'type': 'choose_reward', 'index': 0});
    if (c.phase == 'rest') c.apply({'type': 'rest'});
    if (c.phase == 'shop') c.apply({'type': 'leave_shop'});
    if (c.phase == 'event') c.apply({'type': 'event_choose', 'option': 1});
  }
}

void main() {
  testWidgets('tips plates: all four cards + small-screen worst case', (
    tester,
  ) async {
    await tester.binding.runAsync(loadRealFonts);
    final dir = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_tips_visual'),
    );
    MetaStore.dirOverride = dir!.path;
    addTearDown(() => MetaStore.dirOverride = null);

    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    walkToFight(c);
    if (c.phase != 'player_turn') {
      fail('seed 1 walk did not reach a fight (phase=${c.phase})');
    }

    for (final id in ContextTips.all) {
      c.tipDirector.active = id;
      await capture(tester, c, 'tip_${id}_360x640', const Size(360, 640), 1.0);
    }
    c.tipDirector.active = ContextTips.blockFades;
    await capture(
      tester,
      c,
      'tip_block_fades_320x568_1p3x',
      const Size(320, 568),
      1.3,
    );
    c.tipDirector.active = null;

    // Teardown hygiene (sandbox save-queue flakiness): flush + reset meta.
    await tester.binding.runAsync(() => c.flushSaves());
    await tester.binding.runAsync(() => MetaStore.save(MetaState()));
  });
}
