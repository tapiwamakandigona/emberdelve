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

## Iteration 6 of 10 — native sheets and full-roster anatomical wiring

- Plan: integrate all staged sources; author measured native joints/cut regions,
  reproduce static Dart definitions and hand metadata; opt every playable
  combat figure in while keeping unknown-ID/portrait fallback.
- Production art builder now covers the twenty new sources and keeps existing
  Kindler/Warden PNGs byte-identical. All old validation assertions retained.
- VERIFIED first all-roster production write: 22 models, 40798 PNG bytes,
  675840 decoded RGBA bytes, nearest global silhouette IoU 0.8822.
- Explicit per-character anatomy in `roster_rigs.json` generates static Dart
  data; runtime never reads JSON or guesses joint positions.
- Acceptance update called out before implementation: the old assertion that
  Gambler has no rig is replaced by exact all-22 ID coverage, while unknown-ID
  and standalone SpriteView/WeaponView fallback checks are retained.
- Added source/rig coverage and painted-anatomy tests; these have not yet run.
- VERIFIED new + existing art/design/articulation tests: 38/38, exit 0.
  Every painted wrist and all required anatomical layers are present; hand
  metadata agrees with source-center coordinates for all twenty-two.
- VERIFIED analyzer clean and production `--check` including static rig
  generation passes. Provenance/credits updated candidly for all twenty-two.
- Iteration 6 complete. Family-specific action/raster proof remain open;
  these source/joint checks do not establish seamless moving silhouettes.

## Iteration 7 of 10 — tool-family body action and roster-wide regression

- Plan: explicit signature-tool family coverage, six distinct native body
  paths, measured shared-wrist/grounded-foot and reduced-motion contracts;
  capture native raster continuity separately from joint math.
- Implemented cut/crush/stab/stamp/hook/pick body poses sized to each measured
  arm, explicit signature-tool mapping and matching windup angles. Delivered
  Kindler/Warden poses retained. Warmed cutout-cache byte count is exposed to
  additive tests; no runtime JSON, per-frame image creation or stage rebuild.
- Analyzer stopped on two new fixed constructor lint infos:
  `Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation`.
  Added const to the two fixed Offset constructors; unchanged lint policy.
  One corrected retry follows.
- VERIFIED corrected analyzer clean. New/existing articulation, family,
  body-condition and contact tests: 91/91, exit 0. New mathematical coverage
  alone samples 33000 native joint/condition combinations across all delvers.
- VERIFIED actual raster continuity: 22/22 tests, 3960 rendered bodies across
  72/96/104px, low/high, healthy/20% HP, five poses and three transition
  fractions. No disconnected anatomy in sampled cases; tolerances unchanged
  from the prior native-pixel probe. Full per-character observation JSON kept.
- VERIFIED full roster cutout cache: 1239040 decoded RGBA bytes (22 × 11 ×
  32 × 40 × 4), below the explicit 1.25 MiB cutout bound. This is separate from
  the unchanged 675840-byte decoded-sheet budget and not a frame-rate claim.
- Iteration 7 complete. Actual full-phone/portrait captures and final gates
  are still required before marking the scoped features complete.
