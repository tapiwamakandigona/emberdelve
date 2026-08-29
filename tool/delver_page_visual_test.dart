// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/delver_page_visual_test.dart — manual visual-critique plates for
// v0.101.0 "The Delver's Page". Not part of CI.
//
//   flutter test tool/delver_page_visual_test.dart
//
// Plates (build/delver_page_visual/):
//   • pages_all_360x640 — RECENT DELVES with the page row, 'All delvers'
//     open: chips, sounding line, mixed rows.
//   • pages_warden_360x640 — the Warden's page open: only his delves,
//     line redrawn from his records alone.
//   • pages_320x568 — restraint plate: the page row (with a given-name
//     chip) at the narrowest width, checking wrap.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/delver_page_visual';

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

GameController pagedMeta() {
  final c = GameController();
  // A well-read book: three delvers remembered, one with a given name so
  // the chip wears it too.
  c.meta.charName.addAll({'kindler': 'Ashka Emberborn'});
  final records = [
    ('2026-08-18', 'kindler', 'won', 8, 11),
    ('2026-08-19', 'warden', 'lost', 4, 21),
    ('2026-08-20', 'kindler', 'lost', 6, 31),
    ('2026-08-22', 'warden', 'won', 8, 41),
    ('2026-08-24', 'gambler', 'won', 8, 51),
    ('2026-08-26', 'warden', 'won', 8, 61),
  ];
  for (final (date, ch, result, floor, seed) in records) {
    c.meta.addRunRecord({
      'date': date,
      'character': ch,
      'difficulty': 'normal',
      'ascension': 0,
      'result': result,
      'floor': floor,
      'floors': 8,
      'seed': seed,
      'embers': 40,
    });
  }
  return c;
}

Future<void> capture(
  WidgetTester tester,
  GameController c,
  Size logical,
  String name, {
  String? openPage,
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
          child: LedgerScreen(c),
        ),
      ),
    ),
  );
  await tester.binding.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  final scrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('delver-pages')),
    400,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 100));
  if (openPage != null) {
    await tester.tap(find.byKey(ValueKey('delver-page-$openPage')));
    await tester.pump(const Duration(milliseconds: 300));
  }
  final rowTop = tester
      .getTopLeft(find.byKey(const ValueKey('delver-pages')))
      .dy;
  await tester.drag(scrollable, Offset(0, 90 - rowTop), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await snap(tester, key, name, 2);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delver page plates', (tester) async {
    await loadRealFonts();
    await capture(
      tester,
      pagedMeta(),
      const Size(360, 640),
      'pages_all_360x640',
    );
    await capture(
      tester,
      pagedMeta(),
      const Size(360, 640),
      'pages_warden_360x640',
      openPage: 'warden',
    );
    await capture(tester, pagedMeta(), const Size(320, 568), 'pages_320x568');
  });
}
