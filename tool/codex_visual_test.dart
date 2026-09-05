// Real-font Codex plates. Not a replacement for tests or human device review.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    for (final pair in [
      ('Cinzel', 'assets/fonts/Cinzel-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Regular.ttf'),
    ]) {
      await (FontLoader(pair.$1)
            ..addFont(Future.value(ByteData.sublistView(File(pair.$2).readAsBytesSync()))))
          .load();
    }
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(
              File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync(),
            ))))
          .load();
    }
  });
  for (final size in [const Size(360, 800), const Size(320, 568)]) {
    testWidgets('real Codex plate $size', (tester) async {
      tester.view.physicalSize = size * 2;
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
              data: MediaQueryData(size: size, textScaler: TextScaler.linear(size.width == 320 ? 1.3 : 1)),
              child: CodexScreen(GameController()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      File('build/visual-review/codex_${size.width.toInt()}x${size.height.toInt()}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
      // A branch-scoped review transport through the EXISTING public test log.
      // No new workflow permissions, deployment or external upload endpoint.
      if (Platform.environment['GITHUB_HEAD_REF'] == 'feat/visual-polish-20260905') {
        final encoded = base64Encode(bytes!.buffer.asUint8List());
        final name = 'codex_${size.width.toInt()}x${size.height.toInt()}';
        for (var start = 0; start < encoded.length; start += 512) {
          final end = (start + 512).clamp(0, encoded.length);
          // ignore: avoid_print
          print('VISUAL_PNG:$name:$start:${encoded.substring(start, end)}');
        }
      }
      image!.dispose();
    });
  }
}
