// test/eighth_way_test.dart — v0.136.0 The Eighth Way.
//
// The runesmith's proving and honors: the roster arc's chapter for the
// eighth delver. seven_ways_down stays at 7 — earned recognition never
// re-prices; the new roster count gets its own name (Eight Ways Down).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the proving stands with the character provings, rules-free', () {
    final p = provingById('runesmiths_proving')!;
    expect(p.character, 'runesmith');
    expect(p.difficulty, 'normal');
    expect(p.seed, 5);
    expect(p.mutators, isEmpty, reason: 'a character proving, not a rule');
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('runesmiths_proving'),
      ids.indexOf('flintwrights_proving') + 1,
      reason: 'the character provings stand together',
    );
    expect(provings.length, 16);
    expect(provings.last.id, 'ash_summit');
  });

  test('the proving seed is bot-winnable as declared', () {
    final r = playRun(5, character: 'runesmith', difficulty: 'normal');
    expect(
      r.sim.phase,
      'run_won',
      reason: 'a proving must be winnable exactly as written',
    );
  });

  test('rune-sharp and eight ways down read the real counters', () {
    final sharp = achievements['runesmith_wins']!;
    expect(sharp.stat, 'char_wins');
    expect(sharp.param, 'runesmith');
    final eight = achievements['eight_ways_down']!;
    expect(eight.stat, 'delvers_cleared');
    expect(eight.target, 8);
    // The historical honor never re-prices.
    expect(achievements['seven_ways_down']!.target, 7);

    final m = MetaState();
    for (final id in charactersOrder.sublist(0, 7)) {
      m.charWins[id] = 1;
    }
    m.charWins['ghost_delver'] = 99; // junk can never stand in
    expect(earnedAchievements(m), contains('seven_ways_down'));
    expect(earnedAchievements(m), isNot(contains('eight_ways_down')));
    expect(earnedAchievements(m), isNot(contains('runesmith_wins')));
    m.charWins['runesmith'] = 1;
    expect(earnedAchievements(m), contains('eight_ways_down'));
    expect(earnedAchievements(m), contains('runesmith_wins'));
  });

  test('eighth way copy is honest (no pressure language)', () {
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
    final p = provingById('runesmiths_proving')!;
    final texts = [
      '${p.title} ${p.blurb}',
      for (final id in ['runesmith_wins', 'eight_ways_down'])
        '${achievements[id]!.name} ${achievements[id]!.text}',
    ];
    for (final t in texts) {
      final low = t.toLowerCase();
      for (final b in banned) {
        expect(low.contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
