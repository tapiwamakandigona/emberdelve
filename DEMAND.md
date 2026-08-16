# DEMAND — Emberdelve Classic (`legacy/dice-builder`)

What "good" means for every Gauntlet session on this branch. Edited only when
standards genuinely change. Never contains diagnosis of the current build —
that lives in progress.md.

## Product pillars

1. **Fair dice roguelite.** No ads, no timers, no gacha, no loss-framed nags.
   Free tier is a complete game (Easy + Normal + Hard); Ember Forge ($4.99,
   one-time) buys the Ascension ladder and future depth — never expressive
   core mechanics.
2. **The sim is sacred.** `lib/sim/` stays pure Dart — no Flutter, no
   `dart:io`, no unseeded randomness. `resolveAssignment` is the single
   arithmetic source of truth. Golden hashes only move with a documented
   re-anchor table in the commit.
3. **Performance before spectacle.** Per-device download < 30 MB, < 180 MB
   peak memory on a 3 GB device, no perf-proxy regression > 5% without a
   logged justification.
4. **Honest presentation.** Recaps, share text, and store copy state facts.
   A stranger looking at any screen for 3 seconds should never call it fake,
   empty, or confusing.

## Release standards (current mode: GitHub-only)

- Owner directive 2026-08-16: **do NOT submit to Play Store** until told
  otherwise. Ship every improvement as a **GitHub release** instead: tag at
  the release sha, signed APK+AAB from CI (workflow_dispatch on this branch),
  sha256s in the notes, and release notes that explain the improvement in
  plain player-facing language plus a short technical section.
- One improvement per release where practical; version bump per release
  (patch for fixes/polish, minor for features). Signer cert must match pin
  `031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`.

## Quality gates (all VERIFIED, evidence in progress.md)

- `flutter analyze` clean; full test suite green; no skipped tests.
- New behavior has tests; a bug fix has a regression test that fails on the
  old code.
- UI changes: overflow sweep 320×568 → 412×915 at 1.3× text; screenshot
  critique actually performed (look at the plates, write down what's wrong).
- Sim changes: seeded sweep win rates stay in band (easy 80–90%, normal
  55–70%, hard 30–45%), fuzz harness clean, golden re-anchor table recorded.

## Definition of failure

- Shipping a claim without an evidence artifact.
- A release whose notes don't match what the code does.
- Weakening a check to make it pass.
- Waiting idle for anything — build waits are research/content/test time.
