// tool/settings_scroll_visual_test.dart — manual plates for the settings
// screen's ScrollComfort shell (v0.174): top, mid-scroll, and bottom at
// 320x568, checking the edge fades appear/disappear honestly. Not in CI.
//
//   flutter test tool/settings_scroll_visual_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show ByteData, FontLoader;

import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/settings_scroll_visual';

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

Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
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
  debugPrint('PLATE-OK: $name');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings scroll-comfort plates: top, mid, bottom', (
    tester,
  ) async {
    await tester.binding.runAsync(loadRealFonts);
    const logical = Size(320, 568);
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
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.binding.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shoot(tester, key, 'settings_top');

    final scrollable = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, -500));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shoot(tester, key, 'settings_mid');

    await tester.drag(scrollable, const Offset(0, -4000));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shoot(tester, key, 'settings_bottom');
  });
}
