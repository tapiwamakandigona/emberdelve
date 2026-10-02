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
Regression-first engineering and German listing preparation. Eight-iteration cap.
