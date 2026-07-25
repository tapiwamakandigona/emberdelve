# Remaining work after v0.3.15 — what is still broken, and what it would take

Written 2026-07-25, after four performance releases in one day (v0.3.12 → v0.3.15) and the
audio-clipping fix. This is the honest list of what is **not** fixed. Nothing here is a
code change; this file exists so the open items live in the repo instead of in a chat log.

Every item is labelled:

- **VERIFIED** — measured or read in this repo, with the evidence named.
- **ASSUMED** — a judgement about cause or remedy that has not been proven yet.

Baseline for all numbers: `tool/perf_probe_test.dart`, paints-per-frame, measured on
`0680f20` (v0.3.14) versus `a1cd170` (v0.3.15) in separate worktrees on the same machine.

---

## 1. No number in this repo comes from real hardware — VERIFIED gap

Every performance figure in v0.3.12–v0.3.15, including the ones in the release notes, is a
**widget-test paint and rebuild count**, not a frame time. There is no device or emulator in
CI, so nothing has ever been measured at 60 Hz on an actual phone.

Paint counts are a good proxy and the direction of travel is real, but the original report
was "it feels laggy", and that is a frame-time claim. It remains unproven in both
directions: it is possible the remaining stutter is GPU raster or shader compilation, which
paint counts cannot see at all.

What would close it:

- `flutter run --profile` on the target phone with `--trace-startup`, then read the
  timeline for jank frames and raster-vs-UI thread split. Needs the phone, ~20 minutes.
- Or a CI emulator / Firebase Test Lab job that runs an integration-test driver and reports
  `frameBuildTime` / `frameRasterizerTime` percentiles. Turns "feels laggy" into a number
  that regresses loudly. Half a day of setup, then free forever.
- Shader jank specifically: check whether the release build is shipping precompiled shader
  bundles (`--bundle-sky-shader-path` era tooling is gone in 3.32; Impeller is default, so
  this may already be a non-issue — **ASSUMED**, unverified).

Priority: highest. Everything else in this list is optimisation without a measurement that
matches the complaint.

## 2. `tool/play_session_test.dart` is not deterministic — VERIFIED

The harness seeds its own action picks (`Random(42)`, line 154), but `GameController.startRun`
derives the run seed from the clock:

```dart
// lib/game/controller.dart:244
final s = seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
```

So dice rolls, loot and boss choice differ on every execution. Two consequences:

- A crash that only occurs on some seeds appears and disappears between runs, and cannot be
  reproduced from the failure output.
- The 407-line file contains **one** `expect()`. It is a crash-catcher and screenshot
  generator, not a regression test — it cannot fail on wrong behaviour, only on an
  exception or the stuck-detector.

What would close it:

- Accept a seed override (env var `EMBER_SESSION_SEED`, default fixed) and pass it to
  `startRun(seed:)`. Then a failure is a reproducible command line.
- Add invariant assertions the loop can check on every step: HP never negative or above max,
  ember never negative, assigned dice ⊆ rolled dice, phase transitions only along the legal
  graph, run ends in exactly one of victory/death. That converts the harness into a fuzz
  test with a real oracle.
- Run it over N seeds in CI (`for s in 1..25`) as a nightly job, not per-PR — it is slow.

Cost: a few hours. This is the highest-value *correctness* item in the list.

## 3. Combat button storm is choreography-bound at 87.7 — VERIFIED cause, ASSUMED remedy

v0.3.15 took the button storm from 100.3 to 87.7 paints/frame by splitting the controller
into per-field notifiers and giving each combat band its own `RepaintBoundary`. The state
plumbing is now about as tight as it gets: the remaining paints are tweens and sprite frames
that the design asks for — a verb tap legitimately animates the stage.

Getting materially below ~85 therefore means changing the **animation design**, not the
architecture: shorter or fewer overlapping tweens, fewer simultaneously animating layers
during a hit, or moving the sprite stage to a single `CustomPainter` that repaints one layer
instead of composing several. That is a feel decision, so it should not be made silently in
a perf PR — it needs the owner's call on what the hit is allowed to look like.

## 4. Die-tap rebuilds regressed 14.1 → 16.1 — VERIFIED, accepted

Die selection now bumps two notifier ticks (`dice` and the vitals/preview slice) where the
old single scoped `_uiTick` bumped one, so widget rebuilds per frame rose ~14%. Paints
stayed flat (20.0 → 20.1), and paints are the expensive half, so v0.3.15 shipped with the
regression rather than chasing it.

If it is worth clawing back: coalesce the ticks that always change together into one
notifier, or debounce assignment-preview recomputation to the frame boundary. Small,
low-risk, low-reward — listed for completeness, not recommended.

## 5. Map drag (54.5) and title tap storm (38.8) are the largest un-attacked numbers — VERIFIED

After the button storm, these are the top two. Neither has had a dedicated pass:

- **Map drag, 54.5.** v0.3.14 fixed the idle map (221 → 19.7) by moving the glow animation
  into `super(repaint:)` and boundarying each medallion. Dragging still repaints the
  viewport contents. Likely remaining cost is the parchment/background layer repainting with
  the scroll rather than being cached — **ASSUMED**, not profiled.
- **Title tap storm, 38.8.** Untouched all day. `ScaleTransition` rebuilds 63× in the probe
  (see `top_rebuilt` in the metrics JSON) — the menu buttons animate their own scale on
  press and drag the title art's `CustomPaint` along with them.

Both are cheap to investigate with the existing probe. Neither is where the complaint was
(combat), which is why they are still open.

## 6. Layered SFX is verified by test, not by ear — needs the owner

The voice pool (2–3 round-robin players per hot sound) is covered by 9 unit tests on the
pure `pickVoice` function, and it provably ends the `stop()`-on-replay clipping. What no
test can tell us is whether a four-die cascade now sounds *good* or sounds cluttered, and
whether three simultaneous `coin` voices are too loud in aggregate.

If it sounds busy, the fix is one edit to the `sfxVoices` table in
`lib/audio/audio_service.dart` (drop a count from 3 to 2, or add a small per-voice gain
trim). No architecture change needed.

## 7. `combat_screen.dart` is 2,344 lines — VERIFIED maintainability debt

The band split improved rebuild behaviour but made the file *longer*, not shorter. The five
band builders, the `_Hud` view-model and the tray/action-zone widgets are all still in one
file. Extracting them into `lib/ui/combat/` (one file per band, view-model beside them) is
mechanical, behaviour-preserving, and testable against the byte-identical store-screenshot
gate. Worth doing before the next combat feature lands, not urgent by itself.

## 8. Cross-branch note: `main` is in better shape than this branch's backlog implied

For the record, so nobody re-scopes work that exists: `main` (the v2 platformer) already has
`docs/perf.md` with a P-M7 allocation audit of `Session.update` and the Flame render layer,
plus `test/frame_stats_test.dart` and `test/session_bench_test.dart`, and an in-game
`perf_overlay.dart`. It does **not** need a first perf pass. Notably, `docs/perf.md` marks
real-hardware items **OPEN** for exactly the reason in item 1 above — the same gap, on both
branches.

---

## Suggested order

1. Item 1 — get one real frame-time trace from the phone. Without it we are optimising a
   proxy for a complaint we have never measured.
2. Item 2 — deterministic, assertion-bearing play session. Turns the fuzz harness into
   something that can actually fail.
3. Item 6 — five minutes of listening, tells us whether the audio work is done.
4. Item 7 — file split, before the next combat feature.
5. Items 3 and 5 — further perf, once item 1 says where the time actually goes.
6. Item 4 — only if the rebuild count starts mattering.
