# v1.0.0-alpha.10+22 — Unstuck Steps (w1_l4 chute-trap fix)

## For testers

- World 1-4 "Cinder Steps": the narrow slots between the staircase towers
  are gone. Slipping off a tower used to drop you into a one-tile-wide pit
  that was nearly impossible to jump out of (the second slot literally
  required more jump than the double jump has). The towers now form clean
  ascending steps.

## How it was found

- New playthrough probe: the fairness-test casual bot upgraded with held
  jumps (0.3 s), double-jump on stall, and 1.2 s backtracking after 4 s
  pinned at one column, run for up to 300 s on 4 seeds across all 12 levels
  with per-column stall telemetry. w1_l4 stalled 291 s at col 53 on every
  seed; every other non-boss level cleared or wiped fairly. (w2_l3's
  "timeout" is the memoryless bot re-entering the dead-end secret chamber
  at cols 87-91 forever — verified not a player softlock: the chamber floor
  is level with the outside floor and the broken wall stays open.)

## Fix + gate

- assets/levels/w1_l4.txt: filled col 52 (rows 14-15) and col 59 (rows
  12-15) so the towers merge into a staircase; every step is a rise-2 jump.
  No spawns touched; coins/relic/chest/feather all still reachable
  (reachability suite green).
- New permanent gate test/chute_trap_test.dart: no standable cell in any
  level may sit at the bottom of a 1-wide chute >= 3 tiles deep ('#' and
  'B' both count as walls — breakables open into chutes). VERIFIED fails on
  the old w1_l4 (col 59 depth 4), passes on all 12 levels now.
- Suite: 378/378 (12 new gate tests). Analyze clean. Probe rerun: w1_l4
  CLEAR t=21 s on all 4 seeds. Look pass: phone + desktop shots at the
  steps — autotiled grass caps, reads as intended geometry.
