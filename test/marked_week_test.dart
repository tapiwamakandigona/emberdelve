// test/marked_week_test.dart — v0.103.0 The Marked Week.
//
// Weekly runs banked NO mark: the record rendered as a plain run, and its
// row offered a Delve Code + retrace that would rebuild the run WITHOUT
// its mutator — a code that lies (a Delve Code cannot encode a rule).
// Records now bank 'weekly': true and the run's declared mutators
// (short_road excluded: it encodes as 'short'); modded rows state the rule
// by name and stay quiet on code and retrace.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
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
    final cmd = botCmd(c.sim!, mutators: [c.weeklyMutator ?? '']);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

Map<String, Object?> rec({bool weekly = false, List<String>? muts}) => {
  'date': '2026-08-24',
  'character': 'kindler',
  'difficulty': 'normal',
  'ascension': 0,
  'result': 'won',
  'floor': 8,
  'floors': 8,
  'seed': 42,
  'embers': 60,
  'fights': 6,
  if (weekly) 'weekly': true,
  if (muts != null) 'mutators': muts,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a finished weekly banks its mark and its rule', () {
    final c = GameController();
    c.startWeeklyRun();
    final expected = weeklyMutatorFor(weekIndexForDate(DateTime.now()));
    expect(c.weeklyMutator, expected);
    driveToTerminal(c);
    final r = c.meta.runHistory.first;
    expect(r['weekly'], isTrue);
    expect(r['mutators'], [expected]);
    // short_road is not among the banked mutators even on a short week —
    // it encodes, and banks as 'short'.
    expect((r['mutators'] as List).contains('short_road'), isFalse);
    expect(r['short'], expected == 'short_road' ? isTrue : isNull);
  });

  test('a plain run banks neither key', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    var guard = 0;
    while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    final r = c.meta.runHistory.first;
    expect(r['weekly'], isNull);
    expect(r['mutators'], isNull);
  });

  testWidgets('a modded row states its rule and offers no code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.meta.addRunRecord(rec(weekly: true, muts: ['all_d4']));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(
      find.textContaining('weekly · ${mutators['all_d4']!.name} · normal'),
      findsOneWidget,
    );
    // No code, no retrace — a Delve Code cannot encode the rule.
    expect(find.textContaining('tap to copy its Delve Code'), findsNothing);
    expect(
      find.byKey(const ValueKey('history-retrace-42-2026-08-24')),
      findsNothing,
    );
    // The card is still offered: it states facts, it rebuilds nothing.
    expect(
      find.byKey(const ValueKey('history-card-42-2026-08-24')),
      findsOneWidget,
    );
  });

  testWidgets('an unmodded row still offers code and retrace', (tester) async {
    tester.view.physicalSize = const Size(500, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.meta.addRunRecord(rec());
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    expect(find.textContaining('tap to copy its Delve Code'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('history-retrace-42-2026-08-24')),
      findsOneWidget,
    );
  });
}
