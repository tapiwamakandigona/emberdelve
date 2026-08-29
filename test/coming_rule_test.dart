// test/coming_rule_test.dart — v0.109.0 The Coming Rule.
//
// Next Monday's declared modifier, stated as a fact on the title screen —
// but only once this week has been played. An appointment for the engaged,
// not a nag for the new (§Ethics: no countdowns, no pressure language).
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/data/news.dart' show currentAppVersion;
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comingRuleLine names next week\'s actual rule, deterministically', () {
    for (var idx = 0; idx < 14; idx++) {
      final line = comingRuleLine(idx);
      final next = weeklyRuleFor(idx + 1);
      expect(line, 'Next Monday: ${next.name}');
      expect(comingRuleLine(idx), equals(line));
    }
  });

  test('the line is honest — no streak/expiry/pressure language', () {
    for (var idx = 0; idx < mutatorsOrder.length + 1; idx++) {
      final low = comingRuleLine(idx).toLowerCase();
      for (final banned in [
        'streak',
        'expire',
        'hurry',
        'miss out',
        'last chance',
        'only today',
        'don\'t miss',
      ]) {
        expect(low, isNot(contains(banned)));
      }
    }
  });

  testWidgets('title shows the coming rule only once the week is played', (
    tester,
  ) async {
    final c = GameController();
    c.meta
      ..tutorialSeen = true
      ..tourSeenVersion = tourVersion
      ..lastSeenNewsVersion = currentAppVersion
      ..tipsSeen.addAll(ContextTips.all)
      ..heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump();
    // Fresh meta: this week unplayed — no recap, no coming rule.
    expect(find.byKey(const ValueKey('weekly-coming-rule')), findsNothing);

    // Mark this week played; the recap and the coming rule appear together.
    final thisWeek = weekIndexForDate(DateTime.now());
    c.meta
      ..lastWeeklyKey = weeklyKey(thisWeek)
      ..lastWeeklyWon = false
      ..lastWeeklyFloor = 4
      ..lastWeeklyFloors = 9;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('weekly-recap')), findsOneWidget);
    final w = tester.widget<Text>(
      find.byKey(const ValueKey('weekly-coming-rule')),
    );
    expect(w.data, comingRuleLine(thisWeek));
  });
}
