// tool/summary_scroll_visual_test.dart — plates of the run-lost summary at
// 360×800, top / middle / bottom, for the scroll audit. Not part of CI.
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
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/summary_scroll_visual';
Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async => ByteData.sublistView(File(path).readAsBytesSync());
  final cinzel = FontLoader('Cinzel')..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load(); await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) { final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))); await icons.load(); }
  }
}
Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) { await tester.pump(const Duration(milliseconds: 50)); }
}
Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.binding.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('$outDir/$name.png')..createSync(recursive: true)..writeAsBytesSync(bytes!.buffer.asUint8List());
}
void main() {
  setUpAll(loadRealFonts);
  testWidgets('plates', (tester) async {
    const size = Size(360, 800);
    tester.view.physicalSize = size * 2; tester.view.devicePixelRatio = 2; addTearDown(tester.view.reset);
    final c = GameController();
    c.meta..tourSeenVersion = tourVersion..tutorialSeen = true..tipsSeen.addAll(ContextTips.all)..lastSeenNewsVersion = currentAppVersion..runsPlayed = 3..difficultyChosen = true;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildEmberTheme(), home: MediaQuery(data: const MediaQueryData(size: size), child: GameRoot(c)))));
    await pumpFor(tester, 400);
    c.startRun(character: 'kindler', seed: 7, boons: true);
    await pumpFor(tester, 300);
    var guard = 0;
    while (guard++ < 4000 && c.phase != 'run_won' && c.phase != 'run_lost') { final cmd = botCmd(c.sim!); if (cmd == null) break; c.apply(cmd); }
    await tester.binding.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await pumpFor(tester, 3500);
    await snap(tester, key, 'summary_top');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700)); await pumpFor(tester, 400);
    await snap(tester, key, 'summary_mid');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500)); await pumpFor(tester, 400);
    await snap(tester, key, 'summary_bottom');
  });

  testWidgets('character plates', (tester) async {
    const size = Size(360, 800);
    tester.view.physicalSize = size * 2; tester.view.devicePixelRatio = 2; addTearDown(tester.view.reset);
    final c = GameController();
    c.meta..tourSeenVersion = tourVersion..tutorialSeen = true..tipsSeen.addAll(ContextTips.all)..lastSeenNewsVersion = currentAppVersion..runsPlayed = 3;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildEmberTheme(), home: MediaQuery(data: const MediaQueryData(size: size), child: CharacterScreen(c)))));
    await tester.binding.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await pumpFor(tester, 800);
    await snap(tester, key, 'character_top');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700)); await pumpFor(tester, 400);
    await snap(tester, key, 'character_2');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700)); await pumpFor(tester, 400);
    await snap(tester, key, 'character_3');
    final s = tester.state<ScrollableState>(find.byType(Scrollable).first);
    // ignore: avoid_print
    print('CHAR extent=${s.position.maxScrollExtent}');
  });
}
