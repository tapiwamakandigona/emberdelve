// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/epithets_visual_test.dart — manual visual-critique plates for the
// v0.36.0 Epithets. Not part of CI.
//
//   flutter test tool/epithets_visual_test.dart
//
// Plates (build/epithets_visual/):
//   • picker_360x640 / picker_412x915 — THE EPITHET section, mixed lock
//     state (the Delver earned + worn, the Thorough locked).
//   • charcard_titled — the delver roster header with a worn title.
//   • card_titled / card_bare — the shareable Delver's Card with and
//     without an epithet (does the name line still fit at 340 wide?).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/epithets_visual';

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

Future<void> capturePicker(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name, {
  String scrollTo = 'epithet-the_exact',
  double backDrag = 0,
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
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(scrollTo)),
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 300,
  );
  if (backDrag > 0) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, backDrag));
  }
  await tester.pump(const Duration(milliseconds: 400));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> captureRosterHeader(
  WidgetTester tester,
  GameController c,
  String name,
) async {
  const logical = Size(360, 640);
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
        home: const MediaQuery(
          data: MediaQueryData(size: logical),
          child: SizedBox(),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: MediaQuery(
          data: const MediaQueryData(size: logical),
          child: CharacterScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> cardPlate(
  WidgetTester tester,
  DelverCardFacts facts,
  String name,
) async {
  tester.view.physicalSize = const Size(360, 440) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: Material(
        color: const Color(0xFF222222),
        child: Center(
          child: RepaintBoundary(key: key, child: DelverCard(facts)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await snap(tester, key, name, 3);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('epithet plates', (tester) async {
    await tester.binding.runAsync(loadRealFonts);

    // Mixed lock state: the Delver earned + worn; the Thorough and the
    // rest still locked.
    final c = GameController();
    c.meta.runsWon = 1;
    c.meta.selectedEpithet = 'the_delver';
    await capturePicker(tester, c, const Size(360, 640), 'picker_360x640');
    await capturePicker(tester, c, const Size(412, 915), 'picker_412x915');
    // Top of the section: the None card, the worn Delver card, and the
    // first locked card in one frame.
    await capturePicker(
      tester,
      c,
      const Size(360, 640),
      'picker_worn_top',
      scrollTo: 'epithet-the_thorough',
      backDrag: 420,
    );
    // v0.59.0 The Proven: the shelf tail — locked card with its unlock
    // line, and the earned+worn state.
    await capturePicker(
      tester,
      c,
      const Size(360, 640),
      'picker_proven_locked',
      scrollTo: 'epithet-the_proven',
    );
    final c3 = GameController();
    c3.meta.provingsCleared.addAll(provings.map((p) => p.id));
    c3.meta.selectedEpithet = 'the_proven';
    await capturePicker(
      tester,
      c3,
      const Size(360, 640),
      'picker_proven_worn',
      scrollTo: 'epithet-the_proven',
    );

    // Roster header carrying the worn title under the delver name.
    final c2 = GameController();
    c2.meta.runsWon = 1;
    c2.meta.selectedEpithet = 'the_delver';
    await captureRosterHeader(tester, c2, 'charcard_titled');

    // The shareable card: longest name+title pairing vs bare.
    const titled = DelverCardFacts(
      won: true,
      delverName: 'The Kindler',
      epithetTitle: 'the Highborne',
      difficulty: 'hard',
      ascension: 12,
      traceGridText: '',
      embers: 184,
      fightsWon: 9,
      seed: 4242,
    );
    await cardPlate(tester, titled, 'card_titled');
    const bare = DelverCardFacts(
      won: false,
      delverName: 'The Kindler',
      difficulty: 'normal',
      ascension: 0,
      traceGridText: '',
      embers: 31,
      fightsWon: 2,
      seed: 4242,
    );
    await cardPlate(tester, bare, 'card_bare');
    debugPrint('STAGE: epithet plates done');
  });
}
