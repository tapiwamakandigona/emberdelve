// test/trials_test.dart — v0.9.0 "Today's Trials":
//   1. Catalog integrity: trialsOrder and the map agree; every entry is
//      EXACTLY one kind (mutator day XOR goal day); mutator ids are sim-known;
//      goal days declare a known predicate and a positive bonus.
//   2. trialForDate is deterministic and roughly uniform over 2026–2028, and
//      never correlates into a fixed offset against the weekly rotation.
//   3. Goal predicates judge real facts: met/not-met fixtures per predicate;
//      unknown goal ids are silently false (forward compatibility).
//   4. Copy carries no pressure language (§Ethics) — same sweep as v0.8.0.
//   5. End-to-end through the controller: a mutator day actually applies the
//      mutator to the daily run; a goal day banks its bonus exactly once and
//      the summary getter agrees with the banked amount; share text carries
//      the trial name without losing a single existing fact.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/game/run_trace.dart';
import 'package:emberdelve/game/trials.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';

/// Bot-drive a controller run to terminal.
void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 3000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(guard < 3000, isTrue, reason: 'bot run failed to terminate');
}

/// First date in [year] whose trial satisfies [want]. Self-selecting so a
/// future catalog append can never strand these tests on a wrong-kind date.
DateTime findDate(int year, bool Function(TrialDef) want) {
  var d = DateTime(year, 1, 1);
  for (var i = 0; i < 366; i++) {
    if (want(trialForDate(d.year, d.month, d.day))) return d;
    d = d.add(const Duration(days: 1));
  }
  fail('no date in $year matches the wanted trial kind');
}

