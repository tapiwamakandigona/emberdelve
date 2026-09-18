# Visual pass — append-only progress

## 2026-09-17 — baseline and scope

- VERIFIED canonical harness cloned on main at v3.0.1; HARNESS.md and
  templates read. Templates copied, then adapted; loop.sh retained verbatim
  as reference only, never executed to spawn an agent.
- VERIFIED fresh repository clone and all remote branch refs inspected.
  Root main is frozen platformer; active dice work is legacy/dice-builder.
  Read open #102/#104 critiques, merged #103/#101/#99 and older combat work.
- VERIFIED working branch feat/combat-visuals-sep17 is based on #104 head
  0df9d51. Preserve its blood comfort control and leave old PRs open.
- VERIFIED PAT authenticated as expected account and browser login completed
  through user-approved GitHub Mobile. No credentials stored in this repo.
- Environment failure, quoted: `HTTP Error 404: Not Found` for the official
  Flutter release manifest/archive. One retry returned 404. Mirror returned
  403; no further mirror attempts. Canonical Flutter source tag 3.44.9
  cloned instead; engine bootstrap succeeds, Dart 3.12.2 verified.
- ASSUMED design direction: fix contact causality before spectacle, then
  authored cut/maul body action with shared grip. Actual render baseline
  and new tests are still pending; no visual quality/completion claim.

- Bookkeeping patch failure, quoted: `Error reading /work/todo.md: cat:
  /work/todo.md: No such file or directory`. Prior hunks verified present;
  task checklist recreated once without reapplying those hunks.

## Iteration 1/6 — contact timeline, baseline and red regressions

- VERIFIED unchanged #104 source: analyzer clean, 1387/1387 tests pass,
  SFX reachable cascades pass (existing full-attack -0.90 dBTP TIGHT).
  Initial foreground init was killed by the 200000ms shell deadline;
  single retry as a tracked background job completed successfully.
- VERIFIED additive contact tests reproduce early displayed HP in all four
  delvers: `Expected: <19>` / `Actual: <14>` at 100ms, before 340ms contact.
  No source or original-test edits yet.
- New fixture defect: incoming/burn/fast-forward cases attempted End turn
  before rolling. Exact failure: `The finder "Found 0 widgets with widget
  matching predicate: []" (used in a call to "tap()") could not find any
  matching widgets.` This is test setup, not a game bug. Asked permission
  to add only the missing Roll step; all assertions remain read-only.
  App question action `emberdelve_contact_fixture_setup`; awaiting answer.
- Baseline actual-render job started for Kindler and Warden before source
  edits. Its completion/output must be checked before claiming new captures.

- Owner authorized changes ("you can change anything you want"). Corrected
  only the missing Roll fixture step in incoming, burn and fast-forward
  scenarios; assertions and all original tests unchanged.
- VERIFIED baseline actual-render captures complete: Kindler + Warden,
  175 samples each at 40ms simulated intervals; each capture test passes.
  Original source manifest matches. These are not measured phone FPS.

- VERIFIED corrected fixtures: all 12 new cases reproduce the product
  defects on #104, then pass after contact ledger wiring. Original checks
  remain untouched. Analyzer clean; complete suite 1399/1399.
- Implemented copied presentation fields, advanced from sim event payloads
  at player/enemy impact, riposte and burn. Live sim/input remain immediate.
  Full guard remains through impact; unused block expires at recovery.
  Terminal corpse retains event HP zero while the old route is held.
- Source `lib/sim/`, dependencies, original tests, workflows, art and version
  hashes unchanged. No physical device/performance claim.
- Bookkeeping patch partially applied before a root-log context mismatch:
  `Failed to find expected lines`. Verified scoped hunks present; retry
  appends the new root section against the actual file tail only.

- Commit call exceeded the shell's 10000ms deadline; read-back initially
  saw staged files while the managed operation completed. One retry returned
  `nothing to commit, working tree clean`. Reconciled against Git, rather
  than retrying again: VERIFIED commit `92373eefd633c8028a44a4e64b181d83fc8d81f0`,
  expected subject, clean worktree. Use longer managed-call deadlines.

## Iteration 2/6 — jointed source-pixel action and shared grip

- Plan: preserve the original sheets; segment the first idle cell for
  Kindler/Warden into torso/head, two legs, upper arm/forearm, and foreground
  shield/gauntlet. Drive these through one shared motion sample; the weapon
  painter must use that sample's transformed wrist, not a second idle clock.
- Authored cut versus overhead-maul poses will use different wrist paths,
  independent chest/head rotation, weight shift and planted foot anchors.
  The other 20 delvers retain their existing rendering fallback.
- Source-pixel inspection finds baked primary equipment (Kindler torch,
  Warden diagonal sword) in addition to the runtime blade/maul. Combat-only
  masks will replace those pixels, retaining costume/shield and using the
  existing sprite palette beneath the removed sword. Shipped PNGs unchanged.
