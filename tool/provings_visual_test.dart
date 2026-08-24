// tool/provings_visual_test.dart — manual visual-critique plates for the
// v0.38.0 Provings. Not part of CI.
//
//   flutter test tool/provings_visual_test.dart
//
// Plates (build/provings_visual/):
//   • screen_fresh_360 / screen_fresh_412 — top of the list on a fresh meta
//     (startable card + delver-locked card in frame).
//   • screen_mixed — cleared mark + forge-locked hard proving in one frame.
//   • title_entry — the title screen's quiet Provings line.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/provings_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/provings_visual';

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

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
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
}

Future<void> plateScreen(
  WidgetTester tester,
  Size logical,
  GameController c,
  String name, {
  String? scrollToKey,
  double backDrag = 0,
}) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: logical),
          child: ProvingsScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await pumpFor(tester, 400);
  if (scrollToKey != null) {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(scrollToKey)),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    if (backDrag > 0) {
      await tester.drag(find.byType(Scrollable).first, Offset(0, backDrag));
    }
    await pumpFor(tester, 300);
  }
  await snap(tester, key, name);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('provings plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    addTearDown(tester.view.reset);

    // Fresh meta: The First Flame startable, The Shield Oath delver-locked.
    await plateScreen(
      tester,
      const Size(360, 640),
      GameController(),
      'screen_fresh_360',
    );
    await plateScreen(
      tester,
      const Size(412, 915),
      GameController(),
      'screen_fresh_412',
    );

    // Mixed: cleared mark, unlocked delvers, forge-locked hard proving.
    final c = GameController();
    c.meta.provingsCleared.addAll({'first_flame', 'loaded_dice'});
    c.meta.unlockedCharacters.addAll({'warden', 'gambler', 'ascetic'});
    c.meta.forgeUnlocked = true;
    c.meta.bestAscension = 10;
    await plateScreen(
      tester,
      const Size(360, 640),
      c,
      'screen_mixed',
      scrollToKey: 'proving-start-high_stakes',
      backDrag: 260,
    );

    // Title screen: the quiet Provings entry line above 'Delve a seed'.
    const logical = Size(360, 640);
    tester.view.physicalSize = logical * 2;
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    final c2 = GameController();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: logical),
            child: GameRoot(c2),
          ),
        ),
      ),
    );
    await tester.binding.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await pumpFor(tester, 400);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('provings-button')),
      100,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await pumpFor(tester, 300);
    await snap(tester, key, 'title_entry');

    debugPrint('STAGE: provings plates done');
  });
}
