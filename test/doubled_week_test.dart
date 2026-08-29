// test/doubled_week_test.dart — v0.111.0 The Doubled Week.
//
// One week per cycle the Weekly Delve deals a declared, named PAIR of rules
// — 'Cold Quarter' (no_shops + no_rests), vetted by bot sweep (102/150 on
// the kindler at normal; the all_d4 pairs swept at ~37/150 and were
// rejected as unfair). Same charter as every weekly: declared up front,
// same rule for everyone, no streaks, no expiry.
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first doubled-week Monday at or after 2026-01-05.
DateTime doubledMonday() {
  var idx = weekIndexForDate(DateTime(2026, 1, 5));
  while (weeklyRuleFor(idx).mutators.length < 2) {
    idx++;
  }
  final md = mondayOfWeek(idx);
  return DateTime(md[0], md[1], md[2]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the doubled slot closes the cycle and stays in the catalog', () {
    expect(doubledWeek.mutators, ['no_shops', 'no_rests']);
    for (final id in doubledWeek.mutators) {
      expect(isKnownMutator(id), isTrue);
    }
    expect(weeklyRuleFor(mutatorsOrder.length).name, doubledWeek.name);
    // Exactly one doubled slot per cycle.
    final cycle = mutatorsOrder.length + 1;
    final doubled = [
      for (var i = 0; i < cycle; i++)
        if (weeklyRuleFor(i).mutators.length > 1) i,
    ];
    expect(doubled, hasLength(1));
  });

  test('weeklyRuleName: singles, the pair, and unknowns', () {
    expect(weeklyRuleName('no_shops'), 'No Quarter');
    expect(weeklyRuleName('no_shops+no_rests'), 'Cold Quarter');
    expect(
      weeklyRuleName('no_rests+no_shops'),
      'Cold Quarter',
      reason: 'order-insensitive — the label is a set',
    );
    expect(
      weeklyRuleName('all_d4+no_rests'),
      'Flint Week + Cold Camps',
      reason: 'a non-slot pair falls back to joined catalog names',
    );
    expect(
      weeklyRuleName('someday_rule'),
      'Delve',
      reason: 'a save from the future must not throw',
    );
  });

  test('startWeeklyRun on a doubled week applies both rules', () {
    final c = GameController();
    c.startWeeklyRun(clock: doubledMonday());
    expect(c.weeklyMutator, 'no_shops+no_rests');
    expect(c.sim!.mutators.toSet(), containsAll({'no_shops', 'no_rests'}));
    // The map obeys both: no shop nodes, no rest nodes.
    final kinds = (c.sim!.map!['nodes'] as Map)
        .cast<String, Map>()
        .values
        .map((n) => n['kind'])
        .toList();
    expect(kinds.where((k) => k == 'shop'), isEmpty);
    expect(kinds.where((k) => k == 'rest'), isEmpty);
  });

  test('share text names the pair by its authored name', () {
    final text = weeklyShareText(
      index: 42,
      mutatorId: 'no_shops+no_rests',
      won: false,
      floor: 5,
      floors: 9,
    );
    expect(text, contains('Cold Quarter'));
    expect(text, isNot(contains('no_shops')));
  });

  test('the pair is bot-winnable (fairness proof)', () {
    // Seed 1 is a sweep winner for kindler/normal under the pair.
    final r = playRun(
      1,
      character: 'kindler',
      mutators: ['no_shops', 'no_rests'],
    );
    expect(r.sim.phase, 'run_won');
  });

  test('doubled week strings are honest (no pressure language)', () {
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
    final low = '${doubledWeek.name} ${doubledWeek.blurb}'.toLowerCase();
    for (final b in banned) {
      expect(low.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
