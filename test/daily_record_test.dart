// test/daily_record_test.dart — v0.3.4 Daily Delve record + share
// (review note #3):
//   1. dailyKey / dailyRecapLine / dailyShareText are pure and honest —
//      no streak or expiry language, ever (§Ethics).
//   2. Finishing a daily records ONE result in meta (date, won, floor);
//      normal runs record nothing; abandoning a daily records nothing.
//   3. Title screen shows the recap line only on the day it was played.
//   4. Summary offers "Copy daily result" for daily runs only, and the
//      copied text matches the recorded result.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

/// Walk the current run to a terminal phase with a trivial policy (same
/// approach as widget_test.dart) — rolling without assigning loses fast.
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
        c.apply(
            {'type': 'choose_node', 'node': (e['$p'] as List).cast<int>().first});
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
  test('dailyKey pads and matches the controller label format', () {
    expect(dailyKey(DateTime(2026, 7, 4)), '2026-07-04');
    expect(dailyKey(DateTime(2026, 12, 24)), '2026-12-24');
  });

  test('recap and share text are honest and streak-free', () {
    final lost = dailyRecapLine(won: false, floor: 5, floors: 9);
    expect(lost, contains('floor 5 of 9'));
    final won = dailyRecapLine(won: true, floor: 9, floors: 9);
    expect(won, contains('Ember'));

    final share =
        dailyShareText(date: '2026-07-24', won: false, floor: 5, floors: 9);
    expect(share, contains('Emberdelve Daily 2026-07-24'));
    expect(share, contains('floor 5 of 9'));
    for (final s in [lost, won, share]) {
      expect(s.toLowerCase(), isNot(contains('streak')));
      expect(s.toLowerCase(), isNot(contains('expire')));
    }
  });

  test('finished daily records one result in meta; normal runs do not', () {
    final c = GameController();
    c.startDailyRun(character: 'kindler');
    driveToTerminal(c);
    expect(c.phase, anyOf('run_won', 'run_lost'));

    final today = dailyKey(DateTime.now());
    expect(c.meta.lastDailyDate, today);
    expect(c.meta.lastDailyWon, c.phase == 'run_won');
    expect(c.meta.lastDailyFloor, greaterThan(0));
    expect(c.meta.lastDailyFloors, greaterThanOrEqualTo(3));
    expect(c.meta.lastDailyFloor,
        lessThanOrEqualTo(c.meta.lastDailyFloors));

    final share = c.dailyResultShareText;
    expect(share, isNotNull);
    expect(share, contains(today));

    // A normal run afterwards must not touch the daily record...
    c.startRun(character: 'kindler', seed: 42);
    expect(c.dailyResultShareText, isNull, reason: 'mid-run: no share');
    driveToTerminal(c);
    expect(c.meta.lastDailyDate, today, reason: 'normal run left it alone');
    expect(c.dailyResultShareText, isNull,
        reason: 'normal runs never offer a daily share');
  });

  test('abandoning a daily records nothing', () {
    final c = GameController();
    c.startDailyRun(character: 'kindler');
    c.apply({'type': 'choose_boon', 'index': 0});
    c.abandonRun();
    expect(c.meta.lastDailyDate, isNull,
        reason: 'walking away is not a result');
  });

  testWidgets('title shows the daily recap only on the played day',
      (tester) async {
    final c = GameController();
    c.meta.lastDailyDate = dailyKey(DateTime.now());
    c.meta.lastDailyWon = false;
    c.meta.lastDailyFloor = 5;
    c.meta.lastDailyFloors = 9;
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('daily-recap')), findsOneWidget);
    expect(find.textContaining('floor 5 of 9'), findsOneWidget);

    // A record from another day stays silent.
    c.meta.lastDailyDate = '2001-01-01';
    c.announce('rebuild');
    await pumpFor(tester, 300);
    expect(find.byKey(const ValueKey('daily-recap')), findsNothing);
    await pumpFor(tester, 400);
  });

  testWidgets('summary offers Copy daily result for dailies only',
      (tester) async {
    // Capture what lands on the platform clipboard channel.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final c = GameController();
    await tester.pumpWidget(MaterialApp(
      theme: buildEmberTheme(),
      home: GameRoot(c),
    ));
    c.startDailyRun(character: 'kindler');
    await pumpFor(tester, 700);
    driveToTerminal(c);
    expect(c.phase, anyOf('run_won', 'run_lost'));
    await pumpFor(tester, 2500); // outlast the terminal-hold choreography

    final button = find.byKey(const ValueKey('copy-daily-result'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpFor(tester, 300);
    expect(copied, hasLength(1));
    expect(copied.single, equals(c.dailyResultShareText));
    expect(copied.single, contains('Emberdelve Daily'));

    // Normal-run summary: no share button.
    c.startRun(character: 'kindler', seed: 42);
    await pumpFor(tester, 700);
    driveToTerminal(c);
    await pumpFor(tester, 2500);
    expect(find.byKey(const ValueKey('copy-daily-result')), findsNothing);
    await pumpFor(tester, 400);
  });
}
