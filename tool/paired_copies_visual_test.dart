// tool/paired_copies_visual_test.dart — plates for The Paired Copies: the
// summary's copy row at 320×568 (1.3× text) and 360×800, scrolled to the row.
// Writes build/paired_copies_visual/*.png. Reports, never asserts on pixels.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/paired_copies_visual';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/'
        'material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then((b) => b.buffer.asByteData()),
    );
  await cinzel.load();
  await inter.load();
  await icons.load();
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> plate(
  WidgetTester tester,
  Size logical,
  double scale,
  String name,
) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  final c = GameController();
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    ),
  );
  c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
  await pumpFor(tester, 400);
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  await pumpFor(tester, 2500);
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('copy-seed-challenge')),
    -200,
  );
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
  await pumpFor(tester, 600);
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
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  tester.view.reset();
}

void main() {
  testWidgets('paired copies plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    await plate(tester, const Size(320, 568), 1.3, 'row_320x568_1p3x');
    await plate(tester, const Size(360, 800), 1.0, 'row_360x800');
    await plate(tester, const Size(412, 915), 1.0, 'row_412x915');
  });
}
