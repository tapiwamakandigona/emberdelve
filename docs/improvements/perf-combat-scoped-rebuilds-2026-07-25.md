# Combat screen: scoped rebuilds (2026-07-25)

Follow-up to `perf-repaint-and-sfx-2026-07-25.md`. That change killed the
permanent idle repaint storm (combat idle 204 -> 2 render objects painted per
frame). What it did **not** fix is the cost of a real tap: rapid tapping in
combat still painted **95.4** render objects per frame and rebuilt **31.5**
elements per frame.

## Cause

`lib/ui/screens/combat_screen.dart` is a 2,000-line file with a single ~1,000
line `build()` and ~40 `setState` call sites. `setState` has no granularity:
every one of those re-ran the *entire* build — top bar, enemy panel, sprite
stage, dice tray, action zone — and then repainted everything that came out of
it.

The two worst offenders are not user input at all, they are choreography:

- **Combatant flags** (`_playerLunge`, `_enemyFlash`, `_playerKnock`,
  `_enemyDying`, `_playerSquash`, ...). A single attack fires ~20 of these in
  sequence — squash, lunge, contact flash, hit-stop, knockback, release. Each
  one rebuilt and repainted the whole screen, and a rapid tapper stacks these
  sequences on top of each other.
- **Transient overlay layers** (damage pops, contact FX, call-out notes, assign
  ghosts, the boss-kill flash). Each spawn *and* each expiry was a whole-screen
  `setState`, and a busy turn has a dozen of them in flight.

None of that state is read by the top bar, the HP panels, the dice tray or the
action zone. It was rebuilding them anyway.

## Fix

Two `ValueNotifier<int>` ticks on the state class:

| tick | fires on | consumers |
|---|---|---|
| `_choreoTick` | lunge / knock / flash / dying / squash, and the weapon phase + charge derived from them | the two `_combatant()` subtrees on the stage |
| `_fxTick` | pops, contact FX, call-out notes, assign ghosts, boss-kill flash | the overlay layers themselves |

The **fields are unchanged** — every read site still reads a plain bool or
list. Only the notification is scoped: `_choreo(() => ...)` and
`_fxUpdate(() => ...)` mutate the field and bump the tick instead of calling
`setState`. The consuming subtrees sit in `ValueListenableBuilder`s wrapped in
`RepaintBoundary`s, so the lunge transform no longer dirties the rest of the
stage either.

Sim-driven state (HP, dice faces, phase, selection) still goes through
`setState`: those genuinely change most of the screen.

The three overlay groups became nested `Positioned.fill` stacks rather than
loose children of their parent stacks. Coordinates and paint order are
unchanged — the inner stack occupies exactly the parent's box and keeps
`clipBehavior: Clip.none`.

## Measured (tool/perf_probe_test.dart, same probe as the previous change)

| scenario | before | after | |
|---|---|---|---|
| combat idle, render objects painted/frame | 2.0 | 2.0 | unchanged (already fixed) |
| combat, 12 rapid real taps, painted/frame | 95.4 | **48.3** | 2.0x |
| combat, 12 rapid real taps, rebuilt/frame | 31.5 | 31.0 | ~unchanged |

The rebuild count barely moves, and that is expected: the probe's tap storm
hammers the roll/action buttons, and those taps drive **sim** state, which
still goes through the whole-screen `setState`. What this change removes is the
choreography and overlay traffic that used to ride along on top of it — and the
paint cost, which is the expensive half, halves.

Remaining work for a follow-up (deliberately not in this PR): scope the
interaction state (`selected`, `_busy`, `_queued`, `_rerollMode`) and the
sim-driven view model so that a die tap or a roll rebuilds the tray and action
zone only. That is a genuine restructuring of `build()`, not a mechanical
change, and it wants its own review.

## Verification

- VERIFIED: `flutter analyze` clean.
- VERIFIED: `flutter test` 143/143 pass (unchanged).
- VERIFIED: `tool/play_session_test.dart` — 4 bot-guided runs through the real
  UI, 0 problems.
- VERIFIED: `tool/store_screenshots_test.dart` (deterministic, fixed seeds and
  fixed meta) produces **byte-identical** PNGs before and after across all six
  screenshots, including `04-combat-roll.png`. No visual regression in the
  static states it covers.
- NOT VERIFIED: choreography *mid-animation* frames are not pixel-covered by
  any deterministic harness; the play-session bot exercises them behaviourally
  (0 problems) but does not compare them pixel-wise.
- NOT VERIFIED: on-device frame times — no Android device or emulator in the
  build environment.
