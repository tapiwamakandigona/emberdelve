# Checkpoint 10 — v1.0.0-alpha.7: weapon identity

Date: 2026-07-26 · versionCode 19 · tag `v1.0.0-alpha.7`

## Tester-facing changes since alpha.6

- **You can see the weapon you equipped.** The blade was previously baked
  into every player sprite, so all six weapons looked identical in-hand.
  The blade is now split out of all 9 player sheets into a bladeless body +
  a per-weapon overlay (hilt→blade→tip recolor from the grip, thicker heads
  for axe/hammer), animated in lockstep with the body (flip, squash, blink).
  The baked swing crescents inherit the weapon tint, and the shop skin
  preview composites the equipped weapon too.
- **Skypiercer's lunge is real.** Its `specialText` promised a lunge that
  was never implemented — swings now burst ~7px forward (150 px/s bled off
  by ground friction in ~0.09s), wall-clipped by the normal integrator,
  horizontal-only so jump height and level reachability are unchanged, with
  a dash-streak puff.
- **Ember Fang** hits shed ember sparks; **Woodsman's Axe** one-chop wall
  breaks throw bigger rubble.
- **Apple throws are flatter and readable.** Launch angle 40° → 22.5°
  (speed unchanged, flat-ground range ≈ 56px as before), and holding the
  throw button (touch or K/C) shows a faint arc-preview dot trail computed
  from the projectile's own launch params.

## Engineering

- `tool/build_weapon_sprites.py` splits the ivory blade (#fffff2, verified
  blade/swing-FX-only in the pixivan pack) out of the player sheets;
  `build_skins.py` recolors the bladeless bodies. All assets stay CC0-derived
  (PROVENANCE.md updated). Missing overlay sheets degrade to bare hands,
  never a crash.
- Arc preview uses preallocated buffers — zero per-frame allocations.
- Webtest harness gained `?weapon=<id>` and `?apples=N` (harness-only).
- Suite: 363/363 green (356 baseline + 7 in `test/weapon_identity_test.dart`);
  analyze clean. PR: #69.
- Evidence: per-weapon idle/mid-swing screenshots + apple arc preview in
  `docs/ak-parity/evidence/akp4/`.

## Still open

- P-M7 on-device perf pass (needs hardware) — measured 60fps, APK diet,
  cold-start budget.
- P-M10 `v1.0.0-beta.1` to the Play closed-testing track (owner call on
  timing).
