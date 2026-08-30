// tool/gilt_rune_visual_test.dart — manual visual-critique plates for
// v0.130.0 "The Gilded Face": the temper sheet's six-rune list with
// Gilt CHOSEN, at two sizes. Not part of CI.
//
//   flutter test tool/gilt_rune_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/gilt_rune_visual';

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
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

Future<void> _pump(WidgetTester tester, [int ticks = 6]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

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

void main() {
  for (final probe in <List<Object>>[
    ['phone', const Size(412, 915), 1.0],
    ['small', const Size(320, 568), 1.0],
  ]) {
    final label = probe[0] as String;
    final size = probe[1] as Size;
    final scale = probe[2] as double;

    testWidgets('temper sheet @ $label', (tester) async {
      await tester.binding.runAsync(loadRealFonts);
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final c = GameController();
      c.meta.tutorialSeen = true;
      c.meta.tipsSeen.addAll(ContextTips.all);
      c.startRun(character: 'kindler', seed: 5, boons: false);
      c.sim!.phase = 'rest';
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          // copyWith, never a bare MediaQueryData: a fresh one has size
          // zero, which silently collapses any widget that measures the
          // screen (it hid the temper sheet's controls entirely).
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: GameRoot(c),
              ),
            ),
          ),
        ),
      );
      await _pump(tester);
      // rest plate unchanged by this release — sheet plates only.

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rest-temper')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await _pump(tester, 2);
      await tester.tap(
        find.byKey(const ValueKey('rest-temper')),
        warnIfMissed: false,
      );
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('temper-die-1')));
      await _pump(tester, 3);
      await tester.ensureVisible(find.byKey(const ValueKey('temper-face-4')));
      await _pump(tester, 2);
      await tester.tap(
        find.byKey(const ValueKey('temper-face-4')),
        warnIfMissed: false,
      );
      await _pump(tester, 3);
      // Mend sits last — bring it on-screen before choosing it.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('temper-rune-gilt')),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await _pump(tester, 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('temper-rune-gilt')),
      );
      await _pump(tester, 2);
      await tester.tap(
        find.byKey(const ValueKey('temper-rune-gilt')),
        warnIfMissed: false,
      );
      await _pump(tester, 3);
      await _shoot(tester, key, 'gilt-$label');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
