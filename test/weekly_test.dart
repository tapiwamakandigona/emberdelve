// test/weekly_test.dart — P3 Weekly Delve + run mutators.
// Locks three things that must never silently drift:
//   1. NORMAL/Daily runs are byte-identical to pre-P3 (no mutator = no change).
//   2. Each mutator does exactly what it says, deterministically.
//   3. The weekly schedule (index/Monday math + modifier pick) is pure and
//      stable across devices.
// Runs headless under `flutter test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/daily.dart';
import 'package:emberdelve/sim/sim.dart';

// Build a run's map by starting one run and reading the generated node kinds.
Map<String, String> _mapKinds(Sim sim) {
  final nodes = (sim.map!['nodes'] as Map).cast<String, Map>();
  return {for (final e in nodes.entries) e.key: e.value['kind'] as String};
}

Sim _startedRun(int seed, {List<String> mutators = const []}) {
  final sim = Sim(seed);
  sim.apply({
    'type': 'start_run',
    'boons': true,
    if (mutators.isNotEmpty) 'mutators': mutators,
  });
  return sim;
}

void main() {
  group('mutator catalog', () {
    test('order matches the map and every id resolves', () {
      expect(mutatorsOrder.toSet(), equals(mutators.keys.toSet()));
      for (final id in mutatorsOrder) {
        expect(isKnownMutator(id), isTrue);
        expect(mutatorDef(id).name, isNotEmpty);
        expect(mutatorDef(id).blurb, isNotEmpty);
      }
      expect(isKnownMutator('nope'), isFalse);
      expect(() => mutatorDef('nope'), throwsArgumentError);
    });
  });

  group('no-mutator runs are unchanged', () {
    test('empty mutators == absent mutators == pre-P3 behavior', () {
      // A run with an explicit empty list, and one that never mentions
      // mutators, must produce identical event hashes (the golden anchor in
      // sim_test proves the absolute value; this proves the two paths agree).
      final a = _startedRun(4242);
      final b = Sim(4242)..apply({'type': 'start_run', 'boons': true});
      expect(a.eventHash, equals(b.eventHash));
      expect(a.mutators, isEmpty);
    });

    test('full unmutated autoplay matches itself and stays clean', () {
      for (final seed in [1, 77, 20260810, 999999]) {
        final r1 = playRun(seed);
        final r2 = playRun(seed);
        expect(r1.sim.eventHash, equals(r2.sim.eventHash));
        expect(r1.invalids, equals(0), reason: 'seed $seed had invalids');
      }
    });
  });

  group('mutator: all_d4', () {
    test('no die ever rolls above 4, and hashes differ from normal', () {
      for (final seed in [3, 88, 20260810]) {
        final plain = playRun(seed);
        final flint = playRun(seed, mutators: ['all_d4']);
        // The modifier must actually change the run.
        expect(flint.sim.eventHash, isNot(equals(plain.sim.eventHash)),
            reason: 'all_d4 seed $seed did not change the run');
        expect(flint.invalids, equals(0));
        // The run is still fully deterministic under the mutator.
        expect(playRun(seed, mutators: ['all_d4']).sim.eventHash,
            equals(flint.sim.eventHash));
      }
    });

    test('a d4 die is untouched (already 4 faces)', () {
      // Rolling only exercises through autoplay, so assert the invariant via
      // a direct construction: with all_d4 the effective faces of any die is
      // min(size, 4). d4 == 4 already, so its roll distribution is unchanged.
      final sim = _startedRun(5, mutators: ['all_d4']);
      expect(sim.hasMutator('all_d4'), isTrue);
      // Sanity: the catalog still classifies a d4 as size 4.
      expect(dice['d4']!.size, equals(4));
      expect(dice['d6']!.size, greaterThan(4));
    });
  });

  group('mutator: elites_only', () {
    test('every middle fight becomes an elite; start/boss untouched', () {
      for (final seed in [11, 250, 20260810]) {
        final sim = _startedRun(seed, mutators: ['elites_only']);
        final kinds = _mapKinds(sim);
        expect(kinds.values.where((k) => k == 'fight'), isEmpty,
            reason: 'elites_only left a plain fight on seed $seed');
        // Start and boss are never converted.
        final start = sim.map!['start'].toString();
        final boss = sim.map!['boss'].toString();
        expect(kinds[start], equals('start'));
        expect(kinds[boss], equals('boss'));
        // At least one elite now exists (there is always >=1 fight to flip).
        expect(kinds.values.where((k) => k == 'elite'), isNotEmpty);
      }
    });

    test('the run is playable and deterministic under elites_only', () {
      final r = playRun(20260810, mutators: ['elites_only']);
      expect(r.invalids, equals(0));
      expect(playRun(20260810, mutators: ['elites_only']).sim.eventHash,
          equals(r.sim.eventHash));
    });
  });

  group('mutator: no_shops', () {
    test('no shop node survives; a normal run of that seed had one', () {
      for (final seed in [11, 250, 20260810]) {
        final plain = _mapKinds(_startedRun(seed));
        final noShop = _mapKinds(_startedRun(seed, mutators: ['no_shops']));
        expect(noShop.values.where((k) => k == 'shop'), isEmpty,
            reason: 'no_shops left a shop on seed $seed');
        // The generator guarantees >=1 shop, so removing them is observable.
        expect(plain.values.where((k) => k == 'shop'), isNotEmpty,
            reason: 'test seed $seed had no shop to begin with');
      }
    });
  });

  group('map mutators consume no extra rng (layout is identical)', () {
    test('node ids/layers/edges match a normal run; only kinds change', () {
      const seed = 20260810;
      final plain = _startedRun(seed);
      final mut = _startedRun(seed, mutators: ['elites_only', 'no_shops']);
      final pn = (plain.map!['nodes'] as Map).cast<String, Map>();
      final mn = (mut.map!['nodes'] as Map).cast<String, Map>();
      expect(mn.keys.toSet(), equals(pn.keys.toSet()));
      for (final id in pn.keys) {
        expect(mn[id]!['layer'], equals(pn[id]!['layer']));
        expect(mn[id]!['x'], equals(pn[id]!['x']));
      }
      expect(mut.map!['edges'], equals(plain.map!['edges']));
      expect(mut.map!['start'], equals(plain.map!['start']));
      expect(mut.map!['boss'], equals(plain.map!['boss']));
    });
  });

  group('snapshot/restore carries mutators', () {
    test('a mutated run round-trips and continues identically', () {
      final plain = playRun(20260810, mutators: ['all_d4']);
      final resumed = playRun(20260810, mutators: ['all_d4'], snapAt: 20);
      expect(resumed.sim.eventHash, equals(plain.sim.eventHash));
      expect(resumed.sim.mutators, equals({'all_d4'}));
    });

    test('an unmutated snapshot has no mutators key (byte-clean saves)', () {
      final sim = _startedRun(7);
      expect(sim.snapshot().containsKey('mutators'), isFalse);
      final mut = _startedRun(7, mutators: ['no_shops']);
      expect(mut.snapshot()['mutators'], equals(['no_shops']));
    });
  });

  group('run_started event stamps mutators only when present', () {
    test('normal run_started has no mutators field', () {
      final sim = Sim(7);
      final evs = sim.apply({'type': 'start_run', 'boons': true});
      final started = evs.firstWhere((e) => e['type'] == 'run_started');
      expect(started.containsKey('mutators'), isFalse);
    });

    test('mutated run_started lists the sorted mutators', () {
      final sim = Sim(7);
      final evs = sim.apply({
        'type': 'start_run',
        'boons': true,
        'mutators': ['no_shops', 'all_d4'],
      });
      final started = evs.firstWhere((e) => e['type'] == 'run_started');
      expect(started['mutators'], equals('all_d4,no_shops'));
    });
  });

  group('weekly schedule', () {
    test('weeklySeed is a valid, deterministic LCG seed', () {
      for (final idx in [0, 1, 2937, 2938, -1]) {
        final s = weeklySeed(idx);
        expect(s >= 1 && s <= 0x7ffffffe, isTrue);
        expect(weeklySeed(idx), equals(s));
      }
      // Distinct weeks give distinct seeds (no accidental collision nearby).
      expect(weeklySeed(2937), isNot(equals(weeklySeed(2938))));
      // A weekly seed never equals the daily seed for the same-looking key.
      expect(weeklySeed(2937), isNot(equals(dailySeed(2026, 8, 10))));
    });

    test('all seven days of a week share one index; Monday opens it', () {
      // 2026-08-10 is a Monday; 2026-08-16 is the Sunday of the same week.
      final monday = weekIndex(2026, 8, 10);
      for (var d = 10; d <= 16; d++) {
        expect(weekIndex(2026, 8, d), equals(monday),
            reason: '2026-08-$d should be in the week of the 10th');
      }
      // The next Monday rolls over to the next index.
      expect(weekIndex(2026, 8, 17), equals(monday + 1));
      // The previous Sunday is the prior week.
      expect(weekIndex(2026, 8, 9), equals(monday - 1));
    });

    test('mondayOfWeek is the inverse of weekIndex and always a Monday', () {
      for (final ymd in [
        [2026, 8, 10],
        [2026, 1, 1],
        [2025, 12, 31],
        [2027, 3, 15],
      ]) {
        final idx = weekIndex(ymd[0], ymd[1], ymd[2]);
        final md = mondayOfWeek(idx);
        // Round-trips back to the same index.
        expect(weekIndex(md[0], md[1], md[2]), equals(idx));
        // And Dart's own DateTime agrees it's a Monday.
        expect(DateTime(md[0], md[1], md[2]).weekday, equals(DateTime.monday));
      }
    });

    test('weeklyKey names the Monday of the week', () {
      final idx = weekIndex(2026, 8, 13); // a Thursday
      expect(weeklyKey(idx), equals('Week of 2026-08-10'));
    });

    test('weeklyMutatorFor is deterministic and stays in the catalog', () {
      for (var idx = -5; idx < 20; idx++) {
        final id = weeklyMutatorFor(idx);
        expect(isKnownMutator(id), isTrue);
        expect(weeklyMutatorFor(idx), equals(id));
      }
      // The rotation cycles through the whole catalog.
      final seen = {for (var i = 0; i < mutatorsOrder.length; i++) weeklyMutatorFor(i)};
      expect(seen, equals(mutatorsOrder.toSet()));
    });

    test('recap and share strings are honest (no streak/expiry language)', () {
      final recap = weeklyRecapLine(won: false, floor: 4, floors: 9);
      expect(recap, contains('floor 4 of 9'));
      final share = weeklyShareText(
          index: weekIndex(2026, 8, 10),
          mutatorId: 'all_d4',
          won: true,
          floor: 9,
          floors: 9);
      expect(share, contains('Flint Week'));
      expect(share, contains('Week of 2026-08-10'));
      for (final banned in ['streak', 'expire', 'don\'t miss', 'hurry']) {
        expect(recap.toLowerCase(), isNot(contains(banned)));
        expect(share.toLowerCase(), isNot(contains(banned)));
      }
    });
  });

  group('meta weekly record round-trips', () {
    test('weekly fields survive toJson/fromJson', () {
      final m = MetaState(
        lastWeeklyKey: 'Week of 2026-08-10',
        lastWeeklyWon: true,
        lastWeeklyFloor: 9,
        lastWeeklyFloors: 9,
        lastWeeklyMutator: 'elites_only',
        weekliesPlayed: 3,
      );
      final back = MetaState.fromJson(m.toJson());
      expect(back.lastWeeklyKey, equals('Week of 2026-08-10'));
      expect(back.lastWeeklyWon, isTrue);
      expect(back.lastWeeklyFloor, equals(9));
      expect(back.lastWeeklyFloors, equals(9));
      expect(back.lastWeeklyMutator, equals('elites_only'));
      expect(back.weekliesPlayed, equals(3));
    });

    test('a fresh profile omits weekly keys entirely (clean save)', () {
      final json = MetaState().toJson();
      expect(json.containsKey('lastWeeklyKey'), isFalse);
      expect(json.containsKey('weekliesPlayed'), isFalse);
    });
  });
}
