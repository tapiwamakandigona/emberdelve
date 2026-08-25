// test/ledger_card_test.dart — v0.56.0 "Card from the Ledger": any
// remembered win or loss (meta.runHistory) can become a Delver's Card,
// days after the run ended. Design doc: docs/improvements/
// v0.56.0-lead-scout.md.
//
// Pins:
//   1. fromRecord honesty: every stated field comes straight off the
//      record; a win names its boss ONLY via bossForSeed (The Rumor's
//      proven determinism), a loss names its banked killer, and what the
//      record never banked — fights, trace, worn epithet — is OMITTED,
//      never invented (fightsKnown false, empty trace/epithet).
//   2. Degradation: a pre-v0.51.0 loss (no killed_by) keeps its opener
//      and floor; a seed-0 relic record names no boss and offers no code.
//   3. Short records rebuild SHORT codes (v0.49.0 contract holds here).
//   4. The card render drops the fights figure when it isn't known, and
//      the fixed 340x480 canvas never overflows on record-built facts.
//   5. The Ledger offers the card on won and lost rows, NOT on abandoned
//      ones, and the sheet opens with the record's epitaph on the card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/sim/run_layer.dart' show bossForSeed;
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/share_card.dart';
import 'package:emberdelve/ui/theme.dart';

Map<String, Object?> record({
  String result = 'lost',
  String character = 'kindler',
  String difficulty = 'normal',
  int ascension = 0,
  int floor = 4,
  int seed = 77,
  int embers = 63,
  String? killedBy,
  bool short = false,
}) => {
  'date': '2026-08-20',
  'character': character,
  'difficulty': difficulty,
  'ascension': ascension,
  'result': result,
  'floor': floor,
  'floors': short ? 6 : 9,
  'seed': seed,
  'embers': embers,
  if (short) 'short': true,
  if (killedBy != null) 'killed_by': killedBy,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a won record states only banked facts and names the seed boss', () {
    final r = record(
      result: 'won',
      character: 'gambler',
      difficulty: 'hard',
      ascension: 2,
      floor: 9,
      seed: 20260728,
    );
    final f = DelverCardFacts.fromRecord(r);
    expect(f.won, isTrue);
    expect(f.delverName, 'The Gambler');
    expect(f.modeLine, 'Hard · Ascension 2');
    expect(f.embers, 63);
    expect(f.seed, 20260728);
    // What was never banked is omitted, not invented.
    expect(f.fightsKnown, isFalse);
    expect(f.traceGridText, isEmpty);
    expect(f.epithetTitle, isEmpty);
    // The boss is the seed's boss — the same determinism The Rumor proved.
    final bossName = enemies[bossForSeed(20260728)]!.name;
    expect(f.epitaph, contains('The Gambler'));
    expect(f.epitaph, contains('$bossName felled at the bottom.'));
    // The code reproduces THIS run.
    final ch = decodeDelveCode(f.delveCode)!;
    expect(ch.seed, 20260728);
    expect(ch.character, 'gambler');
    expect(ch.difficulty, 'hard');
    expect(ch.ascension, 2);
    expect(ch.shortRoad, isFalse);
  });

  test('a loss with a banked killer tells who ended it and where', () {
    final f = DelverCardFacts.fromRecord(
      record(killedBy: 'cinder_wisp', floor: 4, seed: 77),
    );
    expect(f.won, isFalse);
    final killer = enemies['cinder_wisp']!.name;
    expect(f.epitaph, contains('$killer ended the run on floor 4.'));
  });

  test('a pre-v0.51 loss without a killer keeps its opener and floor', () {
    // seed 2 is even — the opener form is pinned by obituary_test; here we
    // pin that NO killer is named and the floor survives.
    final f = DelverCardFacts.fromRecord(record(floor: 3, seed: 2));
    expect(f.epitaph, 'Here fell The Kindler on floor 3.');
  });

  test('a seed-0 relic record names no boss and offers no code', () {
    final f = DelverCardFacts.fromRecord(record(result: 'won', seed: 0));
    expect(f.delveCode, isEmpty);
    expect(f.epitaph, isNot(contains('felled')));
    expect(f.challengeLine, 'Seed 0 — delve it yourself.');
  });

  test('a short record rebuilds a SHORT code', () {
    final f = DelverCardFacts.fromRecord(
      record(result: 'won', seed: 6, short: true),
    );
    expect(decodeDelveCode(f.delveCode)!.shortRoad, isTrue);
  });

  testWidgets('the card omits the fights figure and never overflows', (
    tester,
  ) async {
    // Worst-case realistic facts a record can produce: longest delver name
    // form, hard + double-digit ascension, a two-clause loss epitaph, big
    // ember count — on the fixed canvas with NO trace and NO fights.
    final f = DelverCardFacts.fromRecord(
      record(
        character: 'peddler',
        difficulty: 'hard',
        ascension: 20,
        floor: 8,
        seed: 999999999,
        embers: 9999,
        killedBy: 'ashglass_sentinel', // the longest enemy name shipped
      ),
    );
    // Guard: the worst case must actually BE the two-clause form — a bad
    // id would silently degrade the epitaph and hollow out this test.
    expect(f.epitaph, contains('Ashglass Sentinel ended the run on floor 8.'));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Center(child: DelverCard(f)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('fights won'), findsNothing);
    expect(find.text('9999 embers banked'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-epitaph')), findsOneWidget);
  });

  testWidgets('the Ledger offers the card on ended runs, not walkaways', (
    tester,
  ) async {
    final c = GameController();
    c.meta.addRunRecord(record(result: 'abandoned', seed: 30));
    c.meta.addRunRecord(record(result: 'won', seed: 20));
    c.meta.addRunRecord(record(result: 'lost', seed: 10, killedBy: 'ash_rat'));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump();
    // The Ledger is a lazy ListView — bring RECENT DELVES on screen first.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('history-card-10-2026-08-20')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('history-card-10-2026-08-20')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('history-card-20-2026-08-20')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('history-card-30-2026-08-20')),
      findsNothing,
    );
    // Tap the loss row's share icon: the sheet opens on the record's card,
    // epitaph and all — days after the run, the story still travels.
    await tester.tap(find.byKey(const ValueKey('history-card-10-2026-08-20')));
    await tester.pumpAndSettle();
    final killer = enemies['ash_rat']!.name;
    expect(
      find.textContaining('$killer ended the run on floor 4.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('card-share')), findsOneWidget);
  });
}
