# Playtest report — v1.0.0-alpha.3 (browser harness, 2026-07-25)

Owner asked for a play-and-review of the alpha.3 release (perf, controls,
level design). Method: compiled `lib/main_webtest.dart` at tag
`v1.0.0-alpha.3`, drove it with headless Chromium + CDP touch events,
asserted on `window.__emberdelve` telemetry (see `docs/web_testing.md`).
Every claim below is labeled VERIFIED (measured here) or ASSUMED.

## 1. Controls

- **VERIFIED — multi-touch state desync.** Hold RIGHT (finger 1), press JUMP
  (finger 2), lift ONLY the jump finger: `touchRight` flips to false while
  finger 1 is still down, yet the player *keeps running at full speed* for as
  long as sampled (600ms+). Flag and motion disagree → on device this is the
  "controls feel wrong" class of bug: run-state flicker and/or movement that
  continues after thumb-lift. Repro: CDP `touchStart` [right], `touchStart`
  [right,jump], `touchEnd` with [right] remaining. The alpha.3 hud_routing
  tests don't cover multi-finger lift ordering — add a regression test.
- **VERIFIED — touch is noticeably slower than keyboard.** touchStart→first
  x-movement ≈ 218ms vs keyboard ≈ 69ms, same polling method (50ms telemetry
  granularity; the ~150ms *delta* is the signal). Likely gesture-arena
  tap-vs-drag disambiguation in the hold-button path. On a phone this reads
  as sluggish steering.
- **VERIFIED — jump tuning itself is fine.** Full jump 34.4px (~2.2 tiles),
  tap-cut 19.5px, coyote/buffer work as tuned. The *feel* problem is not the
  physics; it's touch latency + the desync above + (in alpha.3) no roll, no
  turnaround assist, no ceiling corner-correction — all landed on main after
  the alpha.3 tag.

## 2. Level design (the bigger problem)

- **VERIFIED — w1_l1 kills a naive player in <3 seconds.** A 6-tile spike pit
  sits ~1.5s of walking from spawn. Holding right (what every new player
  does) drops you in. 4/4 automated "walk right" runs died there.
- **VERIFIED — hazard pits are inescapable death traps.** Pit floor→lip is
  32px; max jump is 34.4px (2px margin). Each hazard tick deals damage,
  resets `hurtTime` (0.25s input lock) and knockback (`vx` toward own center
  → pushes into the pit wall). Even scripted escapes (wait out stun, hold
  away+jump) failed 100% of attempts: the player is juggled for ~5-7s until
  all hearts drain. Fix options: bounce-out on hazard hit (Apple Knight
  knock-UP + longer i-frames), make pits 1 tile shallower than max jump, or
  insta-kill+respawn at a checkpoint instead of the slow drain.
- **VERIFIED — the "intended" route over w1_l1's second (fire) pit is a
  head-bonk trap.** A platform hangs directly in the double-jump arc over the
  pit's right half; bots (and plausibly players — ASSUMED) clip it and fall
  into the fire. alpha.3 has no ceiling corner-correction (main does).
- **VERIFIED — every W1 level has lethal pressure at spawn.** 3.5s of casual
  walk+jump from spawn: w1_l3 dead, w1_l4 dead, boss arena dead, w1_l5 down
  to 1 heart. There is no safe teach-space anywhere, which breaks PROJECT.md
  §8 (the tutorial promise made to Play testers).
- **VERIFIED — w1_l5's spawn spike strip sits underneath the touch buttons**
  (screen-left, exactly where the thumb rests over LEFT/RIGHT).
- Layout shape (from the ASCII files, all W1): one flat ground corridor
  left→right, sparse floating platforms, hazards embedded in the single
  path. No verticality, no alternate routes (secrets are wall-pockets on the
  same corridor). Par times say 90-120s; the walk is ~40-60s — the rest is
  dying. ASSUMED: this is what the owner means by "level designs suck".
  Direction: teach-then-test pacing (safe first screen, telegraphed first
  hazard), recovery platforms inside pits, verticality/branching, put
  hazards away from the HUD zones.

## 3. Performance

- **VERIFIED (web/desktop):** locked 60fps idle AND under busy input —
  avg frame 16.9ms, p95 16.8ms, ≤3 frames over 33ms in 300 (all at load
  boundaries), across all 7 levels incl. boss. The sim/render code is not
  fundamentally heavy.
- **OPEN (device):** the owner's perf complaint is on Android hardware, which
  this sandbox cannot measure (no KVM). alpha.3 predates the perf lane on
  main (zero-alloc render layer, sim bench, frame-time overlay #37). Next
  step: cut alpha.4 from main and read the frame overlay on the physical
  phone — cold start and worst-level frame times.

## 4. Harness bug found while testing

- **VERIFIED — death/level-complete on the web harness = grey screen +
  `Null check operator used on a null value`.** `main_webtest.dart` uses a
  bare `GameWidget` with no `overlayBuilderMap`; `overlays.add(overlayFail)`
  then crashes. Android registers overlays in `ui/game_screen.dart`, so this
  is harness-only — but it blocks automated full-level-clear verification on
  web. Fix: register minimal no-op overlays in the harness.

## 5. Recommended order

1. Cut **alpha.4 from main** (picks up: roll verb, turnaround assist, ceiling
   corner-correction, zero-alloc render, footsteps, World 2) — several of the
   owner's complaints are already fixed there but unreleased.
2. Level-design pass on W1 with the rules in §2 (spawn safety, pit escape,
   HUD-zone hazards). Add a "walk-right survives 5s" bot test per level.
3. Multi-finger lift regression test + fix; measure touch latency on device.
4. On-device perf numbers via the frame overlay (this is the only way to
   close M7 honestly).
