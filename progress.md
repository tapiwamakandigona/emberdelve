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

## 2026-07-25 — Original-asset pass 1: zero required attributions (feat/original-assets)
- Owner ask: can we make our own audio/music/graphics that closely replicate the
  originals without violating copyright, so no credits are ever *required* — research
  it, then do it. Research doc: docs/original-assets.md (mechanics/style free;
  assets/characters/melodies protected; CC-BY attribution non-waivable -> replace;
  no-AI-asset rule kept because purely AI-generated work isn't copyrightable, USCO 2023/2025).
- Replaced ALL CC-BY assets with original in-repo-generated work (P-A1, passes=true):
  4 music loops + defeat theme/sting (original compositions, numpy synthesis,
  tool/build_original_music.py), fire ambience loop (procedural crackle), chest
  sprite (original 3-frame design, tool/build_original_art.py), app icon + mipmaps
  (original "ember in the delve" mark; old icon was CC-BY glyph + stale dice branding).
- CREDITS.md rewritten (courtesy-only credits, history section), PROVENANCE.md
  appended with the replacement table + mastering evidence.
- CHECK CHANGE (called out per protocol): test/meta_screens_test.dart credits test
  asserted the dustdfg CC-BY line; that line is intentionally gone, so the test now
  asserts the no-required-attribution statement + courtesy CC0 credits reachable.
- Verified: flutter analyze clean, flutter test 233/233, decoded audio peaks <= -1.3 dBFS.
- NOTE for owner: app icon changed = visible Play-listing branding change; revert
  trivially by dropping the icon commit hunks if unwanted. Music is synthesized
  chiptune-orchestral — replace with commissioned tracks later if wanted; swapping
  files keeps the same paths/loop contract.

---
## 2026-07-25 — AK-parity phase 1 (pre-gate slice of PR #48 plan)
- Branch feat/ak-parity-phase1 off c1957c1. Scope: AKP-1, AKP-2a/2c, AKP-5,
  AKP-6 from docs/ak-parity-plan.md. Deliberately NOT done: AKP-2b air-dash
  (open owner question), AKP-3/4 (M-sized, post-gate), 352×198 zoom variant.
- AKP-1 (2250da3): viewport 480×270 → 384×216 (char ≈11% of screen, AK-range),
  look-ahead 24→32. hud_routing_test now derives button coords dynamically.
- AKP-2a (0e3e12a): roll/dash is a first-class verb — InputIntent.rollPressed
  edge, shared _tryRoll() (chord + button + keyboard Shift/L), ground-only.
- AKP-5 + 2c (03bdafe): AK-style 4-button diamond (jump 56 biggest, sword 52,
  dash 44, apple 44 auto-hide), down-chevron button (peek/drop-through),
  pause 20→44px, idle 0.55/pressed 1.0 opacity, spawn fade. New assets
  hud/btn_down + hud/icon_dash (CC0, tool/build_hud_extras.py, PROVENANCE.md).
  6-test hud_layout_test: ≥44px targets, no overlaps, routing, fade.
- AKP-6 (706af68): w1_l1 teach-before-test rework (first pit 12 tiles out,
  3-wide, step lip blocks non-jumpers; sign teaches DASH) + hazardEject
  damage path (kHazardEjectSpeedY/X) so pits eject instead of cheap-kill.
  onboarding_test: naive hold-right bot survives ≥30s; design guard: no
  hazard pit >5 wide in ANY shipped level.
- VERIFIED: flutter analyze clean; 250/250 tests green (233 baseline + 17
  new); web-harness screenshots confirm zoom + new HUD live in release build.
- features.json untouched — AKP items are plan-tracked (PR #48), not
  feature-gate items. Device metrics (P-M7) still the open gate item.

---
## 2026-07-25 — owner-directed PR #51 update (zoom, alignment, air dash, spell shop)
- Owner answered all three open questions (DM 09:30): zoom = AK-exact, air
  dash = YES, spell slot = in this PR. Plus new report: button/icon
  misalignment and untested behaviour across screen sizes / nav modes.
- ddae760 AKP-1 rev: 384×216 → 352×198 (24px player = 12.1% of screen height,
  AK ≈12.5%). kCameraLookAhead 32→40 keeps ~1.8s forward sight at kRunSpeed.
- 8d28dfb alignment pass: icon_dash.png glyph was VERIFIED 6px left of centre
  (generator bug, fixed + regenerated); dash/apple now centred on their
  sword/jump columns; HUD geometry moved to _layoutHud() and made safe-area
  aware — GameScreen pushes MediaQuery.viewPadding, converted to viewport
  units with letterbox-band absorption (notches, punch-holes, gesture and
  3-button nav all clear every control). +4 tests incl. an icon
  optical-centering drift guard (decodes the PNGs).
- c790cb3 AKP-2b air dash: dash button fires mid-air — kRollSpeed burst,
  gravity suspended + vy zeroed for the window, roll i-frames, ONE per
  airborne period (landing re-arms). kAirDashEnabled flag for on-device A/B.
  New PlayerEvent.airDashed. +5 tests.
- 6d40dc8 AKP-4d spell shop: SPELLS tab (Ember Burst 700c AoE+ignite —
  pierces Rotshield block; Stone Veil 1100c 3s immunity; Hearth Light 10f
  +2 hearts). One equipped, ONE cast per run, premium-only (pinned by test).
  Save fields ownedSpells/equippedSpell (json round-trip tested), session
  castSpell() headless, auto-hiding HUD button (dash column cap), Q/M keys,
  original CC0 icons via tool/build_spell_icons.py (PROVENANCE updated).
- VERIFIED: analyze clean; 267/267 tests green (250 baseline + 17 new);
  web-harness release build screenshots: akp_352_hud_aligned.png (new zoom,
  centred dash icon, symmetric diamond, spell button correctly absent with
  no spell equipped), akp_airdash_midair.png.
- Next (owner, same DM): more characters + enemies, map/pacing pass,
  per-level lore blurbs, Easy/Med/Hard + smarter AI → follow-up PR.

---
## 2026-07-25 — Stage 2: content depth (owner "go", branch feat/content-depth)
- cf1eb7b two new characters: Grove Sentinel (1600c) + Ash Wraith (25f),
  full 9-sheet sets via build_skins.py recolor pipeline (CC0).
- b596887 difficulty + AI + enemies + lore:
  - Easy/Med/Hard (settings picker, save.difficulty): scales enemy speed /
    telegraph windows / detection + 1 heart on Easy. NEVER hp/damage —
    pinned by test ("no cheap stat walls").
  - Smarter AI: thornling hunt-burst, hopper leads moving targets,
    rotshield guard-turn vs backstab campers, totem/diver ranges scaled.
  - New enemies: Pyre Wisp (chasing spirit, hp3) + Slag Hound (telegraph →
    charge, ledge-safe). 'W'/'H' legend chars, placed in 6 levels by
    swapping existing enemies (density preserved, all bots still pass).
  - Lore: meta: lore= in all 12 levels (≤58 chars, tested); HUD intro
    shows name + blurb for the first 4.5s (evidence:
    docs/ak-parity/evidence/stage2_lore_intro.png).
- VERIFIED: analyze clean, 279/279 tests (267 + 12 stage2_test.dart);
  web-harness release screenshot confirms lore intro live.
- Map/pacing: no geometry changes needed — gap-budget + completability
  guards all green with the new enemy mix; new enemies add threat variety
  without new leap-of-faith or chokepoint risks.

---
## 2026-07-25 — Stage 3: consolidation + owner-reported bug/feel fixes (feat/content-depth)
- Consolidation (owner DM 10:58): #50 (original assets) + #53 (music engine
  v2) merged into this branch; plan/ak-parity (#48) merged so the plan doc +
  reference pack land on main; PR #54 retargeted to main; #48/#50/#51/#53
  closed as superseded.
- 5fac665 enemies rendered in reverse: enemy art faces LEFT, player art faces
  RIGHT; EnemyComponent used the player flip rule. Mirror now on facing > 0;
  rotshield plate drawn facing-explicit outside the mirror; golem same rule.
- c0d6b8d movement stutter root cause 1: playSfx re-prepared the audio source
  on every one-shot (footsteps every 0.26s while running = rhythmic jank).
  Per-id prepared lowLatency (SoundPool) voices, stop+resume per shot. Bonus
  fix: danger loop now pauses/resumes with app lifecycle.
- eb6235d movement stutter root cause 2: fractional camera coords under
  nearest-neighbor ~5-6x upscale = full-screen shimmer while panning +
  frame-rate-dependent linear smoothing. Exponential smoothing on unrounded
  accumulators, viewfinder quantized to whole world pixels, scratch Vector2.
- Level layout pass (owner: "level designs don't make sense"): every
  campaign level rebuilt around its name/lore with real macro structure —
  Old Orchard canopy route, Bramble Hollow spike bowl, Charcoal Camp mounds
  + stone kiln, Rootway Ruins colonnade/sunken court/buried shrine, Ashen
  Gate descending terraces + sealed gate, Ember Vault one grand breakable
  treasury with diver guards, Soot Falls hanging falls (one hides a room
  behind a breakable curtain), Magma Gallery stacked galleries over magma
  channels, Kiln Works work floors ramping to the boss door. Coins now trace
  jump arcs; secrets vary (buried cellars / walled shrines / behind-the-fall
  alcove); enemy rosters + introduction order preserved; w1_l1 (tuned
  onboarding) and both boss arenas untouched.
- VERIFIED: analyze clean (1 pre-existing info), full suite 279/279 green —
  incl. per-level completability bots, gap budget, hazard-run <= 5, quotas,
  secret-behind-cracked-wall, lore, onboarding invariants.

---
## 2026-07-25 — owner-directed alpha pass: bugs, audio, level depth (fix/alpha-polish)
Owner (DM): "quite some bugs… find better audio and sound effects… level design
is not as deep as Apple Knight… play apple knight for inspiration… open a PR and
produce an APK." Everything below is labelled VERIFIED (measured here) or
ASSUMED.

### Method
- Toolchain built in-sandbox: Flutter 3.32.7 (CI-pinned), JDK 17, Android SDK 35.
- **Apple Knight played first-hand** in the Poki web build (Unity, desktop
  viewport, keyboard bindings) — new observations beyond the alpha.3 reference
  pack: AK has **campfire checkpoints** ("Light this campfire to activate the
  checkpoint"), a **lives** counter, attackable **levers**, 3-4 stacked terrain
  tiers per screen, coin columns as skill invitations, and damage numbers +
  white swing arcs. Screenshots kept out of the repo (copyright).
- Emberdelve driven headlessly (session bots) and in the browser harness.

### VERIFIED defects found
1. **Every level killed a casual player in 4-16 s.** Sweep over all 12 levels
   with a hold-right/jump-when-stalled/swing bot: 6 levels ended the run in
   4-16 s (first damage 1.0-2.4 s), the other 6 stalled at 10-26 %. Root cause
   was pacing, not physics: the first enemy stood 1-2 s from spawn in nearly
   every level, and a death threw away the whole run.
2. **A tap-jump rose ~7 px** — less than one 16 px tile. On touch, quick taps
   read as dropped inputs (kJumpCutMultiplier applied with no floor).
3. **World 2's boss arena was a byte-identical copy of World 1's**, same Grove
   Golem entity, renamed "Kiln Golem" in meta only.
4. **All twelve levels played the same music track.** `boss_combat.ogg`
   (661 KB) shipped in every APK with no level referencing it.
5. **The SFX/music set was inaudible on a phone.** Band analysis: land.ogg
   100 % of energy < 300 Hz, danger_loop 100 %, enemy_death 99.8 %, player_hit
   99.4 %, jump 96.6 %; music beds 88-91 %. Phone loudspeakers reproduce almost
   nothing below ~500 Hz. Level spread across the set was 37 dB.
6. **w2_l3's strongroom shaft was one tile wide** — narrower than the player
   body, so its secret chest was unreachable and the lip trapped runners.
7. Deaths from enemy contact, boss hazards and ember shots bypassed the new
   checkpoint path (three direct `_fail()` call sites) — found by re-running
   the sweep after the first checkpoint implementation.

### Fixes
- **Campfire checkpoints + lives** (AK's model): new `K` legend char,
  `CheckpointEntity`, `kStartingLives` 3, respawn heals and grants 2 s of
  i-frames, and enemies within 96 px of the respawn are sent home so a
  campfire can never become a meat grinder. HUD shows lives; new campfire art
  from `tool/build_checkpoint_art.py` (original, CC0).
- **Minimum jump hold** (`kMinJumpHold` 0.09 s): the cut cannot land before the
  jump has been rising that long, so a tap clears ~1.5 tiles while a full hold
  still buys the whole 2.3-tile arc (variable height preserved — pinned by
  physics_test).
- **World 1 re-authored from scratch** via the new `tool/level_author.py` DSL:
  three terrain tiers, high/low branching routes, 12-tile safe teaching runway,
  two campfires per level, shallow escapable spike pits on bedrock instead of
  chain-death wells, strongrooms behind cracked walls, canopy sky-vaults.
- **World 2 pacing pass** (`tool/w2_pacing_pass.py`, mechanical, layouts kept):
  16-tile enemy runway, 14-tile hazard runway, no enemy within 3 columns of a
  hazard, max 3 enemies per 20-tile window, early hazard runs capped at 2
  columns, three campfires placed away from patrols and hazards.
- **Kiln Golem arena rebuilt**: fire channels split the floor into three
  islands with plinths and an upper platform run. (ASSUMED-follow-up: the boss
  *behaviour* is still GroveGolemCore — a distinct moveset is the next step.)
- **Audio v3**: whole SFX set rebuilt from recorded CC0 sources and mastered
  through a phone-speaker model (`tool/build_audio_v3.py`); music re-mastered
  and World 2 given its own bed, boss arenas wired to `boss_combat`
  (`tool/build_music_v3.py`). Measurements ship in `tool/audio_mix.json`.
- **Web harness fixed**: it crashed with a null-check error on death or level
  complete (no `overlayBuilderMap`), which blocked automated full-clear
  verification; telemetry widened to run state, chests, kills, damage.

### VERIFIED results
- `flutter analyze`: clean. `flutter test`: **325/325 green** (279 baseline +
  46 new in `fairness_test.dart` and `audio_mix_test.dart`).
- Survivability sweep after the fixes: **no level ends a run in under 21 s**
  (was 4-16 s in six levels); W1 l1-l4 and several W2 levels survive the full
  180 s sample; w2_l3 now clears at 97 %.
- Audio: every foreground one-shot within ~1 dB of one phone-band target
  (-22 dBFS) with >= 35 % of its energy above 500 Hz; music beds at -26 dBFS.
  Audio payload 3.8 MB -> 1.9 MB.

### CHECK CHANGES (called out per protocol)
- `game_screen_smoke_test.dart` pinned the old tutorial (3 signs, 1 enemy). It
  now pins the new contract: 4 signs (the campfire is taught before the first
  hazard), 2 thornlings, 2 checkpoints. Same intent, new content.
- `physics_test` "early release rises less than full hold" still passes
  unchanged — the minimum-hold window was chosen so variable height survives.

## 2026-07-25 — release: v1.0.0-alpha.5 pre-release (owner request)

Owner: "publish the alpha 5 as pre-release on github releases."

- **VERIFIED** `pubspec.yaml` bumped to `1.0.0-alpha.5+17` (commit `696a400`);
  PR CI run 30164664613 on that SHA: success.
- **VERIFIED** PR #58 merged into `main` (merge commit `e35858e`).
- **VERIFIED** main-push CI run 30165034323 on `e35858e`: both jobs success
  ("Analyze + test (headless)", "Build signed Android release (APK + AAB)").
- **VERIFIED** artifacts `emberdelve-release-apk` / `-aab` downloaded from that
  run; `aapt2 dump badging` reports `versionCode='17'
  versionName='1.0.0-alpha.5'`; `apksigner verify --print-certs` reports signer
  SHA-256 `031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`
  == the expected upload key, so it installs over alpha.1–alpha.4.
- **VERIFIED** release published: tag `v1.0.0-alpha.5` -> `e35858e`,
  `prerelease: true`, `draft: false`, assets
  `emberdelve-v1.0.0-alpha.5.apk` (24,184,091 B) and
  `emberdelve-v1.0.0-alpha.5.aab` (43,200,161 B), both state `uploaded`.
  https://github.com/tapiwamakandigona/emberdelve/releases/tag/v1.0.0-alpha.5
- Note for the record: the APK hand-delivered to the owner earlier in the day
  was built before the version bump and reported `1.0.0-alpha.4+16` despite
  being named alpha.5. The release asset is the correct `1.0.0-alpha.5+17`.
- Open follow-ups unchanged: Kiln Golem moveset (reuses GroveGolemCore),
  World 2 full re-authoring, AK-parity juice (AKP-3), on-device perf (P-M7).

---
## 2026-07-26 — Kiln Golem gets its own fight (fix/kiln-golem-moveset)
Owner (DM): "if there are any issues that need fixing/improvement open a pr
for em." No open tracker issues; the highest-priority VERIFIED open defect on
main was the alpha.5 follow-up: **w2_boss "Kiln Golem" was GroveGolemCore** —
the same World 1 fight renamed and retinted.

### Changes
- `boss_core.dart`: extracted shared abstract `BossCore` (telegraphed
  idle→telegraph→attack→recover machine, self-owned hazards, phase math off
  `maxHpTotal`, hazardHits/hazardSourceX/telegraphPulse). GroveGolemCore
  behaviour is unchanged (same timings/attacks; per-attack code moved under
  the hooks). New `KilnGolemCore`, fire moveset: P1 ember mortar (aimed
  0.58 s-flight lobs that ignite 1.5 s fire patches where they land), P2
  + vent wall (4 flame pillars marching from the golem toward the player,
  staggered warnings, jump the wave), P3 1.5x speed + 3-ember volley and the
  vent wall marches both directions. New hazards: emberBomb / firePatch /
  flamePillar. Hazard iteration is index-based so a landing ember can append
  its patch mid-update without ConcurrentModificationError.
- Session/HUD made boss-kind-agnostic (`whereType<BossCore>`,
  `boss.maxHpTotal` instead of the hardcoded GroveGolemCore.maxHp).
- New legend char `M` = kilnGolem; w2_boss.txt swaps G→M and its sign now
  describes the real fight (layout untouched — arena stays as tuned).
- Renderer: kiln case (terracotta tint, same CC0 thornling base — zero new
  art); ember/patch/pillar drawn procedurally; grove keeps moss tint
  unconditionally (the env-dependent tint hack is gone with its reason).

### VERIFIED
- analyze: 1 pre-existing info (settings activeColor deprecation — left
  alone: replacement API risk on CI's pinned 3.32.7 not worth an info).
- tests: **334/334 green** (325 baseline + 9 in kiln_golem_test.dart:
  spawn/lock, phases+events, telegraph-before-hazard, no-grove-hazards in any
  phase, mortar arcs + ignites + punishes an idle player, vent warnings
  before eruptions + >=4 marching pillars, >=3-ember volley, door unlock,
  victory burst).
- Real-arena sim (temp test, removed): crude jump/attack bot in w2_boss.txt
  — fight functions end to end, boss damaged, emberBomb+firePatch seen;
  same bot vs w1_boss for parity: both fights end a lobotomized bot (bosses
  stay a skill check by design, fairness_test exemption unchanged).

### CHECK CHANGES (called out per protocol)
- `world2_levels_test.dart`: the boss-entity check now pins KilnGolemCore
  and asserts GroveGolemCore is ABSENT from w2_boss (was: expects
  GroveGolemCore). Same intent — "the boss spawns" — plus the regression
  guard against reskinning.
- `fairness_test.dart`: kilnGolem added to the enemy-kind set used by the
  spawn-runway rule (data list, no logic change).

### Open follow-ups (unchanged)
- World 2 full re-authoring, AK-parity juice (AKP-3), on-device perf (P-M7).

---
## 2026-07-26 — AKP-3 animation & game juice (feat/akp3-juice)
Owner (DM): "go ahead" on the follow-up stack. AKP-3 from
docs/ak-parity-plan.md §3 — the "reads like AK" combat pass. AKP-3d
(enemy hit-flash) already shipped earlier; this lands the rest. All render
side: no gameplay value, hitbox or timing changed.

- **AKP-3a landing squash**: PlayerComponent scales 1.15x/0.85y anchored at
  the feet for 80ms on PlayerEvent.landed, easing to 1:1 (render transform
  only). Dust on land/dash already existed.
- **AKP-3b swing arcs**: procedural white crescent (canvas.drawArc) swept
  across the middle 60% of each attack animation, in front of the player,
  flipped with facing, direction alternating per combo step, thicker on the
  finisher, tinted per weapon special (none/wallBreaker/burn/bonusHeart/
  lunge/tripleJump each get a hue). Zero new art assets.
- **AKP-3c damage numbers**: SessionEvent gains `amount` (emitted at all
  four damage sites: melee, apple, spell burst; burn ticks deliberately
  silent). DamageNumberFx: ui.Paragraph laid out once at construction, two
  pre-baked alpha variants instead of a per-frame saveLayer (offscreen
  layer per number would eat the Android frame budget), ease-out rise,
  crits bigger/golden/longer-lived, hard cap of 24 live numbers with
  constructor/onRemove accounting (skips silently at the cap).
- **AKP-3e camera shake**: hurt now bumps the camera (3.0); normal enemy
  hits no longer do — shake only on crits and the combo finisher (the old
  every-hit 1.5 bump was exactly the motion-sickness noise the plan warns
  about). bossPhase/bossDefeated bumps unchanged.

VERIFIED: analyze clean (2 pre-existing activeColor infos), tests
**344/344** (3 new in juice_test.dart: enemyHit carries real damage,
damage-number cap accounting + crit-lives-longer, squash decay). Remaining
AKP-3 DoD item that needs hardware: side-by-side capture vs the AK
reference + perf overlay on the fire-pit scene (folds into P-M7).

## 2026-07-26 — World 2 re-authored + reachability contract (feat/world2-reauthor)
Owner (DM): "go ahead" on the follow-up stack after #61. This is the World 2
full re-authoring, plus a defect it flushed out of BOTH worlds.

### World 2 rebuilt in the design DSL
- w2_l1..w2_l5 moved into `tool/level_author.py` (same DSL, rules and
  teach-then-test pacing as World 1); `tool/build_w2_levels.py` and
  `tool/w2_pacing_pass.py` deleted as superseded. W1 + both boss arenas
  regenerate byte-identical from the tool (idempotence check before touching
  anything).
- Level identities, macro structure first: Ashen Gate = surface shelf, a
  real gate (hollow sealed gatehouse over the road) and terraces stepping
  down into the cave; Ember Vault = one grand sealed treasury (cracked
  doors at body height, gold + diver guards + a reliquary inside); Soot
  Falls = stepped basins with coin-trickle drop lines and the fallers' room
  behind a cracked curtain; Magma Gallery = a pillar colonnade carrying an
  upper gallery over a magma-channel hall; Kiln Works = rising work floors
  around the great kiln (fire in its throat), ramping down to the boss
  door. Rosters and introduction order preserved from alpha.5. Cave read:
  ceiling + stalactite drips kept >= 4 rows out of play space.

### VERIFIED defect (shipped, both worlds): unenterable secret vaults
- `sky_vault` built a 1-tile (16px) interior and 1-tile doors; the player
  body is ~20px. Physically impossible to enter — measured in-session: the
  body cannot pass the door (playerX pinned at the wall), so **every
  sky-vault secret in w1_l1..w1_l5 was uncollectable and the "all chests"
  medal unattainable on those levels.** Interior + doors are now 2 tiles;
  approach platforms re-aligned. Also fixed: w1_l1's upper route needed a
  5-row rise (budget is 4); w1_l3/l4/l5 vault approaches got a mid step;
  w2_l5 had a 4-deep trench (chain-death well) before the kiln — filled.

### New contract: collectible reachability
- `tool/reachability_lint.py` + `test/reachability_test.dart` (same
  algorithm): jump-physics flood fill (double-jump budgets verified
  empirically: a standing double jump lands a 4-row ledge; ~6 columns of
  air reach; body needs head clearance; cracked walls count as breakable).
  Every c/a/f/C/X/K/E in every shipped level must be reachable. The door
  bots prove the exit; this proves the loot. It fails the alpha.5 levels
  as shipped and passes after the fixes.

### VERIFIED results
- analyze clean (2 pre-existing infos: settings activeColor x2, the second
  arrived with #47); tests **353/353 green** (341 post-#61/#47 baseline +
  12 reachability). Runner-bot completability + fairness suites green on
  the new layouts; full-clear seek-bot probe (temp, removed) collected
  every ground-route collectible; w2_l5 runner bot finishes in 21s.

## 2026-07-26 — Land the open follow-up PRs; salvage from stale #62
Owner (DM): "work on alpha version of emberdelve."

- **VERIFIED** integration main + #64 + #65 locally on Flutter 3.32.7:
  analyze clean, 356/356 tests green.
- **VERIFIED** PR #64 squash-merged (208938f): World 2 re-authored in the
  design DSL + collectible-reachability contract; fixes the shipped
  unenterable-sky-vault defect in both worlds.
- **VERIFIED** PR #65 squash-merged (a38751c) after resolving the
  progress.md append conflict against post-#64 main and re-running the
  suite (356/356) + PR CI green on the resolved head (e678b41).
- Salvaged from stale umbrella #62 (superseded by #61+#64+#65):
  `tool/survivability_sweep.dart`, the casual-bot measurement tool behind
  fairness claims. **VERIFIED** it runs on current main
  (SWEEP_SECONDS=30, w1_l1 68% reached/alive, w2_l1 63%/alive).
  Not salvaged: #62's camera_shake.dart module + kHitPauseHeavy (superseded
  by #65's tuned-shake approach), kiln_boss_test.dart (superseded by #61's
  kiln_golem_test.dart, legend M not Q).

## 2026-07-26 — release: v1.0.0-alpha.6+18
- pubspec bumped 1.0.0-alpha.5+17 -> 1.0.0-alpha.6+18; checkpoint
  checkpoints/09-alpha6-w2-reauthor-juice-kiln.md written (tester-facing
  changes: enterable vaults fix, W2 re-author, Kiln Golem fight, AKP-3 juice).
- Release evidence appended after CI + prerelease publish (see below).
- **VERIFIED** release PR #67 squash-merged to main as 1301606a; main-push CI
  run 30197743835 green (Analyze + test (headless) + Build signed Android
  release success).
- **VERIFIED** CI APK badging: com.tsorostudios.emberdelve, versionCode 18,
  versionName 1.0.0-alpha.6; signer cert SHA-256 031acb42...4d44b7a0d matches
  the pinned upload key (also enforced in the CI build job).
- **VERIFIED** GitHub prerelease v1.0.0-alpha.6 published on 1301606a with
  emberdelve-v1.0.0-alpha.6.{apk,aab}; release asset sha256 digests match the
  locally verified CI artifacts (apk 026e51a1..., aab b276a19d...).
- Still open: P-M7 on-device perf (needs hardware), P-M10 beta.1 to Play
  closed testing (owner call), AKP-4 weapon identity.

---
## 2026-07-26 — AKP-4 weapon identity (feat/akp4-weapon-identity)
Owner (DM): "start" — proceeded with the last open workable item: AKP-4
(P-M7 blocked on hardware, P-M10 owner call; AKP-4d already shipped 6d40dc8).

- AKP-4a — render the equipped weapon:
  - tool/build_weapon_sprites.py splits the baked-in ivory blade (#fffff2 —
    VERIFIED that exact color is blade/swing-FX-only in the pixivan pack)
    out of all 9 player sheets into assets/images/player/body/ (bladeless)
    + assets/images/player/weapons/<id>/ (6 per-weapon overlays: hilt→blade
    →tip recolor gradient from the grip, 1px head dilation for axe/hammer).
    The baked swing crescents inherit the weapon tint for free.
  - build_skins.py now recolors the bladeless body sheets (all skins
    regenerated); PlayerComponent drives a weapon-overlay ticker in lockstep
    with the body ticker (same transform: flip/squash/blink); shop
    SkinPreview composites the equipped weapon; missing sheets degrade to
    bare hands, never a crash. PROVENANCE.md updated (all CC0-derived).
- AKP-4b — per-special identity:
  - Skypiercer lunge IMPLEMENTED (was stats-only despite the specialText
    promise): kLungeSpeed 150 px/s burst at swing start; ground friction
    bleeds it in ~0.09s ≈ 7px step; wall-clipped by the normal integrator;
    horizontal-only so jump height and reachability contracts are untouched.
    + dash-streak PuffFx on swing.
  - Ember Fang hits shed ember SparkleFx; Woodsman's Axe one-chop wallBreak
    puffs bigger rubble (radius 7→10).
- AKP-4c — apple lob: launch flattened 40°→22.5° (feel-notes rec; speed 220
  kept — flight is flatter/faster, flat-ground range ~unchanged ≈56px, no
  test pinned the old angle). Held throw button (touch or K/C) shows a faint
  arc-preview dot trail computed from the projectile's own launch params +
  gravity (Session.appleArcPreview, preallocated buffers, zero per-frame
  allocations); throw itself stays on the press edge.
- Webtest harness: ?weapon=<id> and ?apples=N params (harness-only).

### VERIFIED
- flutter analyze: No issues found. Tests 363/363 green (356 baseline + 7
  new in test/weapon_identity_test.dart: overlay sheet completeness /
  dimensions / per-weapon pixel-difference, lunge steps forward ~7px while
  control weapon stays put, lunge never clips a wall, 22.5° launch vector,
  arc preview matches a 120Hz-stepped projectile to <0.01px on every dot).
- In-game evidence (web harness, release build): per-weapon idle + mid-swing
  screenshots + apple arc preview in docs/ak-parity/evidence/akp4/.

## 2026-07-26 — AKP-4 merged to main
- PR #69 squash-merged as 1cb919b (branch feat/akp4-weapon-identity deleted).
- VERIFIED: PR CI "Analyze + test (headless)" pass (1m14s,
  run 30198891118); mergeStateStatus CLEAN before merge.
- No release cut this run (feature-only; next release alpha.7 on owner call).
- Still open: P-M7 (on-device perf, needs hardware), P-M10 (Play beta.1,
  owner call).

## 2026-07-26 — release v1.0.0-alpha.7+19 (chore/release-alpha7)
Owner (DM): "cut me a pre release I can test". Cut from main at ef73fa8
(AKP-4 weapon identity, merged as 1cb919b, was unreleased).

- pubspec 1.0.0-alpha.6+18 → 1.0.0-alpha.7+19 (versionCode 19).
- checkpoints/10-alpha7-weapon-identity.md: tester-facing notes.
- No code changes in this release PR.

### VERIFIED — v1.0.0-alpha.7 shipped
- PR #73 squash-merged to main as 38137e2 (branch deleted); PR CI
  "Analyze + test (headless)" green, mergeStateStatus CLEAN before merge.
- Main CI run 30201005775 on 38137e2: both jobs success — "Analyze + test
  (headless)" and "Build signed Android release (APK + AAB)"; CI's own
  signer check against EXPECTED_CERT_SHA256 passed (untouched).
- Artifacts downloaded from that run and re-verified locally:
  pyaxmlparser badging → package com.tsorostudios.emberdelve,
  versionCode 19, versionName 1.0.0-alpha.7. Signer cert SHA-256 recomputed
  from META-INF/CERT.RSA = 031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb69
  79f68564d44b7a0d — exact match to the pinned upload key, so it installs
  over alpha.1–alpha.6.
- GitHub prerelease v1.0.0-alpha.7 published on 38137e2 with both CI assets
  (state: uploaded):
  emberdelve-v1.0.0-alpha.7.apk  25,545,105 B
    sha256 d3c3cff1558bbbf439c293c35807c2496071d63b7583c3ad23d7184cbda6bbe0
  emberdelve-v1.0.0-alpha.7.aab  45,347,574 B
    sha256 de4ff93945ed7c97450439d8557f6882c52267333d978481b7c3b4d1cce1698d
  https://github.com/tapiwamakandigona/emberdelve/releases/tag/v1.0.0-alpha.7
- No local build shipped (CI artifacts only); no Play upload (P-M10 stays an
  owner call).
- Still open: P-M7 (on-device perf, needs hardware), P-M10 (Play beta.1).

## 2026-08-31 — session start: Emberwood gauntlet resumes (owner: "work on emberdelve alpha version that isn't the dice game")
- Track: `main` (Emberwood platformer, com.tsorostudios.emberwood), worktree
  /work/repos/emberwood off the dice checkout. DEMAND.md written for this
  branch (platformer standards; root DEMAND.md on legacy branch is
  dice-scoped). Owner will drive the loop with "continue" pings, dice-style
  cadence: one improvement per release.
- BLOCKER (carried until fixed): GitHub PAT is dead — 401 on api.github.com
  with the documented token [github, 2026-08-31]. Same failure the dice
  branch has logged since 2026-08-25 ("push pending GitHub auth"): remote
  legacy/dice-builder sits at v0.60.0 while local is v0.148.0 (92 unpushed
  commits). NO pushes, tags, CI dispatches, or GitHub releases possible from
  the sandbox until the owner re-provisions a PAT. Working in
  gates-green-commit-locally mode meanwhile. Escalated to owner this session.
- Baseline VERIFIED at 1326a80: flutter analyze 2 infos (deprecated
  activeColor), suite 363/363 green (Flutter 3.44.9 from /work/temp/flutter;
  pinned 3.32.7 unavailable — no regressions observed, watch goldens).

## v1.0.0-alpha.8+20 — The Readable Wood (2026-08-31)
- One improvement: in-world HUD text legibility. Look pass (web harness,
  915x412 phone + 1280x800 desktop, spawn+mid shots, all 8 sampled levels
  across both worlds) found counters/timer/lives/lore-intro ivory text with
  NO outline — unreadable over World 1's pale sunburst sky in every W1 shot
  (self-found, 3-second-stranger fail). Fix: HudReadout.hudTextStyle gains
  four 1px cardinal ink shadows (0xFF201826, blur 0) — pixel-outline look,
  bakes into cached TextPainters, zero steady-state cost.
- Also: settings_screen.dart activeColor→activeThumbColor (2 deprecations);
  analyze now clean.
- VERIFIED: suite 364/364 (+1 hud outline pin test; fails on old code via
  stash run — compile-level bind on hudTextStyle + shadow asserts). After
  shots confirm crisp readouts on w1_l1/w1_l3 (sunniest levels).
- OBSERVED (open, minor): all coins share one global spin phase — every coin
  on screen hits the edge-on frame simultaneously; caught in the after shots
  looking candle-like for a frame. Candidate future improvement: per-coin
  phase offset from spawn position.
- Release mechanics: version 1.0.0-alpha.8+20, checkpoint
  checkpoints/11-alpha8-hud-legibility.md. Tag/CI/GitHub prerelease PENDING
  GitHub auth (see blocker above); commit is release-shaped so the publish
  is a tag+dispatch away once auth returns.

## v1.0.0-alpha.9+21 — Twinkling Hoard (2026-08-31)
- One improvement: per-coin spin phase (the open minor logged in alpha.8).
  CoinEntity.spinPhase from spawn position; ItemsComponent draws per-coin
  frames from a precomputed sprite list (pure coinFrame(), no per-frame
  allocations, shared ticker removed). Suite 366/366 (+2). Visual VERIFIED:
  w1_l1 cluster shows mixed frames in one still; candle-wall gone.
- Publish still PENDING GitHub auth (PAT dead — see 2026-08-31 blocker).

## v1.0.0-alpha.10+22 — Unstuck Steps (2026-08-31)
- Publish unblocked: user re-provisioned the PAT. alpha.8 + alpha.9 pushed,
  tagged, CI-built (Flutter pin -> 3.44.9 after activeThumbColor broke the
  3.32.7 analyze) and released as GitHub prereleases with signed APK/AAB.
- One improvement: w1_l4 chute-trap fix. Playthrough probe (hold-jump casual
  bot, 4 seeds, all 12 levels, stall telemetry) found the Cinder Steps
  1-wide inter-tower slots trapped the bot for 290+ s every run; col-59 slot
  needed rise 6 (> double-jump budget 4). Filled both slots into staircase
  steps; permanent chute-trap lint gate added (fails on old geometry,
  VERIFIED). Suite 378/378. Probe: w1_l4 now CLEAR in 21 s all seeds.
- Checkpoint: checkpoints/13-alpha10-cinder-steps-trap.md.
