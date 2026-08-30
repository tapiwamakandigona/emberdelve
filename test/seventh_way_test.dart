// test/seventh_way_test.dart — v0.119.0 The Seventh Way.
//
// The flintwright's proving and honors: the roster arc's chapter for the
// seventh delver. six_ways_down stays at 6 — earned recognition never
// re-prices; the new roster count gets its own name.
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the proving stands with the character provings, rules-free', () {
    final p = provingById('flintwrights_proving')!;
    expect(p.character, 'flintwright');
    expect(p.difficulty, 'normal');
    expect(p.seed, 9);
    expect(p.mutators, isEmpty, reason: 'a character proving, not a rule');
    final ids = provings.map((p) => p.id).toList();
    expect(
      ids.indexOf('flintwrights_proving'),
      ids.indexOf('tinkers_proving') + 1,
      reason: 'the character provings stand together',
    );
    expect(provings.last.id, 'ash_summit');
  });

  test('knapped sharp and seven ways down read the real counters', () {
    final knapped = achievements['flintwright_wins']!;
    expect(knapped.stat, 'char_wins');
    expect(knapped.param, 'flintwright');
    final seven = achievements['seven_ways_down']!;
    expect(seven.stat, 'delvers_cleared');
    expect(seven.target, 7);
    // The historical honor never re-prices.
    expect(achievements['six_ways_down']!.target, 6);

    final m = MetaState();
    for (final id in charactersOrder.sublist(0, 6)) {
      m.charWins[id] = 1;
    }
    m.charWins['ghost_delver'] = 99; // junk can never stand in
    expect(earnedAchievements(m), contains('six_ways_down'));
    expect(earnedAchievements(m), isNot(contains('seven_ways_down')));
    expect(earnedAchievements(m), isNot(contains('flintwright_wins')));
    m.charWins['flintwright'] = 1;
    expect(earnedAchievements(m), contains('seven_ways_down'));
    expect(earnedAchievements(m), contains('flintwright_wins'));
  });

  test('seventh way copy is honest (no pressure language)', () {
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
    final p = provingById('flintwrights_proving')!;
    final texts = [
      '${p.title} ${p.blurb}',
      for (final id in ['flintwright_wins', 'seven_ways_down'])
        '${achievements[id]!.name} ${achievements[id]!.text}',
    ];
    for (final t in texts) {
      for (final b in banned) {
        expect(t.toLowerCase().contains(b), isFalse, reason: 'banned: $b');
      }
    }
  });
}
