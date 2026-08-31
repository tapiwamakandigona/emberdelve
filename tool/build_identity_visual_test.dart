// tool/build_identity_visual_test.dart — manual visual-critique plates for
// the four presentation-only run identities. Not part of CI.
//
//   flutter test tool/build_identity_visual_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/ui/build_identity.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/build_identity_visual';

void main() {
  testWidgets('identity weapon plate', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final pools = <BuildPath, List<String>>{
      BuildPath.ember: ['d6', 'd8', 'd10'],
      BuildPath.blade: ['d8_blade', 'd10_blade', 'd12_fury'],
      BuildPath.aegis: ['d8_aegis', 'd10_aegis', 'd12_bulwark'],
      BuildPath.heart: ['d8_surge', 'd10_steady', 'd12_heart'],
    };
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Column(
                children: [
                  const Text('POOL-FORGED WEAPONS', style: EmberText.h2),
                  const SizedBox(height: Space.l),
                  for (final entry in pools.entries)
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 112,
                            child: WeaponView(
                              'kindler',
                              height: 104,
                              identity: buildIdentity(entry.value),
                            ),
                          ),
                          const SizedBox(width: Space.l),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  buildIdentity(entry.value).name.toUpperCase(),
                                  style: EmberText.body.copyWith(
                                    color: buildIdentity(entry.value).color,
                                  ),
                                ),
                                Text(
                                  buildIdentity(entry.value).description,
                                  style: EmberText.micro,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.binding.runAsync(
      () => boundary.toImage(pixelRatio: 2),
    );
    final bytes = await tester.binding.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File('$outDir/weapons.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    // WeaponView intentionally owns a repeating idle ticker. Replace the
    // tree so the manual harness terminates instead of waiting forever.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
