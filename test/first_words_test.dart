// test/first_words_test.dart — v0.71.0 "The First Words": a fresh profile's
// title states the PREMISE once (key 'first-words'); the first ended run
// retires it forever. Pure derived state — no save field. Design doc:
// docs/improvements/v0.71.0-lead-scout.md.
//
// Pins:
//   1. firstWordsLine: fresh profile → exact text; any remembered run or
//      any counted run → null (both gates, independently).
//   2. Widget: a fresh profile shows the line on the title; ending one run
//      and returning to the title shows nothing.
//   3. The line and the kept-fire line can never collide (kept-fire needs
//      a remembered run, first-words needs none).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/game/controller.dart';
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

  test('firstWordsLine gates on a truly fresh profile', () {
    final fresh = MetaState();
    expect(
      firstWordsLine(fresh),
      'The delve is the dark below the hearth — floor under floor '
      'of it. Go down with your dice, come back with the Ember.',
    );
    final played = MetaState()..runsPlayed = 1;
    expect(firstWordsLine(played), isNull);
    final remembered = MetaState()
      ..runHistory.add({'date': '2026-08-20', 'result': 'lost'});
    expect(firstWordsLine(remembered), isNull);
  });

  test('first-words and kept-fire can never collide', () {
    final fresh = MetaState();
    expect(firstWordsLine(fresh), isNotNull);
    expect(keptFireLine(fresh), isNull);
    final away = MetaState()
      ..runsPlayed = 1
      ..runHistory.add({'date': '2026-08-01', 'result': 'lost'});
    expect(firstWordsLine(away), isNull);
    expect(keptFireLine(away, now: DateTime(2026, 8, 26)), isNotNull);
  });

  testWidgets('the fresh title tells the premise; the first run ends it', (
    tester,
  ) async {
    final c = GameController();
    quietTitle(c);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 400);
    expect(find.byKey(const ValueKey('first-words')), findsOneWidget);

    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    await pumpFor(tester, 2500);
    // Remount the title (a run has now banked) — the line is gone forever.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    c.endToTitle();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 600);
    expect(find.byKey(const ValueKey('first-words')), findsNothing);
    expect(firstWordsLine(c.meta), isNull);
  });
}
