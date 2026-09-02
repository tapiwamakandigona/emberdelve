// test/quiet_walk_test.dart — v0.180.0 The Quiet Walk.
//
// The map's "you are here" delver walks node to node after every encounter.
// It used to walk by re-positioning itself in the map Stack each frame, and a
// moving Positioned relays out the Stack — which repainted the whole route
// for the 650ms (~137 paints/frame, tool/repaint_roots_probe_test.dart). The
// walk is now a paint-only translation inside the marker's own boundary.
// Pin: while the delver walks, the map Stack never paints; only the marker's
// boundary does. The shadow still thins (walked_path_test) and the pixels
// are unchanged (plates diffed before/after, max channel delta 8 in the
// marker's own 20×26 px).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<GameController> atMap() async {
  final c = GameController();
  c.markTutorialSeen();
  c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
  var guard = 0;
  while (guard++ < 20 && c.phase != 'map') {
    c.apply(botCmd(c.sim!)!);
  }
  expect(c.phase, 'map');
  return c;
}

/// One encounter, back to the map — the marker now has a node to walk to.
void driveOneNode(GameController c) {
  var moved = 0;
  var guard = 0;
  while (guard++ < 200) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    final wasMap = c.phase == 'map';
    c.apply(cmd);
    if (wasMap && c.phase != 'map') moved++;
    if (moved >= 1 && c.phase == 'map') break;
  }
  expect(c.phase, 'map');
}

void main() {
  testWidgets('the walking delver never repaints the route', (tester) async {
    final c = await atMap();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    driveOneNode(c);
    // Past the phase veil (380ms); the walk (650ms) is under way.
    await tester.pump(const Duration(milliseconds: 420));
    final shadow = find.byKey(const ValueKey('delver-shadow'));
    expect(shadow, findsOneWidget);
    // The map Stack: the first Stack above the marker that is not inside the
    // marker's own boundary (the marker sits in Positioned > Stack).
    final positioned = find
        .ancestor(of: shadow, matching: find.byType(Positioned))
        .first;
    final routeStack = tester.renderObject(
      find.ancestor(of: positioned, matching: find.byType(Stack)).first,
    );
    final startW = tester.getSize(shadow).width;
    final painted = <RenderObject>{};
    debugOnProfilePaint = painted.add;
    try {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    } finally {
      debugOnProfilePaint = null;
    }
    final endW = tester.getSize(shadow).width;
    expect(
      startW != endW || startW < 14,
      isTrue,
      reason: 'the walk must be in flight while we measure',
    );
    expect(
      painted.contains(routeStack),
      isFalse,
      reason: 'a moving marker must not relayout/repaint the route Stack',
    );
    // The marker itself does paint — it is walking.
    final shadowBox = tester.renderObject(shadow);
    expect(painted.contains(shadowBox), isTrue);
    // Idling map FX outlive the test body otherwise.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
