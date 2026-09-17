# PROJECT.md — Contact and body-action visual pass

Adapted from canonical subagent-toolkit v3.0.1 templates/PROJECT.md.

## Goal

Make combat's visual health, wounds and guard agree with impact, and give
Kindler/Warden body action and continuous grip rather than another particle
layer. Deliver an open, verified source PR with actual-render evidence.

## Session-start ritual

1. Read this file, `features.json`, and the tail of `progress.md`.
2. Run `flutter analyze && flutter test` on the current review branch.
3. Pick the single most important unfinished feature; work only on that.

## Standing decisions

- VERIFIED: `main` is frozen; shipping dice branch is `legacy/dice-builder`.
- VERIFIED: inspected PR index and details for #12, #18, #88, #99, #101,
  #102, #103, #104; remote refs cover all existing branches.
- VERIFIED: PR #104 adds the blood comfort control and detailed critique.
  Build on its exact `0df9d51` head, keeping it and #102 open. The new PR
  will initially target #104's branch, making its incremental diff reviewable.
- Preserve original tests, all sealed sim files, dependencies, workflows,
  version, saves and entitlements. No release, tag, merge or Play action.
- Preserve game palette/fonts, roster identities, pixel sizes and actual art.
- Authored pose means anatomy changes, not a renamed whole-sprite transform.
- Physical phone/touch/FPS and Play billing stay explicitly unverified.
- No authentication data in this repo or any verification artifact.

## Constraints

- Single direct executor; no workers/subagents. Maximum six implementation
  iterations; two consecutive no-diff iterations halt. Retry a failed task
  once after quoting its exact non-secret error, then descope or escalate.
- Owner subsequently authorized broad code/test changes on this pass. Routine
  fixture corrections may proceed; never weaken acceptance or hide failures.
- Existing art-generator metadata failure and keystone-unaware interactive
  harness are inherited, not evidence the product is broken. Do not weaken
  them. Art metadata production repair is in scope if needed for grip data;
  interactive-tool repair is deferred unless required for the scoped proof.
- Scoped completion is `docs/visual-sep17/features.json` all true with
  evidence. Root unfinished physical-device features remain untouched.

## Current phase

Iteration 1 verified: 12 new contact cases reproduce the defects on #104,
then pass after production wiring; full suite 1399/1399, analyzer clean.
Baseline real-render samples are preserved separately. Next: iteration 2,
segmented source-pixel Kindler/Warden articulation and continuous grip.

## Iterations

1. Presentation contact ledger and timed regression evidence.
2. Shared body/grip transform and authored Kindler/Warden articulation.
3. Visual polish at phone widths, low/high dice, blood off, guard and fatigue.
4. Edge cases and regression sweep; no expansion into gameplay.
5. Full verification and evidence packaging.
6. Reserved single corrective/descope iteration; do not overrun.
