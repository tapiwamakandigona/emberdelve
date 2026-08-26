// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/wardrobe_visual_test.dart — manual visual-critique plates for the
// v0.27.0 "Delver's Wardrobe" dyes. Not part of CI.
//
//   flutter test tool/wardrobe_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;
import 'package:emberdelve/data/attire.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/wardrobe_visual';

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
  testWidgets('wardrobe plates: rack, worn dye, dye sampler', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    const logical = Size(412, 915);
    tester.view.physicalSize = logical * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final c = GameController();
    c.meta.embers = 5000;

    Future<void> pumpChar(GlobalKey key) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: MediaQuery(
              data: const MediaQueryData(size: logical),
              child: CharacterScreen(c),
            ),
          ),
        ),
      );
      // Sprite decode needs REAL async (image codec) — fake-async pumps
      // alone leave first-mount sprites blank (the 800x1280 title-plate
      // artifact). Run the event loop for real, then pump to paint.
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Plate 1: the rack, scrolled into view, nothing bought yet.
    var key = GlobalKey();
    await pumpChar(key);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dye-wyrmshade')),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await shoot(tester, key, 'wardrobe_rack');

    // Plate 2: emberwash bought + worn; portraits at top show the dye.
    // The rack plate left us at the bottom; the emberwash card is a disposed
    // lazy child — scroll back UP (negative delta) to rebuild it first.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dye-emberwash')),
      -200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('dye-emberwash')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('dye-emberwash')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.meta.dyeFor('kindler'), 'emberwash', reason: 'dye must be worn');
    key = GlobalKey();
    await pumpChar(key);
    await shoot(tester, key, 'portraits_emberwash');

    // Plate 3: sampler — the delver sprite in every dye side by side.
    key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xFF17121C),
            body: Center(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final id in delverDyesOrder)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SpriteView(
                          'kindler',
                          height: 96,
                          animate: false,
                          dye: Art.dyeFilter(id),
                        ),
                        Text(
                          delverDyes[id]!.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
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
    await shoot(tester, key, 'dye_sampler');
  });
}
