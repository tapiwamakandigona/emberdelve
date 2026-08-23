// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/nudge_visual_test.dart — manual visual-critique plates for the
// v0.29.0 post-Easy-win Normal invitation on the summary. Not part of CI.
//
//   flutter test tool/nudge_visual_test.dart
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

const outDir = 'build/nudge_visual';

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
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('PLATE-OK: $name');
}

void main() {
  testWidgets('nudge plates: easy-win summary, phone + tablet', (tester) async {
    await tester.binding.runAsync(loadRealFonts);

    Future<GameController> winEasy() async {
      final c = GameController();
      c.startRun(
        character: 'kindler',
        seed: 1,
        boons: true,
        difficulty: 'easy',
      );
      var guard = 0;
      while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
        final cmd = botCmd(c.sim!);
        if (cmd == null) break;
        c.apply(cmd);
      }
      expect(c.phase, 'run_won');
      return c;
    }

    Future<void> plate(Size logical, String name) async {
      tester.view.physicalSize = logical * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = await winEasy();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: MediaQuery(
              data: MediaQueryData(size: logical),
              child: SummaryScreen(c),
            ),
          ),
        ),
      );
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('normal-nudge')),
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, key, name);
    }

    await plate(const Size(412, 915), 'nudge_phone');
    await plate(const Size(800, 1280), 'nudge_tablet');
    await plate(const Size(360, 640), 'nudge_small');
  });
}
