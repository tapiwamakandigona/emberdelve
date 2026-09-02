// test/deep_day_test.dart — v0.156.0 The Deep Day.
//
// The Deep Mark's trial: a goal day judged from the run's own custom-die
// records — a deep mark is a die whose tier reached 2. Pure observation,
// the sim stays sealed, and the v0.155.0 optional-tier save contract holds
// (absent tier reads as 1, so an old run counts zero, never a crash).
import 'package:emberdelve/game/run_trace.dart';
import 'package:emberdelve/game/trials.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the deep day states its rule and pays like its peers', () {
    final t = trialDef('deep_day');
    expect(t.goalId, 'deep_marks_at_least');
    expect(t.goalParam, 1);
    expect(t.emberBonus, 15, reason: 'goal days pay one flat rate');
    expect(t.mutators, isEmpty, reason: 'goal days run vanilla rules');
    expect(
      trialsOrder[legacyTrialCount - 1],
      'deep_day',
      reason: 'append-LAST (last of the legacy eleven; v0.180.0 appends after)',
    );
  });

  test('the goal judges die tiers exactly, honouring the optional key', () {
    final t = trialDef('deep_day');
    final trace = RunTrace();
    expect(
      trialGoalMet(t, {}, trace),
      isFalse,
      reason: 'no dice map is zero deep marks, not a crash',
    );
    expect(
      trialGoalMet(t, {'custom_dice': <String, dynamic>{}}, trace),
      isFalse,
    );
    // Tier-1 marks — explicit and via the absent-key contract — count zero.
    expect(
      trialGoalMet(t, {
        'custom_dice': {
          'custom_1': {'base': 'd6', 'face': 4, 'rune': 'blade'},
          'custom_2': {'base': 'd8', 'face': 6, 'rune': 'mend', 'tier': 1},
        },
      }, trace),
      isFalse,
    );
    // One deep mark meets the goal.
    expect(
      trialGoalMet(t, {
        'custom_dice': {
          'custom_1': {'base': 'd6', 'face': 4, 'rune': 'blade', 'tier': 2},
        },
      }, trace),
      isTrue,
    );
    // A deep mark alongside a shallow one still meets it.
    expect(
      trialGoalMet(t, {
        'custom_dice': {
          'custom_1': {'base': 'd6', 'face': 4, 'rune': 'blade', 'tier': 2},
          'custom_2': {'base': 'd8', 'face': 6, 'rune': 'mend'},
        },
      }, trace),
      isTrue,
    );
  });

  test('a real deepened run snapshot meets the goal end to end', () {
    // Drive the sim itself through temper + deepen so the judge is proven
    // against the true record shape, not a hand-built fixture.
    final sim = Sim(123)..apply({'type': 'start_run'});
    sim.phase = 'rest';
    sim.apply({'type': 'temper_face', 'die': 1, 'face': 4, 'rune': 'blade'});
    expect(
      trialGoalMet(trialDef('deep_day'), sim.run!, RunTrace()),
      isFalse,
      reason: 'a first temper is tier 1 — not yet deep',
    );
    sim.phase = 'rest';
    sim.apply({'type': 'temper_face', 'die': 1, 'face': 4, 'rune': 'blade'});
    expect(
      trialGoalMet(trialDef('deep_day'), sim.run!, RunTrace()),
      isTrue,
      reason: 'the deepened mark is tier 2 and the judge sees it',
    );
  });
}
