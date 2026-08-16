// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/motion_visual_test.dart — manual visual-critique plates for the
// v0.16.0 Still Flame settings surface. Not part of CI.
//
//   flutter test tool/motion_visual_test.dart
//
// Plates:
//   motion_settings_360x640 — COMFORT section, REDUCED selected.
//   motion_settings_320x568_1p3x — worst-case small screen at 1.3x text.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;

import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/audio/settings.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/motion_visual';

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
    await tester.ensureVisible(find.byKey(ValueKey(scrollToKey)));
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
  Directory(outDir).createSync(recursive: true);
  File(
    '$outDir/$name.png',
  ).writeAsBytesSync(bytes!.buffer.asUint8List(), flush: true);
  debugPrint('wrote $outDir/$name.png');
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    AudioService.instance = AudioService(
      AudioSettings()..reduceMotion = 'on',
    );
    Motion.instance.update(setting: 'on');
  });

  testWidgets('motion settings plates', (tester) async {
    await capture(
      tester,
      const SettingsScreen(),
      'motion_settings_360x640',
      const Size(360, 640),
      1.0,
      scrollToKey: 'reduce-motion',
    );
    await capture(
      tester,
      const SettingsScreen(),
      'motion_settings_320x568_1p3x',
      const Size(320, 568),
      1.3,
      scrollToKey: 'reduce-motion',
    );
  });
}
