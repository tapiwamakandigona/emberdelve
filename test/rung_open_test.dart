// test/rung_open_test.dart — v0.32.0 "The Open Rung" (retention hook #7):
// a win that raises bestAscension announces the newly opened rung on the
// summary — Forge owners only.
//
// Pins:
//   1. Forge-owner frontier win → pendingRungOpened == new bestAscension and
//      the summary shows `rung-open-line` with the exact factual text.
//   2. startRun clears the announcement (same lifecycle as pendingRankUp).
//   3. A win BELOW the frontier moves nothing and announces nothing.
//   4. A loss announces nothing.
//   5. Free profile: bestAscension still moves 0→1 on a first win (ledger
//      fact), but the summary stays silent — a free profile cannot climb,
//      so the line would be a soft upsell (§Ethics, v0.32.0 design doc).
//   6. Rung-20 cap: a win at the top re-clamps to 20 and announces nothing.
//
// Seeds: 1 wins on easy (kindler, boons); 18 loses on easy; kindler seed 6
// wins at hard A20 (pinned by tool/asc_seed_hunt_test.dart, playRun defaults
// boons+keystones — driveToTerminal's botCmd defaults match).
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
    dir = await Directory.systemTemp.createTemp('rung_open_test');
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

  test(
    'frontier win opens a rung and startRun clears the announcement',
    () async {
      final c = GameController(saveDirOverride: dir.path);
      await c.boot();
      c.meta.forgeUnlocked = true;
      c.startRun(
        character: 'kindler',
        seed: 1,
        boons: true,
        difficulty: 'easy',
      );
      driveToTerminal(c);
      expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
      expect(c.meta.bestAscension, 1);
      expect(c.pendingRungOpened, 1);
      // Same lifecycle as pendingRankUp: the next run must not inherit it.
      c.startRun(
        character: 'kindler',
        seed: 1,
        boons: true,
        difficulty: 'easy',
      );
      expect(c.pendingRungOpened, isNull);
      await c.flushSaves();
    },
  );

  test('a win below the frontier announces nothing', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.forgeUnlocked = true;
    c.meta.bestAscension = 5;
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    expect(c.meta.bestAscension, 5, reason: 'rung-0 win must not move a 5');
    expect(c.pendingRungOpened, isNull);
    await c.flushSaves();
  });

  test('a loss announces nothing', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.forgeUnlocked = true;
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    expect(c.pendingRungOpened, isNull);
    await c.flushSaves();
  });

  test('rung 20 is the top: a win at the cap announces nothing', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.forgeUnlocked = true;
    c.meta.bestAscension = 20;
    c.startRun(
      character: 'kindler',
      seed: 6,
      boons: true,
      difficulty: 'hard',
      ascension: 20,
    );
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'kindler seed 6 is a pinned A20 win');
    expect(c.meta.bestAscension, 20, reason: 'no rung 21 may ever mint');
    expect(c.pendingRungOpened, isNull);
    await c.flushSaves();
  });

  testWidgets('Forge-owner frontier win shows the rung-open line', (
    tester,
  ) async {
    final c = GameController();
    c.meta.forgeUnlocked = true;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final line = find.byKey(const ValueKey('rung-open-line'));
    await tester.scrollUntilVisible(line, -200);
    expect(line, findsOneWidget);
    expect(
      tester.widget<Text>(line).data,
      'Rung 1 of the Ascension now stands open.',
    );
  });

  testWidgets('free profile: the ledger moves but the summary stays silent', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500);
    expect(c.meta.bestAscension, 1, reason: 'the ledger fact still banks');
    expect(find.byKey(const ValueKey('rung-open-line')), findsNothing);
  });
}
