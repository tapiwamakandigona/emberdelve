// test/marked_day_test.dart — v0.147.0 The Marked Day.
//
// The temper arc's first trial: a goal day judged from the run's own
// tempers_used counter — pure observation, the sim stays sealed.
import 'package:emberdelve/game/run_trace.dart';
import 'package:emberdelve/game/trials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the marked day states its rule and pays like its peers', () {
    final t = trialDef('marked_day');
    expect(t.goalId, 'tempers_at_least');
    expect(t.goalParam, 1);
    expect(t.emberBonus, 15, reason: 'goal days pay one flat rate');
    expect(t.mutators, isEmpty, reason: 'goal days run vanilla rules');
    expect(trialsOrder.last, 'marked_day', reason: 'append-LAST');
  });

  test('the goal judges the counter exactly', () {
    final t = trialDef('marked_day');
    final trace = RunTrace();
    expect(trialGoalMet(t, {'tempers_used': 0}, trace), isFalse);
    expect(trialGoalMet(t, {'tempers_used': 1}, trace), isTrue);
    expect(trialGoalMet(t, {'tempers_used': 2}, trace), isTrue);
    expect(
      trialGoalMet(t, {}, trace),
      isFalse,
      reason: 'a missing counter is zero, not a crash',
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
    expect(trialGoalMet(future, {'tempers_used': 5}, RunTrace()), isFalse);
  });
}
