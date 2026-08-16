// meta/rank.dart — The Delver's Rank (v0.13.0): a pure function of MetaState.
//
// DERIVED, NEVER STORED. The rank reads only counters MetaState already
// banks for other features; it writes nothing, so cloud merge needs no new
// rules — and because every input survives merge as a per-key MAX or a set
// UNION (meta/cloud_merge.dart), the marks total is monotone under merge: a
// merged profile can never outrank down. test/rank_test.dart pins that.
//
// Marks formula (every term is REAL banked history, §Ethics honesty):
//   3 × delves won                      (runsWon)
//   5 × distinct bosses put down        (bossesBeaten)
//   2 × distinct foes felled            (enemyFelled keys)
//   1 × distinct foes met               (enemyMet keys)
//   1 × codex entries unsealed          (ownedCodex)
//   2 × shared-rule delves finished     (dailiesPlayed + weekliesPlayed)
//
// Hard and Ascension wins count exactly as "a win" — rank must never lean
// on the paid difficulty (§Ethics: no payment interaction).
import '../data/ranks.dart';
import 'meta.dart';

export '../data/ranks.dart' show RankTier, rankTiers;

/// Total marks a profile has banked. Monotone in every MetaState counter it
/// reads, so it can only grow — within a device and across a cloud merge.
int rankMarks(MetaState m) =>
    m.runsWon * 3 +
    m.bossesBeaten.length * 5 +
    m.enemyFelled.length * 2 +
    m.enemyMet.length +
    m.ownedCodex.length +
    (m.dailiesPlayed + m.weekliesPlayed) * 2;

/// The highest tier whose threshold the profile's marks meet. Total: the
/// first tier's threshold is 0, so every profile — including a brand-new
/// one — holds a rank.
RankTier rankFor(MetaState m) {
  final marks = rankMarks(m);
  var held = rankTiers.first;
  for (final t in rankTiers) {
    if (marks >= t.marks) held = t;
  }
  return held;
}

/// The next tier above the held one, or null at the top of the ladder.
RankTier? nextRank(MetaState m) {
  final held = rankFor(m);
  for (final t in rankTiers) {
    if (t.marks > held.marks) return t;
  }
  return null;
}
