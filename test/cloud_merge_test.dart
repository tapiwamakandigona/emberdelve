// test/cloud_merge_test.dart — the P4 cloud-save merge contract
// (lib/meta/cloud_merge.dart): max for monotonic counters, union for owned
// sets, OR for sticky flags, fresher-side for spendables and recap records.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';

void main() {
  group('isFresher', () {
    test('higher lifetimeEmbers wins', () {
      final a = MetaState(lifetimeEmbers: 100);
      final b = MetaState(lifetimeEmbers: 300);
      expect(isFresher(a, b), isFalse);
      expect(isFresher(b, a), isTrue);
    });

    test('lifetime tie falls back to runsPlayed', () {
      final a = MetaState(lifetimeEmbers: 100, runsPlayed: 4);
      final b = MetaState(lifetimeEmbers: 100, runsPlayed: 9);
      expect(isFresher(a, b), isFalse);
      expect(isFresher(b, a), isTrue);
    });

    test('full tie prefers the first argument (call local first)', () {
      final a = MetaState(lifetimeEmbers: 5, runsPlayed: 2);
      final b = MetaState(lifetimeEmbers: 5, runsPlayed: 2);
      expect(isFresher(a, b), isTrue);
    });
  });

  group('mergeMetaStates', () {
    test('monotonic counters take the max from either side', () {
      final local = MetaState(
        runsPlayed: 10,
        runsWon: 3,
        lifetimeEmbers: 500,
        exactKills: 7,
        bestExactStreak: 4,
        bestFloor: 6,
        dailiesPlayed: 2,
        weekliesPlayed: 1,
        winsNoRest: 1,
        hardWins: 0,
        bestAscension: 3,
      );
      final cloud = MetaState(
        runsPlayed: 8,
        runsWon: 5,
        lifetimeEmbers: 400,
        exactKills: 11,
        bestExactStreak: 2,
        bestFloor: 9,
        dailiesPlayed: 5,
        weekliesPlayed: 3,
        winsNoRest: 0,
        hardWins: 2,
        bestAscension: 1,
      );
      final m = mergeMetaStates(local, cloud);
      expect(m.runsPlayed, 10);
      expect(m.runsWon, 5);
      expect(m.lifetimeEmbers, 500);
      expect(m.exactKills, 11);
      expect(m.bestExactStreak, 4);
      expect(m.bestFloor, 9);
      expect(m.dailiesPlayed, 5);
      expect(m.weekliesPlayed, 3);
      expect(m.winsNoRest, 1);
      expect(m.hardWins, 2);
      expect(m.bestAscension, 3);
    });

    test('owned sets union — earned anywhere stays earned', () {
      final local = MetaState(
        unlocked: {'kindler', 'warden'},
        ownedThemes: {'hearth', 'violet'},
        ownedDieSkins: {'bone'},
        ownedCodex: {'enemy:rat'},
        bossesBeaten: {'boss_a'},
        seenAchievements: {'first_win'},
      );
      final cloud = MetaState(
        unlocked: {'kindler', 'ember_witch'},
        ownedThemes: {'hearth'},
        ownedDieSkins: {'bone', 'gilt'},
        ownedCodex: {'relic:coal'},
        bossesBeaten: {'boss_b'},
        seenAchievements: {'first_win', 'deep_six'},
      );
      final m = mergeMetaStates(local, cloud);
      expect(
        m.unlockedCharacters,
        containsAll({'kindler', 'warden', 'ember_witch'}),
      );
      expect(m.ownedThemes, containsAll({'hearth', 'violet'}));
      expect(m.ownedDieSkins, containsAll({'bone', 'gilt'}));
      expect(m.ownedCodex, containsAll({'enemy:rat', 'relic:coal'}));
      expect(m.bossesBeaten, containsAll({'boss_a', 'boss_b'}));
      expect(m.seenAchievements, containsAll({'first_win', 'deep_six'}));
    });

    test('sticky flags OR — a paid Forge unlock is never lost', () {
      final local = MetaState(forgeUnlocked: false, tutorialSeen: true);
      final cloud = MetaState(forgeUnlocked: true, tutorialSeen: false);
      final m = mergeMetaStates(local, cloud);
      expect(m.forgeUnlocked, isTrue);
      expect(m.tutorialSeen, isTrue);
    });

    test('per-character maps merge per key with max', () {
      final local = MetaState(
        charRuns: {'kindler': 5, 'warden': 2},
        charWins: {'kindler': 1},
      );
      final cloud = MetaState(
        charRuns: {'kindler': 3, 'ember_witch': 4},
        charWins: {'kindler': 2, 'warden': 1},
      );
      final m = mergeMetaStates(local, cloud);
      expect(m.charRuns, {'kindler': 5, 'warden': 2, 'ember_witch': 4});
      expect(m.charWins, {'kindler': 2, 'warden': 1});
    });

    test('spendables, recaps and history come from the fresher side', () {
      final local = MetaState(
        lifetimeEmbers: 900, // fresher
        embers: 120,
        activeTheme: defaultThemeForTest(),
        lastDailyDate: '2026-08-11',
        lastDailyWon: true,
        lastDailyFloor: 6,
        lastDailyFloors: 6,
        runHistory: [
          {'date': '2026-08-11', 'result': 'won', 'floor': 6},
        ],
      );
      final cloud = MetaState(
        lifetimeEmbers: 400,
        embers: 990,
        lastDailyDate: '2026-08-01',
        lastDailyWon: false,
        lastDailyFloor: 2,
        lastDailyFloors: 6,
        runHistory: [
          {'date': '2026-08-01', 'result': 'lost', 'floor': 2},
        ],
      );
      final m = mergeMetaStates(local, cloud);
      expect(m.embers, 120); // NOT max — fresher side's spendable balance
      expect(m.lastDailyDate, '2026-08-11');
      expect(m.lastDailyWon, isTrue);
      expect(m.lastDailyFloor, 6);
      expect(m.runHistory.single['result'], 'won');
    });

    test('cloud fresher: local owned skin survives, cloud balance rules', () {
      final local = MetaState(
        lifetimeEmbers: 100,
        embers: 5,
        ownedDieSkins: {'bone', 'gilt'},
      );
      final cloud = MetaState(
        lifetimeEmbers: 800,
        embers: 640,
        ownedDieSkins: {'bone'},
      );
      final m = mergeMetaStates(local, cloud);
      expect(m.embers, 640);
      expect(m.ownedDieSkins, contains('gilt'));
    });

    test('merging with a fresh profile keeps all progress intact', () {
      final veteran = MetaState(
        lifetimeEmbers: 1000,
        embers: 250,
        runsPlayed: 40,
        runsWon: 12,
        forgeUnlocked: true,
        unlocked: {'kindler', 'warden'},
        runHistory: [
          {'date': '2026-08-11', 'result': 'won', 'floor': 6},
        ],
      );
      final blank = MetaState();
      for (final m in [
        mergeMetaStates(veteran, blank),
        mergeMetaStates(blank, veteran),
      ]) {
        expect(m.lifetimeEmbers, 1000);
        expect(m.embers, 250);
        expect(m.runsPlayed, 40);
        expect(m.runsWon, 12);
        expect(m.forgeUnlocked, isTrue);
        expect(m.unlockedCharacters, containsAll({'kindler', 'warden'}));
        expect(m.runHistory, hasLength(1));
      }
    });

    test('inputs are not mutated and history is deep-copied', () {
      final local = MetaState(
        lifetimeEmbers: 10,
        runHistory: [
          {'date': 'x', 'floor': 1},
        ],
      );
      final cloud = MetaState(ownedDieSkins: {'gilt'});
      final m = mergeMetaStates(local, cloud);
      m.runHistory.first['floor'] = 99;
      m.ownedDieSkins.add('extra');
      expect(local.runHistory.first['floor'], 1);
      expect(cloud.ownedDieSkins, {'gilt'});
    });

    test('merge round-trips through toJson/fromJson (cloud payload path)', () {
      final local = MetaState(lifetimeEmbers: 50, embers: 20, runsPlayed: 3);
      final cloud = MetaState.fromJson(
        MetaState(lifetimeEmbers: 80, embers: 66, runsWon: 2).toJson()
            as Map<String, dynamic>,
      );
      final m = mergeMetaStates(local, cloud);
      expect(m.embers, 66);
      expect(m.runsPlayed, 3);
      expect(m.runsWon, 2);
    });
  });
}

// The default theme id without importing data/themes.dart into the test:
// a fresh MetaState always owns and activates it.
String defaultThemeForTest() => MetaState().activeTheme;
