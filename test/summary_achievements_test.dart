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
import 'package:emberdelve/data/dice.dart';
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

    final pool = find.byKey(const ValueKey('pool-forged-recap'));
    expect(pool, findsOneWidget);
    final dice = (c.state!['player'] as Map)['dice'] as List;
    for (final sides in [4, 6, 8, 10, 12]) {
      final count = dice.where((id) => dieDef('$id').size == sides).length;
      expect(
        find.descendant(
            of: pool, matching: find.byKey(ValueKey('pool-d$sides'))),
        count > 0 ? findsOneWidget : findsNothing,
      );
      if (count > 0) {
        expect(
            find.descendant(
                of: pool, matching: find.text('d$sides ×$count')),
            findsOneWidget);
      }
    }
  });

  testWidgets('loss summary also recaps the exact forged pool',
      (tester) async {
    final c = GameController();
    c.meta.tutorialSeen = true;
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    c.startRun(character: 'kindler', seed: 3);
    (c.state!['player'] as Map)['dice'] = <String>[
      'd4_lucky',
      'd6',
      'd8_surge',
      'd10_steady',
      'd12_heart',
    ];
    c.sim!.phase = 'run_lost';
    c.notifyListeners();
    await pumpFor(tester, 700);

    final pool = find.byKey(const ValueKey('pool-forged-recap'));
    expect(pool, findsOneWidget);
    for (final sides in [4, 6, 8, 10, 12]) {
      expect(find.descendant(of: pool, matching: find.text('d$sides ×1')),
          findsOneWidget);
    }
    expect(find.descendant(of: pool, matching: find.text('4 SPECIAL')),
        findsOneWidget);
    expect(find.descendant(of: pool, matching: find.text('HEARTFORGED')),
        findsOneWidget);
  });
}
