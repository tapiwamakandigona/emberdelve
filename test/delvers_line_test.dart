// test/delvers_line_test.dart — v0.105.0 The Delver's Line.
//
// One delver's page on the Ledger gains a lifetime line. The remembered
// list caps at 30 records, so a tally of the page itself would eventually
// lie; the line reads the UNCAPPED counters (charRuns/charWins/
// charBestFloor) instead, which never forget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

Map<String, Object?> rec(String char, String result, int floor, int seed) => {
  'date': '2026-08-2${seed % 10}',
  'character': char,
  'difficulty': 'normal',
  'ascension': 0,
  'result': result,
  'floor': floor,
  'floors': 8,
  'seed': seed,
  'embers': 30,
  'fights': 3,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lifetime line reads uncapped counters, not the remembered list', () {
    final m = MetaState();
    // 40 lifetime runs — 10 more than the history cap could ever show.
    m.charRuns['kindler'] = 40;
    m.charWins['kindler'] = 12;
    m.charBestFloor['kindler'] = 9;
    expect(
      delverLifetimeLine(m, 'kindler'),
      'Lifetime: 40\u00A0delves \u00b7 12\u00A0won \u00b7 best floor\u00A09',
    );
  });

  test('singular forms and the no-best-floor shape are spelled out', () {
    final m = MetaState();
    m.charRuns['warden'] = 1;
    m.charWins['warden'] = 1;
    expect(
      delverLifetimeLine(m, 'warden'),
      'Lifetime: 1\u00A0delve \u00b7 1\u00A0won',
    );
    expect(
      delverLifetimeLine(m, 'gambler'),
      'Lifetime: 0\u00A0delves \u00b7 0\u00A0won',
    );
  });

  testWidgets('line appears on a delver page and not on All delvers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.meta.addRunRecord(rec('kindler', 'won', 8, 1));
    c.meta.addRunRecord(rec('warden', 'lost', 4, 2));
    c.meta.charRuns['kindler'] = 3;
    c.meta.charWins['kindler'] = 1;
    c.meta.charBestFloor['kindler'] = 8;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delver-pages')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    // All delvers: no lifetime line (whose lifetime would it be?).
    expect(find.byKey(const ValueKey('delver-lifetime')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('delver-page-kindler')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('delver-lifetime'))).data,
      'Lifetime: 3\u00A0delves \u00b7 1\u00A0won \u00b7 best floor\u00A08',
    );
    // Back to all: the line leaves with the page.
    await tester.tap(find.byKey(const ValueKey('delver-page-all')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('delver-lifetime')), findsNothing);
  });
}
