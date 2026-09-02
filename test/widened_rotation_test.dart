// test/widened_rotation_test.dart — v0.180.0 "The Widened Rotation".
//
// Pins:
//   1. The anchor: widenedFromWeek IS the Monday-aligned index of 2026-09-14.
//   2. Before the anchor the six-week cycle is byte-for-byte what v0.111.0
//      dealt (singles then Cold Quarter) — nothing already dealt changes.
//   3. From the anchor the cycle is eight: singles, then Cold Quarter,
//      Lean Road, Hard March; every rule stays in the mutator catalog.
//   4. Labels: legalRuleLabels carries all three pairs canonically;
//      weeklyRuleName resolves either id order to the authored name.
//   5. The "Next Monday" line stays truthful across the seam.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/weekly.dart';

void main() {
  test('anchor is Monday 2026-09-14', () {
    expect(widenedFromWeek, weekIndex(2026, 9, 14));
    expect(mondayOfWeek(widenedFromWeek), [2026, 9, 14]);
  });

  test('before the anchor: the six-week cycle is unchanged', () {
    for (var idx = widenedFromWeek - 60; idx < widenedFromWeek; idx++) {
      final i = idx % 6;
      final rule = weeklyRuleFor(idx);
      if (i == 5) {
        expect(rule.mutators, doubledWeek.mutators);
      } else {
        expect(rule.mutators, [mutatorsOrder[i]]);
      }
    }
  });

  test('from the anchor: eight weeks, singles then the three pairs', () {
    const phase = widenedFromWeek % 6; // 1: the anchor continues the sequence
    for (var k = 0; k < 24; k++) {
      final idx = widenedFromWeek + k;
      final i = (k + phase) % 8;
      final rule = weeklyRuleFor(idx);
      if (i < 5) {
        expect(rule.mutators, [mutatorsOrder[i]]);
      } else {
        expect(rule.name, composedWeeks[i - 5].name);
        expect(rule.mutators, composedWeeks[i - 5].mutators);
        expect(rule.mutators.length, 2);
      }
      for (final id in rule.mutators) {
        expect(isKnownMutator(id), isTrue);
      }
    }
    // Seamless: the anchor week deals what the six-week cycle would have,
    // and the two cycles first part at the seventh slot after it.
    expect(weeklyRuleFor(widenedFromWeek).mutators, ['elites_only']);
    expect(weeklyRuleFor(widenedFromWeek - 1).mutators, ['all_d4']);
    expect(weeklyRuleFor(widenedFromWeek + 4).name, 'Cold Quarter');
    expect(weeklyRuleFor(widenedFromWeek + 5).name, 'Lean Road');
    expect(weeklyRuleFor(widenedFromWeek + 6).name, 'Hard March');
    expect(weeklyRuleFor(widenedFromWeek + 7).mutators, ['all_d4']);
  });

  test('pairs are legal labels and resolve to their authored names', () {
    final legal = legalRuleLabels();
    for (final w in composedWeeks) {
      expect(legal, contains(canonicalRuleLabel(w.mutators.join('+'))));
      expect(weeklyRuleName(w.mutators.join('+')), w.name);
      expect(weeklyRuleName(w.mutators.reversed.join('+')), w.name);
    }
    expect(weeklyRuleName('no_shops+short_road'), 'Lean Road');
    expect(weeklyRuleName('no_rests+short_road'), 'Hard March');
    expect(legal.length, mutatorsOrder.length + composedWeeks.length);
  });

  test('the coming-rule line is truthful across the seam', () {
    expect(
      comingRuleLine(widenedFromWeek - 1),
      'Next Monday: ${weeklyRuleFor(widenedFromWeek).name}',
    );
    expect(comingRuleLine(widenedFromWeek - 1), 'Next Monday: Elite Gauntlet');
    // Every week up to and including the seam's sixth slot matches the old
    // cycle, so no "Next Monday" line ever shown becomes false.
    for (var k = 0; k <= 4; k++) {
      final idx = widenedFromWeek + k;
      final old = idx % 6 == 5
          ? doubledWeek.mutators
          : [mutatorsOrder[idx % 6]];
      expect(weeklyRuleFor(idx).mutators, old);
    }
  });

  test('blurbs are honest (no pressure language)', () {
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
    for (final w in composedWeeks) {
      final all = '${w.name} ${w.blurb}'.toLowerCase();
      for (final word in banned) {
        expect(all.contains(word), isFalse, reason: '"$word" in ${w.name}');
      }
    }
  });
}
