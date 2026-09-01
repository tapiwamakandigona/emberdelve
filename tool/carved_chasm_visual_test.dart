// temp plate: THE CARVED CHASM — map screen with rock walls, start + deep.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/carved_chasm_visual';

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

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 25) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('carved chasm plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = GameController();
    c.meta
      ..tutorialSeen = true
      ..tourSeenVersion = tourVersion
      ..tipsSeen.addAll(ContextTips.all);
    c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
    c.startRun(character: 'kindler', seed: 6, difficulty: 'easy');
    var guard = 0;
    while (c.phase != 'map' && guard++ < 50) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'map');

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: RepaintBoundary(key: key, child: GameRoot(c)),
      ),
    );
    await tester.binding.runAsync(
      () => Future.delayed(const Duration(milliseconds: 700)),
    );
    await pumpFor(tester, 900);
    await shoot(tester, key, 'chasm_start');

    // Descend a few floors, land back on a map view.
    guard = 0;
    var moved = 0;
    while (guard++ < 300) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      final wasMap = c.phase == 'map';
      c.apply(cmd);
      if (wasMap && c.phase != 'map') moved++;
      if (moved >= 3 && c.phase == 'map') break;
    }
    if (c.phase == 'map') {
      await tester.binding.runAsync(
        () => Future.delayed(const Duration(milliseconds: 400)),
      );
      await pumpFor(tester, 1200);
      await shoot(tester, key, 'chasm_deep');
    }
  });
}
