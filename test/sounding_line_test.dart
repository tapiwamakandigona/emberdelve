// test/sounding_line_test.dart — v0.77.0 The Sounding Line.
//
// The Ledger draws the depth of the remembered delves: runHistory's floors
// as bars, oldest to newest, wins in ember. Every bar is a REAL record
// (§Ethics honesty). Two records make a line; one stays a row (gate >= 2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/sounding_line.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Map<String, Object?> rec({
  required String result,
  required int floor,
  int seed = 7,
}) => {
  'date': '2026-08-26',
  'character': 'kindler',
  'difficulty': 'easy',
  'ascension': 0,
  'result': result,
  'floor': floor,
  'floors': 12,
  'seed': seed,
  'embers': 10,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('soundingBars draws oldest first, scaled to the deepest in window', () {
    // MetaState keeps newest FIRST; the line draws oldest first.
    final history = [
      rec(result: 'won', floor: 12), // newest
      rec(result: 'abandoned', floor: 3),
      rec(result: 'lost', floor: 6), // oldest
    ];
    final bars = soundingBars(history);
    expect(bars.length, 3);
    expect(bars.first.result, 'lost', reason: 'oldest drawn first');
    expect(bars.last.result, 'won', reason: 'newest drawn last');
    expect(bars.last.frac, 1.0, reason: 'deepest run fills the height');
    expect(bars.first.frac, closeTo(0.5, 1e-9));
    expect(bars[1].frac, closeTo(0.25, 1e-9));
  });

  test('records without a floor draw an honest stub, never invent', () {
    final bars = soundingBars([
      rec(result: 'won', floor: 4),
      {'date': '2026-08-01', 'result': 'lost'}, // legacy: no floor key
    ]);
    expect(bars.first.frac, 0.0, reason: 'legacy record sits on the baseline');
    expect(bars.first.result, 'lost');
    // Unknown results read as lost (dim), never as a win.
    final odd = soundingBars([
      rec(result: 'won', floor: 4),
      rec(result: 'someday', floor: 2),
    ]);
    expect(odd.first.result, 'lost');
  });

  testWidgets('the Ledger shows the line at two records, not at one', (
    tester,
  ) async {
    final c = GameController();
    c.meta.addRunRecord(rec(result: 'lost', floor: 5));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(
      find.byKey(const ValueKey('sounding-line')),
      findsNothing,
      reason: 'one point is not a line',
    );

    c.meta.addRunRecord(rec(result: 'won', floor: 9, seed: 8));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    final line = find.byKey(const ValueKey('sounding-line'));
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(line, findsOneWidget);
  });
}
