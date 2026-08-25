// test/obituary_test.dart — v0.51.0 The Obituary: a finished run tells its
// own story on the summary screen, the record remembers its killer, and the
// Ledger's Recent Delves name the foe that ended a lost run.
//
// Pins:
//   1. obituaryText golden strings — win / loss / epithet / ascension /
//      Shorter Road / no-killer fallback / singular grammar. Deterministic:
//      template choice keys on the run seed.
//   2. Easy WIN (kindler seed 1): story rendered, names the seed's boss,
//      ends in embers banked; copy button offered.
//   3. Easy LOSS (kindler seed 18): story rendered, names the enemy the
//      terminal sim still holds; runHistory head carries killed_by with the
//      SAME id (§Ethics: the record can never disagree with the story);
//      Ledger row reads "fell on floor N of M to <killer>".
//   4. Legacy record without killed_by renders the row exactly as before.
//
// Seeds pinned by the offline bot hunt (kindler, boons, simVersion 7):
// seed 1 wins on easy; seed 18 loses on easy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/obituary.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/run_layer.dart' show bossForSeed;
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

/// Bot-play [c] to a terminal phase, then outlast the terminal-hold
/// choreography so the summary is fully settled.
Future<void> playOut(WidgetTester tester, GameController c) async {
  await pumpFor(tester, 400);
  var guard = 0;
  while (guard++ < 400 && c.phase != 'run_won' && c.phase != 'run_lost') {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(
    {'run_won', 'run_lost'}.contains(c.phase),
    isTrue,
    reason: 'bot must reach a terminal phase (guard=$guard)',
  );
  await pumpFor(tester, 2500);
}

void main() {
  group('obituaryText golden strings', () {
    test('win, even seed, clean floors', () {
      expect(
        obituaryText(
          won: true,
          delverName: 'The Kindler',
          epithetTitle: '',
          difficulty: 'easy',
          ascension: 0,
          floor: 9,
          floors: 9,
          cleanFloors: 4,
          killerName: '',
          bossName: 'The Bellows',
          embers: 212,
          short: false,
          seed: 2,
        ),
        'The Kindler came back up. All 9 floors on Easy, '
        '4 of them without a scratch. The Bellows felled at the bottom. '
        '212 embers banked.',
      );
    });

    test('win, odd seed, epithet + ascension + Shorter Road + singular clean',
        () {
      expect(
        obituaryText(
          won: true,
          delverName: 'The Gambler',
          epithetTitle: 'the Unburnt',
          difficulty: 'normal',
          ascension: 3,
          floor: 6,
          floors: 6,
          cleanFloors: 1,
          killerName: '',
          bossName: 'Ashfall Twins',
          embers: 88,
          short: true,
          seed: 7,
        ),
        'The Gambler, the Unburnt walked out with the Ember. '
        'All 6 floors on Normal (Ascension 3) by the Shorter Road, '
        'one of them without a scratch. Ashfall Twins felled at the bottom. '
        '88 embers banked.',
      );
    });

    test('loss, even seed, named killer', () {
      expect(
        obituaryText(
          won: false,
          delverName: 'The Warden',
          epithetTitle: '',
          difficulty: 'hard',
          ascension: 0,
          floor: 7,
          floors: 9,
          cleanFloors: 2,
          killerName: 'Ash Hound',
          bossName: '',
          embers: 41,
          short: false,
          seed: 2,
        ),
        'Here fell The Warden. Floor 7 of 9 on Hard, '
        '2 of them without a scratch — there Ash Hound ended the run. '
        '41 embers carried home.',
      );
    });

    test('loss, odd seed, no killer, no clean floors, singular ember', () {
      expect(
        obituaryText(
          won: false,
          delverName: 'The Kindler',
          epithetTitle: '',
          difficulty: 'easy',
          ascension: 0,
          floor: 1,
          floors: 9,
          cleanFloors: 0,
          killerName: '',
          bossName: '',
          embers: 1,
          short: false,
          seed: 1,
        ),
        'The delve took The Kindler. Floor 1 of 9 on Easy — '
        'there the delve ended. 1 ember carried home.',
      );
    });
  });

  testWidgets('easy win: story rendered, names the boss, copy offered', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await playOut(tester, c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    final story = c.delveStoryText;
    expect(story, isNotNull);
    final bossName = enemies[bossForSeed(1)]!.name;
    expect(story, contains(bossName));
    expect(story, contains('banked'));
    // The record of a WON run must never carry a killer.
    expect(c.meta.runHistory.first.containsKey('killed_by'), isFalse);
    final storyText = find.byKey(const ValueKey('delve-story'));
    await tester.scrollUntilVisible(storyText, -200);
    expect(storyText, findsOneWidget);
    expect(tester.widget<Text>(storyText).data, story);
    final copy = find.byKey(const ValueKey('copy-delve-story'));
    await tester.scrollUntilVisible(copy, -200);
    expect(copy, findsOneWidget);
  });

  testWidgets(
    'easy loss: story names the killer; record + Ledger row agree',
    (tester) async {
      final c = GameController();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
      );
      c.startRun(
        character: 'kindler',
        seed: 18,
        boons: true,
        difficulty: 'easy',
      );
      await playOut(tester, c);
      expect(c.phase, 'run_lost', reason: 'seed 18 must lose on easy');
      // Only combat kills (events clamp HP to 1) — the terminal sim still
      // holds the enemy, and the banked record remembers the same id.
      final killerId = c.sim!.enemy?['id'] as String?;
      expect(killerId, isNotNull);
      expect(c.meta.runHistory.first['killed_by'], killerId);
      final killerName = enemies[killerId]!.name;
      final story = c.delveStoryText;
      expect(story, isNotNull);
      expect(story, contains(killerName));
      expect(story, contains('carried home'));
      final storyText = find.byKey(const ValueKey('delve-story'));
      await tester.scrollUntilVisible(storyText, -200);
      expect(tester.widget<Text>(storyText).data, story);
      // The Ledger's Recent Delves row names the same foe.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
      );
      await pumpFor(tester, 400);
      // The Ledger is a lazy ListView — scroll the panel into build range
      // (positive delta scrolls DOWN; explicit scrollable required).
      final row = find.byKey(const ValueKey('recent-delves'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final rowText = find.descendant(
        of: row,
        matching: find.textContaining('to $killerName'),
      );
      expect(rowText, findsOneWidget);
    },
  );

  testWidgets('legacy record without killed_by renders as before', (
    tester,
  ) async {
    final c = GameController();
    c.meta.addRunRecord({
      'date': '2026-08-01',
      'character': 'kindler',
      'difficulty': 'normal',
      'ascension': 0,
      'result': 'lost',
      'floor': 5,
      'floors': 9,
      'seed': 12345,
      'embers': 10,
    });
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await pumpFor(tester, 400);
    final row = find.byKey(const ValueKey('recent-delves'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // The outcome text ends exactly at the floor count — no invented killer
    // suffix ("tap to copy its Delve Code" lives in the row's OTHER line, so
    // an exact-text pin is the honest check here).
    expect(
      find.descendant(
        of: row,
        matching: find.text('The Kindler — fell on floor 5 of 9'),
      ),
      findsOneWidget,
    );
  });
}
