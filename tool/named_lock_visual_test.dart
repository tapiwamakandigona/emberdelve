// tool/named_lock_visual_test.dart — manual visual-critique plates for
// v0.180.0 "The Named Lock" (title difficulty segments + the Forge line).
// Not part of CI.   flutter test tool/named_lock_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart' show ContextTips;
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/named_lock_visual';

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

Future<void> capture(
  WidgetTester tester,
  Size logical,
  double textScale,
  String name,
) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final c = GameController();
  c.meta
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion
    ..runsPlayed = 3
    ..difficultyChosen = true;
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
          child: GameRoot(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  if (name.contains('top')) {
    // no scroll
  } else if (name.contains('bottom')) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
  } else {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('difficulty-hard')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.pump(const Duration(milliseconds: 300));
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

void main() {
  setUpAll(loadRealFonts);
  testWidgets('plates', (tester) async {
    await capture(tester, const Size(320, 568), 1.3, 'title_320x568_1_3x');
    await capture(tester, const Size(412, 915), 1.0, 'title_412x915');
    await capture(tester, const Size(360, 800), 1.0, 'title_360x800');
    await capture(tester, const Size(360, 640), 1.0, 'title_360x640');
    await capture(tester, const Size(360, 800), 1.0, 'title_360x800_bottom');
    await capture(tester, const Size(360, 800), 1.0, 'title_360x800_top');
    await capture(tester, const Size(412, 915), 1.0, 'title_412x915_top');
  });
}
