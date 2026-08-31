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
//   delvers_cleared    distinct roster characters with >= 1 win (charWins)
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
  'delvers_crowned',
  'tempers_set',
  'weekly_rules_won',
  'runes_tempered',
  'delvers_cleared',
  'provings_cleared', // v0.59.0 The Proven
  // v0.107.0 The Unwritten Feats — the systems that grew after the ledger.
  'weeklies_played',
  'codex_unsealed',
  'doubled_wins', // v0.113.0 The Cold Honors
  'tales_heard',
  'foes_settled',
  'distinct_felled',
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
  'peddler_wins', 'full_company', 'five_ways_down',
  'tinker_wins', 'six_ways_down',
  'flintwright_wins', 'seven_ways_down',
  'runesmith_wins', 'eight_ways_down',
  'bearer_wins', 'nine_ways_down',
  'mender_wins', 'ten_ways_down',
  'shieldwright_wins', 'eleven_ways_down',
  'gilder_wins', 'twelve_ways_down',
  'cutler_wins', 'thirteen_ways_down',
  // --- the bestiary ------------------------------------------------------
  'tyrant_felled', 'all_three_bosses',
  // --- the hoard ---------------------------------------------------------
  'embers_thousand', 'embers_five_thousand', 'hearth_keeper',
  // --- discipline --------------------------------------------------------
  'no_rest_clear', 'no_rest_three',
  // --- the daily ---------------------------------------------------------
  'daily_first', 'daily_ten', 'daily_thirty',
  // --- the endgame (Forge territory) -------------------------------------
  'hard_clear', 'hard_five', 'three_crowns', 'crowned_company',
  'first_temper', 'well_tempered',
  'rule_taken', 'full_rotation',
  'third_mark', 'six_marks',
  'ascension_three', 'ascension_ten',
  'ascension_twenty',
  // --- the unwritten feats (v0.107.0): the systems that grew after --------
  'weekly_first', 'weekly_ten',
  'codex_ten', 'codex_forty',
  'tales_ten',
  'score_settled',
  'twenty_names',
  // --- the cold honors (v0.113.0): the doubled week's recognition ---------
  'first_winter', 'thrice_wintered',
];

