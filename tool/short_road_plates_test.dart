// tool/short_road_plates_test.dart — screenshot plates for the v0.49.0
// Short Delve toggle (title screen) and a short-map overview. Not part of
// CI: run manually, then LOOK at the plates (DEMAND: UI changes get a
// critique).
//   flutter test tool/short_road_plates_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';

const outDir = 'build/short_road_plates';

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

final rootKey = GlobalKey();

Widget app(Widget child) => RepaintBoundary(
  key: rootKey,
  child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
);

Future<void> pumpFor(WidgetTester tester, int ms) async {
  var t = 0;
  while (t < ms) {
    await tester.pump(const Duration(milliseconds: 50));
    t += 50;
  }
}

Future<void> snap(WidgetTester tester, String name) async {
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final file = File('$outDir/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $outDir/$name.png (${image!.width}x${image.height})');
}

Future<void> plates(WidgetTester tester, String suffix) async {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  await tester.pumpWidget(app(GameRoot(c)));
  await pumpFor(tester, 600);
  await snap(tester, 'title_toggle_off_$suffix');

  await tester.tap(find.byKey(const ValueKey('short-road-toggle')));
  await pumpFor(tester, 400);
  expect(c.meta.preferShortRoad, isTrue);
  await snap(tester, 'title_toggle_on_$suffix');

  c.startRun(character: 'kindler', seed: 6, boons: false,
      shortRoad: c.meta.preferShortRoad);
  await pumpFor(tester, 800);
  expect(c.state!['map'], isNotNull);
  expect((c.state!['map'] as Map)['layers'], equals(6));
  await snap(tester, 'short_map_$suffix');
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('short road plates 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await plates(tester, '360x640');
  });

  testWidgets('short road plates 412x915', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await plates(tester, '412x915');
  });

  testWidgets('short road plates 800x1280', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await plates(tester, '800x1280');
  });

  testWidgets('overflow probe: 320px at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 570);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await plates(tester, '320x570_t13');
  });
}
