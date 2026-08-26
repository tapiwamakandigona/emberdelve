// test/standing_delver_test.dart — v0.69.0 "The Standing Delver": the run
// summary shows the run's OWN delver (key 'summary-delver', worn dye) and
// names them with their worn title (key 'summary-delver-name'). Design doc:
// docs/improvements/v0.69.0-lead-scout.md.
//
// Pins:
//   1. The sprite and name line exist on a won summary; the name line reads
//      'The Kindler' bare when no epithet is worn.
//   2. A worn epithet joins the name — 'The Kindler, the Delver' — resolved
//      per delver (epithetFor), not from the legacy global field.
//   3. A lost summary still shows the sprite and name (the dark claimed
//      them, but they are still YOUR delver).
//
// Seeds: 1 wins on easy, 18 loses on easy (kindler, boons — pinned table).
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

  testWidgets('a won summary shows the delver and their bare name', (
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
    expect(find.byKey(const ValueKey('summary-delver')), findsOneWidget);
    final name = find.byKey(const ValueKey('summary-delver-name'));
    expect(name, findsOneWidget);
    expect(tester.widget<Text>(name).data, 'The Kindler');
  });

  testWidgets('a worn epithet joins the name, resolved per delver', (
    tester,
  ) async {
    final c = GameController();
    c.meta
      ..runsWon = 1
      ..charEpithet['kindler'] = 'the_delver';
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won');
    await pumpFor(tester, 2500);
    final name = find.byKey(const ValueKey('summary-delver-name'));
    expect(tester.widget<Text>(name).data, 'The Kindler, the Delver');
  });

  testWidgets('a lost summary still shows the delver and name', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 18, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_lost');
    await pumpFor(tester, 2500);
    expect(find.byKey(const ValueKey('summary-delver')), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-delver-name')), findsOneWidget);
  });
}
