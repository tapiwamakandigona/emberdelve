// tool/obituary_plates_test.dart — screenshot plates for v0.51.0 The
// Obituary: the summary screen with the delve story on a WIN and on a LOSS,
// and the Ledger's Recent Delves naming a killer. Not part of CI: run
// manually, then LOOK at the plates (DEMAND: UI changes get a critique).
//   flutter test tool/obituary_plates_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/obituary_plates';

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

GameController quietController() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  return c;
}

/// Bot-play [c] to a terminal phase, then outlast the terminal-hold
/// choreography so the summary is fully settled.
Future<void> playOut(WidgetTester tester, GameController c) async {
  await pumpFor(tester, 400);
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  await pumpFor(tester, 2500);
}

/// Summary with the story visible, on a pinned win (seed 1) or loss (18).
Future<GameController> summaryPlate(
  WidgetTester tester,
  String suffix, {
  required int seed,
  required String want,
}) async {
  // Reset the element tree so GameRoot state from the previous plate cannot
  // leak into this one (v0.50.0 lesson).
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  final c = quietController();
  await tester.pumpWidget(app(GameRoot(c)));
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  c.startRun(character: 'kindler', seed: seed, boons: true, difficulty: 'easy');
  await playOut(tester, c);
  expect(c.phase, want, reason: 'seed $seed must reach $want');
  final story = find.byKey(const ValueKey('delve-story'));
  await tester.scrollUntilVisible(story, -200);
  await pumpFor(tester, 300);
  expect(story, findsOneWidget);
  await snap(
    tester,
    'summary_${want == 'run_won' ? 'win' : 'loss'}_$suffix',
  );
  return c;
}

/// Ledger Recent Delves after the loss above — the row names the killer.
Future<void> ledgerPlate(
  WidgetTester tester,
  GameController c,
  String suffix,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pumpWidget(app(LedgerScreen(c)));
  await pumpFor(tester, 400);
  final row = find.byKey(const ValueKey('recent-delves'));
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await pumpFor(tester, 300);
  await snap(tester, 'ledger_killer_$suffix');
}

Future<void> all(WidgetTester tester, String suffix) async {
  await summaryPlate(tester, suffix, seed: 1, want: 'run_won');
  final c = await summaryPlate(tester, suffix, seed: 18, want: 'run_lost');
  await ledgerPlate(tester, c, suffix);
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('obituary plates 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await all(tester, '360x640');
  });

  testWidgets('obituary plates 412x915', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await all(tester, '412x915');
  });

  testWidgets('obituary plates 800x1280', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await all(tester, '800x1280');
  });

  testWidgets('overflow probe: 320px at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 570);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await all(tester, '320x570_t13');
  });
}
