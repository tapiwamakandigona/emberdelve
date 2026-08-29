// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/hearthgold_visual_test.dart — manual visual-critique plates for
// v0.98.0 "The Hearthgold". Not part of CI.
//
//   flutter test tool/hearthgold_visual_test.dart
//
// Plates (build/hearthgold_visual/):
//   • hearthgold_map_360x800 — the map wearing the Hearthgold grade: the
//     first brightening vista, gilded but readable, distinct from the
//     Emberlight identity.
//   • hearthgold_card_locked_320x568 — the vista shelf scrolled to the
//     Hearthgold card while locked: the honest milestone line at the
//     narrowest supported width.
//   • hearthgold_card_worn_360x640 — the same card unlocked and WORN.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/hearthgold_visual';

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

Future<void> snap(
  WidgetTester tester,
  GlobalKey key,
  String name,
  double ratio,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: ratio),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void quietMeta(GameController c) {
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
}

/// A run on the map wearing the Hearthgold: the unlock is earned honestly
/// (full tale cycle heard) and the vista selected before the run starts.
GameController hearthgoldRun() {
  final c = GameController();
  quietMeta(c);
  c.meta.hearthTalesHeard = hearthgoldTales;
  c.selectVista('hearthgold');
  c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
  return c;
}

/// The vista shelf: locked (mid-cycle) or unlocked-and-worn.
GameController shelfMeta({required bool unlocked}) {
  final c = GameController();
  quietMeta(c);
  c.meta
    ..runsWon = 3
    ..bestFloor = 6
    ..hearthTalesHeard = unlocked ? hearthgoldTales : 4;
  if (unlocked) c.selectVista('hearthgold');
  return c;
}

Future<void> captureMap(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name,
) async {
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
          child: GameRoot(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  for (var t = 0; t < 1200; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> captureShelf(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name,
) async {
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
          child: CharacterScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('vista-hearthgold')),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 100));
  final top = tester
      .getTopLeft(find.byKey(const ValueKey('vista-hearthgold')))
      .dy;
  await tester.drag(
    find.byType(Scrollable).first,
    Offset(0, 120 - top),
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hearthgold plates', (tester) async {
    await loadRealFonts();
    await captureMap(
      tester,
      hearthgoldRun(),
      const Size(360, 800),
      'hearthgold_map_360x800',
    );
    // Same seed, identity vista — the distinctness control.
    final control = GameController();
    quietMeta(control);
    control.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    await captureMap(
      tester,
      control,
      const Size(360, 800),
      'emberlight_map_360x800',
    );
    await captureShelf(
      tester,
      shelfMeta(unlocked: false),
      const Size(320, 568),
      'hearthgold_card_locked_320x568',
    );
    await captureShelf(
      tester,
      shelfMeta(unlocked: true),
      const Size(360, 640),
      'hearthgold_card_worn_360x640',
    );
  });
}
