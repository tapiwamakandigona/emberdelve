import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('die pose is deterministic and settles to a finite transform', () {
    Matrix4 pose(double progress) => debugDiePerspectiveTransform(
      sides: 10,
      value: 7,
      selected: false,
      maxed: false,
      spent: false,
      flight: true,
      flightProgress: progress,
    );

    for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final first = pose(progress).storage;
      final second = pose(progress).storage;
      expect(first, orderedEquals(second));
      expect(first.every((value) => value.isFinite), isTrue);
      // Perspective survives every pose; rotations legitimately alter the
      // exact storage value while the die is airborne.
      expect(first[11].abs(), greaterThan(0.0015));
      expect(first[11].abs(), lessThanOrEqualTo(0.0018));
    }

    final airborne = pose(0.25).storage;
    final settled = pose(1).storage;
    expect(airborne, isNot(orderedEquals(settled)));
    expect(settled[0], closeTo(1.0, 0.0000001));
    expect(settled[5], closeTo(1.0, 0.0000001));
  });

  test('dimensional die paint reuses one layer and never saves a layer', () {
    final canvas = TestRecordingCanvas();
    final painter = debugDimensionalDiePainter(
      sides: 6,
      value: 5,
      selected: false,
      maxed: false,
    );

    painter.paint(canvas, const Size.square(64));

    int calls(Symbol name) => canvas.invocations
        .where((recorded) => recorded.invocation.memberName == name)
        .length;
    expect(calls(#saveLayer), 0);
    expect(calls(#drawPath), greaterThanOrEqualTo(3)); // silhouette + 2 planes
    expect(calls(#drawRect), 1); // one directional-light pass
    expect(calls(#drawCircle), greaterThanOrEqualTo(10)); // 5 rim + 5 pips
  });

  test('combat diorama paints without offscreen saveLayer', () async {
    final canvas = TestRecordingCanvas();
    final painter = debugCombatDioramaPainter();

    painter.paint(canvas, const Size(720, 520));

    int calls(Symbol name) => canvas.invocations
        .where((recorded) => recorded.invocation.memberName == name)
        .length;
    expect(calls(#saveLayer), 0);
    expect(calls(#drawPath), greaterThanOrEqualTo(3));
    expect(calls(#drawLine), greaterThanOrEqualTo(7));
    expect(calls(#drawOval), 1);
    expect(painter.shouldRepaint(debugCombatDioramaPainter()), isFalse);
    expect(
      painter.shouldRepaint(debugCombatDioramaPainter(boss: true)),
      isTrue,
    );

    expect(canvas.invocations, isNotEmpty);
  });
}
