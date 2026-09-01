// data/epithets.dart — Earned epithets (v0.36.0, The Epithets). CONTENT AS
// DATA, ZERO LOGIC.
//
// An epithet is a title worn under the delver's name — 'The Kindler, the
// Unburnt'. The third answer to the first outside review's customisation
// ask: dyes (v0.27.0) recolor the body, vistas (v0.35.0) recolor the world,
// epithets name the player's own history.
//
// Honesty contract: every epithet reads a REAL banked counter through the
// Ledger's stat vocabulary (lib/data/achievements.dart) and the shared
// resolver statValue() in lib/meta/achievements.dart. Unlocks are DERIVED —
// nothing is persisted, nothing can be lost, nothing is ever sold
// (docs/spec.md §Ethics). The unlock line states the real milestone.
//
// The default is '' — no epithet, just a delver. A fresh profile renders
// every screen exactly as before this file existed.

class EpithetDef {
  final String id;
  final String title; // worn after the name, e.g. 'the Unburnt'
  final String unlockLine; // honest milestone, shown while locked

  /// Ledger stat vocabulary (achievements.dart `achievementStats`).
  final String stat;
  final int target;
  final String? param;

  const EpithetDef(
    this.id,
    this.title, {
    required this.unlockLine,
    required this.stat,
    required this.target,
    this.param,
  });
}

/// '' = no epithet worn. Always a legal selection.
const String defaultEpithet = '';

/// Display order, early feats first.
const List<String> epithetsOrder = [
  'the_delver',
  'the_thorough',
  'the_exact',
  'the_unresting',
  'the_bossbane',
  'the_emberled',
  'the_unburnt',
  'the_highborne',
  'the_well_oiled',
  // v0.94.0 The Deep Wardrobe — new titles slot BEFORE the Proven: the
  // Provings summit stays the last word (pinned by proven_epithet_test).
  'the_deepdrawn',
  'the_measured',
  'the_six_handed',
  // v0.129.0 The Earned Titles — same rule: before the Proven.
  'the_tempered',
  'the_weathered',
  'the_proven', // v0.59.0 — append-LAST rule
];

const Map<String, EpithetDef> epithets = {
  'the_delver': EpithetDef(
    'the_delver',
    'the Delver',
    unlockLine: 'Win a delve.',
    stat: 'runs_won',
    target: 1,
  ),
  'the_thorough': EpithetDef(
    'the_thorough',
    'the Thorough',
    unlockLine: 'End ten runs — won, lost, or walked away.',
    stat: 'runs_played',
    target: 10,
  ),
  'the_exact': EpithetDef(
    'the_exact',
    'the Exact',
    unlockLine: 'End 25 fights on exactly the damage needed.',
    stat: 'exact_kills',
    target: 25,
  ),
  'the_unresting': EpithetDef(
    'the_unresting',
    'the Unresting',
    unlockLine: 'Win a delve without visiting a single rest site.',
    stat: 'wins_no_rest',
    target: 1,
  ),
  'the_bossbane': EpithetDef(
    'the_bossbane',
    'the Bossbane',
    unlockLine: 'Fell all three bosses of the deep.',
    stat: 'bosses_beaten',
    target: 3,
  ),
  'the_emberled': EpithetDef(
    'the_emberled',
    'the Emberled',
    unlockLine: 'Bank 1,000 embers in total.',
    stat: 'lifetime_embers',
    target: 1000,
  ),
  'the_unburnt': EpithetDef(
    'the_unburnt',
    'the Unburnt',
    unlockLine: 'Win a delve on Hard.',
    stat: 'hard_wins',
    target: 1,
  ),
  'the_highborne': EpithetDef(
    'the_highborne',
    'the Highborne',
    unlockLine: 'Climb to ascension 5.',
    stat: 'best_ascension',
    target: 5,
  ),
  'the_well_oiled': EpithetDef(
    'the_well_oiled',
    'the Well-Oiled',
    unlockLine: 'Win a delve as the Tinker.',
    stat: 'char_wins',
    target: 1,
    param: 'tinker',
  ),
  // v0.94.0 The Deep Wardrobe: three more real feats, same honesty
  // contract — every one reads a banked Ledger counter.
  'the_deepdrawn': EpithetDef(
    'the_deepdrawn',
    'the Deepdrawn',
    unlockLine: 'Reach the ninth floor.',
    stat: 'best_floor',
    target: 9,
  ),
  'the_measured': EpithetDef(
    'the_measured',
    'the Measured',
    unlockLine: 'End five fights in a row on exactly the damage needed.',
    stat: 'best_exact_streak',
    target: 5,
  ),
  // Target must equal characters.length — pinned by test so a future
  // seventh delver can never silently orphan the unlock line's promise.
  // v0.118.0: the roster grew to seven, and the deep_wardrobe pin holds
  // this target to the LIVE roster count by design ('every delver' must
  // stay true). Display name went count-free so the next delver never
  // forces a rename; the id — the save contract — is untouched.
  'the_six_handed': EpithetDef(
    'the_six_handed',
    'the Many-Handed',
    unlockLine: 'Win a delve with every delver.',
    stat: 'delvers_cleared',
    // Promise epithets move with the live roster. v0.181.0: the brewster.
    target: 19,
  ),
  // v0.59.0 The Proven: the Provings arc's summit reward. Target must
  // equal provings.length — pinned by test so a future proving can never
  // silently orphan the unlock line's promise.
  // v0.129.0 The Earned Titles: tonight's two arcs, wearable. The
  // Tempered shares the forgelight vista's rung (ten faces — one milestone,
  // three rewards: vista, badge road, title). The Weathered is PROMISE-
  // worded ('every rule'), so its target tracks the live rotation
  // (§Re-pricing doctrine) — pinned to legalRuleLabels().length.
  'the_tempered': EpithetDef(
    'the_tempered',
    'the Tempered',
    unlockLine: 'Temper ten die faces.',
    stat: 'tempers_set',
    target: 10,
  ),
  'the_weathered': EpithetDef(
    'the_weathered',
    'the Weathered',
    unlockLine: 'Win a Weekly under every rule in the rotation.',
    stat: 'weekly_rules_won',
    target: 6,
  ),
  'the_proven': EpithetDef(
    'the_proven',
    'the Proven',
    unlockLine: 'Clear every proving.',
    stat: 'provings_cleared',
    target: 27, // v0.181.0: the brewster's proving
  ),
};
