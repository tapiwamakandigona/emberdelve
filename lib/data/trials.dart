// data/trials.dart — Today's Trials catalog (v0.9.0). CONTENT AS DATA.
//
// A trial is the ONE declared rule a calendar date carries on top of the
// Daily Delve seed (game/trials.dart picks it deterministically from the
// date). Two kinds, and every entry is exactly one of them:
//
//  - MUTATOR DAY: `mutators` is non-empty and names existing, sim-known
//    mutator ids (data/mutators.dart) applied to the daily run via the
//    existing cmd['mutators'] seam. No goal, no bonus.
//  - GOAL DAY: vanilla rules plus a declared bonus objective (`goalId` +
//    `goalParam`, judged by game/trials.dart as a pure function over the
//    final run snapshot and the RunTrace). Met, it pays `emberBonus`
//    embers through the normal banking path. Missed, it costs nothing and
//    says nothing.
//
// Ethics (spec §Ethics, same charter as the Daily and Weekly Delves): a
// trial is a shared rule, NOT a streak treadmill. Nothing expires, nothing
// is punished, a missed goal is silent. Blurbs state the rule and stop —
// the banned-words sweep in test/trials_test.dart holds them to it.
//
// SEALED-SIM CONTRACT: the sim never learns about trials. Mutator days
// reuse ids the sim already knows; goal days are pure observation.

class TrialDef {
  final String id;
  final String name;
  final String blurb;

  /// Mutator ids applied to the daily run (mutator days). Empty on goal days.
  final List<String> mutators;

  /// Goal predicate id judged by game/trials.dart (goal days). '' on
  /// mutator days. Unknown ids evaluate as "no goal" (forward-compatible:
  /// an old build handed a future trial simply pays nothing).
  final String goalId;
  final int goalParam;

  /// Embers paid when the goal is met (goal days only).
  final int emberBonus;

  const TrialDef(
    this.id,
    this.name,
    this.blurb, {
    this.mutators = const [],
    this.goalId = '',
    this.goalParam = 0,
    this.emberBonus = 0,
  });
}

/// Deterministic authoring order — the date picker indexes into this, so a
/// reorder reshuffles which date gets which trial. Append, don't reorder.
/// Seven entries against three weekly mutators keeps the two rotations from
/// locking into step.
const List<String> trialsOrder = [
  'flint_day',
  'full_purse',
  'elite_day',
  'warpath',
  'lean_day',
  'light_step',
  'ember_hoard',
  'short_day',
  // v0.147.0 — append-LAST (the rotation is a hash over the list; append
  // keeps the change one modulus, not a reshuffle of authored order).
  'marked_day',
  // v0.154.0 — append-LAST, same contract.
  'keepers_day',
  // v0.156.0 — append-LAST, same contract.
  'deep_day',
  // v0.180.0 The Widened Rotation — append-LAST. These three only enter the
  // date hash from 2026-09-14 (game/trials.dart legacyTrialCount), so no
  // morrow line already shown becomes false.
  'cold_camps_day',
  'lean_road_day',
  'hard_march_day',
];

const Map<String, TrialDef> trials = {
  // Mutator days — the daily plays under one declared modifier.
  'flint_day': TrialDef(
    'flint_day',
    'Flint Day',
    'Every die rolls as a d4 in the shared delve.',
    mutators: ['all_d4'],
  ),
  'elite_day': TrialDef(
    'elite_day',
    'Elite Day',
    'Every regular fight is an elite. Harder road, richer loot.',
    mutators: ['elites_only'],
  ),
  'lean_day': TrialDef(
    'lean_day',
    'Lean Day',
    'No shops on the map. What you find is all you get.',
    mutators: ['no_shops'],
  ),
  // v0.49.0 The Shorter Road.
  // v0.180.0 The Widened Rotation: the Weekly's new pairs as days, plus the
  // one single the daily never dealt. Bot sweep kindler/normal 150 seeds:
  // no_rests 103, no_shops+short_road 110, no_rests+short_road 92
  // (baseline 106).
  'cold_camps_day': TrialDef(
    'cold_camps_day',
    'Cold Camps Day',
    'No rests on the map \u2014 every camp is a fight, and healing is '
        'only what you find or carry.',
    mutators: ['no_rests'],
  ),
  'lean_road_day': TrialDef(
    'lean_road_day',
    'Lean Road Day',
    'Six floors and no shops \u2014 what you find is all you carry to the '
        'bottom.',
    mutators: ['no_shops', 'short_road'],
  ),
  'hard_march_day': TrialDef(
    'hard_march_day',
    'Hard March Day',
    'Six floors and no rests \u2014 every camp is a fight, all the way '
        'down.',
    mutators: ['no_rests', 'short_road'],
  ),
  'short_day': TrialDef(
    'short_day',
    'Short Day',
    'The shared delve runs the Short Road — six floors instead of nine.',
    mutators: ['short_road'],
  ),
  // Goal days — vanilla rules plus one declared bonus objective.
  'full_purse': TrialDef(
    'full_purse',
    'Full Purse',
    'End the delve holding 40 gold or more.',
    goalId: 'gold_at_least',
    goalParam: 40,
    emberBonus: 15,
  ),
  'warpath': TrialDef(
    'warpath',
    'Warpath',
    'Win four or more fights.',
    goalId: 'fights_at_least',
    goalParam: 4,
    emberBonus: 15,
  ),
  'light_step': TrialDef(
    'light_step',
    'Light Step',
    'Walk three or more floors without losing a point of health.',
    goalId: 'clean_floors_at_least',
    goalParam: 3,
    emberBonus: 20,
  ),
  'ember_hoard': TrialDef(
    'ember_hoard',
    'Ember Hoard',
    'Gather 60 or more embers in the delve.',
    goalId: 'embers_at_least',
    goalParam: 60,
    emberBonus: 15,
  ),
  // v0.147.0 The Marked Day: the temper arc's day (goal kind
  // 'tempers_at_least', judged from the run's own counter).
  'marked_day': TrialDef(
    'marked_day',
    'The Marked Day',
    'Temper at least one die face at a rest fire.',
    goalId: 'tempers_at_least',
    goalParam: 1,
    emberBonus: 15,
  ),
  // v0.154.0 The Keeper's Day: the relic shelf's day (goal kind
  // 'relics_at_least', judged from the run's own relic list).
  'keepers_day': TrialDef(
    'keepers_day',
    "The Keeper's Day",
    'End the delve carrying two or more relics.',
    goalId: 'relics_at_least',
    goalParam: 2,
    emberBonus: 15,
  ),
  // v0.156.0 The Deep Day: the Deep Mark's day (goal kind
  // 'deep_marks_at_least', judged from the run's own die records).
  'deep_day': TrialDef(
    'deep_day',
    'The Deep Day',
    'Deepen a rune mark at a rest fire.',
    goalId: 'deep_marks_at_least',
    goalParam: 1,
    emberBonus: 15,
  ),
};

TrialDef trialDef(String id) {
  final def = trials[id];
  if (def == null) throw ArgumentError('unknown trial id: $id');
  return def;
}
