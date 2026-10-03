# progress.md — append-only log (segment 2)

Segment 1 (2026-07-23 to 2026-10-03 09:45 UTC, 502,217 bytes) was moved
verbatim to `archive/progress-segment-1.md` because it had grown far past the
64 KiB boot budget (subagent-toolkit `HARNESS.md`: rotate past 64 KB, verbatim,
with a SHA-256 link). Its SHA-256 is
`d1b232abfd6cb06bbae45b9ba6010bee1534e7ef7477380ce8f02352267ac8e0`.
Older references to "progress.md" in code comments, tests and docs mean that
archive. Never edit archived entries; append new ones here.

## 2026-10-03 — 0.186.0 "Clear Choices" published on GitHub

- VERIFIED: the read-only review of #125/#126 passed with no blocking
  findings. The signed CI artifacts of run 37114318037 checked out
  independently (package, versions 219/1219/2219/4219 and AAB 219, signer
  pin, not debuggable). v0.186.0 is published as the latest release, tagged
  at the built commit `2a553ad`, and an unauthenticated asset download
  matched its SHA-256. Details and every hash are in
  `docs/release-0.186.0/progress.md` (iteration 2).
- Play is on hold by my decision of 2026-10-03 14:33 UTC. No Play call was
  made.
- Deferred minor review findings for the next pass:
  `test/victory_moment_test.dart:253` (silent skip when the hero keys are
  missing) and `heroEnvelope` measured on the kindler only.

## 2026-10-03 18:06 UTC — 0.186.0 review findings: the victory banner and every delver

Feature `REVIEW186-VICTORY-EVERY-DELVER`, branch
`fix/victory-every-delver-20261003`. No version bump, build or release.

- VERIFIED: the delver lookup in `test/victory_moment_test.dart` now fails
  the test when the figure (`figure-<id>` or `hero-<id>`) or the
  `combat-weapon` is missing. With those production keys renamed for one
  run (then reverted), the old test still passed (`00:02 +1: All tests
  passed!`) and the new one failed: `no box for the delver kindler:
  figure-kindler missing, hero-kindler missing, combat-weapon missing`.
- VERIFIED: the victory moment now also runs for the other 21 playable
  delvers at 320x568, 360x800 and 412x915, in normal and reduced motion
  (126 new cases). Against the old placement two failed (`00:44 +130 -2:
  Some tests failed.`):
  - `gambler 320x568 +600 ms: banner (101.5, 174.0, 109.2x22.9) on the
    delver (36.4, 117.2, 75.2x75.2)`
  - `gambler 320x568 reduced +600 ms: banner (97.4, 171.5, 127.1x26.6) on
    the delver (38.8, 110.1, 77.5x77.5)`
  At 320x568 the gambler's rolled stage is 40 dp tall, not 86 as for the
  others, so no area fitted and the banner fell back to the stage centre.
- Fix, presentation only: when no area fits, `VictoryBeat.place` tries the
  band beside the delver without the vertical inset before the centre.
  Green: `00:45 +143: All tests passed!` (victory_moment and victory_beat
  tests). The 150x40 "nowhere clear" case still takes the centre.
- VERIFIED, measured on all 22 delvers at the three sizes on the checked
  frames: the figure+weapon box spans x −0.104..1.284 heroH and rises at
  most 0.5 dp past the envelope's top. The farthest reach (gambler,
  ascetic, cutler, glover) is 0.114 heroH past its right edge: 8.2 dp at
  72 dp, 11.9 dp at 104 dp, inside the 4 dp gap plus the banner's 8 dp
  padding. Recorded in the `heroEnvelope` doc comment; `stepBack` unchanged.
- Seed 6 rolls no opening call-out for runesmith, bearer, cutler, stoker
  and miller, so the new cases don't require one. The six kindler cases
  keep every original assertion; `toFight` gained an optional `character`
  (default `kindler`).
- Gate, VERIFIED: `flutter analyze` "No issues found!"; full `flutter test`
  "02:25 +1798: All tests passed!"; `python3 tool/sfx_headroom.py` "Every
  reachable cascade clears the ceiling."; `python3 tool/art/build_delvers.py
  --check` `"check": "pass"`.
- ASSUMED: how it looks on a phone. Nothing was run on a device.
