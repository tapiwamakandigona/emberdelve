// test/remembered_fights_test.dart — v0.58.0 "The Remembered Fights": the
// Ledger row states the worn epithet and the fights count when the fuller
// record (v0.57.0) banked them. Old records render exactly as before.
// Design doc: docs/improvements/v0.58.0-lead-scout.md.
//
// Pins:
//   1. A fuller record's row titles the delver WITH the worn epithet and
//      its meta line carries the fights token (singular/plural correct).
//   2. A pre-v0.57.0 record's row is byte-identical to the old form: bare
//      name, no fights token — absent facts stay absent.
//   3. An abandoned fuller record still gets the tokens (walking away is
//      a remembered day too) but still offers no card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

Map<String, Object?> record({
  String result = 'lost',
  int seed = 77,
  int? fights,
  String? epithet,
}) => {
  'date': '2026-08-25',
  'character': 'kindler',
  'difficulty': 'normal',
  'ascension': 0,
  'result': result,
  'floor': 4,
  'floors': 9,
  'seed': seed,
  'embers': 63,
  if (result == 'lost') 'killed_by': 'ash_rat',
  if (fights != null) 'fights': fights,
  if (epithet != null) 'epithet': epithet,
};

Future<void> show(WidgetTester tester, GameController c) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
  );
  await tester.pump();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('recent-delves')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a fuller record row states epithet and fights', (tester) async {
    final c = GameController();
    c.meta.addRunRecord(record(fights: 7, epithet: 'the_unburnt', seed: 10));
    await show(tester, c);
    expect(
      find.textContaining('The Kindler, the Unburnt — fell on floor 4'),
      findsOneWidget,
    );
    expect(find.textContaining('· 7 fights'), findsOneWidget);
  });

  testWidgets('one fight is singular', (tester) async {
    final c = GameController();
    c.meta.addRunRecord(record(fights: 1, seed: 11));
    await show(tester, c);
    expect(find.textContaining('· 1 fight ·'), findsOneWidget);
    expect(find.textContaining('1 fights'), findsNothing);
  });

  testWidgets('an old record renders exactly as before', (tester) async {
    final c = GameController();
    c.meta.addRunRecord(record(seed: 12));
    await show(tester, c);
    expect(
      find.textContaining('The Kindler — fell on floor 4'),
      findsOneWidget,
    );
    final panel = find.byKey(const ValueKey('recent-delves'));
    expect(
      find.descendant(of: panel, matching: find.textContaining('fights')),
      findsNothing,
    );
    expect(
      find.descendant(of: panel, matching: find.textContaining('The Kindler,')),
      findsNothing,
    );
  });

  testWidgets('an abandoned fuller record gets tokens but no card', (
    tester,
  ) async {
    final c = GameController();
    c.meta.addRunRecord(
      record(result: 'abandoned', fights: 3, epithet: 'the_delver', seed: 13),
    );
    await show(tester, c);
    expect(
      find.textContaining('The Kindler, the Delver — walked away'),
      findsOneWidget,
    );
    expect(find.textContaining('· 3 fights'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('history-card-13-2026-08-25')),
      findsNothing,
    );
  });
}
