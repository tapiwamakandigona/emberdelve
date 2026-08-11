// data/achievements.dart — the Delver's Ledger (v0.5.0). CONTENT AS DATA, ZERO LOGIC.
//
// Schema:
//   AchievementDef { id, name, text, stat, target, param }
//
// Stat vocabulary (exact — resolved by meta/achievements.dart, nothing else is
// legal). Every one of these is a REAL counter already banked in MetaState, so
// a progress bar can never show a lie (§Ethics honesty):
//   runs_played        MetaState.runsPlayed
//   runs_won           MetaState.runsWon
//   char_wins          MetaState.charWins[param]        (param = character id)
//   chars_unlocked     MetaState.unlockedCharacters.length
//   exact_kills        MetaState.exactKills
//   best_exact_streak  MetaState.bestExactStreak
//   lifetime_embers    MetaState.lifetimeEmbers
//   best_ascension     MetaState.bestAscension
//   bosses_beaten      MetaState.bossesBeaten.length
//   best_floor         MetaState.bestFloor
//   dailies_played     MetaState.dailiesPlayed
//   wins_no_rest       MetaState.winsNoRest
//   themes_owned       MetaState.ownedThemes.length
//   hard_wins          MetaState.hardWins
//
// DESIGN NOTE — why achievements and not streaks. Spec §Ethics bans decaying
// streaks and loss framing, which rules out the usual retention lever. The
// measured alternative is *metric* achievements: on Trophy's April 2026
// platform data, users who complete a metric achievement on day one retain at
// 33.96% at D30 versus 20.46% for users who complete none, while streak
// achievements manage only 25.57% — and retention rises monotonically with
// achievement difficulty. So the honest lever is also the stronger one, which
// is why several entries here are deliberately hard.
//
// Nothing in this file grants power. Achievements are recognition only: no
// embers, no dice, no difficulty changes. Earning one can never make the next
// run easier, so the ledger cannot become a grind gate.
//
// `achievementsOrder` = deterministic authoring order (display order too).

class AchievementDef {
  final String id;
  final String name;
  final String text;

  /// Which real counter this reads (see the vocabulary above).
  final String stat;

  /// Value of [stat] at which the achievement is earned. Always >= 1.
  final int target;

  /// Optional scope for stats that need one (`char_wins` -> character id).
  final String? param;

  const AchievementDef(
    this.id,
    this.name,
    this.text, {
    required this.stat,
    required this.target,
    this.param,
  });
}

/// Every legal value of [AchievementDef.stat].
const Set<String> achievementStats = {
  'runs_played',
  'runs_won',
  'char_wins',
  'chars_unlocked',
  'exact_kills',
  'best_exact_streak',
  'lifetime_embers',
  'best_ascension',
  'bosses_beaten',
  'best_floor',
  'dailies_played',
  'wins_no_rest',
  'themes_owned',
  'hard_wins',
};

const List<String> achievementsOrder = [
  // --- first hour: real feats, reachable in runs 1-3 -----------------------
  'first_delve', 'first_blood', 'kindled', 'deeper_still', 'first_clear',
  // --- the climb ----------------------------------------------------------
  'ten_delves', 'fifty_delves', 'hundred_delves',
  'three_clears', 'ten_clears',
  // --- mastery of the maths ----------------------------------------------
  'exact_ten', 'exact_fifty', 'exact_two_hundred',
  'streak_three', 'streak_seven', 'streak_twelve',
  // --- the roster --------------------------------------------------------
  'warden_wins', 'gambler_wins', 'ascetic_wins', 'kindler_wins',
  'full_roster', 'every_delver_clears',
  // --- the bestiary ------------------------------------------------------
  'tyrant_felled', 'all_three_bosses',
  // --- the hoard ---------------------------------------------------------
  'embers_thousand', 'embers_five_thousand', 'hearth_keeper',
  // --- discipline --------------------------------------------------------
  'no_rest_clear', 'no_rest_three',
  // --- the daily ---------------------------------------------------------
  'daily_first', 'daily_ten', 'daily_thirty',
  // --- the endgame (Forge territory) -------------------------------------
  'hard_clear', 'hard_five', 'ascension_three', 'ascension_ten',
  'ascension_twenty',
];

