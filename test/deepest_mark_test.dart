// test/deepest_mark_test.dart — v0.61.0 "The Deepest Mark": a run that
// stands on a deeper layer than any before it earns ONE quiet summary line
// (key 'deepest-line'), win or loss alike. Design doc:
// docs/improvements/v0.61.0-lead-scout.md.
//
// Pins:
//   1. A profile's FIRST-ever run moves bestFloor but announces nothing —
//      "deepest yet" needs a previous record to beat (bestFloor > 0 gate).
//   2. A run deeper than the standing record sets pendingDeepestFloor to the
//      new bestFloor, and startRun clears it (pendingRankUp lifecycle).
//   3. A run that does NOT exceed the record announces nothing and never
//      lowers bestFloor.
//   4. A LOSS deeper than the record still announces — the record is the
//      dignity (loss-retention evidence, v0.61.0 scout doc).
//   5. Widget: the summary shows 'deepest-line' with the exact factual text
//      when the mark is set, and stays silent on a non-record run.
//
// Seeds: 1 wins on easy (kindler, boons — reaches the final layer); 18
// loses on easy (same pinned table as rung_open_test.dart).
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
    dir = await Directory.systemTemp.createTemp('deepest_mark_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('a first-ever run moves bestFloor but announces nothing', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    expect(c.meta.bestFloor, 0, reason: 'fresh profile has no record');
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(c.meta.bestFloor, greaterThan(0), reason: 'the ledger fact banks');
    expect(
      c.pendingDeepestFloor,
      isNull,
      reason: 'no previous record existed to beat',
    );
    await c.flushSaves();
  });

  test('a deeper run sets the mark and startRun clears it', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.bestFloor = 2; // a standing record from "past" runs
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    expect(c.meta.bestFloor, greaterThan(2));
    expect(c.pendingDeepestFloor, c.meta.bestFloor);
    // Same lifecycle as pendingRankUp: the next run must not inherit it.
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    expect(c.pendingDeepestFloor, isNull);
    await c.flushSaves();
  });

  test('a run that does not exceed the record announces nothing', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.bestFloor = 99;
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    expect(c.meta.bestFloor, 99, reason: 'the record is a high-water mark');
    expect(c.pendingDeepestFloor, isNull);
    await c.flushSaves();
  });

  test('a loss deeper than the record still announces', () async {
    // Learn where the pinned loss falls, then beat exactly that record.
    final probe = GameController(saveDirOverride: dir.path);
    await probe.boot();
    probe.startRun(
      character: 'kindler',
      seed: 18,
      boons: true,
      difficulty: 'easy',
    );
    driveToTerminal(probe);
    expect(probe.phase, 'run_lost', reason: 'seed 18 must lose on easy');
    final fell = probe.meta.runHistory.first['floor'] as int;
    expect(
      fell,
      greaterThan(1),
      reason: 'the pinned loss must fall past floor 1 for this pin to bite',
    );
    await probe.flushSaves();

    final c = GameController(saveDirOverride: dir.path);
    c.meta.bestFloor = fell - 1;
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost');
    expect(c.meta.bestFloor, fell);
    expect(
      c.pendingDeepestFloor,
      fell,
      reason: 'a lost run can still be the deepest — that IS the dignity',
    );
  });

  testWidgets('the summary shows the deepest line with exact text', (
    tester,
  ) async {
    final c = GameController();
    c.meta.bestFloor = 1; // any shallower standing record
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final line = find.byKey(const ValueKey('deepest-line'));
    await tester.scrollUntilVisible(line, -200);
    expect(line, findsOneWidget);
    expect(
      tester.widget<Text>(line).data,
      'Floor ${c.meta.bestFloor} — the deepest you have delved.',
    );
  });

  testWidgets('the summary stays silent on a non-record run', (tester) async {
    final c = GameController();
    c.meta.bestFloor = 99;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500);
    expect(find.byKey(const ValueKey('deepest-line')), findsNothing);
  });
}
