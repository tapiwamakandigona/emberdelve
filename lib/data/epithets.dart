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
};
