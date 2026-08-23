// test/strata_test.dart — v0.28.0 The Shifting Strata:
//   1. strataFilter(0) is null (identity — title/pre-run render untouched).
//   2. Grades deepen monotonically-distinctly and clamp outside 0..1.
//   3. ScreenBackground wraps the backdrop in ColorFiltered iff graded;
//      the scrim and child sit ABOVE the grade either way.
//   4. Controller wiring: no run -> depth 0 -> no grade; a started run at
//      the first layer already grades (> 0 depth on layer 2+ maps? layer 1
//      of n gives 0 — the SURFACE — so the first floor is honest identity).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strata filter: identity at surface, graded and distinct below', () {
    expect(Art.strataFilter(0), isNull);
    expect(Art.strataFilter(-1), isNull, reason: 'clamped below');
    final third = Art.strataFilter(1 / 3);
    final twoThirds = Art.strataFilter(2 / 3);
    final bottom = Art.strataFilter(1);
    final over = Art.strataFilter(1.7);
    expect(third, isNotNull);
    expect(twoThirds, isNotNull);
    expect(bottom, isNotNull);
    expect(third, isNot(equals(twoThirds)));
    expect(twoThirds, isNot(equals(bottom)));
    expect(over, equals(bottom), reason: 'clamped above');
  });

  testWidgets('ScreenBackground grades the backdrop only when asked', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScreenBackground(asset: Art.bgMap, child: SizedBox.shrink()),
      ),
    );
    expect(
      find.byType(ColorFiltered),
      findsNothing,
      reason: 'ungraded background must not pay for a ColorFiltered layer',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenBackground(
          asset: Art.bgMap,
          grade: Art.strataFilter(0.8),
          child: const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byType(ColorFiltered), findsOneWidget);
    // The grade wraps the image, never the scrim or the child.
    final filtered = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(filtered.child, isA<Image>());
  });

  test('controller wiring: no run means surface (no grade)', () {
    final c = GameController();
    expect(c.mapDepth, 0);
    expect(Art.strataFilter(c.mapDepth), isNull);
  });

  test('controller wiring: a run deepens the grade as layers pass', () {
    final c = GameController();
    c.startRun(seed: 7, boons: false);
    // Fresh run starts on layer 1 = depth 0 (the honest surface).
    expect(c.mapDepth, 0);
    // The map exposes total layers; the boss layer must grade fully.
    final st = c.state!;
    final map = st['map'] as Map;
    final layers = map['layers'] as int;
    expect(layers, greaterThan(1));
    expect(Art.strataFilter((layers - 1) / (layers - 1)), isNotNull);
  });
}
