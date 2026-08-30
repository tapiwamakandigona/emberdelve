// test/waymark_line_test.dart — v0.121.0 The Waymark Line.
//
// The title screen names the one unearned achievement closest to done,
// before the run — the summary's WITHIN REACH resolver promoted to where
// session intent forms. Contract: fresh installs see NOTHING (the game
// never assigns homework), counts are real and clamped, the line follows
// nearestAchievements' ordering, and tapping it opens the Ledger.
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  final end = ms ~/ 50;
  for (var i = 0; i < end; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh profile has no waymark line — no homework on boot', () {
    // A fresh profile is NOT progress-free (the default hearth theme
    // counts toward Full Hearth) — the pre-first-delve gate is what
    // keeps the title clean, so pin both facts.
    final m = MetaState();
    expect(nearestAchievements(m, limit: 1), isNotEmpty);
    expect(waymarkLine(m), isNull);
  });

  test('the line names the nearest waymark with real clamped counts', () {
    final m = MetaState();
    m.runsPlayed = 2;
    m.runsWon = 2; // clears: third is 2 of 3 in reach
    // nearestAchievements picks the highest fraction: 2/5 leads any
    // zero-progress goal (excluded) and any smaller fraction.
    final line = waymarkLine(m)!;
    expect(line, startsWith('Next waymark: '));
    expect(line, contains('\u2014'));
    final near = nearestAchievements(m, limit: 1).first;
    expect(line, contains(near.name));
    final v = statValue(m, near.stat, near.param).clamp(0, near.target);
    expect(line, endsWith('$v of ${near.target}'));
  });

  test('earning the named waymark moves the line to the next one', () {
    final m = MetaState();
    m.runsPlayed = 5;
    m.runsWon = 2;
    final first = nearestAchievements(m, limit: 1).first;
    // Bank whatever the first one asks for by maxing its stat family.
    m.runsWon = 5;
    final second = nearestAchievements(m, limit: 1).first;
    expect(second.id, isNot(first.id), reason: 'earned goals leave the line');
    expect(waymarkLine(m), contains(second.name));
  });

  testWidgets('title shows the line only with progress; tap opens Ledger', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final fresh = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: TitleScreen(fresh)),
    );
    await pumpFor(tester, 300);
    expect(find.byKey(const ValueKey('waymark-line')), findsNothing);

    final c = GameController();
    c.meta.runsPlayed = 2;
    c.meta.runsWon = 2;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: TitleScreen(c)),
    );
    await pumpFor(tester, 300);
    final line = find.byKey(const ValueKey('waymark-line'));
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(line);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(line, warnIfMissed: false);
    await pumpFor(tester, 400);
    expect(find.byType(LedgerScreen), findsOneWidget);
  });

  test('waymark line copy is honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    final m = MetaState();
    m.runsPlayed = 2;
    m.runsWon = 2;
    final t = waymarkLine(m)!.toLowerCase();
    for (final b in banned) {
      expect(t.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
