// test/opened_vista_test.dart — v0.73.0 "The Opened Vista": vistas a run's
// banking opens are announced with ONE quiet summary line each (key
// 'opened-vista-<id>'), the same derived-diff shape as the earned-name
// lines. Design doc: docs/improvements/v0.73.0-lead-scout.md.
//
// Pins:
//   1. A first win opens the Moonveil and pendingVistas carries it;
//      startRun clears the list (pendingRankUp lifecycle).
//   2. A vista already open is never re-announced.
//   3. Widget: the summary shows the opened-vista line with the exact
//      text, and stays silent when nothing opened.
//
// Seeds: 1 wins on easy (kindler, boons — pinned table, post-v0.47.0).
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
    dir = await Directory.systemTemp.createTemp('opened_vista_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('a first win opens the Moonveil; startRun clears the list', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(c.pendingVistas, contains('moonveil'));
    // Same lifecycle as pendingRankUp: the next run must not inherit it.
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    expect(c.pendingVistas, isEmpty);
    await c.flushSaves();
  });

  test('a vista already open is never re-announced', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.runsWon = 5; // moonveil open long before this run
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    expect(c.pendingVistas, isNot(contains('moonveil')));
    await c.flushSaves();
  });

  testWidgets('the summary shows the opened-vista line with exact text', (
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

    final line = find.byKey(const ValueKey('opened-vista-moonveil'));
    await tester.scrollUntilVisible(line, -200);
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).data, 'The Moonveil vista stands open.');
  });

  testWidgets('the summary stays silent when nothing opened', (tester) async {
    final c = GameController();
    c.meta.runsWon = 5; // moonveil already open
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500);
    expect(find.byKey(const ValueKey('opened-vista-moonveil')), findsNothing);
  });
}
