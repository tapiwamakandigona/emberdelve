// tool/proving_plates_test.dart — screenshot plates for v0.52.0 The Tinker's
// Proving: the provings list scrolled to the new tenth row, the epithet
// picker showing the Well-Oiled card, and the news post. Not part of CI:
// run manually, then LOOK at the plates (DEMAND: UI changes get a critique).
//   flutter test tool/proving_plates_test.dart
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
import 'package:emberdelve/ui/provings_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/proving_plates';

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
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildEmberTheme(),
    home: child,
  ),
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

GameController seasoned() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  c.meta.unlockedCharacters.addAll(charactersOrder);
  return c;
}

Future<void> provingPlate(WidgetTester tester, String suffix) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  final c = seasoned();
  c.meta.charWins['tinker'] = 1; // Well-Oiled earned, proving startable
  await tester.pumpWidget(app(ProvingsScreen(c)));
  await pumpFor(tester, 400);
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('proving-start-tinkers_proving')),
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
  await pumpFor(tester, 300);
  expect(find.text("The Tinker's Proving"), findsOneWidget);
  await snap(tester, 'provings_tinker_$suffix');
}

Future<void> epithetPlate(WidgetTester tester, String suffix) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  final c = seasoned();
  c.meta.charWins['tinker'] = 1;
  c.meta.selectedEpithet = 'the_well_oiled';
  await tester.pumpWidget(app(CharacterScreen(c)));
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await pumpFor(tester, 600);
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('epithet-the_well_oiled')),
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await pumpFor(tester, 300);
  expect(find.text('the Well-Oiled'), findsWidgets);
  await snap(tester, 'epithet_well_oiled_$suffix');
}

Future<void> newsPlate(WidgetTester tester, String suffix) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..runsPlayed = 3
    ..lastSeenNewsVersion = '0.51.0';
  await tester.pumpWidget(app(GameRoot(c)));
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await pumpFor(tester, 1000);
  final panel = find.byKey(const ValueKey('news-panel'));
  await tester.scrollUntilVisible(panel, 80);
  await pumpFor(tester, 300);
  expect(panel, findsOneWidget);
  expect(find.textContaining('Proving'), findsWidgets);
  await snap(tester, 'news_proving_$suffix');
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('proving plates 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await provingPlate(tester, '360x640');
    await epithetPlate(tester, '360x640');
    await newsPlate(tester, '360x640');
  });

  testWidgets('proving plates 412x915', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await provingPlate(tester, '412x915');
    await epithetPlate(tester, '412x915');
  });

  testWidgets('proving plates 800x1280', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await provingPlate(tester, '800x1280');
    await epithetPlate(tester, '800x1280');
  });

  testWidgets('overflow probe: 320px at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 570);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await provingPlate(tester, '320x570_t13');
    await epithetPlate(tester, '320x570_t13');
    await newsPlate(tester, '320x570_t13');
  });
}
