// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/peddler_visual_test.dart — manual visual-critique plates for the
// v0.40.0 fifth delver. Not part of CI.
//
//   flutter test tool/peddler_visual_test.dart
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

const outDir = 'build/peddler_visual';

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
  testWidgets('peddler plates: character card + live combat', (tester) async {
    await tester.binding.runAsync(loadRealFonts);

    Future<GlobalKey> mount(Size logical, GameController c) async {
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
            home: GameRoot(c),
          ),
        ),
      );
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return key;
    }

    // Plate 1: the delver roster scrolled to the Peddler's card.
    {
      final c = GameController();
      final key = await mount(const Size(360, 640), c);
      await tester.ensureVisible(find.text('Choose a delver'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Choose a delver'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.dragUntilVisible(
        find.text('The Peddler'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      // Settle so the card sits fully inside the frame.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 140));
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, key, 'peddler_card_360');
    }

    // Plate 2: live combat as the Peddler — teal sprite + Coin Hook on stage.
    {
      final c = GameController();
      final key = await mount(const Size(412, 915), c);
      c.startRun(character: 'peddler', seed: 2, boons: false);
      var guard = 0;
      while (guard++ < 200 && c.phase != 'player_turn') {
        final cmd = botCmd(c.sim!);
        if (cmd == null) break;
        c.apply(cmd);
      }
      expect(c.phase, 'player_turn', reason: 'bot must reach a fight');
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shoot(tester, key, 'peddler_combat_412');
    }
  });
}
