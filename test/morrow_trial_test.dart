// test/morrow_trial_test.dart — THE MORROW'S DELVE (retention lane):
//   1. trialForMorrow is pure next-calendar-day derivation — same answer as
//      trialForDate on tomorrow, correct across month/year rollover.
//   2. morrowTrialLine states tomorrow's rule as a fact and stays inside the
//      §Ethics vocabulary (no streak/expiry/pressure words, ever).
//   3. A finished DAILY summary shows the line; a normal run's summary never
//      does.
//   4. The title's played-today recap block carries the same line; on any
//      other day (day-2 return, old record) it renders nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/game/trials.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

/// Same trivial terminal-walk policy as daily_record_test.dart.
void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 400) {
    switch (c.phase) {
      case 'boon':
        c.apply({'type': 'choose_boon', 'index': 0});
        break;
      case 'map':
        final m = c.state!['map'] as Map;
        final e = (m['edges'] as Map).cast<String, List>();
        final p = m['position'] as int;
        c.apply({
          'type': 'choose_node',
          'node': (e['$p'] as List).cast<int>().first,
        });
        break;
      case 'player_turn':
        c.apply({'type': 'roll'});
        c.apply({'type': 'end_turn'});
        break;
      case 'reward':
        c.apply({'type': 'choose_reward', 'index': 0});
        break;
      case 'rest':
        c.apply({'type': 'rest'});
        break;
      case 'shop':
        c.apply({'type': 'leave_shop'});
        break;
      case 'event':
        c.apply({'type': 'event_choose', 'option': 1});
        break;
    }
  }
}

void main() {
  test('trialForMorrow is trialForDate on the next calendar day', () {
    final t = trialForMorrow(DateTime(2026, 9, 1, 23, 30));
    expect(t.id, trialForDate(2026, 9, 2).id);

    // Month rollover: Sep 30 -> Oct 1.
    expect(
      trialForMorrow(DateTime(2026, 9, 30)).id,
      trialForDate(2026, 10, 1).id,
    );
    // Year rollover: Dec 31 -> Jan 1.
    expect(
      trialForMorrow(DateTime(2026, 12, 31)).id,
      trialForDate(2027, 1, 1).id,
    );
  });

  test('morrowTrialLine names tomorrow\'s trial and stays honest', () {
    final now = DateTime(2026, 9, 1);
    final t = trialForMorrow(now);
    final line = morrowTrialLine(now);
    expect(line, startsWith('Tomorrow\u2019s trial: '));
    expect(line, contains(t.name));
    expect(line, contains(t.blurb));
    final lower = line.toLowerCase();
    for (final banned in [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'only today',
    ]) {
      expect(lower, isNot(contains(banned)), reason: 'banned word: $banned');
    }
  });

  testWidgets('daily summary states tomorrow\'s trial; normal run stays '
      'silent', (tester) async {
    final c = GameController();
    c.startDailyRun(character: 'kindler');
    driveToTerminal(c);
    expect(c.phase, anyOf('run_won', 'run_lost'));

    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 600);
    expect(find.byKey(const ValueKey('morrow-trial')), findsOneWidget);
    expect(
      find.textContaining(trialForMorrow(DateTime.now()).name),
      findsWidgets,
    );

    // A NORMAL run's summary never mentions tomorrow — the line belongs to
    // the daily alone.
    c.startRun(character: 'kindler', seed: 42);
    driveToTerminal(c);
    await pumpFor(tester, 600);
    expect(find.byKey(const ValueKey('morrow-trial')), findsNothing);
  });

  testWidgets('title recap carries the morrow line only on the played day', (
    tester,
  ) async {
    final c = GameController();
    c.meta.lastDailyDate = dailyKey(DateTime.now());
    c.meta.lastDailyWon = true;
    c.meta.lastDailyFloor = 9;
    c.meta.lastDailyFloors = 9;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('daily-recap')), findsOneWidget);
    expect(find.byKey(const ValueKey('morrow-trial')), findsOneWidget);

    // Day-2 arrival: the return line stands ALONE — yesterday's player is
    // told today's delve is new, not lectured about the day after.
    c.meta.lastDailyDate = dailyKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    c.announce('rebuild');
    await pumpFor(tester, 300);
    expect(find.byKey(const ValueKey('morrow-trial')), findsNothing);
    expect(find.byKey(const ValueKey('daily-return')), findsOneWidget);
  });
}
