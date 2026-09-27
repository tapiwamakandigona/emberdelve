# PROJECT.md — Living Foes (2026-09-24)

Adapted from canonical subagent-toolkit v3.0.1 templates/PROJECT.md.
Scoped state for the second half of the owner's 2026-09-24 request (Viktor
app, Tapiwa): *"improve the models and animations to be more enjoyable"*,
plus a test APK. Stacked on the exact-kill Clean Cut commit in PR #108
(`docs/exact-kill-clean-cut-2026-09-24/`).

## Goal

Make the 42 enemies feel alive with presentation-only changes: they were the
least-animated layer of combat after the roster-sep18 pass articulated all 22
delvers (Sept-13 critique, P2: "then a small enemy set").

## What was wrong (VERIFIED from source + real-render captures at `741b439`)

- Every foe idled with the same 2px bob; floaters stood on the floor.
- Deaths faded and sank; the body never broke apart.
- 31 of 42 enemy sheets carry an authored 4-frame `run` row that combat never
  played — lunges slid the idle pose across the stage.
- Defect: the enemy wind-up tint (`foregroundDecoration`, srcATop) blended
  over the whole combatant box, so every enemy attack showed a translucent red
  rectangle over the stage around the foe.

## What shipped (one verified commit each)

| # | Commit | Change |
|---|---|---|
| F2 | `5c4a2d4` | **Ashfall** — the slain foe crumbles into its own art pixels inside the unchanged 700 ms death beat (`lib/ui/ashfall.dart`). |
| F3 | `ad51b5e` | **Charging foes** — the lunge plays the authored run row at 14 fps. |
| F4 | `508960b` | **Living idles** — hover / heave / scuttle personalities per body. |
| F5 | `ed0f710` | **Wind-up heat fix** — the tint heats the body's pixels, not a box. |

## Standing decisions

- Presentation only. `lib/sim/`, saves, purchases, dependencies, workflows,
  version, `android/` and `assets/` are unchanged — VERIFIED by
  `git diff --stat 741b439 -- lib/sim pubspec.yaml pubspec.lock android .github assets` (empty).
- No timing change: `_deathTime`, strike windup/travel/contact and the
  contact timeline are untouched; Ashfall runs inside the existing beat.
- Zero new assets. Enemy sheets are integer-upscaled art (sprite_meta
  `scale`, uniform blocks verified for all 42), so each block is an art pixel.
- Reduce motion keeps the legacy death fade; the idle life ticker still stops.
- Tests are additive only. No inherited test or check was edited.
- Every new test was mutation-checked: removing the wiring (or the reduce
  gate) turns it red; the wind-up test is red on the old code.
- Source PR only: no merge, release, version bump, signing dispatch or Play
  action. Aesthetic approval and physical-device FPS remain owner/device gates.

## Constraints

- Single executor, plan → act → verify → commit, one feature per iteration.
  Four feature iterations + one evidence iteration; no no-diff iterations.
- Headless Flutter captures (40 ms simulated steps) are review evidence, not
  device frame timing.

## Current phase

All four scoped features VERIFIED and committed; full gates green at
`ed0f710` (analyzer clean, 1553/1553 tests, art check pass, SFX clear).
Evidence and reproduction steps: `README.md`. Owner review via test APK.
