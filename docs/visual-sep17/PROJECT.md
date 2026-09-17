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
- Preserve game palette/fonts, roster identities and native pixel budgets.
- September 18 owner scope addition: improve actual character designs, not
  only animation. Redesign Kindler/Warden source art and sheets, with
  reproducible conversion/provenance and matching grip metadata. The other
  20 character sheets remain unchanged. This supersedes the earlier
  assistant-selected constraint to preserve all shipped character art.
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

Iteration 3 implemented: new Kindler/Warden source art, reproducible native
conversion, matching joints/grip metadata and candid provenance. Analyzer
clean; full 1413/1413 with exit 0. Other twenty models byte-identical.
Iteration 4 checks rendered joint continuity and all phone-size fixtures;
math alone does not establish gap-free anatomy or human aesthetic approval.
Six-iteration cap unchanged.

## Iterations

1. Presentation contact ledger and timed regression evidence.
2. Shared body/grip transform and authored Kindler/Warden articulation.
3. Kindler/Warden character redesign, source conversion and matching rig.
4. Visual polish/edge cases at phone widths; guard, fatigue, blood off.
5. Full verification and evidence packaging.
6. Reserved single corrective/descope iteration; do not overrun.
