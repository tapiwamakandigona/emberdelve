// test/honest_ledger_test.dart — v0.141.0 The Honest Ledger.
//
// The re-pricing audit swept every promise-worded honor against its live
// catalog and found two shipped lies (the Whole Bestiary at 6 of 8 bosses,
// Full Company at 5 of 8 delvers). These pins make the whole CLASS unable
// to rot again: every 'every/all/whole' honor's target is asserted against
// the catalog it promises.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int bossCount() => enemies.values.where((e) => e.boss).length;

  test('every promise-worded honor asks for its whole live catalog', () {
    expect(achievements['all_three_bosses']!.target, bossCount());
    expect(achievements['full_company']!.target, characters.length);
    expect(achievements['crowned_company']!.target, characters.length);
    expect(achievements['hearth_keeper']!.target, hearthThemesOrder.length);
    expect(achievements['full_rotation']!.target, legalRuleLabels().length);
    expect(achievements['six_marks']!.target, faceRunes.length);
    expect(epithets['the_six_handed']!.target, characters.length);
    expect(epithets['the_weathered']!.target, legalRuleLabels().length);
  });

  test('promise-worded copy carries no stale count', () {
    // A promise honor whose text bakes in a number rots the moment its
    // catalog grows — the two fixed today both failed exactly this way.
    for (final id in [
      'all_three_bosses',
      'full_company',
      'crowned_company',
      'hearth_keeper',
      'full_rotation',
      'six_marks',
    ]) {
      final text = achievements[id]!.text.toLowerCase();
      for (final w in [
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
      ]) {
        expect(
          text.contains(' $w '),
          isFalse,
          reason: "$id text bakes in '$w' — promise copy stays count-free",
        );
      }
    }
  });

  test('historical counted honors keep their earned prices', () {
    // Fixed-count names never re-price (the other half of the doctrine).
    expect(achievements['five_ways_down']!.target, 5);
    expect(achievements['six_ways_down']!.target, 6);
    expect(achievements['seven_ways_down']!.target, 7);
    expect(achievements['full_roster']!.target, 4, reason: 'Full Hearth');
    expect(
      achievements['every_delver_clears']!.target,
      4,
      reason: 'Four Ways Down — counted name, frozen',
    );
  });
}
