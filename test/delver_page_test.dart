// test/delver_page_test.dart — v0.101.0 The Delver's Page.
//
// When the remembered delves belong to more than one delver, RECENT DELVES
// gains pages: all delves, or one delver's. Reading aid only — the filter
// is ephemeral (never persisted), the records are untouched, and the
// sounding line honestly redraws from the open page (its two-record gate
// applies to the PAGE, not the whole book).
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

Map<String, Object?> rec(
  String character, {
  String result = 'won',
  int seed = 7,
  String date = '2026-08-20',
}) => {
  'date': date,
  'character': character,
  'difficulty': 'normal',
  'ascension': 0,
  'result': result,
  'floor': result == 'won' ? 8 : 3,
  'floors': 8,
  'seed': seed,
  'embers': 40,
};

Future<GameController> pumpLedger(
  WidgetTester tester,
  List<Map<String, Object?>> records,
) async {
  // Tall viewport: the ledger's ListView builds lazily, and these tests
  // assert on presence/absence of below-the-fold widgets.
  tester.view.physicalSize = const Size(500, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = GameController();
  for (final r in records) {
    c.meta.addRunRecord(r);
  }
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
  );
  await pumpFor(tester, 400);
  return c;
}

Future<void> showRecent(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('recent-delves')),
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 200,
  );
  await pumpFor(tester, 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one delver remembered = no pages', (tester) async {
    await pumpLedger(tester, [
      rec('kindler'),
      rec('kindler', result: 'lost', seed: 8),
    ]);
    expect(find.byKey(const ValueKey('delver-pages')), findsNothing);
  });

  testWidgets('two delvers remembered = a page per delver, plus all', (
    tester,
  ) async {
    await pumpLedger(tester, [rec('kindler'), rec('warden', seed: 8)]);
    expect(find.byKey(const ValueKey('delver-pages')), findsOneWidget);
    expect(find.byKey(const ValueKey('delver-page-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('delver-page-kindler')), findsOneWidget);
    expect(find.byKey(const ValueKey('delver-page-warden')), findsOneWidget);
    // No page for a delver with nothing remembered.
    expect(find.byKey(const ValueKey('delver-page-gambler')), findsNothing);
  });

  testWidgets('opening a page shows only that delver\'s delves', (
    tester,
  ) async {
    final c = await pumpLedger(tester, [
      rec('kindler'),
      rec('warden', seed: 8, result: 'lost'),
    ]);
    await showRecent(tester);
    final kindler = c.meta.nameFor('kindler');
    final warden = c.meta.nameFor('warden');
    expect(find.textContaining(kindler), findsWidgets);
    expect(find.textContaining(warden), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delver-page-warden')),
      -200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await tester.tap(find.byKey(const ValueKey('delver-page-warden')));
    await pumpFor(tester, 300);
    await showRecent(tester);
    expect(find.textContaining('$warden —'), findsOneWidget);
    expect(find.textContaining('$kindler —'), findsNothing);

    // Back to all: nothing was lost.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delver-page-all')),
      -200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await tester.tap(find.byKey(const ValueKey('delver-page-all')));
    await pumpFor(tester, 300);
    await showRecent(tester);
    expect(find.textContaining('$kindler —'), findsOneWidget);
    expect(find.textContaining('$warden —'), findsOneWidget);
  });

  testWidgets('the sounding line redraws from the open page', (tester) async {
    // Three records: two kindler, one warden. All-delvers line exists;
    // warden's page has one record, so its line honestly disappears.
    await pumpLedger(tester, [
      rec('kindler'),
      rec('kindler', seed: 8, result: 'lost', date: '2026-08-21'),
      rec('warden', seed: 9, date: '2026-08-22'),
    ]);
    expect(find.byKey(const ValueKey('sounding-line')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delver-page-warden')));
    await pumpFor(tester, 300);
    expect(find.byKey(const ValueKey('sounding-line')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('delver-page-kindler')));
    await pumpFor(tester, 300);
    expect(find.byKey(const ValueKey('sounding-line')), findsOneWidget);
  });

  testWidgets('the open page is ephemeral — records untouched', (tester) async {
    final c = await pumpLedger(tester, [
      rec('kindler'),
      rec('warden', seed: 8),
    ]);
    await tester.tap(find.byKey(const ValueKey('delver-page-warden')));
    await pumpFor(tester, 300);
    // The underlying book is intact — both records still banked.
    expect(c.meta.runHistory.length, 2);
    expect(c.meta.toJson().containsKey('delverPage'), isFalse);
  });
}
