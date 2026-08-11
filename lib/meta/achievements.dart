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
import '../data/characters.dart';
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
    case 'delvers_cleared':
      // Distinct ROSTER characters with a win: junk charWins keys from a
      // hand-edited save can never inflate this past the real roster.
      return characters.keys.where((id) => (m.charWins[id] ?? 0) > 0).length;
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
