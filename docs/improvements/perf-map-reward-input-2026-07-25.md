# Perf pass 3 — map glow, reward flip, input scoping, screen shake (v0.3.14+19)

Branch `perf/scoped-state`. Third and (for the screens the player actually
sits on) final pass of the 2026-07-25 performance work, after
`perf/repaint-and-sfx` (v0.3.12) and `perf/combat-scoped-rebuilds` (v0.3.13).

## 0. Harness correction — read this before comparing to older numbers

`tool/perf_probe_test.dart` boots a **fresh** save, so the first-fight tutorial
overlay (`_TutorialOverlay`, shown while `!meta.tutorialSeen`) was on screen for
every combat scenario. Two consequences:

- its full-screen scrim swallowed the "12 rapid taps" gestures — they never
  reached the Roll / Reroll / End-turn buttons they claimed to be hammering;
- its own layers were counted in the combat paint totals.

The probe now calls `c.markTutorialSeen()` right after boot. **The combat
tap-storm figures quoted for v0.3.12 and v0.3.13 therefore measured a different
thing than their label says.** Every number below was re-measured on both sides
with the corrected harness: baseline = `legacy/dice-builder` @ `c5b8177`
(v0.3.13+18) in a separate worktree, same probe file, same machine.

Two scenarios were also added, because the two screens with the worst numbers
in the game had never been measured at all:
`combat_die_tap_storm_12` (pure-UI die selection), `reward_flip_90f`,
`map_idle_60f`, `map_drag_60f`.

## 1. Measured (render objects painted per frame / elements rebuilt per frame)

| Scenario | v0.3.13 paints | v0.3.14 paints | v0.3.13 rebuilds | v0.3.14 rebuilds |
|---|---|---|---|---|
| Map, idle | 221.0 | **19.7** (11.2x) | 40.1 | 0.1 |
| Map, dragging the delve | 221.0 | **54.5** (4.1x) | 40.0 | 0.0 |
| Combat, 12 rapid die taps | 151.9 | **20.0** (7.6x) | 29.2 | 14.1 |
| Combat, 12 rapid button taps | 169.9 | **100.3** (1.7x) | 20.9 | 19.9 |
| Reward flip ceremony | 86.4 | **52.9** (1.6x) | 8.7 | 4.0 |
| Title, idle | 3.0 | 3.0 | 0.0 | 0.0 |
| Title, 12 rapid taps | 38.8 | 38.8 | 3.3 | 3.3 |
| Combat, idle | 2.0 | 2.0 | 0.0 | 0.0 |

## 2. What was wrong and what changed

### Map screen — the worst screen in the game (221 painted objects per idle frame)

Every medallion sat inside `AnimatedBuilder(animation: _pulse)`, so the shared
1.6s glow controller rebuilt the `CustomPaint`, the node icon `Image` and their
boxes for **all ~20 nodes, every frame** — inside a `SingleChildScrollView`,
whose viewport is the nearest repaint boundary, so the whole delve repainted
with them. Unreachable nodes (no halo at all) paid the same price.

Fix: `_MedallionPainter` now takes `Animation<double>? pulse` and passes it to
`super(repaint:)`, reading `pulse.value` inside `paint`; unreachable nodes pass
`null` and never listen. Each medallion is wrapped in a `RepaintBoundary`.
Zero widget rebuilds remain on an idle map.

### Reward flip — the face was re-laid-out on every flip frame

`_FlipCard` built `_face()` / `_back()` **inside** its `AnimatedBuilder`, so all
~26 frames of each card's turn re-ran a `FittedBox` over a column of text runs,
three cards at a time. Both sides are now built once per parent build (identical
widget instances, so the framework skips their subtrees) and each is its own
`RepaintBoundary`, letting the rotation re-composite a cached layer.

### Combat — pure input state no longer rebuilds the HUD

Added a third scoped tick next to `_choreoTick` / `_fxTick`:

- `_uiTick` — die selection, the `_busy` input lock, reroll mode + its
  multi-select, and the verb-button arrival pulses.

Consumers wrapped in `ValueListenableBuilder` + `RepaintBoundary`: the dice
tray, the action zone, the assignment-preview badge (its text is now computed
by a callback inside that builder), and the how-to-play button (it reads
`_busy`). Eleven `setState` sites that touch only those fields became `_ui()`.
A die tap no longer rebuilds the top bar, enemy panel, HP bars or sprite stage.

### Screen shake was repainting the entire screen

`ShakeBox` translates the whole screen on every hit. With no boundary under the
transform, all ~150 render objects repainted on each of its ~14 frames. Its
child is now a `RepaintBoundary`, so the shake re-composites one cached layer.
This is also why the reward screen got faster — it is under the same box.

### Section repaint boundaries in combat

The combat HUD is one `Column` under a single boundary, so *any* animating
pixel — an HP bar tweening, a sprite frame, a lunge — repainted every other
section's text and boxes (~17 `RenderParagraph`s per frame during a swing).
`_TopBar`, the enemy panel, the stage and the player HP bar each got a
`RepaintBoundary`. Measured on its own: 151.5 -> 100.3 painted/frame on the
button storm, 30.9 -> 20.0 on the die-tap storm.

Tried and **reverted** because it measured nothing: a `RepaintBoundary` per tray
chip (162.9 -> 162.8).

## 3. Why the button storm only improves 1.7x

Those taps issue sim commands. `GameController` is a `ChangeNotifier` and
`GameRoot` rebuilds the active screen on every `notifyListeners()`, so the whole
combat screen still rebuilds per command by design — the win there comes from
paint scoping, not rebuild scoping. Cutting that further means a view-model
split (per-field notifiers on the controller) and is not attempted here.

## 4. Verification

- `flutter analyze` clean.
- 143/143 tests pass.
- `tool/store_screenshots_test.dart` (deterministic): all 6 PNGs byte-identical
  to the same harness run on `c5b8177`. Note the committed PNGs in
  `docs/store/screenshots/` differ from what this toolchain regenerates on both
  sides — pre-existing drift, not caused by this branch, so they are left
  untouched.
- NOT VERIFIED: on-device frame times (no device or emulator in the sandbox);
  mid-choreography frames are not pixel-covered by any deterministic harness.
