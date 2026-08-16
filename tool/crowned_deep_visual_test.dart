// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/crowned_deep_visual_test.dart — manual visual-critique plates for the
// v0.22.0 "Crowned Deep" content drop. Not part of CI.
//
//   flutter test tool/crowned_deep_visual_test.dart
//
// Plates:
//   codex_new_enemy_360x640 — the Codex scrolled to a v0.22.0 enemy
//     (Slag Regent, boss) with its 'Not yet met.' record line.
//   codex_new_enemy_320x568_1p3x — same, worst-case small screen at 1.3x.
//   codex_new_relic_360x640 — the Codex scrolled to the King's Ransom
//     relic entry (v0.22.0 multi-hook relic).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/crowned_deep_visual';

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
  String? scrollToKey,
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
  if (scrollToKey != null) {
    final target = find.byKey(ValueKey(scrollToKey));
    if (tester.any(target)) {
      await tester.ensureVisible(target);
    } else {
      // Lazily-built list item: scroll the list until it exists.
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.pump(const Duration(milliseconds: 100));
      // scrollUntilVisible can leave the target clipped at the viewport
      // edge; ensureVisible finishes the job once the widget exists.
      await tester.ensureVisible(target);
    }
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
  testWidgets('new embers plates: codex enemy + relic entries', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    final dir = await tester.binding.runAsync(
      () => Directory.systemTemp.createTemp('ed_crowned_visual'),
    );
    MetaStore.dirOverride = dir!.path;
    addTearDown(() => MetaStore.dirOverride = null);

    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());
    // One new enemy already fought once, its neighbours unmet — both record
    // copy shapes land in frame around the new entries.
    c.meta.enemyMet['hearthless_king'] = 1;
    c.meta.enemyFellTo['hearthless_king'] = 1;
    await capture(
      tester,
      CodexScreen(c),
      'codex_new_enemy_360x640',
      const Size(360, 640),
      1.0,
      scrollToKey: 'codex-enemy:slag_regent',
    );
    await capture(
      tester,
      CodexScreen(c),
      'codex_new_enemy_320x568_1p3x',
      const Size(320, 568),
      1.3,
      scrollToKey: 'codex-enemy:slag_regent',
    );
    debugPrint('STAGE: enemy plates done');

    await capture(
      tester,
      CodexScreen(c),
      'codex_new_relic_360x640',
      const Size(360, 640),
      1.0,
      scrollToKey: 'codex-relic:kings_ransom',
    ); // ValueKey('codex-${e.id}')
    debugPrint('STAGE: relic plate done');
  });
}
