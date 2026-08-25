// tool/epitaph_plates_test.dart — screenshot plates for v0.54.0 The
// Epitaph: the Delver's Card sheet after a real win and a real loss (the
// pinned seed-1 / seed-18 easy kindler pair), plus the news post. Not part
// of CI: run manually, then LOOK at the plates (DEMAND: UI changes get a
// critique).
//   flutter test tool/epitaph_plates_test.dart
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
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/epitaph_plates';

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

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

Future<void> cardPlate(WidgetTester tester, String suffix, int seed) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  final c = seasoned();
  await tester.pumpWidget(app(GameRoot(c)));
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await pumpFor(tester, 400);
  c.startRun(character: 'kindler', seed: seed, boons: true, difficulty: 'easy');
  driveToTerminal(c);
  final won = c.phase == 'run_won';
  await pumpFor(tester, 2500); // outlast the terminal-hold choreography
  final btn = find.byKey(const ValueKey('share-delve-card'));
  await tester.scrollUntilVisible(
    btn,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
  await tester.tap(btn);
  await pumpFor(tester, 600);
  expect(find.byType(DelverCard), findsOneWidget);
  expect(find.byKey(const ValueKey('card-epitaph')), findsOneWidget);
  await snap(tester, 'card_${won ? 'win' : 'loss'}_$suffix');
  await tester.tap(find.byKey(const ValueKey('card-close')));
  await pumpFor(tester, 400);
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
    ..lastSeenNewsVersion = '0.53.0';
  await tester.pumpWidget(app(GameRoot(c)));
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await pumpFor(tester, 1000);
  final panel = find.byKey(const ValueKey('news-panel'));
  await tester.scrollUntilVisible(panel, 80);
  await pumpFor(tester, 300);
  expect(panel, findsOneWidget);
  expect(find.textContaining('Epitaph'), findsWidgets);
  await snap(tester, 'news_epitaph_$suffix');
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('epitaph plates 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await cardPlate(tester, '360x640', 1); // win
    await cardPlate(tester, '360x640', 18); // loss
    await newsPlate(tester, '360x640');
  });

  testWidgets('epitaph plates 412x915', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await cardPlate(tester, '412x915', 1);
    await cardPlate(tester, '412x915', 18);
  });

  testWidgets('epitaph plates 800x1280', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await cardPlate(tester, '800x1280', 1);
    await cardPlate(tester, '800x1280', 18);
  });

  testWidgets('overflow probe: 320px at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 570);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await cardPlate(tester, '320x570_t13', 1);
    await cardPlate(tester, '320x570_t13', 18);
    await newsPlate(tester, '320x570_t13');
  });
}