- Acceptance: joint/grip invariants, low/high commitment, actual live
  consumer wiring, blood-off fatigue, reduced-motion stillness and full
  regression. Rendered quality remains unverified until the next iteration.
- First format pass failed at the new overlay constructor:
  `line 210, column 69 of lib/ui/sprites.dart: Expected to find ')'`.
  Removed the extra comma after the named-argument group; retry once.
- Analyzer: `Undefined class 'ValueListenable'` (six references), plus two
  `Statements in an if should be enclosed in a block` infos. Added the
  explicit foundation import and braces; acceptance unchanged.
- VERIFIED analyzer clean after correction; 63 targeted cases pass, full
  suite 1411/1411 (1387 original + 12 contact + 12 articulation cases).
- Joint tests sweep 3000 pose/condition samples and assert exact shoulder,
  elbow, wrist and boot seams; live SpriteView/WeaponView/gauntlet consume
  the identical sampled wrist notifier. Native-height 72/96/104 alignment.
- VERIFIED reduced idle paints zero custom painters in the isolated figure;
  pixel comparisons show blood on/off changes marks, fatigue persists,
  restored blood-off pixels match, information-bearing action still moves.
- Source sheets untouched. Two cached native rig atlases add 112640 decoded
  RGBA bytes; no new asset files or dependencies. Other 20 delvers retain
  standalone sprite/weapon fallback. No visual-quality claim from green math.

## Iteration 3/6 — requested character redesigns

- Owner added: "also better and more suitable character designs".
  ASSUMED design direction communicated: soot-worn firekeeper Kindler versus
  heavy shield-bearer Warden, grounded in the game's forge-and-ash world.
- Plan updated before implementation. Source art/Kindler/Warden PNGs and
  matching rig/metadata are now allowed; all existing gameplay/ID/unlock
  contracts and original tests stay protected. No blanket roster-recolour
  claim: this is a first two-character production pass.
- New CHARACTERS acceptance records real integration, provenance, original
  margins/binary alpha/memory gates and the unchanged other 20 models.
  Six-iteration hard cap remains; not resetting it for the new message.
- First motion captures completed at commit a7359b1. Automated descriptions
  of the footage were inconsistent about poses/colours; not used as a
  subjective visual-quality pass. Re-evaluate final plates explicitly.
- First generated source had fine shading and a thin forward sleeve; one
  image refinement requested coarser clusters/clearer grip. No further image
  retries. Kept final generated source and both prompts with candid provenance.
- VERIFIED inherited generator failure locally before repair:
  `AssertionError: metadata differs`. Production fix supplies authored
  hand_anchors rather than reading expected output back into the builder;
  original checks/assertions unchanged. Rebuild plus --check now pass.
- VERIFIED 22 models, 38952 compressed PNG bytes, 675840 decoded RGBA bytes;
  nearest silhouette IoU 0.7321 (Warden/Miller), below original 0.93 bound.
  Only Kindler/Warden PNGs and sprite metadata changed among shipped assets.
- New native cells remove baked primary weapons; updated joint positions
  and exact wrist metadata. Deleted now-unneeded weapon-removal masks and
  sword underpaint. Targeted original model/blood and articulation 31/31 pass.
- Added two design tests: actual native wrist pixels are opaque and belong
  to the hand layer; metadata matches rig coordinates, every required limb
  has painted source pixels, and existing IDs/kits/unlocks are pinned.
  Both pass; analyzer clean.
- Full-suite command reached `02:58 +1413: All tests passed!` in its log,
  but the enclosing shell reached `command timed out after 200000 milliseconds`
  before exit-code read-back. Retry the gate once as tracked background work,
  not repeated foreground timeouts.
- Actual 320px Kindler phone probe and source/pose plate pass. In-app pose
  preview delivered; no human aesthetic approval inferred from that delivery.
- VERIFIED single tracked retry finished with exit 0: full suite 1413/1413.
  This resolves the foreground deadline, not a product/test failure.
- Iteration 3 complete as a source checkpoint. Final rendered shoulder,
  wrist and shield continuity remains an iteration-4 review item; automated
  visual descriptions are not sufficient to mark body/art acceptance true.

## Iteration 4/6 — rendered continuity and phone evidence

- Plan: test the rasterized body, not only mathematical joints. The current
  exclusive pixel partitions can expose transparent gaps as limbs turn.
  Add a same-alpha-component check for torso/head/arm/boots across real
  native-scaled sizes, low/high poses and healthy/wounded conditions.
- If the raster check reproduces separation, fix production joint overlaps
  using source pixels at the joint, not new flat-color limbs or weaker checks.
  Check shield pivot against its actual grip. Then run the full phone probe
  at 320/360/412 with blood-off, fatigue, guard and reduced-motion fixtures.
