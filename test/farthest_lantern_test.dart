// test/farthest_lantern_test.dart — v0.82.0 The Farthest Lantern.
//
// The map paints one gold rule at the boundary between the lifetime deepest
// floor and the floor beyond (key 'plumb-mark'). Gated bestFloor > 0 and
// bestFloor < layers: no lantern on a fresh profile, and none when the
// record already exceeds this map's floors (short road after a long career).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Future<void> pumpMap(WidgetTester tester, GameController c) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
  );
  await pumpFor(tester, 800);
  expect(c.phase, 'map');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a delved profile sees its lantern on the map', (tester) async {
    final c = GameController();
    c.meta.bestFloor = 3;
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    await pumpMap(tester, c);
    expect(find.byKey(const ValueKey('plumb-mark')), findsOneWidget);
  });

  testWidgets('a fresh profile has no lantern', (tester) async {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    await pumpMap(tester, c);
    expect(find.byKey(const ValueKey('plumb-mark')), findsNothing);
  });

  testWidgets('a record beyond this map draws no line', (tester) async {
    final c = GameController();
    c.meta.bestFloor = 99;
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    await pumpMap(tester, c);
    expect(find.byKey(const ValueKey('plumb-mark')), findsNothing);
  });
}
