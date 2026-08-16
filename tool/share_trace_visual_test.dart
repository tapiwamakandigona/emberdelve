// tool/share_trace_visual_test.dart — manual visual-critique plates for the
// v0.8.0 summary-screen floor trace + seed challenge button. Not part of CI.
//
//   flutter test tool/share_trace_visual_test.dart
//
// Note: the sandbox harness has no color-emoji font, so the grid squares
// render as tofu boxes here; on-device Android falls back to Noto Color
// Emoji. The plates verify LAYOUT (grid placement, spacing, button order,
// small-screen fit) — square color is verified by the unit tests on the
// share STRING itself.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/share_trace_visual';

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

void drive(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 3000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

Future<void> capture(
  WidgetTester tester,
  GameController c,
  String name,
  Size logical,
  double textScale, {
  String? scrollToKey,
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
            textScaler: TextScaler.linear(textScale),
          ),
          // Scaffold matches the in-app host (GameRoot wraps every screen in
          // a Scaffold); without a Material ancestor the harness paints
          // yellow double-underlines under all text.
          child: Scaffold(body: SummaryScreen(c)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  if (scrollToKey != null) {
    await tester.ensureVisible(find.byKey(ValueKey(scrollToKey)));
    await tester.pump(const Duration(milliseconds: 400));
  }
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
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('summary plates with trace + seed challenge', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    final dir = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_trace_visual'),
    );
    MetaStore.dirOverride = dir!.path;
    addTearDown(() => MetaStore.dirOverride = null);

    // A lost normal run (seed challenge + red-tail grid)...
    final lost = GameController(saveDirOverride: dir.path);
    lost.startRun(character: 'kindler', seed: 111);
    drive(lost);
    // ...and a WON run. Seed 503 wins for kindler/normal/boons-off under
    // botCmd (pre-hunted via tool/hunt_won_seed.dart — hunting through the
    // controller is too slow because every command autosaves).
    final won = GameController(saveDirOverride: dir.path);
    won.startRun(character: 'kindler', seed: 503);
    drive(won);
    expect(won.phase, 'run_won', reason: 'seed 503 must win; re-hunt if sim changed');

    await capture(tester, lost, 'lost_360x640', const Size(360, 640), 1.0);
    await capture(tester, lost, 'lost_320x568_1p3x', const Size(320, 568), 1.3);
    await capture(tester, won, 'won_360x640', const Size(360, 640), 1.0);
    await capture(tester, won, 'won_412x915', const Size(412, 915), 1.0);
    // Scrolled plates: the trace grid + seed-challenge button live below the
    // fold, so the top-of-screen plates never show the actual v0.8.0 work.
    await capture(tester, won, 'won_360x640_grid', const Size(360, 640), 1.0,
        scrollToKey: 'copy-seed-challenge');
    await capture(
        tester, lost, 'lost_320x568_1p3x_grid', const Size(320, 568), 1.3,
        scrollToKey: 'copy-seed-challenge');

    // The share strings themselves, for eyeball + paste checks.
    File('$outDir/share_texts.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'LOST (${lost.runTrace.marks.length} floors):\n'
        '${lost.seedChallengeShareText}\n\n'
        'WON (${won.runTrace.marks.length} floors, phase=${won.phase}):\n'
        '${won.seedChallengeShareText}\n',
      );
    await lost.flushSaves();
    await won.flushSaves();
  });
}
