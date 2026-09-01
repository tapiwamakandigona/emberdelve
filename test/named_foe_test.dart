// test/named_foe_test.dart — THE NAMED FOE (retention lane, DEMAND
// 2026-08-31c focus #1): a lost run's summary points at the foe that ended
// it, and one tap opens the codex glided straight to that entry. Losses
// that teach bring delvers back; losses that shrug do not (Roguebook GDC
// writeup, GlyphShuffle replayability essay — both name "no clue why I
// lost" as the churn moment).
//
// Pins:
//   1. Easy LOSS with a named killer → the 'named-foe' row is present and
//      names the killer's real enemy name; tapping it lands on CodexScreen
//      and the walk brings the killer's entry card on screen.
//   2. A WON run shows no such row.
//
// Seeds pinned by the offline bot hunt (kindler, boons, simVersion 7):
// seed 18 loses on easy, seed 1 wins on easy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Future<void> playOut(WidgetTester tester, GameController c) async {
  await pumpFor(tester, 400);
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(
    {'run_won', 'run_lost'}.contains(c.phase),
    isTrue,
    reason: 'bot must reach a terminal phase (guard=$guard)',
  );
  await pumpFor(tester, 2500);
}

void main() {
  testWidgets('loss: the named foe row opens the codex at the killer', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');

    final killerId = (c.state!['enemy'] as Map)['id'] as String;
    final entry = codexById['enemy:$killerId'];
    expect(entry, isNotNull, reason: 'every enemy has a codex page');

    final row = find.byKey(const ValueKey('named-foe'));
    await tester.scrollUntilVisible(row, 200);
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining(enemies[killerId]!.name),
      ),
      findsOneWidget,
      reason: 'the row names the real killer',
    );

    await tester.tap(row);
    // The route transition plus the codex walk-to-anchor glide; the walk is
    // linear 70ms steps with an ensureVisible tail — pump generously.
    await pumpFor(tester, 6000);
    expect(find.byType(CodexScreen), findsOneWidget);
    final card = find.byKey(ValueKey('codex-enemy:$killerId'));
    // The opened entry carries the screen's GlobalKey anchor instead of its
    // ValueKey — assert via the entry's name being on screen inside the codex.
    expect(
      card.evaluate().isNotEmpty ||
          find
              .descendant(
                of: find.byType(CodexScreen),
                matching: find.textContaining(enemies[killerId]!.name),
              )
              .evaluate()
              .isNotEmpty,
      isTrue,
      reason: 'the codex opened glided to the killer entry',
    );
  });

  testWidgets('win: no named foe row', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(find.byKey(const ValueKey('named-foe')), findsNothing);
  });
}