void main() {
  group('catalog integrity', () {
    test('trialsOrder and the map agree exactly', () {
      expect(trialsOrder.toSet(), trials.keys.toSet());
      expect(trialsOrder.length, trials.length, reason: 'no duplicate ids');
      for (final id in trialsOrder) {
        expect(trials[id]!.id, id, reason: 'key/id drift on $id');
      }
    });

    test('every trial is exactly one kind, and each kind is well-formed', () {
      for (final t in trials.values) {
        final isMutatorDay = t.mutators.isNotEmpty;
        final isGoalDay = t.goalId.isNotEmpty;
        expect(
          isMutatorDay ^ isGoalDay,
          isTrue,
          reason: '${t.id} must be mutator day XOR goal day',
        );
        if (isMutatorDay) {
          for (final m in t.mutators) {
            expect(
              isKnownMutator(m),
              isTrue,
              reason:
                  '${t.id} names unknown mutator $m — the sim would '
                  'silently ignore it and the declared rule would be a lie',
            );
          }
          expect(t.emberBonus, 0, reason: 'mutator days pay nothing extra');
        } else {
          expect(
            t.emberBonus,
            greaterThan(0),
            reason: 'goal day ${t.id} must pay a real bonus',
          );
          expect(t.goalParam, greaterThan(0));
          // The predicate must be one the judge knows TODAY: a met fixture
          // below proves each id; this guards a typo'd id in the catalog.
          const known = {
            'gold_at_least',
            'fights_at_least',
            'embers_at_least',
            'clean_floors_at_least',
            'tempers_at_least', // v0.147.0 The Marked Day
            'relics_at_least', // v0.154.0 The Keeper's Day
          };
          expect(
            known.contains(t.goalId),
            isTrue,
            reason: '${t.id} declares unknown goal ${t.goalId}',
          );
        }
        expect(t.name, isNotEmpty);
        expect(t.blurb, isNotEmpty);
      }
    });
  });

  group('trialForDate', () {
    test('deterministic, valid, and roughly uniform over 2026-2028', () {
      final counts = <String, int>{};
      var d = DateTime(2026, 1, 1);
      final end = DateTime(2029, 1, 1);
      while (d.isBefore(end)) {
        final t = trialForDate(d.year, d.month, d.day);
        expect(trials.containsKey(t.id), isTrue);
        expect(
          trialForDate(d.year, d.month, d.day).id,
          t.id,
          reason: 'same date must always yield the same trial',
        );
        counts[t.id] = (counts[t.id] ?? 0) + 1;
        d = d.add(const Duration(days: 1));
      }
      // 1096 days over 7 trials ≈ 156 each; DJB2 mod 7 is rough, not exact.
      for (final id in trialsOrder) {
        expect(
          counts[id] ?? 0,
          greaterThan(80),
          reason: '$id appears too rarely — rotation is skewed',
        );
      }
    });

    test('consecutive days are not one fixed catalog step apart', () {
      // A date-hash rotation must not degenerate into "yesterday + 1".
      final deltas = <int>{};
      var d = DateTime(2026, 1, 1);
      var prev = trialsOrder.indexOf(trialForDate(2026, 1, 1).id);
      for (var i = 0; i < 60; i++) {
        d = d.add(const Duration(days: 1));
        final cur = trialsOrder.indexOf(
          trialForDate(d.year, d.month, d.day).id,
        );
        deltas.add((cur - prev) % trialsOrder.length);
        prev = cur;
      }
      expect(
        deltas.length,
        greaterThan(1),
        reason: 'rotation collapsed into a constant stride',
      );
    });

    test('trialForDailyKey mirrors trialForDate and rejects garbage', () {
      expect(trialForDailyKey('2026-08-16')!.id, trialForDate(2026, 8, 16).id);
      expect(
        trialForDailyKey('2026-8-16')!.id,
        trialForDate(2026, 8, 16).id,
        reason: 'unpadded key still parses (int.tryParse)',
      );
      expect(trialForDailyKey(''), isNull);
      expect(trialForDailyKey('not-a-date'), isNull);
      expect(trialForDailyKey('2026-13-01'), isNull);
      expect(trialForDailyKey('2026-02-99'), isNull);
    });
  });

  group('goal predicates', () {
    RunTrace traceWith(List<String> marks) {
      final t = RunTrace();
      t.marks.addAll(marks);
      return t;
    }

    test('gold_at_least judges final gold', () {
      final t = const TrialDef(
        'x',
        'X',
        'x',
        goalId: 'gold_at_least',
        goalParam: 40,
        emberBonus: 1,
      );
      expect(trialGoalMet(t, {'gold': 40}, RunTrace()), isTrue);
      expect(trialGoalMet(t, {'gold': 39}, RunTrace()), isFalse);
      expect(
        trialGoalMet(t, {}, RunTrace()),
        isFalse,
        reason: 'missing field is 0, never a throw',
      );
    });

    test('fights_at_least judges fights won', () {
      final t = const TrialDef(
        'x',
        'X',
        'x',
        goalId: 'fights_at_least',
        goalParam: 4,
        emberBonus: 1,
      );
      expect(trialGoalMet(t, {'fights_won': 5}, RunTrace()), isTrue);
      expect(trialGoalMet(t, {'fights_won': 3}, RunTrace()), isFalse);
    });

    test('embers_at_least judges run embers', () {
      final t = const TrialDef(
        'x',
        'X',
        'x',
        goalId: 'embers_at_least',
        goalParam: 60,
        emberBonus: 1,
      );
      expect(trialGoalMet(t, {'embers': 61}, RunTrace()), isTrue);
      expect(trialGoalMet(t, {'embers': 59}, RunTrace()), isFalse);
    });

    test('clean_floors_at_least counts untouched floors from the trace', () {
      final t = const TrialDef(
        'x',
        'X',
        'x',
        goalId: 'clean_floors_at_least',
        goalParam: 3,
        emberBonus: 1,
      );
      expect(
        trialGoalMet(
          t,
          {},
          traceWith([markClean, markHurt, markClean, markClean]),
        ),
        isTrue,
      );
      expect(
        trialGoalMet(t, {}, traceWith([markClean, markHurt, markClean])),
        isFalse,
      );
    });

    test('mutator days and unknown goal ids are silently false', () {
      expect(
        trialGoalMet(trialDef('flint_day'), {'gold': 999}, RunTrace()),
        isFalse,
      );
      final future = const TrialDef(
        'f',
        'F',
        'f',
        goalId: 'goal_from_the_future',
        goalParam: 1,
        emberBonus: 5,
      );
      expect(
        trialGoalMet(future, {'gold': 999}, RunTrace()),
        isFalse,
        reason:
            'an old build handed a future goal pays nothing, '
            'never crashes',
      );
    });
  });

  group('copy honesty (§Ethics)', () {
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

    test('trial names and blurbs carry no pressure language', () {
      for (final t in trials.values) {
        final copy = '${t.name} ${t.blurb}'.toLowerCase();
        for (final word in banned) {
          expect(
            copy.contains(word),
            isFalse,
            reason: '"$word" in trial ${t.id}',
          );
        }
      }
    });

    test('daily share header gains the trial name, loses nothing', () {
      final withTrial = dailyShareText(
        date: '2026-08-16',
        won: true,
        floor: 9,
        floors: 9,
        trial: 'Flint Day',
      );
      expect(withTrial, contains('Emberdelve Daily 2026-08-16 · Flint Day'));
      expect(withTrial, contains('🔥 Claimed the Ember — floor 9 of 9'));
      expect(withTrial, contains('One shared delve — same seed for everyone.'));

      final without = dailyShareText(
        date: '2026-08-16',
        won: true,
        floor: 9,
        floors: 9,
      );
      expect(
        without.split('\n').first,
        'Emberdelve Daily 2026-08-16',
        reason: 'no trial -> header byte-identical to the old format',
      );
    });
  });

  group('end to end through the controller', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ed_trials');
      MetaStore.dirOverride = dir.path;
    });

    tearDown(() async {
      await MetaStore.save(MetaState());
      MetaStore.dirOverride = null;
      for (var i = 0; i < 10; i++) {
        try {
          await dir.delete(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    });

    test('a mutator day applies its mutator to the daily run', () async {
      final clock = findDate(2026, (t) => t.mutators.isNotEmpty);
      final trial = trialForDate(clock.year, clock.month, clock.day);
      final c = GameController(saveDirOverride: dir.path);
      await c.boot();
      c.startDailyRun(character: 'kindler', clock: clock);
      for (final m in trial.mutators) {
        expect(
          c.sim!.mutators.contains(m),
          isTrue,
          reason: 'daily run must carry declared mutator $m',
        );
      }
      expect(
        c.dailyTrial!.id,
        trial.id,
        reason: 'controller re-derives the trial from the date label',
      );
      expect(c.dailyTrialBonus, 0, reason: 'mutator day never pays a bonus');
      driveToTerminal(c);
      expect(c.dailyTrialBonus, 0);
      await c.flushSaves();
    });

    test(
      'a goal day banks its bonus exactly once and the getter agrees',
      () async {
        final clock = findDate(2026, (t) => t.goalId.isNotEmpty);
        final c = GameController(saveDirOverride: dir.path);
        await c.boot();
        final embersBefore = c.meta.embers;
        final lifetimeBefore = c.meta.lifetimeEmbers;
        c.startDailyRun(character: 'kindler', clock: clock);
        expect(c.sim!.mutators, isEmpty, reason: 'goal day is vanilla rules');
        expect(c.dailyTrialBonus, 0, reason: 'mid-run: nothing judged yet');
        driveToTerminal(c);
        final banked = c.sim!.run?['embers'] as int? ?? 0;
        final bonus = c.dailyTrialBonus; // 0 when missed, emberBonus when met
        expect(
          c.meta.embers,
          embersBefore + banked + bonus,
          reason: 'bank = run embers + trial bonus, nothing else',
        );
        expect(c.meta.lifetimeEmbers, lifetimeBefore + banked + bonus);
        if (bonus > 0) {
          expect(bonus, c.dailyTrial!.emberBonus);
        }
        // Idempotence: booting a fresh controller over the same store must not
        // re-bank anything (the terminal save was cleared at bank time).
        await c.flushSaves();
        final c2 = GameController(saveDirOverride: dir.path);
        await c2.boot();
        expect(
          c2.meta.embers,
          embersBefore + banked + bonus,
          reason: 'resume after a banked daily must never double-pay',
        );
        await c2.flushSaves();
      },
    );

    test('finished daily share text carries the trial name', () async {
      final clock = findDate(2026, (t) => t.goalId.isNotEmpty);
      final trial = trialForDate(clock.year, clock.month, clock.day);
      final c = GameController(saveDirOverride: dir.path);
      await c.boot();
      c.startDailyRun(character: 'kindler', clock: clock);
      driveToTerminal(c);
      final share = c.dailyResultShareText;
      expect(share, isNotNull);
      expect(
        share,
        contains('· ${trial.name}'),
        reason: 'shared result must carry the rule it was played under',
      );
      await c.flushSaves();
    });
  });
}
