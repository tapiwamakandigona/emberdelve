// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/gramophone_visual_test.dart — manual visual-critique plates for the
// v0.33.0 Gramophone section in the Ledger. Not part of CI.
//
//   flutter test tool/gramophone_visual_test.dart
//
// Plates (build/gramophone_visual/): mixed heard state (title/map/victory
// heard; combat/boss/defeat locked) at 360x640, 412x915, 800x1280, plus a
// playing-state plate at 360x640 (Hearthside tapped).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/gramophone_visual';

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
  Widget screen,
  String name,
  Size logical,
  double textScale, {
  bool tapHearthside = false,
}) async {
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
        home: MediaQuery(
          data: MediaQueryData(
            size: logical,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  // The Ledger is a lazy ListView — the Gramophone lives near the bottom and
  // is not built until scrolled into existence.
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('gramophone-section')),
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 200,
  );
  await tester.ensureVisible(find.byKey(const ValueKey('gramophone-section')));
  await tester.pump(const Duration(milliseconds: 400));
  if (tapHearthside) {
    await tester.tap(find.text('Hearthside'));
    await tester.pump(const Duration(milliseconds: 400));
  }
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
}

void main() {
  testWidgets('gramophone plates: mixed heard state', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    final dir = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_gramo_visual'),
    );
    MetaStore.dirOverride = dir!.path;
    addTearDown(() => MetaStore.dirOverride = null);

    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    c.meta.heardTracks.addAll({'title_menu', 'map', 'victory'});

    await capture(
        tester, LedgerScreen(c), 'gramophone_360x640', const Size(360, 640), 1.0);
    await capture(tester, LedgerScreen(c), 'gramophone_412x915',
        const Size(412, 915), 1.0);
    await capture(tester, LedgerScreen(c), 'gramophone_800x1280',
        const Size(800, 1280), 1.0);
    await capture(tester, LedgerScreen(c), 'gramophone_playing_360x640',
        const Size(360, 640), 1.0,
        tapHearthside: true);
    debugPrint('STAGE: gramophone plates done');
  });
}
