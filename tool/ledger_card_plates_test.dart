// tool/ledger_card_plates_test.dart — screenshot plates for v0.56.0 Card
// from the Ledger: the RECENT DELVES rows with their new share icons, and
// the card sheet opened from a remembered loss and a remembered win. Not
// part of CI: run manually, then LOOK at the plates (DEMAND: UI changes
// get a critique).
//   flutter test tool/ledger_card_plates_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

const outDir = 'build/ledger_card_plates';

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

final rootKey = GlobalKey();

Widget app(Widget child) => RepaintBoundary(
  key: rootKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildEmberTheme(),
    home: child,
  ),
);

Future<void> pumpFor(WidgetTester tester, int ms) async {
  var t = 0;
  while (t < ms) {
    await tester.pump(const Duration(milliseconds: 50));
    t += 50;
  }
}

Future<void> snap(WidgetTester tester, String name) async {
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final file = File('$outDir/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $outDir/$name.png (${image!.width}x${image.height})');
}

GameController seasoned() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
  c.meta.unlockedCharacters.addAll(charactersOrder);
  // Three remembered runs: a loss with a banked killer, a hard win, a
  // walkaway (which must offer NO card).
  c.meta.addRunRecord({
    'date': '2026-08-18',
    'character': 'warden',
    'difficulty': 'normal',
    'ascension': 0,
    'result': 'abandoned',
    'floor': 2,
    'floors': 9,
    'seed': 501,
    'embers': 0,
  });
  c.meta.addRunRecord({
    'date': '2026-08-19',
    'character': 'gambler',
    'difficulty': 'hard',
    'ascension': 3,
    'result': 'won',
    'floor': 9,
    'floors': 9,
    'seed': 20260728,
    'embers': 148,
  });
  c.meta.addRunRecord({
    'date': '2026-08-20',
    'character': 'kindler',
    'difficulty': 'normal',
    'ascension': 0,
    'result': 'lost',
    'floor': 4,
    'floors': 9,
    'seed': 77,
    'embers': 63,
    'killed_by': 'ashglass_sentinel',
  });
  // v0.57.0 The Fuller Record: two records banked WITH the new keys — the
  // card must show grid + fights + worn epithet again.
  c.meta.addRunRecord({
    'date': '2026-08-25',
    'character': 'gambler',
    'difficulty': 'hard',
    'ascension': 20,
    'result': 'lost',
    'floor': 8,
    'floors': 9,
    'seed': 999999999,
    'embers': 9999,
    'killed_by': 'ashglass_sentinel',
    'fights': 99,
    'trace': 'chchchchh',
    'epithet': 'the_well_oiled',
  });
  c.meta.addRunRecord({
    'date': '2026-08-25',
    'character': 'peddler',
    'difficulty': 'normal',
    'ascension': 0,
    'result': 'won',
    'floor': 9,
    'floors': 9,
    'seed': 20260721,
    'embers': 184,
    'fights': 11,
    'trace': 'ccchcchcc',
    'epithet': 'the_delver',
  });
  return c;
}

Future<void> openCard(WidgetTester tester, String rowKey) async {
  final icon = find.byKey(ValueKey(rowKey));
  await tester.scrollUntilVisible(
    icon,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(icon);
  await pumpFor(tester, 700);
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('ledger rows + remembered cards', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    await tester.pumpWidget(app(LedgerScreen(c)));
    await tester.binding.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await pumpFor(tester, 400);
    // Plate 1: the rows themselves — share icons on won/lost, none on the
    // walkaway.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('recent-delves')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFor(tester, 300);
    await snap(tester, 'ledger_rows_360x640');
    // Plate 2: the remembered LOSS card (no fights, no trace, killer named).
    await openCard(tester, 'history-card-77-2026-08-20');
    await snap(tester, 'remembered_loss_card_360x640');
    await tester.tap(find.byKey(const ValueKey('card-close')));
    await pumpFor(tester, 500);
    // Plate 3: the remembered WIN card (boss named from the seed).
    await openCard(tester, 'history-card-20260728-2026-08-19');
    await snap(tester, 'remembered_win_card_360x640');
    await tester.tap(find.byKey(const ValueKey('card-close')));
    await pumpFor(tester, 500);
    // Plate 4 (v0.57.0): FULLER loss card — worst case: longest
    // name+epithet form, 2-row trace, fights line, two-clause epitaph.
    await openCard(tester, 'history-card-999999999-2026-08-25');
    await snap(tester, 'fuller_loss_card_360x640');
    await tester.tap(find.byKey(const ValueKey('card-close')));
    await pumpFor(tester, 500);
    // Plate 5 (v0.57.0): FULLER win card — grid ends in the ember cell.
    await openCard(tester, 'history-card-20260721-2026-08-25');
    await snap(tester, 'fuller_win_card_360x640');
  });

  testWidgets('ledger rows at 320 — v0.58.0 restraint check', (tester) async {
    // The scout's ship condition: epithet + fights tokens must read clean,
    // not cluttered, at the narrowest supported width.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = seasoned();
    await tester.pumpWidget(app(LedgerScreen(c)));
    await tester.binding.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await pumpFor(tester, 400);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('recent-delves')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFor(tester, 300);
    await snap(tester, 'ledger_rows_320x568');
  });
}
