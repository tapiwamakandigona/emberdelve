// test/still_route_test.dart — v0.180.0 "The Still Route" (perf).
//
// Dragging the map into its stretch-overscroll used to repaint the whole
// route every frame — HUD text, footer, background — because the stretch
// indicator's setState sits inside the map's LayoutBuilder scope, and that
// relayout walked up the Column and marked paint clear to the route
// boundary (probe: 80 paints/frame). The map body is now its own relayout
// + repaint boundary, so a drag leaves the HUD untouched.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFrames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('dragging the map does not repaint the HUD', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.meta
      ..tutorialSeen = true
      ..tourSeenVersion = tourVersion
      ..tipsSeen.addAll(ContextTips.all)
      ..lastSeenNewsVersion = currentAppVersion
      ..runsPlayed = 3;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFrames(tester, 30);
    c.startRun(character: 'kindler', seed: 11, boons: false);
    await pumpFrames(tester, 90);
    expect(c.phase, 'map');
    expect(find.text('GOLD'), findsOneWidget);

    var hudPaints = 0;
    var paragraphPaints = 0;
    debugOnProfilePaint = (RenderObject ro) {
      if (ro is! RenderParagraph) return;
      paragraphPaints++;
      if (ro.text.toPlainText() == 'GOLD') hudPaints++;
    };
    addTearDown(() => debugOnProfilePaint = null);
    // 60 frames × 12 px runs well past the map's scroll extent at this size,
    // so the back half of the drag is stretch-overscroll.
    final g = await tester.startGesture(
      tester.getCenter(find.byType(Scrollable).first),
    );
    for (var i = 0; i < 60; i++) {
      await g.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    debugOnProfilePaint = null;
    // Before the boundary: 60 (once per frame). Allow a stray frame or two.
    expect(
      hudPaints,
      lessThanOrEqualTo(2),
      reason: 'HUD repainted $hudPaints× in 60 drag frames',
    );
    expect(
      paragraphPaints,
      lessThan(60),
      reason: 'text painted $paragraphPaints× in 60 drag frames',
    );
    await pumpFrames(tester, 90);
  });
}
