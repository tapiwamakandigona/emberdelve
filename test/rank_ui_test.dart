// test/rank_ui_test.dart — The Delver's Rank in the UI (v0.13.0).
//
//   1. Ledger header: the rank line renders, names the derived tier, and
//      shows real marks + the honest next-tier threshold (no teaser copy).
//   2. Top of the ladder: the next-tier line becomes "the ladder ends here"
//      instead of inventing a tier that does not exist.
//   3. Summary: a first full run that banks past a threshold announces the
//      crossed tier with ONE quiet line (key 'rank-up-line') — seed 11 is a
//      deterministic autoplay win, so the crossing always happens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/rank.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  testWidgets('ledger names the derived rank with real marks', (tester) async {
    final c = GameController();
    // A mid-ladder profile: 5 wins, 1 boss, 8 felled / 10 met, 3 codex
    // entries = 15 + 5 + 16 + 10 + 3 = 49 marks -> Sparktender (24..59).
    c.meta.runsWon = 5;
    c.meta.bossesBeaten.add('ashen_colossus');
    for (var i = 0; i < 10; i++) {
      c.meta.enemyMet['foe_$i'] = 1;
      if (i < 8) c.meta.enemyFelled['foe_$i'] = 1;
    }
    c.meta.ownedCodex.addAll({'enemy:a', 'enemy:b', 'relic:c'});
    expect(rankMarks(c.meta), 49);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump();
    final line = find.byKey(const ValueKey('rank-line'));
    expect(line, findsOneWidget);
    expect(
      find.descendant(
        of: line,
        matching: find.text('You delve as a Sparktender'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: line,
        matching: find.text('49 marks · Emberwright at 60'),
      ),
      findsOneWidget,
      reason: 'next-tier line shows REAL earned progress',
    );
  });

  testWidgets('top of the ladder says so instead of inventing a tier', (
    tester,
  ) async {
    final c = GameController();
    c.meta.runsWon = 1300; // 3900 marks > top threshold 3750 (v0.166.0)
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump();
    expect(nextRank(c.meta), isNull);
    final line = find.byKey(const ValueKey('rank-line'));
    expect(
      find.descendant(
        of: line,
        matching: find.textContaining('the ladder ends here'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('summary announces the tier a run crossed into', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 11, boons: true);
    await pumpFor(tester, 400);
    var guard = 0;
    while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(
      c.phase,
      'run_won',
      reason: 'seed 11 is a deterministic autoplay win (guard=$guard)',
    );
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography
    expect(
      c.pendingRankUp,
      isNotNull,
      reason: 'a won first run banks well past the 8-mark first threshold',
    );
    final line = find.byKey(const ValueKey('rank-up-line'));
    expect(line, findsOneWidget);
    expect(
      find.text('You delve as ${c.pendingRankUp!.withArticle} now.'),
      findsOneWidget,
    );
    // The announced tier is exactly the derived rank of the banked profile.
    expect(c.pendingRankUp!.id, rankFor(c.meta).id);
  });
}
