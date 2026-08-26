// test/depth_gauge_test.dart — v0.83.0 The Depth Gauge.
//
// The map hint line opens with the live depth ('Floor N of M'), read from
// the current node's layer and the map's layer count — the same numbers the
// run record and the farthest lantern already use.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the map states the live depth', (tester) async {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 800);
    expect(c.phase, 'map');
    final map = c.state!['map'] as Map;
    final layers = map['layers'] as int;
    expect(
      find.textContaining('Floor 1 of $layers'),
      findsOneWidget,
      reason: 'a fresh run starts on floor 1',
    );
  });
}
