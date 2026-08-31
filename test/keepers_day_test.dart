// test/keepers_day_test.dart — v0.154.0 The Keeper's Day.
//
// The relic shelf's trial: a goal day judged from the run's own relic
// list — pure observation, the sim stays sealed.
import 'package:emberdelve/game/run_trace.dart';
import 'package:emberdelve/game/trials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the keeper's day states its rule and pays like its peers", () {
    final t = trialDef('keepers_day');
    expect(t.goalId, 'relics_at_least');
    expect(t.goalParam, 2);
    expect(t.emberBonus, 15, reason: 'goal days pay one flat rate');
    expect(t.mutators, isEmpty, reason: 'goal days run vanilla rules');
    expect(trialsOrder.last, 'keepers_day', reason: 'append-LAST');
  });

  test('the goal judges the relic list exactly', () {
    final t = trialDef('keepers_day');
    final trace = RunTrace();
    expect(trialGoalMet(t, {'relics': <String>[]}, trace), isFalse);
    expect(trialGoalMet(t, {'relics': <String>['ember_charm']}, trace),
        isFalse);
    expect(
      trialGoalMet(
          t, {'relics': <String>['ember_charm', 'iron_ward']}, trace),
      isTrue,
    );
    expect(
      trialGoalMet(
          t,
          {
            'relics': <String>['ember_charm', 'iron_ward', 'old_bellows'],
          },
          trace),
      isTrue,
    );
    expect(
      trialGoalMet(t, {}, trace),
      isFalse,
      reason: 'a missing list is empty, not a crash',
    );
  });

  test('an old build meets this goal id with silence, not a crash', () {
    // Forward-compat contract: unknown goal ids pay nothing. Proven from
    // this side by handing the judge a goal id nobody knows.
    const future = TrialDef(
      'future_day',
      'Future Day',
      'From a newer build.',
      goalId: 'not_a_goal_yet',
      goalParam: 1,
      emberBonus: 15,
    );
    expect(
      trialGoalMet(future, {
        'relics': <String>['ember_charm', 'iron_ward'],
      }, RunTrace()),
      isFalse,
    );
  });
}
