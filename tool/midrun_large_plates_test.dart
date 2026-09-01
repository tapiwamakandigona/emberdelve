// tool/midrun_large_plates_test.dart — THE LARGE PRINT doctrine sweep over
// the mid-run surfaces (tool/, NOT in CI): reward, rest, shop, event, and
// the WIN summary at 320px in BOTH 1.0x and 1.3x text scale. These are the
// last freeze-era surfaces not re-plated since large_font_plates landed.
// overflow_probe catches layout ERRORS at these sizes; only plates catch a
// clipped or ellipsized WORD.
//
//   flutter test tool/midrun_large_plates_test.dart
//
// Seeds (kindler easy, simVersion 7): seed 7 reaches shop, seed 6 reaches
// rest, seed 1 wins; reward/event walked to on their own seeds below.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/midrun_large_plates';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String p) async =>
      ByteData.sublistView(File(p).readAsBytesSync());
  final c = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final i = FontLoader('Inter')..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await c.load();
  await i.load();
  final fr = Platform.environment['FLUTTER_ROOT'];
  final f = File(
    '$fr/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (f.existsSync()) {
    final ic = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await ic.load();
  }
}

Future<void> pumpFor(WidgetTester t, int ms) async {
  for (var e = 0; e < ms; e += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> shoot(WidgetTester t, GlobalKey k, String name) async {
  final b = k.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = await t.binding.runAsync(() => b.toImage(pixelRatio: 2));
  final bytes = await t.binding.runAsync(
    () => img!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('PLATE-OK: $name');
}

/// Walk the kindler to the given phase with the autoplay bot.
GameController walkTo(String phase, {int seed = 7}) {
  final c = GameController();
  c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
  var guard = 0;
  while (c.phase != phase &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, phase, reason: 'seed $seed walk must reach $phase');
  return c;
}

Future<void> plate(
  WidgetTester tester,
  String name,
  double scale,
  GameController c,
) async {
  const logical = Size(320, 568);
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
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: GameRoot(c),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 700)),
  );
  await pumpFor(tester, 1200);
  final tag = scale == 1.0 ? '10x' : '13x';
  await shoot(tester, key, '${name}_320_$tag');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scale in [1.0, 1.3]) {
    testWidgets('mid-run plates at $scale', (tester) async {
      await tester.binding.runAsync(loadRealFonts);
      await plate(tester, 'reward', scale, walkTo('reward', seed: 7));
      await plate(tester, 'rest', scale, walkTo('rest', seed: 6));
      await plate(tester, 'shop', scale, walkTo('shop', seed: 7));
      await plate(tester, 'event', scale, walkTo('event', seed: 7));
      // The WIN summary (seed 1 wins): terminal walk, meta pre-seeded so
      // no overlays intrude.
      final c = GameController();
      c.markTutorialSeen();
      c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
      var guard = 0;
      while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
        final cmd = botCmd(c.sim!);
        if (cmd == null) break;
        c.apply(cmd);
      }
      expect(c.phase, 'run_won');
      await plate(tester, 'summary_win', scale, c);
    });
  }
}
