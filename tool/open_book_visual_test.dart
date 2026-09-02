// tool/open_book_visual_test.dart — v0.180.0 The Open Book: the title
// footer with the 'How to play' link (fresh profile, scrolled to the footer)
// and the primer's first card, at 320×568 and 360×800.
// tool/fresh_walk_visual_test.dart — plates of a BRAND-NEW profile's first
// minutes at 360×800 with the shipped fonts: title, boon, map, first fight
// (tour beat), the run's end (summary). Critique pass for everything the
// v0.180.0 draft touched on that path. Not CI.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/open_book_visual';

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
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 30; i++) {
    if (tester.takeException() == null) break;
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
  // ignore: avoid_print
  print(
    'PLATE $name phase=${find.byType(GameRoot).evaluate().isEmpty ? '?' : ''}',
  );
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(320, 568), Size(360, 800)]) {
    testWidgets('open book ${size.width.toInt()}', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = GameController();
      c.meta.lastSeenNewsVersion = currentAppVersion;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: GameRoot(c),
          ),
        ),
      );
      await pumpFor(tester, 1500);
      final link = find.byKey(const ValueKey('how-to-play'));
      await snap(tester, key, 'title_top_${size.width.toInt()}');
      await tester.tap(link);
      await pumpFor(tester, 800);
      await snap(tester, key, 'primer_1_${size.width.toInt()}');
      await tester.tap(find.text('Next'));
      await pumpFor(tester, 300);
      await snap(tester, key, 'primer_2_${size.width.toInt()}');
    });
  }
}
