// test/fitted_name_test.dart — v0.63.0 "The Fitted Name": the EMBERDELVE
// wordmark scales its paint size down to the width it is actually given
// instead of clipping at 320dp screens. Design note in
// docs/improvements/v0.63.0-lead-scout.md.
//
// Pins:
//   1. fittedLogoFontSize: unbounded/zero widths keep the requested size;
//      a width the text already fits keeps the requested size; a narrower
//      width scales proportionally (never up) and the scaled text then fits.
//   2. Widget: EmberLogotype in a narrow box paints at a smaller effective
//      size, in a wide box at the requested size — and the RESERVED height
//      is the requested size * 1.5 in both (vertical rhythm never shifts).
//
// The test environment's Ahem font renders every glyph 1em wide, so
// 'EMBERDELVE' at 42px measures far beyond 320px — the narrow case
// triggers reliably without real fonts.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/ui/logo.dart';

double effectiveFontSize(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(EmberLogotype),
      matching: find.byType(CustomPaint),
    ),
  );
  // The painter computes its fitted size at paint time and exposes it.
  return (paint.painter as dynamic).effectiveFontSize as double;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fittedLogoFontSize scales down, never up, and then fits', (
    tester,
  ) async {
    // Degenerate widths keep the requested size.
    expect(fittedLogoFontSize('EMBERDELVE', 42, double.infinity), 42);
    expect(fittedLogoFontSize('EMBERDELVE', 42, 0), 42);
    expect(fittedLogoFontSize('EMBERDELVE', 42, -1), 42);
    // A very wide box keeps the requested size.
    expect(fittedLogoFontSize('EMBERDELVE', 42, 10000), 42);
    // A narrow box scales down…
    final narrow = fittedLogoFontSize('EMBERDELVE', 42, 300);
    expect(narrow, lessThan(42));
    expect(narrow, greaterThan(0));
    // …and the scaled size actually fits (linear width model holds).
    final probe = TextPainter(
      text: TextSpan(
        text: 'EMBERDELVE',
        style: TextStyle(
          fontFamily: 'Cinzel',
          fontSize: narrow,
          fontWeight: FontWeight.w900,
          letterSpacing: narrow * 0.06,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(probe.width, lessThanOrEqualTo(300.01));
  });

  testWidgets('a narrow box paints smaller; a wide box paints as asked', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: EmberLogotype('EMBERDELVE', fontSize: 42),
          ),
        ),
      ),
    );
    expect(effectiveFontSize(tester), lessThan(42));
    // Reserved height stays the REQUESTED size * 1.5.
    expect(tester.getSize(find.byType(EmberLogotype)).height, 42 * 1.5);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 2000,
            child: EmberLogotype('EMBERDELVE', fontSize: 42),
          ),
        ),
      ),
    );
    expect(effectiveFontSize(tester), 42);
    expect(tester.getSize(find.byType(EmberLogotype)).height, 42 * 1.5);
  });
}
