# Perf pass 4 — per-field controller notifiers + layered SFX voices (v0.3.15+20)

Date: 2026-07-25 · Branch `perf/controller-notifiers` · Base `0680f20` (v0.3.14+19)

Passes 1–3 scoped rebuilds *inside* the screens and hit a wall: the last one
measured the combat button storm at 100.3 painted render objects per frame and
could not move it, because `GameController` is a single `ChangeNotifier` and
`GameRoot` rebuilt the whole active screen on every `notifyListeners()`. This
pass removes that ceiling — partially — and fixes an audio side effect the
low-latency SFX rewrite introduced in v0.3.12.

## What changed

**1. `GameController` publishes per-field ticks.** `phaseTick`, `turnTick`,
`runTick`, `enemyTick`, `playerVitalsTick` (hp/max_hp/block), `diceTick` (pool,
faces, assignment, rerolls), `mapTick`, `metaTick`. Each fires only when the
field's value actually changed, detected by hashing it with the sim's own
deterministic hasher (`hashValue`) after every notification.

The detection hangs off an override of `notifyListeners()`, so *every* existing
mutation path feeds the ticks and there is no second place to remember to bump.
A tick is never a substitute for reading state: consumers still read `state()`
when they rebuild.

**2. `GameRoot` hands the combat screen back as one stable widget instance.**
Returning the identical widget makes `Element.updateChild` short-circuit, so a
sim command no longer re-runs `CombatScreen.build()` top to bottom. Every other
screen is still wrapped in `AnimatedBuilder(animation: c)` — i.e. exactly the
old whole-screen rebuild. Opting a screen in is a per-screen decision, made
after measuring it.

**3. The combat HUD is split into five listening bands.** Top bar → `runTick`;
enemy panel → `enemyTick` + `turnTick`; stage → `enemyTick` + `runTick`; player
HP → `playerVitalsTick`; dice tray and action zone → `diceTick` + the screen's
own input tick. Each band recomputes a `_Hud` snapshot from live state when it
rebuilds, so no section can render from another section's stale snapshot (the
assign preview on the stage explicitly re-reads live state for this reason).

**4. SFX voices layer instead of cutting off.** v0.3.12 replaced the six-player
round-robin with one resident low-latency player per sound id, which killed the
audio hitch but made a retrigger *restart* the sound. Ids that genuinely
overlap in play now hold 2–3 resident voices (`AudioService.sfxVoices`) and each
trigger takes an idle one: `die_assign` ×3, `enemy_hit` ×3, `coin` ×3,
`dice_roll`/`reroll`/`player_hit`/`block`/`ember_gain`/`whoosh` ×2. UI clicks and
stings stay single-voice — a click that layers sounds broken. An idle voice also
skips the `stop()` platform hop.

## Measured — painted render objects per frame (probe unchanged, both sides)

| Scenario | v0.3.14 (`0680f20`) | v0.3.15 | Δ |
|---|---|---|---|
| combat, 12 rapid BUTTON taps | 100.3 | **87.7** | −12.6% |
| combat, 12 rapid DIE taps | 20.0 | 20.1 | ~0 |
| combat idle | 2.0 | 2.0 | — |
| title idle / tap storm | 3.0 / 38.8 | 3.0 / 38.8 | — |
| reward flip | 52.9 | 52.7 | ~0 |
| map idle / drag | 19.7 / 54.5 | 19.7 / 54.5 | — |

Elements rebuilt per frame: button storm 19.9 → 19.3; **die storm 14.1 → 16.1
(worse)**. The extra rebuilds are band builders re-running with no paint
consequence (die-storm paints are flat), so this ships as a knowingly accepted
trade, not a hidden regression.

## The honest part: which half of the change did the work

Measured in two steps on the same code:

- per-field scoping **without** a repaint boundary at the band: button storm
  **100.3** — byte-for-byte the same 6020 paints as the baseline, i.e. the
  scoping alone bought *nothing*;
- the same scoping **with** a boundary per band: **87.7**.

So the win is the combination. Scoping decides *which* sections rebuild; the
band boundary is what stops a rebuilt section from dragging its neighbours'
pixels along. v0.3.14 already had boundaries inside the section bodies and
still measured 100.3, because a whole-screen rebuild dirties every section
anyway. Neither half is useful alone — worth remembering before "just add a
RepaintBoundary" is proposed again.

The remaining 87.7 is largely genuine choreography: over 60 frames the storm
rebuilt 206 `TweenAnimationBuilder`s (damage pops, assign ghosts) and painted
419 paragraphs. The button storm issues sim commands that change the dice, the
player's vitals *and* the enemy, so most bands legitimately rebuild.

## Verification

- `flutter analyze`: clean.
- `flutter test`: **152/152** (143 existing + 9 new `test/audio_voices_test.dart`).
- `tool/store_screenshots_test.dart` (the deterministic harness): all 6 PNGs
  **byte-identical** to `0680f20`, combat screen included — the refactor is not
  visible on screen.
- `tool/play_session_test.dart`: green (smoke only; it is not deterministic).
- Probe run before and after in separate worktrees with the identical probe file.

## Not verified

- **On-device frame times.** No device or emulator exists in this environment;
  every number above is framework-level paint/rebuild accounting, and the
  transfer to real hardware is inferred, not measured.
- **Audio layering by ear.** The voice-pool logic is unit-tested
  (`AudioService.pickVoice`), but nobody has heard it. If a layered dice cascade
  sounds cluttered, lower the counts in `AudioService.sfxVoices` — it is one
  table, no other code changes.
- Mid-choreography frames are not pixel-covered by any deterministic harness.
