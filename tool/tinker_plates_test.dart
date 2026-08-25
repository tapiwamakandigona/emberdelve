// tool/tinker_plates_test.dart — screenshot plates for v0.50.0 The Tinker:
// the character card in the delver picker, the six-delver hearth, and the
// news post. Not part of CI: run manually, then LOOK at the plates (DEMAND:
// UI changes get a critique).
//   flutter test tool/tinker_plates_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';

const outDir = 'build/tinker_plates';

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
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  // Six-delver hearth: everyone unlocked.
  c.meta.unlockedCharacters.addAll(charactersOrder);
  await tester.pumpWidget(app(GameRoot(c)));
  // Let sprite sheets decode off the test clock, then settle the fade-in.
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await pumpFor(tester, 1400);
  await snap(tester, 'hearth_six_$suffix');

  // Delver picker with the Tinker card dragged into view.
  await tester.ensureVisible(find.text('Choose a delver'));
  await pumpFor(tester, 100);
  await tester.tap(find.text('Choose a delver'));
  await pumpFor(tester, 700);
  await tester.dragUntilVisible(
    find.text('The Tinker'),
    find.byType(Scrollable).first,
    const Offset(0, -200),
  );
  await pumpFor(tester, 400);
  await snap(tester, 'picker_tinker_$suffix');
}

Future<void> newsPlate(WidgetTester tester, String suffix) async {
  // Reset the element tree so GameRoot state (e.g. an open picker) from the
  // previous plate cannot leak into this one.
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // Fresh-but-stale profile: has played before, saw the previous post.
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..runsPlayed = 3
    ..lastSeenNewsVersion = '0.49.0';
  await tester.pumpWidget(app(GameRoot(c)));
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await pumpFor(tester, 1000);
  final panel = find.byKey(const ValueKey('news-panel'));
  await tester.scrollUntilVisible(panel, 80);
  await pumpFor(tester, 300);
  expect(panel, findsOneWidget);
  expect(find.textContaining('Tinker'), findsWidgets);
  await snap(tester, 'news_tinker_$suffix');
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('tinker plates 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await plates(tester, '360x640');
    await newsPlate(tester, '360x640');
  });

  testWidgets('tinker plates 412x915', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await plates(tester, '412x915');
  });

  testWidgets('tinker plates 800x1280', (tester) async {
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
    await newsPlate(tester, '320x570_t13');
  });
}
