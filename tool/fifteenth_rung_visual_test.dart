// tool/fifteenth_rung_visual_test.dart — manual visual-critique plates
// for v0.143.0 "The Fifteenth Rung": the provings screen scrolled to
// the new rung with its delve-code line. Not part of CI.
//
//   flutter test tool/fifteenth_rung_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/provings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/fifteenth_rung_visual';

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
  final end = tester.binding.clock.now().add(Duration(milliseconds: ms));
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
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
  testWidgets('proven rules plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    addTearDown(tester.view.reset);

    GameController rulesMeta() {
      final c = GameController();
      c.meta.unlockedCharacters.add('warden');
      c.meta.forgeUnlocked = true; // maxAscensionFor rides the Forge
      c.meta.bestAscension = 15; // the rung must be climbable to show START
      c.meta.provingsCleared.addAll({'first_flame', 'tinkers_proving'});
      return c;
    }

    await plateScreen(
      tester,
      const Size(360, 640),
      rulesMeta(),
      'rung_360x640',
      scrollToKey: 'proving-start-fifteenth_rung',
      backDrag: 200,
    );
    await plateScreen(
      tester,
      const Size(320, 568),
      rulesMeta(),
      'rung_320x568',
      scrollToKey: 'proving-start-fifteenth_rung',
      backDrag: 200,
    );
  });
}
