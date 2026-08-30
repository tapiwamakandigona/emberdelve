// test/full_rotation_test.dart — v0.127.0 The Full Rotation.
//
// The Weekly's collection arc: every rule a profile has WON under, banked
// canonically (sorted '+'-joined ids), junk-proof against hand-edited
// saves, unioned on merge, and driving two honors whose full target is
// pinned to the LIVE rotation.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monday 2026-02-02: the pinned bot-winnable doubled week (kindler).
DateTime doubledMonday() => DateTime(2026, 2, 2, 12);

void main() {
  test('labels canonicalize and the legal set tracks the rotation', () {
    expect(canonicalRuleLabel('no_shops+no_rests'), 'no_rests+no_shops');
    expect(canonicalRuleLabel('no_rests+no_shops'), 'no_rests+no_shops');
    expect(canonicalRuleLabel('all_d4'), 'all_d4');
    expect(legalRuleLabels(), hasLength(6));
    expect(legalRuleLabels(), contains('no_rests+no_shops'));
  });

  test('a won doubled weekly banks its canonical rule label', () {
    final c = GameController();
    c.meta.tutorialSeen = true;
    c.startWeeklyRun(clock: doubledMonday());
    var guard = 0;
    while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect(c.phase, 'run_won', reason: '2026-02-02 is the pinned bot win');
    expect(c.meta.weeklyRulesWon, {'no_rests+no_shops'});
  });

  test('junk labels never count toward the honors', () {
    final m = MetaState();
    m.weeklyRulesWon.addAll({'ghost_rule', 'all_d4+ghost'});
    expect(statValue(m, 'weekly_rules_won', null), 0);
    m.weeklyRulesWon.add('all_d4');
    expect(statValue(m, 'weekly_rules_won', null), 1);
    expect(earnedAchievements(m), contains('rule_taken'));
    expect(earnedAchievements(m), isNot(contains('full_rotation')));
    m.weeklyRulesWon.addAll(legalRuleLabels());
    expect(earnedAchievements(m), contains('full_rotation'));
  });

  test('the full honor tracks the live rotation (re-pricing doctrine)', () {
    expect(achievements['full_rotation']!.target, legalRuleLabels().length);
    expect(achievements['rule_taken']!.target, 1);
  });

  test('the set survives the round-trip and unions on merge', () {
    final m = MetaState();
    expect(m.toJson().containsKey('weeklyRulesWon'), isFalse);
    m.weeklyRulesWon.add('all_d4');
    expect(MetaState.fromJson(m.toJson()).weeklyRulesWon, {'all_d4'});
    final merged = mergeMetaStates(
      MetaState()..weeklyRulesWon.add('all_d4'),
      MetaState()..weeklyRulesWon.add('no_rests'),
    );
    expect(merged.weeklyRulesWon, {'all_d4', 'no_rests'});
  });

  testWidgets('the title shows the tally only once a rule is taken', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The line rides the played-this-week recap block, so pin a played
    // week AND a taken rule together.
    final c = GameController();
    c.meta
      ..tutorialSeen = true
      ..lastWeeklyKey = weeklyKey(weekIndexForDate(DateTime.now()))
      ..lastWeeklyWon = true
      ..lastWeeklyFloor = 9
      ..lastWeeklyFloors = 9;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: TitleScreen(c)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('weekly-rules-taken')), findsNothing);

    c.meta.weeklyRulesWon.addAll({'all_d4', 'ghost_rule'});
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: TitleScreen(c)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final line = find.byKey(const ValueKey('weekly-rules-taken'));
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<Text>(line).data,
      'Rules taken: 1 of 6',
      reason: 'junk labels never inflate the tally',
    );
  });

  test('rotation honor copy is honest (no pressure language)', () {
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
    for (final id in ['rule_taken', 'full_rotation']) {
      final t = '${achievements[id]!.name} ${achievements[id]!.text}'
          .toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
