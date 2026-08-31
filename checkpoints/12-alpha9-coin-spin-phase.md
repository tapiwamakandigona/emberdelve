# v1.0.0-alpha.9+21 — Twinkling Hoard (per-coin spin phase)

## For testers

- Coins no longer spin in lockstep: each coin runs its own phase, so a
  cluster twinkles instead of the whole level snapping to the edge-on frame
  at once (which read as a wall of "candles" in stills).

## Technical

- `CoinEntity.spinPhase`: final, derived from spawn position
  (`(x*0.37 + y*0.23) mod 1`), deterministic, no RNG, stable across
  restarts. Chest-burst coins spawned at one point share a phase but
  scatter immediately.
- `ItemsComponent`: shared coin ticker replaced by a precomputed 4-frame
  `List<Sprite>` + `_coinClock`; pure `coinFrame(clock, phase, n)` picks the
  frame. No per-frame allocations (same perf budget as before).
- Tests: +2 in session_test.dart — phase determinism/range/spread across a
  coin row, and quarter-phases landing on all 4 frames while still
  animating over time. Suite 366/366. Compile-level bind on old code
  (spinPhase/coinFrame don't exist there).
- Visual VERIFIED: two shots 180ms apart on w1_l1 show mixed frames
  coexisting (face/oval/edge-on) instead of synchronized flips.
