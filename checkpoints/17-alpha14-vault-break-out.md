# v1.0.0-alpha.14+26 — Vault Break-Out (w2_l3 progression fix)

## For testers

- **World 2-3's secret vault no longer traps you.** The loot vault under
  the roof at cols 86-92 (coins + secret chest) was breakable on the entry
  side only — break in, grab the loot, and the exit side was bare solid
  wall under a solid roof. Now both side walls are cracked (`B`), matching
  every other vault in the game: chop your way out and keep going.

## Why (probe sweep evidence)

- The alpha.13 full-level sweep found w2_l3 TIMING OUT on every seed:
  pct 76, the bot pinned at col 91 for 177 of 300 s. Attribution showed no
  deaths at that column — it wasn't difficulty, it was geometry: a
  one-way vault. Every other secret vault in both worlds uses the
  `B.X.B` grammar (breakable both sides); this one shipped `B.cXc.#`.

## Implementation

- assets/levels/w2_l3.txt: right vault wall (92,14) and (92,15) `#` -> `B`.
  Row-width uniformity asserted in the edit script (121 uniform).
- New permanent gate `test/secret_vault_test.dart` (12 tests): for every
  secret chest 'X', scan both directions along its standing row; if the
  first barrier within 8 tiles is 2-tall (solid at row and row above — a
  1-tall step is a hop-out), its tile at the chest's row must be 'B'.
  VERIFIED red on the old geometry — flags exactly
  `w2_l3 X@(89,15): solid right wall at (92,15) is not breakable` — and
  green on the new.

## Results

- w2_l3 probe: TIMEOUT t=300s pct=76 (all seeds) -> **COMPLETED t=26s
  pct=98 deaths=1 hits=3 (all seeds)**; col-91 stall drops 177 s -> 1 s.
- Full sweep status after alpha.13+14: w1_l1..l5, w2_l1..l5 all COMPLETED
  by the casual probe; only the two bosses wipe it (telegraph-dodge fights
  — by design for a casual button-masher; owner call whether to tune).
- Gates: analyze clean, 409 passed + 1 skipped.
- Look pass phone+desktop at the vault site (warden_blade harness param,
  a13 shot-script pattern reused as shoot_a14.py).

## Next candidates

- Boss casual-accessibility review (w1_boss/w2_boss wipe the probe at
  pct 42-46 — design intent check first, not an automatic nerf).
- On-device perf (P-M7, hardware); Play beta (P-M10, owner call).
