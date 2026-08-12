# Gauntlet — competitive visual/performance upgrade (2026-08-12)

- [~] Finish v0.6.1 release: signed CI/artifacts/GitHub release verified; Play
      Early Access v0.6.1+32 at 100% and in review; publication check pending.
- [x] Benchmark direct competitors from current primary sources: visual
      presentation, tactile feedback, depth, content, retention, pricing,
      mobile constraints, and review pain points.
- [x] Audit current Emberdelve screenshots, render architecture, asset/package
      budget, and existing profile-trace evidence.
- [x] Choose and document a performance-first visual direction (full 3D vs
      2.5D), measurable device/frame/package budgets, and competitor-beating
      differentiators.
- [x] Implement the highest-value presentation upgrade without changing the
      deterministic simulation or weakening low-end Android support.
- [x] Add regression/performance checks, render deterministic screenshots,
      critique them, and iterate.
- [x] Run analyze + full tests + relevant probes.
- [x] Commit, push, and open PR.
- [x] Repair the real-UI play probe's off-screen summary-button handling
      (terminal `run_won` was falsely classified as stuck), then rerun its
      deterministic four-run session without weakening invariant checks.
- [x] Update progress/state docs with verified evidence and next loop.

## Gauntlet — visible build identity (iteration 2)

- [x] Define a deterministic presentation-only build identity from the live
      dice pool; no sim/save/golden change.
- [x] Add pure identity derivation + weapon evolution.
- [x] Add “Pool forged this run” terminal recap with exact pool counts.
- [x] Test every identity/path, short-phone layout, screenshot and perf budget.
- [x] Full verification, commit, PR, CI and merge.

## Gauntlet — face forge + keystones (iteration 3)

- [x] Write the v7 simulation contract and migration/golden plan.
- [x] Independent contract/UX/balance review (multi-agent fan-out attempted;
      workspace returned out-of-credits, so parent review continues directly).
- [x] Run-local custom die IDs, v7 state, one-use Temper command, natural-face
      tracking, and all four runes (Blade, Aegis, Surge, Echo) in the sim.
- [x] Four keystones live in the sim with a real acquisition point (chooser
      screen, one pick per run after the first won fight) and a deliberate
      golden re-anchor recorded old -> new.
- [x] Rest-node temper sheet, rune marks on dice, and combat feedback for the
      effects a die's own number cannot show.
- [x] Seeded balance sweep across difficulties, v6-autosave migration test,
      perf probes, signed build-size measurement, then PR (docs/improvements/
      v7-gates-2026-08-12.md).
- [x] Replace duplicated UI/sim assignment arithmetic with one pure resolver;
      v6 golden and seeded preview parity remain green.
- [x] Implement four first keystones with named events and exact previews.
- [x] Add rest forge UX, rune visuals, keystone pick/inspection UX.
- [x] Rebalance with seeded autoplay; replay/restore/migration/fuzz gates.
- [x] Full presentation/performance/accessibility verification.
- [x] Commit, PR, CI, signed build-size measurement; do not release until the
      mechanics and migration gates are all green.

## Gauntlet — ship v0.7.0 (iteration 9)

- [x] Manual workflow_dispatch signed build of `legacy/dice-builder` at 3a199e5:
      test job + signed job both green.
- [x] Download artifacts, verify signer cert SHA-256 against the pinned upload
      key, record byte sizes and hashes.
- [x] GitHub release v0.7.0 published with APK + AAB attached.
- [ ] Play Console: create 0.7.0 (33) on Early Access, 100% rollout, submit.
      BLOCKED on Google 2-Step Verification (session expired; phone-push
      unreachable, SMS path needs the owner's number + code).
- [ ] Verify publication (console track + public listing) after review clears.
