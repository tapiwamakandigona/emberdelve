// test/banked_coals_test.dart — v0.177.0 The Banked Coals.
//
// 1) The frame-loop repaint fix: a multi-frame sprite WITHOUT the bob/sway
//    ticker must hand its AnimationController to the painter's repaint
//    listenable (before the fix the driver was built in initState, before
//    the controller existed, and never rebuilt — title hearth, map nodes,
//    and codex cards froze on frame 0).
// 2) The warm cache: warmSpriteSheets decodes every bundled sheet, and a
//    warmed SpriteView paints its sprite on the FIRST frame (no empty-box
//    decode pop).
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('warmSpriteSheets banks every bundled sheet', (tester) async {
    await tester.runAsync(() => warmSpriteSheets());
    // A delver, the newest delver, an early regular, and a boss.
    for (final id in ['kindler', 'stoker', 'cinder_wisp', 'hearthless_king']) {
      expect(
        debugSpriteSheetCached(id),
        isTrue,
        reason: '$id should be decoded into the warm cache',
      );
    }
  });

  testWidgets('a warmed sprite paints on its first frame', (tester) async {
    await tester.runAsync(() => warmSpriteSheets());
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SpriteView('kindler', height: 84)),
      ),
    );
    // FIRST pump, no settle: the warm fast path commits synchronously in
    // initState, so the painter exists immediately.
    final paint = find.descendant(
      of: find.byType(SpriteView),
      matching: find.byType(CustomPaint),
    );
    expect(paint, findsOneWidget, reason: 'no empty-box frame when warm');
  });

  testWidgets(
    'the frame loop drives the painter even without bob or sway',
    (tester) async {
      await tester.runAsync(() => warmSpriteSheets());
      await tester.pumpWidget(
        const MaterialApp(
          // bob/sway default false — the exact shape that froze.
          home: Center(child: SpriteView('kindler', height: 84)),
        ),
      );
      final paintWidget = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(SpriteView),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      final painter = paintWidget.painter!;
      // The kindler idle row is 4 frames, so the frame-loop controller must
      // be wired into the painter's repaint listenable. Listenable.merge or
      // the controller itself both satisfy this; null repaint means frozen.
      expect(
        painter.runtimeType.toString(),
        '_SpritePainter',
      );
      var repainted = false;
      painter.addListener(() => repainted = true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        repainted,
        isTrue,
        reason: 'a frame tick must repaint the sprite layer',
      );
    },
  );
}
