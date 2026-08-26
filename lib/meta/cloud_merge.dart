// lib/meta/cloud_merge.dart — pure merge of two MetaState snapshots (P4 cloud
// save). No I/O, no plugin imports: unit-testable headless and safe to call
// from anywhere.
//
// The problem: the same player on two devices (or a reinstall) has two save
// files that both contain real progress. Picking one wholesale loses the
// other's progress; summing counters double-counts. The contract here:
//
//   • Monotonic counters (runsPlayed, lifetimeEmbers, bestFloor, …) — MAX.
//     Each device's value is a lower bound on the truth; max never invents
//     progress and never loses the larger record. Per-character maps merge
//     per key the same way.
//   • Owned sets (characters, themes, skins, codex, bosses, seen
//     achievements) — UNION. Something earned anywhere stays earned.
//   • Sticky flags (forgeUnlocked, tutorialSeen, difficultyChosen) — OR.
//     forgeUnlocked especially: a paid unlock must never be lost by a merge
//     (§Ethics: no punishment). Play purchases re-grant via StoreService
//     anyway; OR just avoids a window where it looks lost.
//   • Everything mutable-by-spending or last-writer-wins (embers, active
//     cosmetics, preferred difficulty, daily/weekly recap records, run
//     history) — taken wholesale from the FRESHER side. Freshness =
//     higher lifetimeEmbers, then higher runsPlayed, then the local side.
//     lifetimeEmbers only ever grows, so the side that has seen more total
//     embers is the side that has played more recently *or* longer — either
//     way its spendable balance and recaps are the ones the player last saw.
//
// Union+max CAN inflate spendables in one corner: buy a skin on device A,
// then merge with an older device B — A's post-purchase ember balance is
// kept (fresher side) AND the skin is kept (union), which is exactly right.
// The reverse (B fresher, A owns the skin) keeps B's balance and the skin:
// the player gets the skin "for free" relative to B's ledger. Accepted: the
// alternative (dropping owned cosmetics) punishes, and embers are a soft
// currency with no real-money value.
import '../data/news.dart' show compareVersions;
import 'meta.dart';

/// True when [a] is the fresher snapshot (see file header for the contract).
bool isFresher(MetaState a, MetaState b) {
  if (a.lifetimeEmbers != b.lifetimeEmbers) {
    return a.lifetimeEmbers > b.lifetimeEmbers;
  }
  if (a.runsPlayed != b.runsPlayed) return a.runsPlayed > b.runsPlayed;
  return true; // tie -> first argument (call with local first)
}

Map<String, int> _maxMap(Map<String, int> a, Map<String, int> b) {
  final out = Map<String, int>.from(a);
  b.forEach((k, v) {
    final cur = out[k];
    if (cur == null || v > cur) out[k] = v;
  });
  return out;
}

