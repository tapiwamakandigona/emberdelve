// test/cold_honors_test.dart — v0.113.0 The Cold Honors.
//
// Two achievements on the doubled week's monotonic win counter — the same
// meta.doubledWins that feeds the Frostvein vista (v0.112.0). Recognition
// only, grants nothing (§Ethics).
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold honors are catalogued, legal, and read the real counter', () {
    for (final id in ['first_winter', 'thrice_wintered']) {
      expect(achievementsOrder, contains(id));
      final a = achievements[id]!;
      expect(achievementStats, contains(a.stat));
      expect(a.stat, 'doubled_wins');
    }
    expect(achievements['first_winter']!.target, 1);
    expect(achievements['thrice_wintered']!.target, 3);
    final m = MetaState()..doubledWins = 2;
    expect(statValue(m, 'doubled_wins', null), 2);
  });

  test('the honors earn at 1 and 3 wins, with real progress between', () {
    final m = MetaState();
    expect(earnedAchievements(m), isNot(contains('first_winter')));
    m.doubledWins = 1;
    expect(earnedAchievements(m), contains('first_winter'));
    expect(earnedAchievements(m), isNot(contains('thrice_wintered')));
    expect(
      progress(m, achievements['thrice_wintered']!),
      closeTo(1 / 3, 0.001),
    );
    m.doubledWins = 3;
    expect(earnedAchievements(m), contains('thrice_wintered'));
    // Junk-proof: the counter is banked, never derived, so a fresh profile
    // with a hand-edited huge value still just reads the number.
    expect(statValue(MetaState()..doubledWins = 99, 'doubled_wins', null), 99);
  });

  test('cold honors copy is honest (no pressure language)', () {
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
    for (final id in ['first_winter', 'thrice_wintered']) {
      final a = achievements[id]!;
      final low = '${a.name} ${a.text}'.toLowerCase();
      for (final b in banned) {
        expect(low.contains(b), isFalse, reason: '$id banned: $b');
      }
    }
  });
}
