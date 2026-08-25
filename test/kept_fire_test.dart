// test/kept_fire_test.dart — v0.62.0 "The Kept Fire": the title greets a
// player returning after a week or more with ONE warm factual line (key
// 'kept-fire-line'), derived entirely from the newest runHistory date.
// Design doc: docs/improvements/v0.62.0-lead-scout.md.
//
// Pins:
//   1. keptFireLine: >= 7 calendar days since the newest remembered run →
//      exact text with the real day count; 6 days → null; fresh profile →
//      null; malformed/absent date → null (never a crash).
//   2. Calendar-day math: 23:59 to 00:01 across seven midnights counts 7 —
//      the wall-clock hour never changes the answer.
//   3. Banking a new run retires the line (the newest date becomes today).
//   4. Widget: an away profile shows the line on the title; an active
//      profile shows nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

/// A minimal ended-run record dated [date] (newest-first list order is the
/// caller's job — addRunRecord prepends).
Map<String, Object?> record(String date) => {
  'date': date,
  'character': 'kindler',
  'difficulty': 'easy',
  'ascension': 0,
  'result': 'lost',
  'floor': 3,
  'floors': 9,
  'seed': 7,
  'embers': 12,
};

/// Suppress every title overlay (tour, tips, news) so the widget pins see
/// the bare title column.
void quietTitle(GameController c) {
  c.meta
    ..tourSeenVersion = tourVersion
    ..tutorialSeen = true
    ..tipsSeen.addAll(ContextTips.all)
    ..lastSeenNewsVersion = currentAppVersion;
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

  test('the line states the real day count at 7+ days and only then', () {
    final now = DateTime(2026, 8, 25, 12);
    final m = MetaState();

    // Fresh profile: nothing remembered, nothing said.
    expect(keptFireLine(m, now: now), isNull);

    // 12 days away → the exact warm fact.
    m.runHistory.insert(0, record('2026-08-13'));
    expect(
      keptFireLine(m, now: now),
      '12 days since your last delve — the hearth kept its fire.',
    );

    // 6 days away → silence (the threshold is 7).
    m.runHistory.insert(0, record('2026-08-19'));
    expect(keptFireLine(m, now: now), isNull);

    // Exactly 7 days → speaks.
    m.runHistory.insert(0, record('2026-08-18'));
    expect(
      keptFireLine(m, now: now),
      '7 days since your last delve — the hearth kept its fire.',
    );
  });

  test('calendar-day math ignores the wall-clock hour', () {
    final m = MetaState()..runHistory.insert(0, record('2026-08-18'));
    // 00:01 on day 7 and 23:59 on day 7 agree.
    expect(keptFireLine(m, now: DateTime(2026, 8, 25, 0, 1)), isNotNull);
    expect(keptFireLine(m, now: DateTime(2026, 8, 25, 23, 59)), isNotNull);
    // 23:59 the evening BEFORE the seventh midnight stays silent.
    expect(keptFireLine(m, now: DateTime(2026, 8, 24, 23, 59)), isNull);
  });

  test('malformed or absent dates stay silent, never crash', () {
    final now = DateTime(2026, 8, 25);
    final junk = MetaState()..runHistory.insert(0, record('not-a-date'));
    expect(keptFireLine(junk, now: now), isNull);
    final absent = MetaState()
      ..runHistory.insert(0, (record('2026-01-01')..remove('date')));
    expect(keptFireLine(absent, now: now), isNull);
  });

  test('banking a new run retires the line', () {
    final c = GameController();
    c.meta.runHistory.insert(0, record('2026-01-01'));
    expect(keptFireLine(c.meta), isNotNull, reason: 'long away → speaks');
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(
      keptFireLine(c.meta),
      isNull,
      reason: 'the newest record is now today — the line retires itself',
    );
  });

  testWidgets('an away profile sees the line on the title', (tester) async {
    final c = GameController();
    quietTitle(c);
    // Ten calendar days before today, whatever today is.
    final away = DateTime.now().subtract(const Duration(days: 10));
    c.meta.runHistory.insert(0, record(dailyKey(away)));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    final line = find.byKey(const ValueKey('kept-fire-line'));
    expect(line, findsOneWidget);
    expect(
      tester.widget<Text>(line).data,
      '10 days since your last delve — the hearth kept its fire.',
    );
  });

  testWidgets('an active profile sees nothing', (tester) async {
    final c = GameController();
    quietTitle(c);
    c.meta.runHistory.insert(0, record(dailyKey(DateTime.now())));
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('kept-fire-line')), findsNothing);
  });
}