const Map<String, AchievementDef> achievements = {
  // --- first hour ---------------------------------------------------------
  // Text is honest about the counter: runsPlayed also counts a run the
  // player walked away from (abandonRun), so "finish" would overclaim.
  'first_delve': AchievementDef(
    'first_delve',
    'Into the Delve',
    'End your first run — win, die, or walk away.',
    stat: 'runs_played',
    target: 1,
  ),
  'first_blood': AchievementDef(
    'first_blood',
    'Exact Change',
    'End a fight on exactly the damage needed.',
    stat: 'exact_kills',
    target: 1,
  ),
  'kindled': AchievementDef(
    'kindled',
    'Kindled',
    'Bank 100 embers in total.',
    stat: 'lifetime_embers',
    target: 100,
  ),
  'deeper_still': AchievementDef(
    'deeper_still',
    'Deeper Still',
    'Reach layer 5 of the delve.',
    stat: 'best_floor',
    target: 5,
  ),
  'first_clear': AchievementDef(
    'first_clear',
    'Ember Bearer',
    'Win a run: put down whatever waits on the last layer.',
    stat: 'runs_won',
    target: 1,
  ),

  // --- the climb ---------------------------------------------------------
  'ten_delves': AchievementDef(
    'ten_delves',
    'Ten Deep',
    'Finish 10 runs.',
    stat: 'runs_played',
    target: 10,
  ),
  'fifty_delves': AchievementDef(
    'fifty_delves',
    'Old Delver',
    'Finish 50 runs.',
    stat: 'runs_played',
    target: 50,
  ),
  'hundred_delves': AchievementDef(
    'hundred_delves',
    'The Long Descent',
    'Finish 100 runs.',
    stat: 'runs_played',
    target: 100,
  ),
  'three_clears': AchievementDef(
    'three_clears',
    'Thrice Down',
    'Win 3 runs.',
    stat: 'runs_won',
    target: 3,
  ),
  'ten_clears': AchievementDef(
    'ten_clears',
    'Delve Master',
    'Win 10 runs.',
    stat: 'runs_won',
    target: 10,
  ),

  // --- mastery of the maths ---------------------------------------------
  'exact_ten': AchievementDef(
    'exact_ten',
    'Counter of Pips',
    'End 10 fights on an exact kill.',
    stat: 'exact_kills',
    target: 10,
  ),
  'exact_fifty': AchievementDef(
    'exact_fifty',
    'Arithmetic of Ash',
    'End 50 fights on an exact kill.',
    stat: 'exact_kills',
    target: 50,
  ),
  'exact_two_hundred': AchievementDef(
    'exact_two_hundred',
    'No Pip Wasted',
    'End 200 fights on an exact kill.',
    stat: 'exact_kills',
    target: 200,
  ),
  'streak_three': AchievementDef(
    'streak_three',
    'Three in a Row',
    'Win 3 fights in a row on exact kills.',
    stat: 'best_exact_streak',
    target: 3,
  ),
  'streak_seven': AchievementDef(
    'streak_seven',
    'Seven Clean',
    'Win 7 fights in a row on exact kills.',
    stat: 'best_exact_streak',
    target: 7,
  ),
  'streak_twelve': AchievementDef(
    'streak_twelve',
    'Twelve, Unbroken',
    'Win 12 fights in a row on exact kills.',
    stat: 'best_exact_streak',
    target: 12,
  ),

  // --- the roster -------------------------------------------------------
  'kindler_wins': AchievementDef(
    'kindler_wins',
    'The Kindler\'s Way',
    'Win a run as the Kindler.',
    stat: 'char_wins',
    target: 1,
    param: 'kindler',
  ),
  'warden_wins': AchievementDef(
    'warden_wins',
    'The Warden\'s Way',
    'Win a run as the Warden.',
    stat: 'char_wins',
    target: 1,
    param: 'warden',
  ),
  'gambler_wins': AchievementDef(
    'gambler_wins',
    'The Gambler\'s Way',
    'Win a run as the Gambler.',
    stat: 'char_wins',
    target: 1,
    param: 'gambler',
  ),
  'ascetic_wins': AchievementDef(
    'ascetic_wins',
    'The Ascetic\'s Way',
    'Win a run as the Ascetic.',
    stat: 'char_wins',
    target: 1,
    param: 'ascetic',
  ),
  // v0.40.0 reword: the roster grew to five, so "every delver" would lie
  // about a target of 4 — but bumping the target would UN-earn a mark
  // players already hold, and a derived recognition must never be taken
  // back (§Ethics: nothing can be lost). The counts stay; the words now
  // state exactly what they count. The five-delver chases are new marks.
  'full_roster': AchievementDef(
    'full_roster',
    'Full Hearth',
    'Unlock four delvers.',
    stat: 'chars_unlocked',
    target: 4,
  ),
  // v0.5.0 fix: the name promises four delvers, so the counter must too.
  // (It shipped reading 4 Ascetic wins — name and stat told different
  // stories, which fails the §Ethics honesty test.)
  'every_delver_clears': AchievementDef(
    'every_delver_clears',
    'Four Ways Down',
    'Win a run with four different delvers.',
    stat: 'delvers_cleared',
    target: 4,
  ),
  'peddler_wins': AchievementDef(
    'peddler_wins',
    'Fair Trade',
    'Win a run as the Peddler.',
    stat: 'char_wins',
    target: 1,
    param: 'peddler',
  ),
  // v0.141.0 honesty fix: 'ALL five' is promise wording (contrast Full
  // Hearth's plain 'four' — a milestone, which stays). Count-free text,
  // target pinned to the live roster.
  'full_company': AchievementDef(
    'full_company',
    'Full Company',
    'Unlock every delver.',
    stat: 'chars_unlocked',
    target: 13, // v0.168.0: the cutler joins (promise doctrine)
  ),
  'five_ways_down': AchievementDef(
    'five_ways_down',
    'Five Ways Down',
    'Win a run with five different delvers.',
    stat: 'delvers_cleared',
    target: 5,
  ),
  'tinker_wins': AchievementDef(
    'tinker_wins',
    'Well Oiled',
    'Win a run as the Tinker.',
    stat: 'char_wins',
    target: 1,
    param: 'tinker',
  ),
  'six_ways_down': AchievementDef(
    'six_ways_down',
    'Six Ways Down',
    'Win a run with six different delvers.',
    stat: 'delvers_cleared',
    target: 6,
  ),
  // v0.119.0 The Seventh Way — the flintwright's chapter of the roster
  // arc. six_ways_down stays at 6: it honored a real feat when six was
  // the whole roster, and earned recognition never re-prices (§Ethics).
  'flintwright_wins': AchievementDef(
    'flintwright_wins',
    'Knapped Sharp',
    'Win a run as the Flintwright.',
    stat: 'char_wins',
    target: 1,
    param: 'flintwright',
  ),
  'seven_ways_down': AchievementDef(
    'seven_ways_down',
    'Seven Ways Down',
    'Win a run with seven different delvers.',
    stat: 'delvers_cleared',
    target: 7,
  ),
  // v0.136.0 The Eighth Way (the v0.119 pattern: the char win, then the
  // roster count under a NEW name — historical honors never re-price).
  'runesmith_wins': AchievementDef(
    'runesmith_wins',
    'Rune-Sharp',
    'Win a delve with the Runesmith.',
    stat: 'char_wins',
    target: 1,
    param: 'runesmith',
  ),
  'eight_ways_down': AchievementDef(
    'eight_ways_down',
    'Eight Ways Down',
    'Win a run with eight different delvers.',
    stat: 'delvers_cleared',
    target: 8,
  ),
  // v0.146.0 The Ninth Way (the v0.119 pattern, third use).
  'bearer_wins': AchievementDef(
    'bearer_wins',
    'Stone-Shouldered',
    'Win a delve as the Bearer.',
    stat: 'char_wins',
    target: 1,
    param: 'bearer',
  ),
  'nine_ways_down': AchievementDef(
    'nine_ways_down',
    'Nine Ways Down',
    'Win a run with nine different delvers.',
    stat: 'delvers_cleared',
    target: 9,
  ),
  // v0.151.0 The Tenth Way (the v0.119 pattern, fourth use).
  'mender_wins': AchievementDef(
    'mender_wins',
    'The First Stitch',
    'Win a delve as the Mender.',
    stat: 'char_wins',
    target: 1,
    param: 'mender',
  ),
  'ten_ways_down': AchievementDef(
    'ten_ways_down',
    'Ten Ways Down',
    'Win a run with ten different delvers.',
    stat: 'delvers_cleared',
    target: 10,
  ),
  // v0.159.0 The Eleventh Way (the v0.119 pattern, fifth use).
  'shieldwright_wins': AchievementDef(
    'shieldwright_wins',
    'The First Ward',
    'Win a delve as the Shieldwright.',
    stat: 'char_wins',
    target: 1,
    param: 'shieldwright',
  ),
  'eleven_ways_down': AchievementDef(
    'eleven_ways_down',
    'Eleven Ways Down',
    'Win a run with eleven different delvers.',
    stat: 'delvers_cleared',
    target: 11,
  ),
  // v0.163.0 The Twelfth Way (the v0.119 pattern, sixth use).
  'gilder_wins': AchievementDef(
    'gilder_wins',
    'The First Coin',
    'Win a delve as the Gilder.',
    stat: 'char_wins',
    target: 1,
    param: 'gilder',
  ),
  'twelve_ways_down': AchievementDef(
    'twelve_ways_down',
    'Twelve Ways Down',
    'Win a run with twelve different delvers.',
    stat: 'delvers_cleared',
    target: 12,
  ),
  // v0.170.0 The Thirteenth Way (the v0.119 pattern, seventh use).
  'cutler_wins': AchievementDef(
    'cutler_wins',
    'The First Edge',
    'Win a delve as the Cutler.',
    stat: 'char_wins',
    target: 1,
    param: 'cutler',
  ),
  'thirteen_ways_down': AchievementDef(
    'thirteen_ways_down',
    'Thirteen Ways Down',
    'Win a run with thirteen different delvers.',
    stat: 'delvers_cleared',
    target: 13,
  ),

  // --- the bestiary -----------------------------------------------------
  'tyrant_felled': AchievementDef(
    'tyrant_felled',
    'Tyrant Felled',
    'Beat any boss on the final layer.',
    stat: 'bosses_beaten',
    target: 1,
  ),
  // v0.5.0 fix: the bestiary grew to six bosses in the same release this
  // shipped in, so "all three" was stale on arrival. Id kept (it lives in
  // players' seenAchievements sets); target/text follow the real roster.
  // v0.141.0 honesty fix: said 'all six bosses' while the bestiary holds
  // eight (grew v0.98/v0.112). The name was always count-free — the text
  // goes count-free too, and the target tracks the live catalog (pinned).
  // The id's own history ('all_three_bosses') shows it was re-priced once
  // before the doctrine existed and then forgotten again.
  'all_three_bosses': AchievementDef(
    'all_three_bosses',
    'The Whole Bestiary',
    'Beat every boss in the bestiary at least once.',
    stat: 'bosses_beaten',
    target: 8,
  ),

  // --- the hoard --------------------------------------------------------
  'embers_thousand': AchievementDef(
    'embers_thousand',
    'Ember Hoard',
    'Bank 1,000 embers in total.',
    stat: 'lifetime_embers',
    target: 1000,
  ),
  'embers_five_thousand': AchievementDef(
    'embers_five_thousand',
    'Forge-Fed',
    'Bank 5,000 embers in total.',
    stat: 'lifetime_embers',
    target: 5000,
  ),
  // v0.140.0 honesty fix: 'every hearth colour' had target 4 since
  // v0.3.3 while the shelf grew to 12 in v0.4.3 — a shipped lie caught
  // by the re-pricing audit. Promise wording moves with the catalog
  // (pinned to hearthThemesOrder.length by test).
  'hearth_keeper': AchievementDef(
    'hearth_keeper',
    'Hearth Keeper',
    'Own every hearth colour.',
    stat: 'themes_owned',
    target: 16,
  ),

  // --- discipline -------------------------------------------------------
  'no_rest_clear': AchievementDef(
    'no_rest_clear',
    'No Fire, No Rest',
    'Win a run without resting once.',
    stat: 'wins_no_rest',
    target: 1,
  ),
  'no_rest_three': AchievementDef(
    'no_rest_three',
    'Sleepless',
    'Win 3 runs without resting.',
    stat: 'wins_no_rest',
    target: 3,
  ),

  // --- the daily --------------------------------------------------------
  'daily_first': AchievementDef(
    'daily_first',
    'Today\'s Delve',
    'Finish a Daily Delve.',
    stat: 'dailies_played',
    target: 1,
  ),
  'daily_ten': AchievementDef(
    'daily_ten',
    'Ten Days Deep',
    'Finish 10 Daily Delves — in any 10 days you like.',
    stat: 'dailies_played',
    target: 10,
  ),
  'daily_thirty': AchievementDef(
    'daily_thirty',
    'A Month of Rolls',
    'Finish 30 Daily Delves. No streak required, no day expires.',
    stat: 'dailies_played',
    target: 30,
  ),

  // --- the endgame ------------------------------------------------------
  'hard_clear': AchievementDef(
    'hard_clear',
    'Hard Way Down',
    'Win a run on hard.',
    stat: 'hard_wins',
    target: 1,
  ),
  // v0.123.0 The Crowned Company: hard mastery charted per delver. The
  // company achievement is PROMISE-worded ('every delver'), so its target
  // tracks the live roster and the name stays count-free (§Re-pricing
  // doctrine, v0.119.0).
  'three_crowns': AchievementDef(
    'three_crowns',
    'Three Crowns',
    'Win on hard with 3 different delvers.',
    stat: 'delvers_crowned',
    target: 3,
  ),
  'crowned_company': AchievementDef(
    'crowned_company',
    'The Crowned Company',
    'Win on hard with every delver.',
    stat: 'delvers_crowned',
    // v0.168.0: moved with the roster (promise wording).
    target: 13,
  ),
  // v0.125.0 The Tempered Hand: the Face Forge's lifetime arc.
  'first_temper': AchievementDef(
    'first_temper',
    'The Marked Face',
    'Temper a die face.',
    stat: 'tempers_set',
    target: 1,
  ),
  'well_tempered': AchievementDef(
    'well_tempered',
    'Well Tempered',
    'Temper 25 die faces across your delves.',
    stat: 'tempers_set',
    target: 25,
  ),
  // v0.127.0 The Full Rotation: the Weekly's collection arc. The full
  // honor is PROMISE-worded ('every rule'), so its target tracks the live
  // rotation (§Re-pricing doctrine) — pinned to the legal-label count.
  'rule_taken': AchievementDef(
    'rule_taken',
    'Rule Taken',
    'Win a Weekly Delve under any rule.',
    stat: 'weekly_rules_won',
    target: 1,
  ),
  'full_rotation': AchievementDef(
    'full_rotation',
    'The Full Rotation',
    'Win a Weekly under every rule in the rotation.',
    stat: 'weekly_rules_won',
    target: 6,
  ),
  // v0.133.0 The Six Marks: the temper collection arc, mirroring the
  // Weekly's (v0.127). The full honor is PROMISE-worded ('every rune'),
  // so its target tracks the live rune set — pinned by test.
  'third_mark': AchievementDef(
    'third_mark',
    'The Third Mark',
    'Temper three different runes across your delves.',
    stat: 'runes_tempered',
    target: 3,
  ),
  'six_marks': AchievementDef(
    'six_marks',
    'The Six Marks',
    'Temper every rune the anvil offers.',
    stat: 'runes_tempered',
    target: 6,
  ),
  'hard_five': AchievementDef(
    'hard_five',
    'Hard Habit',
    'Win 5 runs on hard.',
    stat: 'hard_wins',
    target: 5,
  ),
  'ascension_three': AchievementDef(
    'ascension_three',
    'Third Rung',
    'Reach ascension 3.',
    stat: 'best_ascension',
    target: 3,
  ),
  'ascension_ten': AchievementDef(
    'ascension_ten',
    'Tenth Rung',
    'Reach ascension 10.',
    stat: 'best_ascension',
    target: 10,
  ),
  'ascension_twenty': AchievementDef(
    'ascension_twenty',
    'Top of the Ladder',
    'Reach ascension 20 — the last rung there is.',
    stat: 'best_ascension',
    target: 20,
  ),

  // --- the unwritten feats (v0.107.0) -------------------------------------
  // The weekly, the codex, the tales, the settled scores and the bestiary's
  // breadth all bank real counters — these give them the recognition the
  // older systems already had. Recognition only, as ever: no power.
  'weekly_first': AchievementDef(
    'weekly_first',
    'The Shared Seed',
    'Finish a Weekly Delve.',
    stat: 'weeklies_played',
    target: 1,
  ),
  'weekly_ten': AchievementDef(
    'weekly_ten',
    'Ten Mondays',
    'Finish 10 Weekly Delves.',
    stat: 'weeklies_played',
    target: 10,
  ),
  'codex_ten': AchievementDef(
    'codex_ten',
    'The Open Book',
    'Unseal 10 Codex entries.',
    stat: 'codex_unsealed',
    target: 10,
  ),
  'codex_forty': AchievementDef(
    'codex_forty',
    'The Deep Library',
    'Unseal 40 Codex entries.',
    stat: 'codex_unsealed',
    target: 40,
  ),
  'tales_ten': AchievementDef(
    'tales_ten',
    'Fireside Regular',
    'Hear 10 hearth tales at rests.',
    stat: 'tales_heard',
    target: 10,
  ),
  'score_settled': AchievementDef(
    'score_settled',
    'The Settled Score',
    'Fell a foe that had felled you twice.',
    stat: 'foes_settled',
    target: 1,
  ),
  // v0.113.0 The Cold Honors — recognition for the rotation's hardest sit
  // (the doubled week, v0.111.0). Reads the same monotonic counter that
  // feeds the Frostvein vista; recognition only, grants nothing (§Ethics).
  'first_winter': AchievementDef(
    'first_winter',
    'The First Winter',
    'Claim the Ember on a doubled week.',
    stat: 'doubled_wins',
    target: 1,
  ),
  'thrice_wintered': AchievementDef(
    'thrice_wintered',
    'Thrice Wintered',
    'Claim the Ember on three doubled weeks.',
    stat: 'doubled_wins',
    target: 3,
  ),
  'twenty_names': AchievementDef(
    'twenty_names',
    'Twenty Names',
    'Fell 20 different foes.',
    stat: 'distinct_felled',
    target: 20,
  ),
};
