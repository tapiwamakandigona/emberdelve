// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/hedger_visual_test.dart — manual visual-critique plates for THE
// HEDGER (v0.179.0): character screen with the seventeenth chair unlocked,
// and the hedger standing in combat. Not part of CI.
//
//   flutter test tool/hedger_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/hedger_visual';

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

Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  Directory(outDir).createSync(recursive: true);
  File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $outDir/$name.png');
}

GameController seasoned() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = 99
    ..embers = 2600
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.meta.unlockedCharacters.addAll(charactersOrder);
  return c;
}

void main() {
  testWidgets('character screen with the hedger (360x640 @1.0)', (
    tester,
  ) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: RepaintBoundary(key: key, child: CharacterScreen(c)),
      ),
    );
    await tester.binding.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    // The hedger is the LAST row — drag to the bottom in big steps
    // (lazy ListView: the row has no element until scrolled into view).
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 25));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    await shoot(tester, key, 'character-screen-hedger');
  });

  testWidgets('hedger stands in combat (seed 17 normal)', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    c.startRun(character: 'hedger', seed: 17, boons: false);
    var guard = 0;
    while (guard++ < 200 && c.phase != 'player_turn') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: RepaintBoundary(key: key, child: CombatScreen(c)),
      ),
    );
    await tester.binding.runAsync(
      () => Future.delayed(const Duration(milliseconds: 400)),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    await shoot(tester, key, 'combat-hedger');
  });
}
