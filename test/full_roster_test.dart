// test/full_roster_test.dart — v0.74.0 "The Full Roster": the ledger's
// delver rows speak the whole identity — dyed sprite, given name, worn
// title, charted depth. Design doc: docs/improvements/v0.74.0-lead-scout.md.
//
// Pins:
//   1. An unlocked, named, dressed, charted delver's row shows the given
//      name, the worn title (key 'roster-title-<id>'), the sprite (key
//      'roster-delver-<id>'), and a tally ending in '· floor N'.
//   2. Depth honesty: an uncharted delver's tally has NO floor segment.
//   3. Locked rows are untouched: roster name, no sprite, no title,
//      'locked' tally.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the roster row speaks name, title, sprite, and depth', (
    tester,
  ) async {
    final c = GameController();
    c.meta
      ..runsWon = 12
      ..runsPlayed = 20;
    c.meta.charName['kindler'] = 'Ashka';
    c.meta.charEpithet['kindler'] = 'the_delver';
    c.meta.charRuns['kindler'] = 20;
    c.meta.charWins['kindler'] = 12;
    c.meta.charBestFloor['kindler'] = 9;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump();
    final list = find.byType(ListView);
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('roster-delver-kindler')),
      400,
      scrollable: scrollable,
    );
    expect(find.byKey(const ValueKey('roster-delver-kindler')), findsOneWidget);
    expect(find.text('Ashka'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('roster-title-kindler')))
          .data,
      'the Delver',
    );
    expect(find.text('12 wins · 20 delves · floor 9'), findsOneWidget);
  });

  testWidgets('an uncharted delver shows no floor; locked rows untouched', (
    tester,
  ) async {
    final c = GameController();
    c.meta.charRuns['kindler'] = 1;
    c.meta.charWins['kindler'] = 1;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump();
    final list = find.byType(ListView);
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('roster-delver-kindler')),
      400,
      scrollable: scrollable,
    );
    // Honesty rule: no guessed 'floor 0'.
    expect(find.text('1 win · 1 delve'), findsOneWidget);
    expect(find.textContaining('floor'), findsNothing);
    // Locked delvers: roster name, lock, no sprite, no title.
    expect(find.text('The Warden'), findsOneWidget);
    expect(find.byKey(const ValueKey('roster-delver-warden')), findsNothing);
    expect(find.byKey(const ValueKey('roster-title-warden')), findsNothing);
    expect(find.text('locked'), findsWidgets);
  });
}