- Preserve iteration-3 renders as pre-polish evidence; final evidence must
  come from the post-polish source. No additional art-generation attempts.
- VERIFIED raster regression on iteration-3 production:
  `Expected: <1>` / `Actual: <2>` /
  `kindler 72.0 DieTier.low 1.0 RigBeat.windup rear boot must connect to the torso`.
  Warden's same-alpha-component cases pass; automated suggestions of fully
  detached Warden anatomy are not corroborated by this stronger check.
- Production correction: small original-pixel hinge overlaps, thigh roots
  mapped through the actual chest transform, and shield pivot at its grip
  instead of low in the plate. Retry the unchanged raster test once.
- VERIFIED raster + existing articulation tests pass (14/14). Raster
  coverage: 120 posed bodies across both delvers, heights 72/96/104, low/high
  dies, healthy/20% HP and all five rig beats.
- Analyzer stopped before render probe:
  `Unused import: 'dart:ui'. Try removing the import directive`
  and `Use 'const' with the constructor to improve performance.`
  Removed unused test import and made the plate title const. No assertion
  or acceptance changes. Retry analyzer once, then run the phone probe.
- VERIFIED analyzer retry clean. All seven actual-render tests pass with
  exit 0: both delvers at 320x568, 360x640 and 412x892 plus source/pose plate.
  Six scenarios yield 1050 state/grip samples; 360px scenarios retain all
  175 PNG frames each. Max sampled grip error is 2.01e-14 logical pixels.
- VERIFIED displayed low/high enemy damage first changes at sample 28/68
  (360ms after the corresponding tap, consistent with 340ms contact and
  40ms sampling). Incoming HP/guard first changes 440ms into its action.
  The tighter 330/340ms and 430/440ms assertions remain in contact tests.
- Phone probes include forced 20% HP blood-on/off, reduced-motion and 1.3x
  system-text fixtures, partial/full guard. Layout checks cover stat bars,
  dice and enabled Attack/Block controls plus framework exceptions, not all
  visual pixels. Existing HUD text-scale clamp is preserved.
- Iteration 4 complete; final full regression/SFX/integrity and review
  evidence packaging are iteration 5. No physical-device FPS claim.

## Iteration 5/6 — final gates, evidence and incremental PR

- Plan: rerun analyzer, full test suite, native-art generator and SFX against
  source checkpoint ddfc127. Package original #104 and final phone renders,
  observation logs, red controls and integrity evidence with exact source
  identities. Check the live base branch/PR before pushing.
- Open a new review PR stacked on #104's branch; do not close or modify old
  PRs, merge, release or trigger signed builds. CI status must be read back,
  not inferred from local tests. Device/billing and inherited supplemental
  play-session-tool limitations remain explicit.
- VERIFIED final gates on ddfc127: analyzer clean, 1415/1415 tests, native
  art build and SFX exit 0. Existing full-attack headroom remains -0.90 dBTP
  TIGHT; all reachable cascades clear the ceiling.
- Verification-tool correction: managed Git truncates long inventories and
  returns a "Full output saved to:" path. The earlier credential scanner
  read only the displayed excerpts, so its reported 8xx-file coverage was
  incomplete (the independent protected SHA checks were not affected).
  Read the complete saved listing and require every original file to be
  present; rerun before push. Never treat truncated stdout as an inventory.
- Final automated video descriptions still disagree with authored source
  details and contain implausible claims. They are not accepted as human
  aesthetic approval. The PR provides actual final frames/clips and
  independently passing raster/grip/contact evidence without numeric art
  scores or a claim of physical-device review.
- Additive verification-only proof for the previous critique's particle-free
  criterion: isolate the real CombatFigure at its exact 72/104 logical-pixel
  phone sizes, low/high poses, recoil and forced 20%-HP fatigue. Keep source
  and all existing tests untouched; this closes a proof gap, not a new
  implementation iteration.
- VERIFIED particle-free native probe 2/2 and subsequent analyzer clean.
  Curated repository evidence includes both synchronized before/after clips,
  source/pose plates, actual72/104px isolated poses, all six observation
  logs and explicit forced fixtures. Full original renders preserved.
- VERIFIED complete-inventory credential scan passes after truncation fix;
  all262 original tests and all protected sim/dependency/workflow hashes
  match #104. Only documented Kindler/Warden sheets and metadata differ
  among protected assets. Final integrity report includes each SHA-256.
- Re-read live #104: still OPEN/DRAFT at 0df9d51; #102 also open, shipping
  branch unchanged. No remote version of the new branch exists yet.
- All five scoped feature criteria now carry evidence. Root art-reproduction
  and body-acting follow-ups marked passing with new evidence; keystone UI,
  physical-device and Play billing follow-ups left unchanged/false.
- Human aesthetic approval remains NOT VERIFIED. This is an evidence-backed
  two-character implementation ready for review, not a release approval.
