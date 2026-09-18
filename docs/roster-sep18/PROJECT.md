# PROJECT.md — Whole playable roster

Adapted from canonical subagent-toolkit v3.0.1 templates/PROJECT.md.

## Goal

Extend the actual Kindler/Warden character-design and combat-articulation pass
to every playable delver. Deliver a new incremental source PR with reproducible
art, all-character native-pixel/phone evidence and green scoped checks.

## Session-start ritual

1. Read this file, `features.json` and the tail of `progress.md`.
2. Search source and progress before treating work as unbuilt.
3. Check the worktree and baseline; choose one unfinished task only.
4. Plan → act → verify → commit. One executor; no subagents or workers.

## Standing decisions

- VERIFIED: owner requested "do all characters" following the two-delver PR.
  Scope is all 22 PLAYABLE delvers, not enemies, bosses or new characters.
- VERIFIED live base: #105 is OPEN at `8a5478447a209e764d963ea8fe05f38202d0d2fc`.
  #104/#102 remain OPEN; shipping branch is `legacy/dice-builder`, not main.
  Stack the follow-up on `feat/combat-visuals-sep17`; re-read before publishing.
- Preserve the two delivered source sheets and their anatomy; redesign the
  remaining twenty. Keep stable IDs, order, kits, unlocks, palettes/identity.
- ASSUMED creative intent: practical forge-and-ash tradespeople with distinct
  silhouettes, coarse value clusters and empty visible primary grips. Their
  runtime signature tools must remain coherent; no generic recolour roster.
- Six existing tool-motion families remain meaningful. Extend explicit mapping
  to the rest of the signature tools and author matching body poses.
- Actual render verification found that the presentation parsed tempered
  `custom_N` dice as d6. Correct that size lookup through the existing run-die
  resolver, with additive red/green tier/heat tests; do not change dice or sim.
- Preserve sealed sim, gameplay/content definitions, saves, purchases,
  dependencies, workflows, version and all unrelated assets/evidence.
- A single old acceptance assertion that only two delvers can opt into rigs is
  obsolete under this explicit roster request. Replace it with STRONGER exact
  all-roster coverage; preserve its unknown-ID/standalone fallback assertions
  and all other existing tests. Call this specification change out in the PR.
- Art is generated source plus deterministic native conversion, not claimed
  human illustration. Source prompts, hashes and authored rig data stay public.
- No merge, release, force-push, signing dispatch or Play/store operation.
  Physical-device touch/FPS, actual purchases and aesthetic approval remain
  separate from deterministic Flutter evidence. Do not mark their gates true.

## Constraints

- Ten implementation iterations for this new whole-roster task (assistant-set
  cap, distinct from the closed previous task). Two no-diff iterations halt.
- One corrected retry after recording the exact failure; then descope/escalate.
  No disabled assertions, wider tolerances or hardcoded expected outputs.
- Five art groups of four delvers, at most one refinement per group when needed.
  No purchased assets or third-party paid-service setup.
- Existing 32x40 native cells, 64x120 sheets, binary alpha, two-pixel margins,
  100 KiB character PNG budget and 1.5 MiB decoded-sheet budget stay intact.
  Whole-roster cutout cache must be explicitly bounded and measured.

## Iterations

1. Baseline, scoped acceptance/design matrix and first four source designs.
2. Flintwright, Runesmith, Bearer and Mender source designs.
3. Shieldwright, Gilder, Cutler and Collier source designs.
4. Stoker, Hearthkeeper, Hedger and Miller source designs.
5. Brewster, Lamplighter, Farrier and Glover source designs.
6. Reproducible sheets, native anatomical annotations and full-roster rig wiring.
7. Tool-family body/weapon action and all-roster regression proof.
8. Actual phone renders and raster-continuity polish.
9. Full gates, integrity, evidence package and incremental PR.
10. Single corrective/descope reserve; never silently overrun.

## Current phase

Iterations 1–8 verified. All 22 playable rigs and six tool-family paths are
integrated. Actual phone/picker/native capture matrix passes 72/72; a real
tempered-die size presentation defect found there has a red/green regression.
Iteration9 is final whole-suite/integrity/evidence closure and publication.
Do not treat the green baseline as the final tree's result. Reserve10 unused.
