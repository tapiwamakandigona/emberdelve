// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/hearth_tale_visual_test.dart — manual visual-critique plates for
// v0.96.0 "The Hearth Tale". Not part of CI.
//
//   flutter test tool/hearth_tale_visual_test.dart
//
// Plates (build/hearth_tale_visual/):
//   • hearth_tale_360x640 — fresh profile: the first tale under the
//     hollow's subtitle, quoted, italic, dim.
//   • hearth_tale_320x568 — restraint plate: narrowest width, the
//     LONGEST tale forced (arc index of the longest string) must wrap
//     cleanly and never crowd the buttons.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/tales.dart';
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

const outDir = 'build/hearth_tale_visual';

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

GameController atRest({bool bonus = false, int heard = 0}) {
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
  c.meta.hearthTalesHeard = heard;
  return c;
}

Future<void> captureRest(
  WidgetTester tester,
  Size logical,
  String name, {
  bool bonus = false,
  int heard = 0,
}) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final c = atRest(bonus: bonus, heard: heard);
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

  testWidgets('hearth tale plates', (tester) async {
    await loadRealFonts();
    await captureRest(tester, const Size(360, 640), 'hearth_tale_360x640');
    var longest = 0;
    for (var i = 0; i < hearthTales.length; i++) {
      if (hearthTales[i].length > hearthTales[longest].length) longest = i;
    }
    await captureRest(
      tester,
      const Size(320, 568),
      'hearth_tale_320x568',
      bonus: true,
      heard: longest,
    );
  });
}
