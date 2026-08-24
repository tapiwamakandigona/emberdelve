// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/vistas_visual_test.dart — manual visual-critique plates for the
// v0.35.0 Vistas. Not part of CI.
//
//   flutter test tool/vistas_visual_test.dart
//
// Plates (build/vistas_visual/):
//   • bg_<vista>.png — the map backdrop under each vista at surface depth
//     (360x640): does each vista read as its own place?
//   • bg_<vista>_deep.png — same at depth 0.8: does the strata grade still
//     compose on top without turning to mud?
//   • wardrobe_360x640 / wardrobe_412x915 — the picker section, mixed
//     lock state (moonveil earned, verdigris/bloodstone locked).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/vistas_visual';

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

Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
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
}

Future<void> captureBackdrop(
  WidgetTester tester,
  String vistaId,
  double depth,
  String name,
) async {
  const logical = Size(360, 640);
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
        home: ScreenBackground(
          asset: 'assets/images/backgrounds/bg_map.png',
          grade: Art.backgroundGrade(depth, vistaId),
          wash: Art.backgroundWash(depth, vistaId),
          child: Center(
            child: Text(
              '${vistas[vistaId]!.name}\ndepth ${depth.toStringAsFixed(1)}',
              textAlign: TextAlign.center,
              style: EmberText.h2,
            ),
          ),
        ),
      ),
    ),
  );
  // First-mount sprite/image warm-up.
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await snap(tester, key, name);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> captureWardrobe(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name,
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
          data: MediaQueryData(size: logical),
          child: CharacterScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('vista-bloodstone')),
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 200,
  );
  await tester.ensureVisible(find.byKey(const ValueKey('vista-emberlight')));
  await tester.pump(const Duration(milliseconds: 400));
  await snap(tester, key, name);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('vista plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);

    for (final id in vistasOrder) {
      await captureBackdrop(tester, id, 0.0, 'bg_$id');
      await captureBackdrop(tester, id, 0.8, 'bg_${id}_deep');
    }

    final c = GameController();
    c.meta.runsWon = 1; // moonveil earned; verdigris/bloodstone locked
    c.meta.selectedVista = 'moonveil';
    await captureWardrobe(tester, c, const Size(360, 640), 'wardrobe_360x640');
    await captureWardrobe(tester, c, const Size(412, 915), 'wardrobe_412x915');
    debugPrint('STAGE: vista plates done');
  });
}
