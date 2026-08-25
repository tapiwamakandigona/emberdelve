// test/delver_tally_test.dart — v0.60.0 "The Delver's Tally": the delver
// picker states your record with each delver ("N wins · M delves"), read
// from the same charRuns/charWins counters the Ledger roster uses. Design
// doc: docs/improvements/v0.60.0-lead-scout.md.
//
// Pins:
//   1. A delver with banked runs shows the tally line, singular forms
//      respected ("1 win · 1 delve").
//   2. A delver never delved with shows NO tally key — no "0 delves"
//      clutter on a fresh install.
//   3. The tally reads the live meta counters (charRuns/charWins), so the
//      Ledger roster and the picker can never disagree.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a delved delver shows its tally; plural forms', (tester) async {
    final c = GameController();
    c.meta.charRuns['kindler'] = 12;
    c.meta.charWins['kindler'] = 5;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('char-tally-kindler')), findsOneWidget);
    expect(find.text('5 wins · 12 delves'), findsOneWidget);
  });

  testWidgets('singular forms: 1 win · 1 delve', (tester) async {
    final c = GameController();
    c.meta.charRuns['kindler'] = 1;
    c.meta.charWins['kindler'] = 1;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.text('1 win · 1 delve'), findsOneWidget);
  });

  testWidgets('a fresh delver shows no tally line at all', (tester) async {
    final c = GameController();
    // Fresh meta: kindler unlocked by default but never delved.
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('char-tally-kindler')), findsNothing);
    // And no zero-count string sneaks in under any delver.
    expect(find.textContaining('0 delves'), findsNothing);
  });

  testWidgets('losses count as delves: wins can be zero while runs show', (
    tester,
  ) async {
    final c = GameController();
    c.meta.charRuns['kindler'] = 3;
    // charWins absent entirely — the tally must not throw and must say 0 wins.
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.text('0 wins · 3 delves'), findsOneWidget);
  });
}
