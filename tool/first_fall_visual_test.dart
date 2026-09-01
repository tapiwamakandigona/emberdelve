// tool plate: THE FIRST FALL line on a fresh profile's first loss at 320px
// (1.0x and 1.3x text). NOT in CI.
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

const outDir = 'build/first_fall_visual';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String p) async =>
      ByteData.sublistView(File(p).readAsBytesSync());
  final c = FontLoader('Cinzel')..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final i = FontLoader('Inter')..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await c.load(); await i.load();
  final fr = Platform.environment['FLUTTER_ROOT'];
  final f = File('$fr/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (f.existsSync()) {
    final ic = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await ic.load();
  }
}

Future<void> shoot(WidgetTester t, GlobalKey k, String name) async {
  final b = k.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = await t.binding.runAsync(() => b.toImage(pixelRatio: 2));
  final bytes = await t.binding.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
  File('$outDir/$name.png')..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('PLATE-OK: $name');
}

Future<void> pumpFor(WidgetTester t, int ms) async {
  for (var e = 0; e < ms; e += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scale in [1.0, 1.3]) {
    testWidgets('first fall plates $scale', (tester) async {
      await tester.binding.runAsync(loadRealFonts);
      const logical = Size(320, 568);
      tester.view.physicalSize = logical * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final c = GameController();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: GameRoot(c),
        ),
      ));
      c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
      await pumpFor(tester, 400);
      var guard = 0;
      while (guard++ < 400 && c.phase != 'run_lost' && c.phase != 'run_won') {
        final cmd = botCmd(c.sim!);
        if (cmd == null) break;
        c.apply(cmd);
      }
      await tester.binding.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
      await pumpFor(tester, 2500);
      final line = find.byKey(const ValueKey('first-fall'));
      await tester.scrollUntilVisible(line, 200);
      await pumpFor(tester, 400);
      final tag = scale == 1.0 ? '10x' : '13x';
      await shoot(tester, key, 'summary_first_fall_320_$tag');
    });
  }
}
