# progress.md — append-only log (one dated block per completed task, decision, or gate)

> **Compacted 2026-07-25 (owner-directed cleanup).** The old 559-line log spent
> most of its length on the archived dice-builder era and on already-fixed bugs.
> Full detail is preserved in this file's git history
> (`git log --follow -p -- progress.md`), in `checkpoints/`, and on
> `legacy/dice-builder`. Keep NEW entries short: what shipped, evidence, open items.

## Era 1 — dice-builder roguelite (2026-07-23 → 2026-07-24, ARCHIVED)

Emberdelve v1 was a turn-based dice-builder (Defold/Lua → pivoted to
Flutter/Dart with proven sim parity). Shipped through v0.3.9+12 to Google Play
closed testing. Archived intact: branch `legacy/dice-builder`, tag
`v0.3.10-legacy`, release "Emberdelve Classic". Dice-era docs: `docs/legacy/`;
dice-era checkpoints: `docs/legacy/checkpoints/`. **Do not build against it.**

Durable facts that still matter:
- **Play closed testing is LIVE** on release 12 (v0.3.9+12), 177 countries,
  package `com.tsorostudios.emberdelve`. Production gate: 12+ opted-in testers
  for 14 continuous days (met 2026-07-24 → earliest apply ~2026-08-07; a dip
  below 12 resets the clock). App updates and listing edits do NOT reset it.
  Testers get no update notification; Play auto-updates (~24h).
- **PUBLIC PROMISE to testers: an in-game tutorial ships "in the next
  update"** — release blocker for the first pivot release to Play.
- Upload keystore + cert are permanent; CI verifies
  `EXPECTED_CERT_SHA256 = 031acb42…7a0d`. Never regenerate; never change.
- Fine-grained-PAT pushes DO trigger CI (an early claim to the contrary was
  corrected). GitHub Pages serves `main:/docs` — everything under `docs/` is a
  public web page; the hosted privacy policy URL lives in `docs/store/` and
  must not move.
- Tester group: emberdelve@googlegroups.com; store/testing links in
  `docs/store/play-listing.md`.

## Era 2 — action platformer pivot (2026-07-24 → , CURRENT)

2026-07-24 **PIVOT (owner-directed):** Apple-Knight-style 2D action
platformer, Flutter + Flame. Spec `docs/spec.md`, architecture
`docs/architecture.md`. Kept: CI+signing, package id, audio service, seeded
RNG, atomic saves. Standing rule: **push at every milestone** (a prior agent's
unpushed pivot attempt was lost).

2026-07-24/25 **M1–M5 built** (headless-first): tuning in
`lib/game/tuning.dart`; LevelSession headless runtime; physics with
coyote/buffer/variable jump/double jump; 3-hit combo; enemies (Thornling,
Ashbat, Hopper, Ember Totem, Rotshield) + Grove Golem boss (3 telegraphed
phases); ASCII levels `assets/levels/` (legend frozen in
`lib/game/level/level_data.dart` — only ADD); shop/skins/abilities meta;
World 1 "Emberwood" 5 levels + boss with runner-bot completability tests.

2026-07-25 **v1.0.0-alpha.1 → alpha.3 released** (GitHub prereleases, signed
APK+AAB, CI green each time). alpha.1/alpha.2 shipped with touch controls
dead on devices; two root causes found and fixed in alpha.3 (99d0131):
(1) Flame gesture dispatchers must be registered at EmberGame construction —
component-mount registration never attaches in release builds; (2) never hide
a tappable component with `scale=0` — it swallows every tap; gate
`containsLocalPoint` on visibility. Regression: `test/hud_routing_test.dart`.
Verified via the **web test harness** (`lib/main_webtest.dart` +
`docs/web_testing.md` — build web with `-t lib/main_webtest.dart`, telemetry
on `window.__emberdelve`). Harness exists because sandboxes have no KVM for
Android emulation.

2026-07-25 **M8 shipped:** perfect-clear bonus (+25 coins for 3-medal runs)
and Daily Delve (pure date→seed remix of w1_l2..l5, no streaks/FOMO per spec
§7 Ethics). **M9 shipped:** World 2 "Cinder Depths" (5 levels + Kiln Golem,
Soot Creeper + Cinder Diver, cave tileset, two-world level select). Also on
main since alpha.3: roll verb (DOWN+JUMP commit-dodge with i-frames),
footsteps, turnaround assist + ceiling corner-correction, zero-alloc render
layer, sim benchmark, frame-time overlay, W1 decor + juice + layout pass.
**None of this is in any published release yet.**

2026-07-25 **M7 gate (perf) honest status:** headless side done (zero
per-frame allocations in sim+render, benchmark green at `docs/perf.md`);
**measured 60fps + cold start on a 2GB device STILL OPEN — needs a physical
phone.** Release notes must carry this caveat until closed.

2026-07-25 **Owner playtest review of alpha.3** (browser harness, evidence in
`docs/playtest-2026-07-25-alpha3.md`): controls — multi-touch lift desync +
~150ms touch-vs-keyboard latency gap (VERIFIED); level design — w1_l1 spike
pit kills a walk-right player in <3s, hazard pits are inescapable death traps
(32px pit vs 34px jump + knockback juggle), every W1 level has lethal
pressure at spawn (VERIFIED); perf — locked 60fps on web/desktop, device
numbers still open. Recommended: cut alpha.4 from main, W1 safety pass,
multi-finger regression test, on-device overlay numbers.

2026-07-25 **Repo cleanup (owner-directed, this commit):** progress.md
compacted (full text in git history); dice-era checkpoints moved to
`docs/legacy/checkpoints/`; 32 fully-merged/superseded remote branches
deleted (all were ancestors of `main`, `legacy/dice-builder`, or open-PR
branch `feat/content-depth`); kept: `main`, `legacy/dice-builder`, open-PR
heads (`feat/content-depth` #54, `feat/telemetry-v2` #47, `telemetry-phase1`
#27), and unique unmerged work (`plan/legacy-feel`, `feat/combat-weapons-juice`,
`flutter`).
