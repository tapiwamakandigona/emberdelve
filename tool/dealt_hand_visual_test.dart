// temp plate: THE DEALT HAND — boon screen mid-deal frames (deal start,
// mid-stagger, settled) at 360x800.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/dealt_hand_visual';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dealt hand plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: RepaintBoundary(key: key, child: GameRoot(c)),
      ),
    );
    await tester.binding.runAsync(
      () => Future.delayed(const Duration(milliseconds: 700)),
    );
    c.startRun(character: 'kindler', boons: true, seed: 1);

    // Walk to the moment card 1 starts moving, then plate three beats.
    for (var t = 0; t < 1000; t += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      final found = find.byKey(const ValueKey('boon-1')).evaluate();
      if (found.isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, key, 'deal_start');
    await tester.pump(const Duration(milliseconds: 150));
    await shoot(tester, key, 'deal_mid');
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, key, 'deal_settled');
  });
}
