// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/strata_visual_test.dart — manual visual-critique plates for the
// v0.28.0 "Shifting Strata" depth-graded backgrounds. Not part of CI.
//
//   flutter test tool/strata_visual_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/strata_visual';

Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 1),
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
  testWidgets('strata plates: map + combat at four depths', (tester) async {
    const logical = Size(1000, 1600);
    tester.view.physicalSize = logical;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (asset, name) in [
      (Art.bgMap, 'map_strata'),
      (Art.bgCombat, 'combat_strata'),
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: Column(
              children: [
                for (final depth in [0.0, 1 / 3, 2 / 3, 1.0])
                  Expanded(
                    child: ScreenBackground(
                      asset: asset,
                      grade: Art.strataFilter(depth),
                      wash: Art.strataWash(depth),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'depth ${(depth * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      // Real async so the background PNG decodes before the plate.
      await tester.binding.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await shoot(tester, key, name);
    }
  });
}
