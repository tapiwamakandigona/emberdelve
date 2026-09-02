// tool/codex_lanes_visual_test.dart — manual visual-critique plates for
// the Codex Lanes: the chip bar at phone and narrow widths, and the list
// landed on THE DICE / walked back to THE WORLD. Not part of CI.
//
//   flutter test tool/codex_lanes_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/codex_lanes_visual';

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

GameController richMeta() {
  final c = GameController();
  c.meta.embers = 350;
  return c;
}

Future<void> capture(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name, {
  String? lane,
  String? thenLane,
  String? scrollTo,
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
          data: MediaQueryData(size: logical),
          child: CodexScreen(c),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  Future<void> walk(String id) async {
    await tester.ensureVisible(find.byKey(ValueKey('codex-lane-$id')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('codex-lane-$id')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  if (lane != null) await walk(lane);
  if (thenLane != null) await walk(thenLane);
  if (scrollTo != null) {
    final target = find.byKey(ValueKey('codex-$scrollTo'));
    for (var i = 0; i < 160 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CodexScreen), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(target);
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plates: codex lanes at phone and narrow widths', (tester) async {
    await loadRealFonts();
    await capture(tester, richMeta(), const Size(390, 844), 'top_phone');
    await capture(
      tester,
      richMeta(),
      const Size(390, 844),
      'dice_phone',
      lane: 'dice',
    );
    await capture(
      tester,
      richMeta(),
      const Size(390, 844),
      'back_world_phone',
      lane: 'dice',
      thenLane: 'world',
    );
    // v0.180.0 The Wayside: the world shelf's ninth card, unsealed, at
    // phone width — scrolled to the bottom of the world shelf.
    final wayside = richMeta();
    wayside.meta.ownedCodex.add('place:the_wayside');
    await capture(
      tester,
      wayside,
      const Size(390, 844),
      'wayside_phone',
      scrollTo: 'place:the_wayside',
    );
    // v0.180.0 The Set Stones: the keystone shelf, two of four unsealed, at
    // phone width and at 320.
    for (final (size, name) in const [
      (Size(390, 844), 'stones_phone'),
      (Size(320, 568), 'stones_narrow'),
    ]) {
      final stones = richMeta();
      stones.meta.ownedCodex.addAll([
        'keystone:ashen_edge',
        'keystone:living_bastion',
      ]);
      await capture(
        tester,
        stones,
        size,
        name,
        lane: 'stones',
        scrollTo: 'keystone:ashen_edge',
      );
    }
    await capture(tester, richMeta(), const Size(320, 568), 'top_narrow');
    await capture(
      tester,
      richMeta(),
      const Size(320, 568),
      'rules_narrow',
      lane: 'rules',
    );
  });
}
