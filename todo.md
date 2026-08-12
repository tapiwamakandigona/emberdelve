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

- [~] Write the v7 simulation contract and migration/golden plan.
- [ ] Implement run-local custom die IDs and one-rune Temper command.
- [ ] Implement four first keystones with named events and exact previews.
- [ ] Add rest forge UX, rune visuals, keystone pick/inspection UX.
- [ ] Rebalance with seeded autoplay; replay/restore/migration/fuzz gates.
- [ ] Full presentation/performance/accessibility verification.
- [ ] Commit, PR, CI, signed build-size measurement; do not release until the
      mechanics and migration gates are all green.
