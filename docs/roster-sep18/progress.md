# Whole-roster visual follow-up — append-only progress

## Setup / iteration 1 of 10 — 2026-09-18

- Owner: "do all characters", following delivered two-character PR #105.
- VERIFIED: read canonical main/v3.0.1 HARNESS.md and all four templates.
  No loop executed, workers or subagents spawned.
- VERIFIED: fetched and inspected every remote branch, all-state PR inventory,
  current #105/#104/#102 bodies/comments/reviews/checks. No newer work found.
- VERIFIED: created `feat/roster-visuals-sep18` in an isolated worktree from
  `8a5478447a209e764d963ea8fe05f38202d0d2fc`; #105 remains open and green.
- Read character data, production builder, existing art, rig, shared figure,
  weapon definitions and previous scoped state/evidence before planning.
- Plan frozen in PROJECT.md/features.json. Explicit task-driven acceptance
  update: replace "only the two authored delvers opt in" with exact all-22
  coverage, keep fallback assertions and every unrelated check.
- ASSUMED: preserve Kindler/Warden and redesign the remaining twenty in five
  coherent art groups. New art quality is for review, not pre-approved.
- VERIFIED unchanged production baseline: analyzer clean, 1415/1415 tests and
  art check exit 0. Tracked baseline job completed successfully.
- VERIFIED group 1 source converted using the unchanged production converter:
  Gambler, Ascetic, Peddler, Tinker, four poses each. Binary alpha/margins,
  walking difference and silhouette checks pass; nearest silhouette IoU
  0.7840. Source `2999ae2d...62b61` with complete prompt retained.
- Native source masks show the intended hat/split coat, narrow robe, high pack
  and compact shoulder-pad silhouettes and visible empty forward gloves.
  Actual combat integration and rendered visual review are later gates,
  not yet claimed. Production sheets remain unchanged during source staging.
- Iteration 1 complete: verified baseline + first art group and frozen plan.

## Iteration 2 of 10 — flint, rune, load and mend

- Plan: four distinct source designs for Flintwright, Runesmith, Bearer and
  Mender, with empty primary gloves and genuine alternate walk poses.
- VERIFIED source `f97e7bc6...1d590` generated and mechanically reduced by the
  unchanged production converter. All four pass existing alpha/margin/walk/
  silhouette checks; nearest group silhouette IoU 0.8167.
- Native masks distinguish the low dust hood/apron, upright visor, broad
  rear stone harness and small linen hood/bandage packs. Matching art/grip
  integration remains pending; no aesthetic-approval claim.
- Iteration 2 complete; source is staged with full prompt and hash.

## Iteration 3 of 10 — shield, gilt, edge and coal

- Plan: Shieldwright, Gilder, Cutler and Collier, with trade-specific silhouettes
  and clean forward grips rather than baked-in duplicate weapons.
- VERIFIED source `0ba19df9...60d8c4` passes unchanged native conversion and all
  existing art checks. Nearest group silhouette IoU 0.7810. All four have
  different walking poses and preserved transparent margins.
- The native cells retain broad blue smith bib, fitted gold-trimmed apron,
  lean diagonal apron and rounded coal-basket cowl respectively. Public source
  prompt/hash retained; source staging does not yet imply runtime completion.
- Iteration 3 complete.

## Iteration 4 of 10 — fire, hearth, hedge and grain

- Plan: Stoker, Hearthkeeper, Hedger and Miller source designs; preserve separate
  short-costume legs and attachable gloves despite their outer gear.
- VERIFIED source `d2e59b30...ce59a35`, unchanged production converter/checks.
  Four complete models and different walk poses; nearest group silhouette
  IoU 0.8822, below the unchanged 0.93 guard. Not an aesthetic score.
- Native masks preserve asymmetric heat mantle, rear half-cape/key ring,
  broad low brim/shoulder mat and round flour cap/low sack distinctions.
- Iteration 4 complete; native combat and global all-roster checks pending.

## Iteration 5 of 10 — kettle, lamp, iron and leather

- Plan: Brewster, Lamplighter, Farrier and Glover to complete the remaining
  twenty source redesigns. Existing Kindler/Warden sources stay untouched.
- VERIFIED source `66942f14...0b528b2` passes unchanged production converter/
  validation for all four, nearest group silhouette IoU 0.7845.
- Native masks distinguish rear kettle/wide apron, pointed hood/long split
  coat, low square cap/heavy apron and slim asymmetric cuffs. All have painted
  forward fists; no runtime tool is baked into a grip.
- All five staged sources retain original prompts/hashes. Their art checks
  passed separately; global silhouette/metadata/rig integration is next.
- Iteration 5 complete, no source regeneration required.
