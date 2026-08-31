# v1.0.0-alpha.12+24 — Totem Squeeze Purge (level fairness)

## For testers

- Three levels had an **unfair totem pocket**: a stationary ember totem
  standing one free tile from a 2-tall (or taller) wall. Get knocked or walk
  into that slot and you trade unavoidable contact damage with nowhere to go.
  All three pockets are gone:
  - **World 1-5**: the thornling pen's 3-tall pillar (x38-40) collapsed to a
    1-tall step — you can hop out now — and the totem moved off the ground
    lane up onto the row-12 platform (45,11), where it pressures the platform
    route instead of body-blocking the corridor.
  - **World 2-4**: the totem at (50,15) now perches on top of the 58-60 wall
    (59,13). It still guards the midsection but can't pin you against the
    wall base.
  - **World 2-5**: the totem stepped back one tile (95,9), leaving a proper
    2-tile landing between it and the 91-92 wall.

## Why

- The committed wipe probe attributed repeat deaths to totem contact damage
  in wall-adjacent slots. w1_l5 was the worst: 10 hits / 2 deaths per seed,
  most of them credited to the totem@44 flush against the 46-48 pillar.
- Pattern generalized: "stationary contact-damage enemy 1 tile from a >=2
  wall" is a pocket the player cannot dodge through. Purged everywhere and
  gated so it can't come back.

## Implementation

- assets/levels/w1_l5.txt: pillar x38-40 row14 removed (1-tall at row 15);
  totem (44,15) -> (45,11).
- assets/levels/w2_l4.txt: totem (50,15) -> (59,13), perched on the 58-60
  stack. (Ground moves to 52 and 55 were tried first and probed WORSE —
  39-42% wipes; the perch keeps pressure without the pocket.)
- assets/levels/w2_l5.txt: totem (94,9) -> (95,9).
- New permanent gate test/totem_squeeze_test.dart (12 tests): for every
  totem, the free gap from its standing row to the nearest >=2-tall wall on
  either side must be >= 2 tiles (scan breaks at drops and 1-tall steps,
  capped at 8; 'B' counts solid). VERIFIED red on the old geometry — flags
  exactly the three shipped pockets — green on the new.
- test/wipe_probe_test.dart is now a **committed, permanently-skipped**
  difficulty probe (`@Skip`, run with
  `flutter test --run-skipped --dart-define=LVL=<id> test/wipe_probe_test.dart`).
  The alpha.11 probe was a deleted temp file and its rebuild drifted; the
  committed bot is the standard reference from now on (held jumps 0.3 s,
  double-jump on stall, 1.2 s backtrack when pinned 4 s, 0.5 s attack
  cadence, 0.7 s back-off on hit, 300 s cap, seeds 7/13/42/99, per-column
  stall + nearest-enemy hit attribution).

## Results

- w1_l5 probe: 10 hits / 2 deaths / 38 s -> **3 hits / 0 deaths / 22 s,
  COMPLETED all 4 seeds**.
- w2_l5 probe: COMPLETED all seeds (~27 s, 1 death, 5 hits).
- w2_l4 probe: still WIPED at 73% (same as baseline) — the pocket is gone
  (fairness fix) but completion is unchanged; the remaining attrition is the
  soot creepers @32/74-76 (2 hits each) + diver@44 + totem stretch @96,
  wiping near col 93. That attrition chain is the next release's target.
- Bug caught during the work: a w2_l4 edit accidentally INSERTED a character
  into row 15, silently shifting every column right of x=52. Repaired
  (row lengths uniform 131 again) and the level-shape suite plus the new
  gate keep it honest.
- Suite 397 passed + 1 skipped (+12). Analyze clean. Look pass phone+desktop
  at all three totem sites.