const Map<String, AchievementDef> achievements = {
  // --- first hour ---------------------------------------------------------
  'first_delve': AchievementDef('first_delve', 'Into the Delve',
      'Finish your first run, however it ends.',
      stat: 'runs_played', target: 1),
  'first_blood': AchievementDef('first_blood', 'Exact Change',
      'End a fight on exactly the damage needed.',
      stat: 'exact_kills', target: 1),
  'kindled': AchievementDef('kindled', 'Kindled',
      'Bank 100 embers in total.',
      stat: 'lifetime_embers', target: 100),
  'deeper_still': AchievementDef('deeper_still', 'Deeper Still',
      'Reach layer 5 of the delve.',
      stat: 'best_floor', target: 5),
  'first_clear': AchievementDef('first_clear', 'Ember Bearer',
      'Win a run: put down whatever waits on the last layer.',
      stat: 'runs_won', target: 1),

  // --- the climb ---------------------------------------------------------
  'ten_delves': AchievementDef('ten_delves', 'Ten Deep',
      'Finish 10 runs.',
      stat: 'runs_played', target: 10),
  'fifty_delves': AchievementDef('fifty_delves', 'Old Delver',
      'Finish 50 runs.',
      stat: 'runs_played', target: 50),
  'hundred_delves': AchievementDef('hundred_delves', 'The Long Descent',
      'Finish 100 runs.',
      stat: 'runs_played', target: 100),
  'three_clears': AchievementDef('three_clears', 'Thrice Down',
      'Win 3 runs.',
      stat: 'runs_won', target: 3),
  'ten_clears': AchievementDef('ten_clears', 'Delve Master',
      'Win 10 runs.',
      stat: 'runs_won', target: 10),

  // --- mastery of the maths ---------------------------------------------
  'exact_ten': AchievementDef('exact_ten', 'Counter of Pips',
      'End 10 fights on an exact kill.',
      stat: 'exact_kills', target: 10),
  'exact_fifty': AchievementDef('exact_fifty', 'Arithmetic of Ash',
      'End 50 fights on an exact kill.',
      stat: 'exact_kills', target: 50),
  'exact_two_hundred': AchievementDef('exact_two_hundred', 'No Pip Wasted',
      'End 200 fights on an exact kill.',
      stat: 'exact_kills', target: 200),
  'streak_three': AchievementDef('streak_three', 'Three in a Row',
      'Win 3 fights in a row on exact kills.',
      stat: 'best_exact_streak', target: 3),
  'streak_seven': AchievementDef('streak_seven', 'Seven Clean',
      'Win 7 fights in a row on exact kills.',
      stat: 'best_exact_streak', target: 7),
  'streak_twelve': AchievementDef('streak_twelve', 'Twelve, Unbroken',
      'Win 12 fights in a row on exact kills.',
      stat: 'best_exact_streak', target: 12),

  // --- the roster -------------------------------------------------------
  'kindler_wins': AchievementDef('kindler_wins', 'The Kindler\'s Way',
      'Win a run as the Kindler.',
      stat: 'char_wins', target: 1, param: 'kindler'),
  'warden_wins': AchievementDef('warden_wins', 'The Warden\'s Way',
      'Win a run as the Warden.',
      stat: 'char_wins', target: 1, param: 'warden'),
  'gambler_wins': AchievementDef('gambler_wins', 'The Gambler\'s Way',
      'Win a run as the Gambler.',
      stat: 'char_wins', target: 1, param: 'gambler'),
  'ascetic_wins': AchievementDef('ascetic_wins', 'The Ascetic\'s Way',
      'Win a run as the Ascetic.',
      stat: 'char_wins', target: 1, param: 'ascetic'),
  'full_roster': AchievementDef('full_roster', 'Full Hearth',
      'Unlock every delver.',
      stat: 'chars_unlocked', target: 4),
  'every_delver_clears': AchievementDef('every_delver_clears', 'Four Ways Down',
      'Win at least 4 runs as the Ascetic — the hardest start there is.',
      stat: 'char_wins', target: 4, param: 'ascetic'),

  // --- the bestiary -----------------------------------------------------
  'tyrant_felled': AchievementDef('tyrant_felled', 'Tyrant Felled',
      'Beat any boss on the final layer.',
      stat: 'bosses_beaten', target: 1),
  'all_three_bosses': AchievementDef('all_three_bosses', 'The Whole Bestiary',
      'Beat all three bosses at least once each.',
      stat: 'bosses_beaten', target: 3),

  // --- the hoard --------------------------------------------------------
  'embers_thousand': AchievementDef('embers_thousand', 'Ember Hoard',
      'Bank 1,000 embers in total.',
      stat: 'lifetime_embers', target: 1000),
  'embers_five_thousand': AchievementDef(
      'embers_five_thousand', 'Forge-Fed',
      'Bank 5,000 embers in total.',
      stat: 'lifetime_embers', target: 5000),
  'hearth_keeper': AchievementDef('hearth_keeper', 'Hearth Keeper',
      'Own every hearth colour.',
      stat: 'themes_owned', target: 4),

  // --- discipline -------------------------------------------------------
  'no_rest_clear': AchievementDef('no_rest_clear', 'No Fire, No Rest',
      'Win a run without resting once.',
      stat: 'wins_no_rest', target: 1),
  'no_rest_three': AchievementDef('no_rest_three', 'Sleepless',
      'Win 3 runs without resting.',
      stat: 'wins_no_rest', target: 3),

  // --- the daily --------------------------------------------------------
  'daily_first': AchievementDef('daily_first', 'Today\'s Delve',
      'Finish a Daily Delve.',
      stat: 'dailies_played', target: 1),
  'daily_ten': AchievementDef('daily_ten', 'Ten Days Deep',
      'Finish 10 Daily Delves — in any 10 days you like.',
      stat: 'dailies_played', target: 10),
  'daily_thirty': AchievementDef('daily_thirty', 'A Month of Rolls',
      'Finish 30 Daily Delves. No streak required, no day expires.',
      stat: 'dailies_played', target: 30),

  // --- the endgame ------------------------------------------------------
  'hard_clear': AchievementDef('hard_clear', 'Hard Way Down',
      'Win a run on hard.',
      stat: 'hard_wins', target: 1),
  'hard_five': AchievementDef('hard_five', 'Hard Habit',
      'Win 5 runs on hard.',
      stat: 'hard_wins', target: 5),
  'ascension_three': AchievementDef('ascension_three', 'Third Rung',
      'Reach ascension 3.',
      stat: 'best_ascension', target: 3),
  'ascension_ten': AchievementDef('ascension_ten', 'Tenth Rung',
      'Reach ascension 10.',
      stat: 'best_ascension', target: 10),
  'ascension_twenty': AchievementDef('ascension_twenty', 'Top of the Ladder',
      'Reach ascension 20 — the last rung there is.',
      stat: 'best_ascension', target: 20),
};
