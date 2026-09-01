// THE WALKED PATH: the delver marker's walk is a walk, not a lerp —
// the grounded shadow thins at each hop apex, and under reduce motion
// the hop (and shadow squash) disappears while the glide remains.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<GameController> atMap() async {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: 6, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'map' && guard++ < 50) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, 'map');
  return c;
}

/// Clear one node and return to the map so the return walk plays.
void driveOneNode(GameController c) {
  var guard = 0;
  var moved = 0;
  while (guard++ < 300) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    final wasMap = c.phase == 'map';
    c.apply(cmd);
    if (wasMap && c.phase != 'map') moved++;
    if (moved >= 1 && c.phase == 'map') break;
  }
  expect(c.phase, 'map');
}

/// Sample the shadow width over the walk; returns (min, last) widths.
Future<(double, double)> sampleShadow(WidgetTester tester) async {
  final shadow = find.byKey(const ValueKey('delver-shadow'));
  var minW = double.infinity;
  var lastW = double.infinity;
  for (var t = 0; t < 2000; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
    if (shadow.evaluate().isEmpty) continue;
    lastW = tester.getSize(shadow).width;
    if (lastW < minW) minW = lastW;
  }
  return (minW, lastW);
}

void main() {
  testWidgets('shadow thins at the hop apex and settles back', (tester) async {
    final c = await atMap();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    driveOneNode(c);
    final (minW, lastW) = await sampleShadow(tester);
    // Hop apex: 14 - 5 = 9. Sampling can miss the exact peak; anything
    // clearly under 14 proves the squash ran.
    expect(minW, lessThan(12.0));
    expect(lastW, closeTo(14.0, 0.01)); // settled: full-width shadow
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduce motion keeps the shadow grounded and full', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on'); // 'on' = always reduced
    addTearDown(() => Motion.instance.update(setting: 'system'));
    final c = await atMap();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    driveOneNode(c);
    final (minW, lastW) = await sampleShadow(tester);
    expect(minW, closeTo(14.0, 0.01)); // no squash ever
    expect(lastW, closeTo(14.0, 0.01));
    // Idling map FX (node pulse) outlive the test body otherwise.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
