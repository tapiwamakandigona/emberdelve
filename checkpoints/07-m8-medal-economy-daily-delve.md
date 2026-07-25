# Checkpoint 07 — M8: medal economy + Daily Delve (2026-07-25)

## State at checkpoint
- main = 7595ce2 (+ this state-file commit). 153/153 tests, analyze clean.
- P-M0..P-M6, P-M8 pass. Open: P-M7 (perf/device-proof), P-M9 (World 2), P-M10 (beta.1).
- v1.0.0-alpha.1 prerelease live on GitHub; Play closed testing on release 12 (v0.3.9+12).

## What M8 added
- `kPerfectClearBonus=25` (tuning.dart) — every 3-medal run pays it; see
  `LevelResults.perfectBonus`/`totalCoins` (session.dart), `_persistResults`
  (ember_game.dart), gold PERFECT callout (_ResultsOverlay).
- `lib/meta/daily.dart` — deterministic daily remix: dailyKey/dailySeed/dailyLevelId,
  pool w1_l2..w1_l5. Title screen launches GameScreen(levelId, seed, daily:true).
- Save: `dailyBestDate` (String) + `dailyBestTimeMs` (int), field-tolerant.
- Daily runs never write campaign LevelRecords — by design (unlock progression).

## Invariants for the next worker
- Medals are finished / all-chests / low-damage (NOT time-based). Don't churn.
- Daily Delve must stay dark-pattern-free: no streaks, no decay, no countdown copy.
- Package id, keystore, EXPECTED_CERT_SHA256 remain untouchable.

## Next: P-M7
- Sandbox can do: allocation code-audit for Session.update hot path → docs/perf.md;
  split-per-abi + tree-shake-icons size experiment via CI; record decision.
- Sandbox cannot do: real-device profile timeline + cold-start measurement — leave
  P-M7 open until someone runs it on hardware, document honestly.
