// lib/meta/achievements.dart — Delver's Ledger evaluation (v0.5.0).
//
// OUTSIDE the sealed sim: this reads MetaState counters only, never run state,
// and it never feeds anything back into a run. Pure functions of (meta, def) so
// the ledger UI and the tests see exactly the same numbers.
//
// Honesty contract (spec §Ethics): [statValue] returns the REAL banked counter.
// There is no padding, no head start, and no decay — a progress bar built from
// [progress] can only ever show what the player actually did.
import '../data/achievements.dart';
import '../game/weekly.dart' show legalRuleLabels;
import '../sim/run_dice.dart' show faceRunes;
import '../data/characters.dart';
import '../data/enemies.dart';
import 'meta.dart';

/// Current value of [stat] for [m]. Unknown stats return 0 rather than throwing:
/// a future data file must never be able to crash a player's ledger. The
/// achievements test asserts every shipped def uses a known stat, so an unknown
/// stat can only mean a build newer than this file.
int statValue(MetaState m, String stat, [String? param]) {
  switch (stat) {
    case 'runs_played':
      return m.runsPlayed;
    case 'runs_won':
      return m.runsWon;
    case 'char_wins':
      return param == null ? 0 : (m.charWins[param] ?? 0);
    case 'chars_unlocked':
      return m.unlockedCharacters.length;
    case 'exact_kills':
      return m.exactKills;
    case 'best_exact_streak':
      return m.bestExactStreak;
    case 'lifetime_embers':
      return m.lifetimeEmbers;
    case 'best_ascension':
      return m.bestAscension;
    case 'bosses_beaten':
      return m.bossesBeaten.length;
    case 'best_floor':
      return m.bestFloor;
    case 'dailies_played':
      return m.dailiesPlayed;
    case 'wins_no_rest':
      return m.winsNoRest;
    case 'themes_owned':
      return m.ownedThemes.length;
    case 'hard_wins':
      return m.hardWins;
    case 'provings_cleared':
      // v0.59.0 The Proven: distinct provings cleared (Set, junk-proof).
      return m.provingsCleared.length;
    // v0.107.0 The Unwritten Feats — same honesty contract: real banked
    // counters only, junk-proofed against hand-edited saves where a
    // catalog exists to check against.
    case 'tempers_set':
      return m.tempersSet;
    case 'weekly_rules_won':
      // Junk-proof: only labels the live rotation can deal are counted.
      return m.weeklyRulesWon.where(legalRuleLabels().contains).length;
    case 'runes_tempered':
      // Junk-proof: only runes the live anvil offers are counted.
      return m.runesTempered.where(faceRunes.contains).length;
    case 'weeklies_played':
      return m.weekliesPlayed;
    case 'codex_unsealed':
      return m.ownedCodex.length;
    case 'tales_heard':
      return m.hearthTalesHeard;
    case 'foes_settled':
      return m.settledFoes.length;
    // v0.113.0 The Cold Honors: weeklies WON on a doubled week — the same
    // monotonic counter the Frostvein vista reads (banked in controller
    // weekly banking, never derivable, never re-locks).
    case 'doubled_wins':
      return m.doubledWins;
    case 'distinct_felled':
      // Distinct REAL enemies felled: junk enemyFelled keys can never
      // inflate this past the bestiary (delvers_cleared precedent).
      return enemies.keys.where((id) => (m.enemyFelled[id] ?? 0) > 0).length;
    case 'delvers_cleared':
      // Distinct ROSTER characters with a win: junk charWins keys from a
      // hand-edited save can never inflate this past the real roster.
      return characters.keys.where((id) => (m.charWins[id] ?? 0) > 0).length;
    case 'delvers_crowned':
      // v0.123.0: the same junk-proof rule for hard-mode wins per delver.
      return characters.keys
          .where((id) => (m.charHardWins[id] ?? 0) > 0)
          .length;
    default:
      return 0;
  }
}

/// Real progress toward [def], clamped to 0.0..1.0.
double progress(MetaState m, AchievementDef def) {
  if (def.target <= 0) return 1.0;
  final v = statValue(m, def.stat, def.param);
  if (v <= 0) return 0.0;
  if (v >= def.target) return 1.0;
  return v / def.target;
}

/// True when [def] has been earned by the counters as they stand.
bool isEarned(MetaState m, AchievementDef def) =>
    statValue(m, def.stat, def.param) >= def.target;

/// Every earned achievement id, in authoring order.
List<String> earnedAchievements(MetaState m) => [
  for (final id in achievementsOrder)
    if (achievements[id] != null && isEarned(m, achievements[id]!)) id,
];

/// Ids earned now but not yet recorded in [MetaState.seenAchievements] — i.e.
/// the ones a toast should announce. Order is authoring order, so a run that
/// completes several at once announces them predictably.
List<String> unseenAchievements(MetaState m) => [
  for (final id in earnedAchievements(m))
    if (!m.seenAchievements.contains(id)) id,
];

/// Mark [ids] as announced. Caller persists the meta afterwards.
void markSeen(MetaState m, Iterable<String> ids) {
  for (final id in ids) {
    if (achievements.containsKey(id)) m.seenAchievements.add(id);
  }
}

/// How many achievements exist / are earned — for the ledger header.
int get achievementCount => achievementsOrder.length;
int earnedCount(MetaState m) => earnedAchievements(m).length;

/// The next few unearned achievements closest to completion, for a "so close"
/// section. Ties break on authoring order, so the list is deterministic.
/// Achievements with zero progress are excluded: a goal you have not started
/// is not a goal you are close to.
List<AchievementDef> nearestAchievements(MetaState m, {int limit = 3}) {
  final open = <AchievementDef>[];
  for (final id in achievementsOrder) {
    final def = achievements[id];
    if (def == null || isEarned(m, def)) continue;
    if (progress(m, def) <= 0.0) continue;
    open.add(def);
  }
  open.sort((a, b) {
    final c = progress(m, b).compareTo(progress(m, a));
    if (c != 0) return c;
    return achievementsOrder
        .indexOf(a.id)
        .compareTo(achievementsOrder.indexOf(b.id));
  });
  return open.length <= limit ? open : open.sublist(0, limit);
}

/// v0.121.0 The Waymark Line: the title screen's quiet pointer at the one
/// unearned achievement closest to done — "Next waymark: Knapped Sharp —
/// 0 of 1". Reuses [nearestAchievements] wholesale, so the §Ethics contract
/// is inherited: zero-progress goals are excluded (a fresh install sees NO
/// line — the game never assigns homework), counts are the real counters
/// clamped to the target, and the line is a recognition fact, not a nag.
/// Returns null when nothing is in reach — and always before the first
/// delve: a fresh profile technically has progress (the default hearth
/// theme counts toward Full Hearth), and pointing a new player at an
/// ember-spending goal before they have even played once is exactly the
/// homework-on-boot this line must never be.
String? waymarkLine(MetaState m) {
  if (m.runsPlayed <= 0) return null;
  final near = nearestAchievements(m, limit: 1);
  if (near.isEmpty) return null;
  final def = near.first;
  final v = statValue(m, def.stat, def.param).clamp(0, def.target);
  return 'Next waymark: ${def.name} \u2014 $v of ${def.target}';
}
