// test/plumb_line_test.dart — v0.80.0 The Plumb Line.
//
// The Ledger's LIFETIME panel states the deepest floor ever reached
// (meta.bestFloor) — absolute, gated on having delved at all. The sounding
// line draws the relative arc; the plumb line is the number.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a fresh profile shows no plumb line', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('plumb-line')), findsNothing);
  });

  testWidgets('a delved profile states its deepest floor', (tester) async {
    final c = GameController();
    c.meta.bestFloor = 12;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('plumb-line')), findsOneWidget);
    expect(find.text('Deepest floor'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}
