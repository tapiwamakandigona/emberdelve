// test/retraced_page_test.dart — v0.81.0 The Retraced Page.
//
// Any remembered row that can rebuild its Delve Code can also just START
// that delve again — same seed, delver, difficulty, ascension, and map
// length. Legacy seed-0 rows stay quiet (same gate as the code).
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

Map<String, Object?> rec({
  required int seed,
  String result = 'lost',
  String difficulty = 'hard',
  int ascension = 2,
  bool short = false,
  String date = '2026-08-20',
}) => {
  'date': date,
  'character': 'kindler',
  'difficulty': difficulty,
  'ascension': ascension,
  'result': result,
  'floor': 4,
  'floors': short ? 8 : 12,
  'seed': seed,
  'embers': 12,
  if (short) 'short': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('retrace starts the record\'s exact run', (tester) async {
    final c = GameController();
    // A hard record implies the profile that banked it owned the Forge;
    // retrace rides startRun's clampRunParams like a pasted code does.
    c.meta.forgeUnlocked = true;
    c.meta.bestAscension = 3;
    c.meta.addRunRecord(rec(seed: 77));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);

    final btn = find.byKey(const ValueKey('history-retrace-77-2026-08-20'));
    await tester.scrollUntilVisible(
      btn,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // v0.118.0: the roster section above grew a row — pin the button fully
    // on-screen before tapping (a clipped tap silently does nothing).
    await tester.ensureVisible(btn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(btn, warnIfMissed: false);
    await pumpFor(tester, 300);

    expect(c.sim, isNotNull);
    expect(c.runSeed, 77);
    final run = c.sim!.run!;
    expect(run['character'], 'kindler');
    expect(run['difficulty'], 'hard');
    expect(run['ascension'], 2);
    expect(c.sim!.hasMutator('short_road'), isFalse);
  });

  testWidgets('a short record retraces the SAME six-layer road', (
    tester,
  ) async {
    final c = GameController();
    c.meta.addRunRecord(rec(seed: 6, short: true, date: '2026-08-21'));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);

    final btn = find.byKey(const ValueKey('history-retrace-6-2026-08-21'));
    await tester.scrollUntilVisible(
      btn,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // v0.118.0: the roster section above grew a row — pin the button fully
    // on-screen before tapping (a clipped tap silently does nothing).
    await tester.ensureVisible(btn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(btn, warnIfMissed: false);
    await pumpFor(tester, 300);

    expect(c.runSeed, 6);
    expect(c.sim!.hasMutator('short_road'), isTrue);
  });

  testWidgets('legacy seed-0 rows offer no road back', (tester) async {
    final c = GameController();
    c.meta.addRunRecord(rec(seed: 0, date: '2026-08-01'));
    c.meta.addRunRecord(rec(seed: 9, date: '2026-08-22'));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('history-retrace-9-2026-08-22')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('history-retrace-0-2026-08-01')),
      findsNothing,
    );
  });
}
