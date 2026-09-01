// temp plate: THE KINDLED TALE — rest hollow tale mid-smolder + settled.
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

const outDir = 'build/kindled_tale_visual';

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
  testWidgets('kindled tale plates', (tester) async {
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
    while (c.phase != 'rest' && guard++ < 400) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'rest');

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
    // Walk past the phase fade, then catch the sweep.
    for (var t = 0; t < 800; t += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byKey(const ValueKey('hearth-tale')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 250));
    await shoot(tester, key, 'smolder_mid');
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, key, 'smolder_late');
    await tester.pump(const Duration(milliseconds: 600));
    await shoot(tester, key, 'smolder_settled');
  });
}
