# Emberdelve v0.3.1 — Playtest Fix Plan

Source: Viktor's hands-on playtest review of v0.3.0 (2026-07-23) — two full runs to
death, daily delve, rest/forge, events, an elite, all menus, plus APK/audio/code
audit. This plan turns every finding into a concrete, verifiable fix. Executed
solo (no subagents) on branch `fix/v0.3.1-playtest-fixes`, merged to main when
the acceptance gate passes.

## Priorities

- **P1** — bugs that make the game feel broken or will fail Play review
- **P2** — trust/readability issues and the early-game balance spike
- **P3** — small features the review flagged as "before closed test"

## P1 — bugs

### F1 · Phantom MAX glow / dead die (review bug #1)
Assigned dice keep the gold "MAX" ring/glow while their taps are disabled — the
die looks *more* active than free dice and silently ignores input.
- `lib/ui/widgets.dart` `DieChip._face`: suppress the maxed/selected ring, glow
  and gold "MAX" label whenever `assigned` is true (keep the 0.35 fade).
- Tap feedback: `DieChip` no longer swallows taps itself; `CombatScreen` passes
  an `onTap` for assigned dice that flashes an "ALREADY ASSIGNED" call-out.

### F2 · Dropped input during choreography (review bug #2)
The `_busy` lock (~0.8–1s per swing) discards taps with no queue and no feedback.
- Die *selection* is pure UI state — allow it while `_busy` (no sim mutation).
- One-slot action queue: Attack/Block/End-turn tapped while `_busy` are stored
  (latest wins) and executed when the current choreography finishes, guarded on
  the encounter still running. No more silently eaten turns.

### F3 · No app-lifecycle audio handling (review bug #5, Play-review killer)
Music keeps playing after Home/lock/calls.
- `AudioService.pauseAll()` / `resumeAll()` (music + ambience players).
- `EmberdelveApp` becomes stateful with a `WidgetsBindingObserver`:
  paused/inactive/hidden → `pauseAll()`, resumed → `resumeAll()`.

### F4 · Event button text overflow (review bug #3)
"TRADE (LOSE A RANDOM DIE, GAIN A RANDO…" clips at 412 px.
- `EmberButton`: label wrapped in `Flexible` (center-aligned, soft-wrap, no
  ellipsis) so long labels wrap to a second line instead of clipping.

## P2 — trust, readability, balance

### F5 · Events resolve with zero feedback (review bug #4)
- `GameController._handleFlash`: when a batch contains `event_resolved`, compose
  a result toast from the concrete effect events (`die_lost`, `die_gained`,
  `gold_gained/spent`, `hp_lost`, `healed`, `max_hp_changed`, `embers_gained`,
  `relic_gained`), e.g. "Lost Ember Die → gained Flint Shard · +20 gold".

### F6 · Unreadable attack_block intent badge (review bug #6)
- `_IntentBadge`: `attack_block` renders as two chips — ⚔ amount (danger color)
  and 🛡 block (block color) — instead of "⚡15/14".

### F7 · Layer-1 balance spike (review: first-fight coin-flip)
First fights (map layer 2) can serve 29–36 HP enemies cycling 15–23 damage vs a
30 HP / 3×d6 start.
- "Early mercy", deterministic, sim-side: `combatBegin` gains a `layer` param
  (regular fights only, pre-ascension): layer ≤ 2 → HP capped at 26 and intent
  amounts −4 (min 1); layer 3 → intent amounts −2 (min 1). Elites/boss and
  layers 4+ unchanged; late-band identity untouched.
- Gate: 200-seed autoplay win rate stays inside the fair band (20–80%) and does
  not *drop*; sim tests assert the mercy numbers.

### F8 · Fightless deaths pay 0 embers (breaks the fair-death pillar)
- `runPost` loss branch: `embers = max(embers ~/ 2, 5 + layer reached)` — every
  death banks something, exactly where retention matters most.

### F9 · "REST — HEAL 30%" offered at full HP
- `RestScreen`: at full HP the button is disabled and reads "Fully rested";
  forge list unaffected.

## P3 — missing pieces (review "before closed test" list)

### F10 · In-run pause menu
No way to reach settings (volume!) or leave a run mid-delve.
- Gear icon in `_TopBar` → ember-styled modal: Resume · Settings (existing
  screen) · Abandon run (danger, explicit confirm; discards the run save
  without banking — abandoning is voluntary, unlike death).

### F11 · Minimal onboarding
"Boons", "pips", "forge", "risky reroll" are never explained.
- 3-step dismissible overlay on the first-ever combat (flag persisted in
  `MetaState.tutorialSeen`): (1) enemy intent is always shown, (2) tap a die →
  Attack/Block, (3) matching faces = combos, straight = free reroll. Skippable,
  never repeats.

### F12 · Haptics
- `Haptics` helper over `HapticFeedback` with an on/off toggle in Settings
  (persisted with audio settings): light on roll/assign, medium on hits, heavy
  on death/victory.

### F13 · Inaudible block SFX
- Remaster `assets/audio/sfx/block.ogg` with headroom-safe gain so blocks read
  next to hits; note the processing in `PROVENANCE.md`.

### F14 · Doc drift + version
- `PROJECT.md`: drop the "built with Defold" opener, stop calling the repo
  private. Bump `pubspec.yaml` to `0.3.1+4`.

## Explicitly out of scope for v0.3.1
IAP full-unlock (R8), GPGS cloud save (M4), attack/death sprite frames,
low-HP audio danger layer, new content. Tracked for v0.4.0.

## Acceptance gate (all must pass before merge)
1. `flutter analyze` clean (fatal warnings).
2. `flutter test` green, including new sim tests for F7/F8.
3. `dart run bin/autoplay.dart 200`: win rate in 20–80%, 0 invalids, twin
   determinism check passes.
4. Hands-on web smoke test (playtest harness): assigned die shows no glow and
   flashes feedback; rapid tray taps during a swing are not lost; event choice
   shows a result toast; attack_block intent shows two chips; rest at full HP
   disabled; pause menu opens mid-combat and Settings works; tutorial shows
   once and never again.
5. Merge to main → CI builds the signed release (cert pin check).
