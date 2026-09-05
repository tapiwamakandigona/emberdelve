// Additive regression: decorative campfire motion follows the shared setting.
import 'package:emberdelve/ui/fx.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> firePaints(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  var paints = 0;
  debugOnProfilePaint = (RenderObject object) {
    if (object is RenderCustomPaint &&
        object.painter.runtimeType.toString() == '_CampFirePainter') {
      paints++;
    }
  };
  try {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  } finally {
    debugOnProfilePaint = null;
  }
  return paints;
}

void main() {
  setUp(Motion.instance.reset);
  tearDown(Motion.instance.reset);

  testWidgets('campfire is visible but stops repainting with reduced motion', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    await tester.pumpWidget(const MaterialApp(home: Center(child: CampFire())));
    expect(find.byType(CampFire), findsOneWidget);
    expect(await firePaints(tester), 0);
    Motion.instance.update(setting: 'off');
    expect(await firePaints(tester), greaterThan(0));
    Motion.instance.update(setting: 'on');
    expect(await firePaints(tester), 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('a static campfire invalidates when its hearth colors change', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    await tester.pumpWidget(const MaterialApp(home: Center(child: CampFire())));
    final finder = find.descendant(
      of: find.byType(CampFire),
      matching: find.byType(CustomPaint),
    );
    final before = tester.widget<CustomPaint>(finder).painter!;
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CampFire(warm: Colors.blue, bright: Colors.white),
        ),
      ),
    );
    final after = tester.widget<CustomPaint>(finder).painter!;
    expect(after.shouldRepaint(before), isTrue);
  });
}
