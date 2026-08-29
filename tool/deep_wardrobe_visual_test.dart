// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/deep_wardrobe_visual_test.dart — manual visual-critique plates for
// v0.94.0 "The Deep Wardrobe". Not part of CI.
//
//   flutter test tool/deep_wardrobe_visual_test.dart
//
// Plates (build/deep_wardrobe_visual/):
//   • new_dyes_360x640 — the dye rack scrolled to the two NEW cards
//     (Emberheart, Glowmere), sprites tinted by each dye, prices shown.
//   • new_dyes_320x568 — the restraint plate: narrowest supported width.
//   • new_epithets_360x640 — the epithet shelf scrolled to the three NEW
//     titles: the Deepdrawn WORN, the Measured unlocked, the Six-Handed
//     still locked with its honest milestone line.
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

const outDir = 'build/deep_wardrobe_visual';

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
  Size logical,
  String name, {
  required Key scrollTo,
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
    find.byKey(scrollTo),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 100));
  // Place the target card near the top so the cards after it show too.
  final top = tester.getTopLeft(find.byKey(scrollTo)).dy;
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

/// A veteran profile: rich enough that the new dyes show real prices and
/// the three new epithets sit in every state — deepdrawn WORN (bestFloor
/// 10), measured unlocked (streak of 6), six-handed LOCKED (five of six
/// delvers have wins).
GameController deepMeta() {
  final c = GameController();
  c.meta
    ..unlockedCharacters.addAll([
      'warden',
      'gambler',
      'ascetic',
      'peddler',
      'tinker',
    ])
    ..embers = 700
    ..runsWon = 12
    ..runsPlayed = 30
    ..bestFloor = 10
    ..bestExactStreak = 6
    ..ownedDyes.addAll(['emberwash', 'emberheart'])
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  c.meta.charWins.addAll({
    'kindler': 4,
    'warden': 2,
    'gambler': 1,
    'ascetic': 1,
    'peddler': 1,
  });
  c.meta.charDye['kindler'] = 'emberheart';
  c.meta.charEpithet['kindler'] = 'the_deepdrawn';
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deep wardrobe plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      deepMeta(),
      const Size(360, 640),
      'new_dyes_360x640',
      scrollTo: const ValueKey('dye-emberheart'),
    );
    await capture(
      tester,
      deepMeta(),
      const Size(320, 568),
      'new_dyes_320x568',
      scrollTo: const ValueKey('dye-emberheart'),
    );
    await capture(
      tester,
      deepMeta(),
      const Size(360, 640),
      'new_epithets_360x640',
      scrollTo: const ValueKey('epithet-the_deepdrawn'),
    );
  });
}
