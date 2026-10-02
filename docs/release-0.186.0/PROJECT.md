# 0.186.0 — Clear Choices

## Goal
Owner-authorized 2026-10-02: improve the game, add a German Play listing, cut
GitHub and Play releases, and publish relevant Reddit updates. Ship a focused
presentation release from `legacy/dice-builder` at 535029b. Candidate 0.186.0+219.

## Standing decisions
- Preserve the sealed simulation, saves, billing implementation and entitlement
  rules. No prices, products, ads, consumables, paid campaigns or external tips.
- Keep every existing Forge promise, including future acts/delvers.
- German store copy must not claim a German in-game translation.
- R8/resource shrinking and background bitmap downsampling already exist;
  audit them rather than claiming to introduce them.
- Preserve all existing tests and open physical-device/purchase gates.
- Leave historical PR102 alone. Work on the authorized release branch.

## Verification
Use the unchanged CI: analyzer, full tests, SFX and permanent-key signed build.
Add regressions first and record the red result before implementation.
Independently inspect package/version/certificate/hash of delivered binaries.
Play submission is distinct from live availability; report each separately.

## Environment
The managed GitHub module is unavailable in this environment. The owner-provided
GitHub credential authorizes the documented REST release/Actions operations;
no shell Git commands or fabricated commit authors are used.
Official pinned Flutter SDK endpoints returned HTTP404 locally (one retry).
Use the existing pinned GitHub Actions environment; do not change dependencies
or toolchain merely to make local setup pass.

## Current phase
Implementation verified with seven new red→green regressions. Full CI is
blocked only by the inherited contradictory weekly test; draft PR111 is open.
German listing is in review. No version bump, signed build or release.
Eight-iteration cap; two engineering iterations used. See `verification.md`.

## Baseline-discovered release blockers
CI37017234889 ran the unchanged original tests plus seven new regressions:
1596 passed,9 failed. Besides the new expected failures, the returning title
needs8px less vertical whitespace at412x915. Fix the production layout, not
the existing no-scroll assertion.

The original weekly-history test requires this week's short_road entry in
`mutators`, then forbids it there. Production intentionally encodes it in
`short` instead. Preserve the test and game behavior pending an explicit
decision on this contradictory check; never change the clock or rotation to
obtain a green build. A read-only reviewer will verify the diagnosis.
