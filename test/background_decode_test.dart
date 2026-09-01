// Regression tests for the Play-2027 memory work (DEMAND 2026-09-01c):
// backgrounds must never decode above the device's physical width, and the
// character-screen vista swatch must never decode the full 1080x1920 source.
// On the old code both Image.assets carried no decode hint, so decoded bitmap
// memory was ~7.9 MB per background regardless of screen size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/ui/art.dart';

void main() {
  testWidgets('ScreenBackground decodes at physical width, capped at source', (
    tester,
  ) async {
    // A 360dp @ 2.0 phone: physical width 720 < the 1080 source.
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ScreenBackground(asset: Art.bgMap, child: SizedBox.shrink()),
      ),
    );
    final img = tester.widget<Image>(find.byType(Image).first);
    final provider = img.image;
    expect(provider, isA<ResizeImage>(), reason: 'cacheWidth must be set');
    expect((provider as ResizeImage).width, 720);
  });

  testWidgets('ScreenBackground never upscales the decode past the source', (
    tester,
  ) async {
    // A 480dp @ 3.5 tablet: physical width 1680 > the 1080 source.
    tester.view.physicalSize = const Size(1680, 2400);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ScreenBackground(asset: Art.bgTitle, child: SizedBox.shrink()),
      ),
    );
    final img = tester.widget<Image>(find.byType(Image).first);
    expect((img.image as ResizeImage).width, 1080);
  });
}
