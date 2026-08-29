// test/earned_name_test.dart — v0.68.0 "The Earned Name": epithets a run's
// banking unlocks are announced with ONE quiet summary line each (key
// 'earned-name-<id>'), win or loss alike. Design doc:
// docs/improvements/v0.68.0-lead-scout.md.
//
// Pins:
//   1. A first win earns the_delver and pendingEpithets carries it;
//      startRun clears the list (pendingRankUp lifecycle).
//   2. A name already held is never re-announced.
//   3. A LOSS can earn a name — the_thorough lands on the tenth ENDED run
//      (runs_played counts losses; statValue honesty).
//   4. Widget: the summary shows the earned-name line with the exact text,
//      and stays silent when nothing was earned.
//
// Seeds: 1 wins on easy, 18 loses on easy (kindler, boons — pinned table,
// post-v0.47.0).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(guard < 4000, isTrue, reason: 'bot run failed to terminate');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('earned_name_test');
  });
  tearDown(() async {
    for (var i = 0; i < 10; i++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('a first win earns the Delver; startRun clears the list', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(c.pendingEpithets, contains('the_delver'));
    // Same lifecycle as pendingRankUp: the next run must not inherit it.
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    expect(c.pendingEpithets, isEmpty);
    await c.flushSaves();
  });

  test('a name already held is never re-announced', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.runsWon = 5; // the_delver held long before this run
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    expect(c.pendingEpithets, isNot(contains('the_delver')));
    await c.flushSaves();
  });

  test(
    'a LOSS can earn a name — the tenth ended run is the Thorough',
    () async {
      final c = GameController(saveDirOverride: dir.path);
      await c.boot();
      c.meta.runsPlayed = 9; // this loss is the tenth ended run
      c.startRun(
        character: 'kindler',
        seed: 18,
        boons: true,
        difficulty: 'easy',
      );
      driveToTerminal(c);
      expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
      expect(
        c.pendingEpithets,
        contains('the_thorough'),
        reason: 'runs_played counts losses — won, lost, or walked away',
      );
      await c.flushSaves();
    },
  );

  testWidgets('the summary shows the earned-name line with exact text', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final line = find.byKey(const ValueKey('earned-name-the_delver'));
    await tester.scrollUntilVisible(line, -200);
    expect(line, findsOneWidget);
    expect(
      tester.widget<Text>(line).data,
      '\u201cthe Delver\u201d is yours to wear.',
    );
  });

  testWidgets('the summary stays silent when nothing was earned', (
    tester,
  ) async {
    final c = GameController();
    c.meta.runsWon = 5; // the_delver already held
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500);
    expect(find.byKey(const ValueKey('earned-name-the_delver')), findsNothing);
  });
}
