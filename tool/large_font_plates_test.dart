// tool/large_font_plates_test.dart — manual visual-critique plates at 1.3x
// system text (Android "Large"), 320px wide: the accessibility worst case.
// The overflow probe catches ERRORS at 1.3x; these plates catch what it
// cannot — ellipsized words, cramped rows, unreadable shrinks. Not in CI.
//
//   flutter test tool/large_font_plates_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show ByteData, FontLoader;

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/large_font_plates';
const scale = 1.3;

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

Future<GlobalKey> pumpAt(
  WidgetTester tester,
  Size logical,
  Widget home, {
  int warmupMs = 600,
}) async {
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
          data: MediaQueryData(
            size: logical,
            textScaler: const TextScaler.linear(scale),
          ),
          child: home,
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(Duration(milliseconds: warmupMs)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return key;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('large-font plates: title, picker, summary, settings', (
    tester,
  ) async {
    await tester.binding.runAsync(loadRealFonts);
    const narrow = Size(320, 568);

    // -- Title with the day-2 return line active ------------------------
    final ct = GameController();
    ct.markTutorialSeen();
    ct.meta
      ..runsPlayed = 3
      ..tipsSeen.addAll(['shared_delve'])
      ..lastDailyDate = dailyKey(
        DateTime.now().subtract(const Duration(days: 1)),
      )
      ..lastDailyWon = false
      ..lastDailyFloor = 5
      ..lastDailyFloors = 9;
    var key = await pumpAt(tester, narrow, GameRoot(ct));
    await shoot(tester, key, 'title_day2_320_13x');

    // -- Wardrobe picker, full roster ------------------------------------
    final cp = GameController();
    cp.meta
      ..unlockedCharacters.addAll(charactersOrder)
      ..embers = 1200;
    key = await pumpAt(tester, narrow, CharacterScreen(cp), warmupMs: 900);
    await shoot(tester, key, 'picker_320_13x');

    // -- Summary (loss, next-delver panel) --------------------------------
    final cs = GameController();
    cs.startRun(character: 'kindler', seed: 13, boons: true, difficulty: 'easy');
    var guard = 0;
    while (guard++ < 400 && cs.phase != 'run_won' && cs.phase != 'run_lost') {
      final cmd = botCmd(cs.sim!);
      if (cmd == null) break;
      cs.apply(cmd);
    }
    key = await pumpAt(tester, narrow, SummaryScreen(cs));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('next-delver')),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, key, 'summary_next_delver_320_13x');

    // -- Settings, top ----------------------------------------------------
    key = await pumpAt(tester, narrow, const SettingsScreen());
    await shoot(tester, key, 'settings_top_320_13x');
  });
}
