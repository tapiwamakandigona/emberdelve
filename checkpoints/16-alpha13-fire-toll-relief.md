# v1.0.0-alpha.13+25 — Fire Toll Relief (w2_l4 completion fix)

## For testers

- **World 2-4 is beatable now.** The measured bot flips from a 73% wipe on
  every seed to COMPLETED on every seed (28 s, 1 death).
- The high road now runs all the way to the totem tower: a new tier
  (row 12, cols 85-94) bridges the chest tower to the 95-99 totem tower,
  exactly like the tiers that already covered every fire pit — the level's
  own sign promised it ("The galleries run in tiers... miners took the
  high road").
- The tower totem stepped back to (98,12), so climbing the tower no longer
  lands you point-blank in its face — you get a 2-tile fighting ledge.
- Two new hearts: one on the ledge before the first fire pit (41,15), one
  after the third pit stretch (101,15).

## Why (decoded from the committed probe)

- The hit log showed 7-8 hits but 3 deaths with hearts bouncing 1 -> 2
  between hits: deaths were never enemy hits. They were fire-pit "tolls" —
  hazard tiles deal 1 damage + eject (AKP-6b), and every life crossed a pit
  at exactly 1 heart. Pit 1 (42-43), pit 2 (66-67), pit 3 (103-105): three
  tolls, three lives, wipe at pct 79. Deterministic on all 4 seeds.
- The attrition chain that drained hearts before each pit: creeper@24
  (hp 9 = 3 starter-sword swings of exchange), diver@44, totem@59 perch,
  creeper@74, totem tower @96.

## Implementation (assets/levels/w2_l4.txt only)

- Row 12: `==========` at cols 85-94 (one-way platform tier); totem
  (96,12) -> (98,12).
- Row 15: `h` at 41 and 101.
- Row-length check passed (131 uniform) — alpha.12's insert-bug lesson.

## Probe evidence

- Before: WIPED t=27s pct=73 deaths=3 hits=8 (all seeds, identical trace).
- Totem shift alone: WIPED pct=79 (point-blank double-tap gone, tolls
  remain). Platform alone: no change (bot is ground-biased).
- With hearts: **COMPLETED t=28s pct=97 deaths=1 hits=7, all 4 seeds.**
- Gates: analyze clean, 397 passed + 1 skipped (totem_squeeze gate green on
  the new geometry; heart design pin covers w2_l4).

## Look pass

- 4/4 PASS in /work/temp/emberwood_shots/a13/ (phone 915×412 + desktop
  1280×800 at site A heart@41/pit 1 and site B platform+totem@98).
- Site-B capture needed the a12c probe-bot tactics + `?weapon=warden_blade`
  harness param; phone needed a 120 ms bot tick (250 ms reacts too slowly).

## Next candidates

- w2 boss approach; w1_l5 polish; on-device perf (P-M7, hardware); Play
  beta (P-M10, owner call).
