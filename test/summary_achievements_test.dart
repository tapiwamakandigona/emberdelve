// test/summary_achievements_test.dart — v0.5.0 fix: the summary screen must
// ANNOUNCE the achievements a run earned. _bankRun had collected them into
// pendingAchievements "for the summary screen" since the Ledger shipped, but
// no widget ever read the list — the announcement silently never happened,
// and markSeen guaranteed it never could later. This pins the wiring:
//   1. A first run always earns first_delve, so its summary must show the
//      achievements-earned panel with that name.
//   2. The panel is recognition only: the run's own name/text, no reward talk.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

void main() {
  testWidgets('summary announces the achievements the run earned',
      (tester) async {
    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    c.startRun(character: 'kindler', seed: 11, boons: true);
    await pumpFor(tester, 400);
    var guard = 0;
    while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect({'run_won', 'run_lost'}.contains(c.phase), isTrue,
        reason: 'bot must reach a terminal phase (guard=$guard)');
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final panel = find.byKey(const ValueKey('achievements-earned'));
    expect(panel, findsOneWidget,
        reason: 'a first run always earns first_delve, so the summary '
            'must announce it');
    expect(
        find.descendant(
            of: panel, matching: find.text(achievements['first_delve']!.name)),
        findsOneWidget);
  });
}
