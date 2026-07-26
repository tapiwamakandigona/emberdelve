# Checkpoint 09 — v1.0.0-alpha.6: World 2 re-authored, AKP-3 juice, Kiln Golem's own fight

Date: 2026-07-26 · versionCode 18 · tag `v1.0.0-alpha.6`

## Tester-facing changes since alpha.5

- **Secret vaults are enterable again (both worlds).** alpha.5 shipped
  sky-vault interiors/doors 1 tile (16px) tall against a ~20px player body —
  every sky-vault secret in w1_l1–l5 was physically uncollectable and the
  "all chests" medal unattainable on those levels. Interiors and doors are
  now 2 tiles; approach platforms re-aligned; three more geometry defects
  fixed (w1_l1 upper-route rise, w1_l3/l4/l5 vault steps, w2_l5 chain-death
  trench).
- **World 2 "Cinder Depths" fully re-authored** in the design DSL with
  World 1's rules (teaching runways, tiered routes, campfires designed in,
  secrets behind cracked walls): Ashen Gate's sealed gatehouse, the Ember
  Vault treasury, Soot Falls' stepped basins, the Magma Gallery colonnade,
  Kiln Works' rising work floors. Enemy rosters and introduction order
  preserved.
- **The Kiln Golem is its own fight** (shipped in #61, first release here):
  ember mortars igniting fire patches, marching vent walls to jump, a
  3-ember enraged volley — no longer a Grove Golem retint.
- **Combat juice (AKP-3):** landing squash-and-stretch, weapon-tinted
  procedural swing arcs (finisher reads thicker), floating damage numbers
  (crits bigger + golden, hard-capped at 24 live), camera shake retuned to
  fire on getting hit / crits / finishers instead of every enemy hit.

## Engineering

- New reachability contract: `tool/reachability_lint.py` (design-time) +
  `test/reachability_test.dart` (CI) — jump-physics flood fill proving every
  chest/secret/feather/coin/campfire/exit in every shipped level is
  reachable. Fails alpha.5's levels as shipped; passes after the fixes.
- `tool/survivability_sweep.dart` salvaged from #62: casual-bot fairness
  measurement across shipped levels (not run by CI).
- Suite: 356/356 green; analyze clean. PRs: #61, #64, #65, #66.

## Still open

- P-M7 on-device perf pass (needs hardware) — includes AKP-3's side-by-side
  capture DoD.
- P-M10 `v1.0.0-beta.1` to the Play closed-testing track (owner call on
  timing).
- AKP-4 weapon identity (natural next step on top of #65's swing arcs).
