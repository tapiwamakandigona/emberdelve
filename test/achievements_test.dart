// test/achievements_test.dart — Delver's Ledger: data schema + honest progress.
// No hardcoded balance numbers; assertions reference the data modules.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/meta/achievements.dart';
import 'package:emberdelve/meta/meta.dart';

void main() {
  test('achievements: order matches map, ids self-consistent, legal stats', () {
    expect(achievementsOrder.toSet(), equals(achievements.keys.toSet()));
    expect(achievementsOrder.length, equals(achievements.length),
        reason: 'authoring order must not contain duplicates');
    achievements.forEach((id, a) {
      expect(a.id, equals(id));
      expect(a.name.trim(), isNotEmpty);
      expect(a.text.trim(), isNotEmpty);
      expect(achievementStats.contains(a.stat), isTrue,
          reason: '$id uses unknown stat ${a.stat}');
      expect(a.target, greaterThanOrEqualTo(1),
          reason: '$id must require real progress');
    });
  });

  test('achievements: char_wins params are real characters, and only they '
      'carry a param', () {
    achievements.forEach((id, a) {
      if (a.stat == 'char_wins') {
        expect(a.param, isNotNull, reason: '$id needs a character param');
        expect(characters.containsKey(a.param), isTrue,
            reason: '$id targets unknown character ${a.param}');
      } else {
        expect(a.param, isNull, reason: '$id must not carry a param');
      }
    });
  });

  test('achievements: roster/theme/boss targets stay inside real content', () {
    final bossCount = enemies.values.where((e) => e.boss).length;
    for (final a in achievements.values) {
      switch (a.stat) {
        case 'chars_unlocked':
          expect(a.target, lessThanOrEqualTo(characters.length),
              reason: '${a.id} asks for more delvers than exist');
          break;
        case 'themes_owned':
          expect(a.target, lessThanOrEqualTo(hearthThemes.length),
              reason: '${a.id} asks for more hearth colours than exist');
          break;
        case 'bosses_beaten':
          expect(a.target, lessThanOrEqualTo(bossCount),
              reason: '${a.id} asks for more bosses than exist');
          break;
        case 'best_ascension':
          expect(a.target, lessThanOrEqualTo(20),
              reason: '${a.id} exceeds the top rung');
          break;
      }
    }
  });

  test('a fresh profile has earned nothing and is close to nothing', () {
    final m = MetaState();
    expect(earnedAchievements(m), isEmpty);
    expect(earnedCount(m), equals(0));
    expect(unseenAchievements(m), isEmpty);
    // Zero progress is not "nearly there" — the near list must stay empty.
    expect(nearestAchievements(m), isEmpty);
    for (final a in achievements.values) {
      expect(progress(m, a), equals(0.0), reason: '${a.id} starts at a lie');
    }
  });

  test('progress is real, monotonic and clamped', () {
    final def = achievements['ten_delves']!;
    final m = MetaState();
    expect(progress(m, def), equals(0.0));
    m.runsPlayed = 5;
    expect(progress(m, def), closeTo(0.5, 1e-9));
    expect(isEarned(m, def), isFalse);
    m.runsPlayed = 10;
    expect(progress(m, def), equals(1.0));
    expect(isEarned(m, def), isTrue);
    m.runsPlayed = 999; // never overflows the bar
    expect(progress(m, def), equals(1.0));
  });

  test('every stat is wired to a real counter', () {
    // Guards against a stat that exists in the vocabulary but returns 0 for
    // every profile — which would strand any achievement using it forever.
    final m = MetaState(
      unlocked: characters.keys.toSet(),
      ownedThemes: hearthThemes.keys.toSet(),
    )
      ..runsPlayed = 3
      ..runsWon = 2
      ..exactKills = 4
      ..bestExactStreak = 5
      ..lifetimeEmbers = 600
      ..bestAscension = 7
      ..bestFloor = 8
      ..dailiesPlayed = 9
      ..winsNoRest = 2
      ..hardWins = 3;
    m.charWins['kindler'] = 6;
    m.bossesBeaten.add('ember_tyrant');
    for (final stat in achievementStats) {
      final param = stat == 'char_wins' ? 'kindler' : null;
      expect(statValue(m, stat, param), greaterThan(0),
          reason: '$stat reads 0 on a fully populated profile');
    }
    expect(statValue(m, 'not_a_stat'), equals(0));
  });

  test('a toast fires once: unseen empties after markSeen', () {
    final m = MetaState()..runsPlayed = 1;
    final first = unseenAchievements(m);
    expect(first, contains('first_delve'));
    markSeen(m, first);
    expect(unseenAchievements(m), isEmpty);
    // More progress announces only the NEW ones.
    m.runsPlayed = 10;
    final second = unseenAchievements(m);
    expect(second, contains('ten_delves'));
    expect(second, isNot(contains('first_delve')));
  });

  test('nearest list is ordered, deterministic and excludes earned', () {
    final m = MetaState()
      ..runsPlayed = 9 // 90% of ten_delves
      ..exactKills = 1 // first_blood earned, exact_ten at 10%
      ..lifetimeEmbers = 50; // 50% of kindled
    final near = nearestAchievements(m, limit: 3);
    expect(near.map((a) => a.id), isNot(contains('first_blood')),
        reason: 'earned achievements are not "near"');
    expect(near.first.id, equals('ten_delves'));
    for (var i = 1; i < near.length; i++) {
      expect(progress(m, near[i - 1]),
          greaterThanOrEqualTo(progress(m, near[i])));
    }
    expect(nearestAchievements(m, limit: 3).map((a) => a.id).toList(),
        equals(near.map((a) => a.id).toList()), reason: 'must be stable');
  });

  test('ledger counters survive a save/load round trip', () {
    final m = MetaState()
      ..bestFloor = 6
      ..dailiesPlayed = 4
      ..winsNoRest = 2
      ..hardWins = 1;
    m.bossesBeaten.addAll({'ember_tyrant', 'pyre_matriarch'});
    m.seenAchievements.addAll({'first_delve', 'deeper_still'});
    final back = MetaState.fromJson(Map<String, dynamic>.from(m.toJson()));
    expect(back.bestFloor, equals(6));
    expect(back.dailiesPlayed, equals(4));
    expect(back.winsNoRest, equals(2));
    expect(back.hardWins, equals(1));
    expect(back.bossesBeaten, equals({'ember_tyrant', 'pyre_matriarch'}));
    expect(back.seenAchievements, contains('deeper_still'));
  });

  test('a pre-v0.5.0 save migrates honestly, never generously', () {
    // No ledger fields at all, but a run history and a recorded daily.
    final legacy = <String, dynamic>{
      'schema': 2,
      'runsPlayed': 12,
      'lastDailyDate': '2026-08-01',
      'runHistory': [
        {'floor': 4, 'floors': 9, 'result': 'lost'},
        {'floor': 7, 'floors': 9, 'result': 'lost'},
        {'floor': 2, 'floors': 9, 'result': 'lost'},
      ],
    };
    final m = MetaState.fromJson(legacy);
    // bestFloor is provable from history: 7.
    expect(m.bestFloor, equals(7));
    // Exactly one daily is provable; runsPlayed must NOT inflate it.
    expect(m.dailiesPlayed, equals(1));
    // Nothing unprovable is invented.
    expect(m.winsNoRest, equals(0));
    expect(m.hardWins, equals(0));
    expect(m.bossesBeaten, isEmpty);
    expect(m.seenAchievements, isEmpty);
  });

  test('earning an achievement never changes what a run may start with', () {
    // Recognition only (spec section Ethics): the ledger must not be able to
    // hand out embers, unlocks, difficulty or ascension. Earning everything a
    // fresh profile can earn must leave every entitlement untouched.
    final before = MetaState();
    final after = MetaState()
      ..runsPlayed = 100
      ..runsWon = 10
      ..exactKills = 200
      ..bestExactStreak = 12
      ..bestFloor = 9
      ..dailiesPlayed = 30
      ..winsNoRest = 3;
    markSeen(after, unseenAchievements(after));
    expect(earnedCount(after), greaterThan(0));
    expect(after.embers, equals(before.embers));
    expect(after.unlockedCharacters, equals(before.unlockedCharacters));
    expect(after.ownedThemes, equals(before.ownedThemes));
    expect(after.bestAscension, equals(before.bestAscension));
    expect(after.forgeUnlocked, equals(before.forgeUnlocked));
    expect(after.preferredDifficulty, equals(before.preferredDifficulty));
  });
}