/// Merge [local] and [cloud] into a NEW MetaState. Neither input is mutated.
MetaState mergeMetaStates(MetaState local, MetaState cloud) {
  final fresh = isFresher(local, cloud) ? local : cloud;
  return MetaState(
    // Fresher side: spendables, active cosmetics, preferences, recaps.
    embers: fresh.embers,
    activeTheme: fresh.activeTheme,
    activeDieSkin: fresh.activeDieSkin,
    activeDye: fresh.activeDye,
    selectedVista: fresh.selectedVista,
    selectedEpithet: fresh.selectedEpithet,
    // v0.66.0: per-delver dress is a cosmetic SELECTION, so the fresher
    // side wins wholesale — same convention as selectedEpithet/activeDye.
    charEpithet: Map.of(fresh.charEpithet),
    preferredDifficulty: fresh.preferredDifficulty,
    preferShortRoad: fresh.preferShortRoad,
    lastDailyDate: fresh.lastDailyDate,
    lastDailyWon: fresh.lastDailyWon,
    lastDailyFloor: fresh.lastDailyFloor,
    lastDailyFloors: fresh.lastDailyFloors,
    lastWeeklyKey: fresh.lastWeeklyKey,
    lastWeeklyWon: fresh.lastWeeklyWon,
    lastWeeklyFloor: fresh.lastWeeklyFloor,
    lastWeeklyFloors: fresh.lastWeeklyFloors,
    lastWeeklyMutator: fresh.lastWeeklyMutator,
    runHistory: fresh.runHistory
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
    // Max: monotonic counters.
    bestAscension: local.bestAscension > cloud.bestAscension
        ? local.bestAscension
        : cloud.bestAscension,
    runsPlayed: local.runsPlayed > cloud.runsPlayed
        ? local.runsPlayed
        : cloud.runsPlayed,
    runsWon: local.runsWon > cloud.runsWon ? local.runsWon : cloud.runsWon,
    lifetimeEmbers: local.lifetimeEmbers > cloud.lifetimeEmbers
        ? local.lifetimeEmbers
        : cloud.lifetimeEmbers,
    exactKills: local.exactKills > cloud.exactKills
        ? local.exactKills
        : cloud.exactKills,
    // exactStreak is "current consecutive" — a device-local, in-the-moment
    // value; the fresher side's streak is the live one.
    exactStreak: fresh.exactStreak,
    bestExactStreak: local.bestExactStreak > cloud.bestExactStreak
        ? local.bestExactStreak
        : cloud.bestExactStreak,
    bestFloor: local.bestFloor > cloud.bestFloor
        ? local.bestFloor
        : cloud.bestFloor,
    dailiesPlayed: local.dailiesPlayed > cloud.dailiesPlayed
        ? local.dailiesPlayed
        : cloud.dailiesPlayed,
    weekliesPlayed: local.weekliesPlayed > cloud.weekliesPlayed
        ? local.weekliesPlayed
        : cloud.weekliesPlayed,
    winsNoRest: local.winsNoRest > cloud.winsNoRest
        ? local.winsNoRest
        : cloud.winsNoRest,
    hardWins: local.hardWins > cloud.hardWins ? local.hardWins : cloud.hardWins,
    charRuns: _maxMap(local.charRuns, cloud.charRuns),
    charWins: _maxMap(local.charWins, cloud.charWins),
    charBestFloor: _maxMap(local.charBestFloor, cloud.charBestFloor),
    enemyMet: _maxMap(local.enemyMet, cloud.enemyMet),
    enemyFelled: _maxMap(local.enemyFelled, cloud.enemyFelled),
    enemyFellTo: _maxMap(local.enemyFellTo, cloud.enemyFellTo),
    // Union: earned anywhere stays earned.
    unlocked: {...local.unlockedCharacters, ...cloud.unlockedCharacters},
    ownedThemes: {...local.ownedThemes, ...cloud.ownedThemes},
    ownedDieSkins: {...local.ownedDieSkins, ...cloud.ownedDieSkins},
    ownedDyes: {...local.ownedDyes, ...cloud.ownedDyes},
    ownedCodex: {...local.ownedCodex, ...cloud.ownedCodex},
    bossesBeaten: {...local.bossesBeaten, ...cloud.bossesBeaten},
    seenAchievements: {...local.seenAchievements, ...cloud.seenAchievements},
    provingsCleared: {...local.provingsCleared, ...cloud.provingsCleared},
    heardTracks: {...local.heardTracks, ...cloud.heardTracks},
    tipsSeen: {...local.tipsSeen, ...cloud.tipsSeen},
    // OR: sticky flags.
    forgeUnlocked: local.forgeUnlocked || cloud.forgeUnlocked,
    tutorialSeen: local.tutorialSeen || cloud.tutorialSeen,
    // Asked anywhere = asked everywhere: the one review ask must never be
    // repeated on a second device after a cloud merge.
    reviewAsked: local.reviewAsked || cloud.reviewAsked,
    // Union: a code redeemed anywhere stays redeemed everywhere.
    redeemedCodes: {...local.redeemedCodes, ...cloud.redeemedCodes},
    // Max: toured anywhere counts everywhere (v0.8.0 Guided Delve).
    tourSeenVersion: local.tourSeenVersion > cloud.tourSeenVersion
        ? local.tourSeenVersion
        : cloud.tourSeenVersion,
    difficultyChosen: local.difficultyChosen || cloud.difficultyChosen,
    // Max VERSION (v0.15.0 Hearthside Post): the news is "seen" once seen
    // anywhere — a merge must never re-surface an already-dismissed post.
    lastSeenNewsVersion:
        compareVersions(local.lastSeenNewsVersion, cloud.lastSeenNewsVersion) >=
            0
        ? local.lastSeenNewsVersion
        : cloud.lastSeenNewsVersion,
  );
}
