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

## Iteration 8 of 10 — full-phone and roster visual evidence

- Plan: all 22 × 3 phone widths with actual GameRoot, attacks/guards and
  blood-off/reduced/text fixtures; all selection portraits and particle-free
  low/high native-size pose plates. Explicitly label controlled enemy HP and
  rolled faces used to exercise every unchanged kit.
- New render-tool analyzer flagged two visible-for-testing calls under
  `tool/` rather than `test/`:
  `The member 'reset' can only be used within 'package:emberdelve/ui/motion.dart' or a test`
  and `The member 'debugSpriteSheetCached' can only be used within 'package:emberdelve/ui/sprites.dart' or a test`.
  Use the public motion update; locally document the test-only cache assertion
  without removing it or changing analyzer policy. One corrected retry.
- VERIFIED analyzer retry clean. First narrow-phone pilot stopped with:
  `Bad state: Too many elements`
  at `_observe`'s global `tester.widget<WeaponView>` during incoming contact.
  Source inspection verified the existing 60ms hit-flash AnimatedSwitcher
  temporarily paints two complete figures. The capture probe now asserts the
  sprite/tool/hand contract separately for EVERY painted figure, not a global
  singleton. No production change or assertion suppression.
- Pre-retry fixture review found three additional assumptions to correct:
  resolve original run-local tempered dice before comparing kit IDs; honor die
  and relic minimum faces (Tinker's legal low comes from the plain d6 with floor
  2, not Steady Ember); use `sides - 1` for high, because a d4's ceil(80%) is
  MAX, not high. Recompute combo flags/bonuses for the labelled forced faces.
  Keep original kit/temper checks and exact tier expectations. One corrected
  pilot retry follows; no game code is changed by these fixture corrections.
- VERIFIED corrected narrow-phone pilot passed, exit 0, all 190 sampled
  observations retained. Every transitional figure copy is checked. Start the
  complete 72-case capture matrix; sampled clip time is separately labelled
  from the fixture clock, because roll/setup time between actions is omitted.
- Full capture revealed a real pre-existing presentation defect on Bearer and
  Mender, not permission to loosen the tier assertion:
  `Expected: DieTier:<DieTier.high>`
  `Actual: DieTier:<DieTier.max>`.
  `_selectedFace` parsed `custom_N` as an unknown d6 instead of resolving its
  unchanged run-local catalog base. Their d12/d8 high rolls therefore chose a
  max-tier body/weapon plan. Sealed simulation resolution already uses the
  correct size; rolls/damage are not being changed.
- Plan revision within iteration 8: after the first complete capture run,
  add a red/green widget regression for tempered d4/d6/d8/d10/d12 relative
  tiers/heat; change only the presentation size lookup to `resolveRunDie`,
  then one corrected full capture retry with all tier assertions intact.
  Include this narrowly scoped extra original-file diff in integrity/PR notes.
- First complete run ended exit 1: 63 passed / 9 failed. Six failures are the
  same real tempered-die defect (Bearer/Mender × three widths). The other three
  are picker-probe ambiguity after reaching wardrobe name controls:
  `The "getTopLeft()" method needs a single target.`
  Scope the finder to the actual `EmberText.h2` card heading, retain every
  portrait expectation, and add explicit viewport bounds. No production picker
  change is needed. First-run pixels/logs are preserved as pre-fix evidence.
- VERIFIED additive red control failed on the actual defect:
  `Expected: a numeric value within <1e-10> of <0.9291666666666666>`
  `Actual: <1.0>`
  `custom d12 face 11 must not use a d6 denominator`.
  Changed only `_selectedFace`'s size lookup to the already-imported
  `resolveRunDie`. No simulation/gameplay mutation. Run the unchanged new
  20-case d4/d6/d8/d10/d12 × four-tier regression as green verification.
- VERIFIED all 20 tempered tier/heat regression cases pass after the production
  lookup fix; the regression itself is unchanged from red. Corrected picker
  capture passes at all three widths, all 66 portraits include bounds checks.
  Preserve first-run output separately, then perform the one full-matrix retry.
- VERIFIED corrected full capture exit 0, 72/72: every playable character at
  320×568/360×640/412×892, all selection portraits, 72/96/104px native plates.
  12540 observations, max grip error 2.842170943040401e-14 logical px; all
  outgoing/incoming hit-flash copies checked. 4608 PNGs are fully inventoried.
- VERIFIED evidence assembler exit 0. Source comparison uses all22 exact
  #105 PNG hashes. Six individual 190-frame/7.6s/25fps-encoding clips plus a
  labelled six-family comparison; roll/setup gaps explicitly omitted. Phone
  sampling is not physical-device FPS. Curated evidence/readme committed;
  full raw output retained separately rather than bloating the source PR.
- Source atlases inspected directly; trade silhouettes, empty forward gloves
  and separate boots present. Artistic approval is not inferred from tests
  or model descriptions. Shared real captures for owner review privately.
- Iteration 8 complete: actual-render evidence exposed and fixed the tempered
  tier/heat presentation defect, with additive red/green regression. Final
  whole-suite/integrity/publish remains iteration9; reserve10 unused.
- Checkpoint wrapper did not launch because the shell parsed an unquoted
  commit subject: `syntax error near unexpected token '('`. No managed Git
  mutation ran. Retry once with the complete subject quoted.

## Iteration 9 of 10 — final gates, integrity and incremental PR

- VERIFIED iteration8 committed as `f82d74ff134c9bc1b096bad68a29340b80bc1ce4`,
  worktree clean. Complete managed inventory: 1488 files, secret scan passed;
  only original test diff is the pre-declared stronger all-roster opt-in check.
- Plan: run analyzer/full test suite/art/SFX on this production checkpoint;
  inventory every original protected file and all new files; preserve full
  command evidence. Mark scoped features only with those results. Re-read
  live base/PRs, push the new branch, create incremental PR and verify exact
  remote head/automatic checks. No merge, release or signed dispatch.
- VERIFIED final local gate runner exit 0 on production checkpoint `f82d74f`:
  analyzer clean,1526/1526 tests (111 additive over baseline), production art
  check and SFX. Existing full-attack -0.90dBTP TIGHT boundary retained; all
  reachable cascades clear ceiling, impossible same-frame overloads remain
  reported. Full sanitized command logs/red controls committed as evidence.
- VERIFIED complete inventory scan of1503 files before this report's addition:
  all1417 original paths present;13 sim,22 content,25 meta/game,3 workflow and
 109 prior-review/evidence files hash-identical.266 original test files, only
  declared opt-in update. Kindler/Warden PNGs, non-character assets, dependencies,
  version and lint settings unchanged. Provisioned-secret-value scan passes.
- All four frozen scoped features now have evidence-backed passes. Root
  keystone UI-playthrough, physical-device and actual Play purchase/restore
  criteria remain false. No claim of aesthetic approval or measured device FPS.
- VERIFIED live pre-publication read: #105 OPEN/MERGEABLE at unchanged
  `8a54784`, #104 OPEN/DRAFT, #102 OPEN with inherited conflicts. No new PR on
  this branch. Target remains `feat/combat-visuals-sep17`; existing PRs untouched.
  Final docs/evidence-only closure follows the fully tested production
  checkpoint. Every scoped passes flag has inspected command/artifact evidence.
