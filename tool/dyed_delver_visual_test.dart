// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/dyed_delver_visual_test.dart — manual visual-critique plates for
// v0.67.0 "The Dyed Delver". Not part of CI.
//
//   flutter test tool/dyed_delver_visual_test.dart
//
// Plates (build/dyed_delver_visual/):
//   • dye_rack_360x640 — THE WARDROBE section with the dye chip row, six
//     delvers unlocked, target (kindler) wearing Emberwash, swatches
//     painting the TARGET delver.
//   • dye_rack_320x568 — the restraint plate: narrowest supported width,
//     same chip row and rack.
//   • dyed_hearth_360x640 — title screen: delvers around the fire, each in
//     their OWN dye (kindler emberwash, warden frostveil, rest undyed).
//   • dyed_picker_360x640 — picker top with per-delver coats on the cards.
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

const outDir = 'build/dyed_delver_visual';

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

Future<void> capture(
  WidgetTester tester,
  GameController c,
  Widget screen,
  Size logical,
  String name, {
  bool scrollToRack = false,
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
          child: screen,
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  if (scrollToRack) {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dye-dress-kindler')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Place the chip row just under the app bar with the rack below it.
    final chipTop = tester
        .getTopLeft(find.byKey(const ValueKey('dye-dress-kindler')))
        .dy;
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, 140 - chipTop),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Six delvers, dyes owned, mixed coats: kindler emberwash, warden
/// frostveil, the rest undyed (fallback).
GameController dyedMeta() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.addAll([
      'warden',
      'gambler',
      'ascetic',
      'peddler',
      'tinker',
    ])
    ..embers = 400
    ..runsWon = 12
    ..runsPlayed = 30
    ..ownedDyes.addAll(['emberwash', 'frostveil'])
    // Suppress the tour/tips/news so the title plate is clean.
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  c.meta.charDye.addAll({'kindler': 'emberwash', 'warden': 'frostveil'});
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dyed delver plates', (tester) async {
    await loadRealFonts();
    var c = dyedMeta();
    await capture(
      tester,
      c,
      CharacterScreen(c),
      const Size(360, 640),
      'dye_rack_360x640',
      scrollToRack: true,
    );
    c = dyedMeta();
    await capture(
      tester,
      c,
      CharacterScreen(c),
      const Size(320, 568),
      'dye_rack_320x568',
      scrollToRack: true,
    );
    c = dyedMeta();
    await capture(
      tester,
      c,
      Material(color: EmberColors.bg, child: TitleScreen(c)),
      const Size(360, 640),
      'dyed_hearth_360x640',
    );
    c = dyedMeta();
    await capture(
      tester,
      c,
      CharacterScreen(c),
      const Size(360, 640),
      'dyed_picker_360x640',
    );
  });
}
