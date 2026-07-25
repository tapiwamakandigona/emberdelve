# Apple Knight Parity Plan

**Goal (owner-directed, 2026-07-25):** make Emberdelve play like *Apple Knight* —
similar on-screen character size, play style, animations, weapons, and controls —
while keeping the things we already do better (tighter jump feel, no ad sludge,
fair monetization).

**Evidence base:** hands-on playtest of Emberdelve (web harness, touch + keyboard
bots, 2026-07-25) and Apple Knight played with Pixel-7 touch emulation, plus a
code audit of `tuning.dart`, `hud.dart`, `player_component.dart`, `catalog.dart`.
Claims below are VERIFIED against code/screenshots unless marked ASSUMED.

**Feel reference:** `docs/reference/apple-knight/feel-notes.md` holds frame-measured
AK physics (jump curve, dash, apple arc, collision FX) with filmstrips/GIFs.
**Visual reference:** `docs/reference/apple-knight/` holds captioned AK
screenshots of every screen (main menu, all three shop tabs, gameplay verbs,
pause menu, controls) — see its README index before working any AKP item.

Each work item has an ID (`AKP-#`) so it can be lifted into `features.json`
verbatim when scheduled. Sizes: XS < 1h, S ≈ half-day, M ≈ 1–2 days.

---

## 1. Character size & camera (AKP-1) — S

**Current:** fixed-resolution camera 480×270 (`ember_game.dart`); player sprite
22×24 logical px → the character is **24/270 ≈ 8.9 % of screen height**.
**Apple Knight:** knight measured at ~103 px in an 824 px-high viewport →
**≈ 12.5 % of screen height** (screenshot-measured). AK also shows far fewer
tiles per screen — the world reads bigger and closer.

**Plan:**
- AKP-1a: change the camera to `withFixedResolution(384, 216)` (same 16:9,
  ×1.25 zoom). Player becomes 24/216 ≈ 11.1 % of screen height — within ~1 pt
  of AK without touching any sprite or physics constant. If the owner wants a
  full match, 352×198 gives 12.1 % but shows only 22 tiles across; recommend
  384×216 first, evaluate on-device.
- AKP-1b: HUD is drawn in viewport coordinates, so the whole HUD scales up
  with the zoom — re-check all HUD geometry after the change (see §5, which
  rebuilds HUD placement anyway; do AKP-1 before AKP-5).
- AKP-1c: level readability pass. At 384×216 only 24×13.5 tiles are visible
  (vs 30×16.9 today). Re-run all level bots (`tool/` completability tests +
  web-harness kbtour) and check that no hazard becomes visible **later than
  1 s of travel time** before it must be reacted to. Bump `kCameraLookAhead`
  24 → 32 to compensate for lost forward sight.
- **DoD:** screenshot at 1280×720 shows player height 10.5–12.5 % of screen;
  all 75+ completability tests green; no level requires a leap of faith.

## 2. Play style / verb set (AKP-2) — M

**Current verbs:** run, jump + double jump, 3-hit melee combo, apple throw,
roll (DOWN+JUMP chord), camera peek-down, platform drop-through.
**AK verbs:** run, jump + double jump, melee swing, apple throw, **dash as a
first-class button**. No chords, no hidden verbs — every verb has a button.

**Known blocker (from playtest):** `EmberGame.touchDown` is declared but never
wired and no down-button asset exists — roll, peek-down, and drop-through are
keyboard-only on the Android build today. The tutorial sign even teaches roll.

**Plan:**
- AKP-2a: promote roll to a **dedicated dash/roll button** (AK's dash slot).
  Keep the DOWN+JUMP chord as a keyboard alternative. Internally it stays the
  existing roll (`kRollDuration` 0.38 s, i-frames 0.28 s) — AK's dash is
  functionally the same commit-dodge.
- AKP-2b: ground-roll only today; AK's dash works in the air. Add an air-dash
  variant: horizontal `kRollSpeed`, gravity suspended for the duration, one
  air-dash per airborne period (resets on landing). Gate behind a tuning flag
  so it can be A/B'd; ASSUMED it will feel right — verify with the bots.
- AKP-2c: wire `touchDown` at last: swipe-down on the movement half of the
  screen (or a small down-chevron under the arrows) for peek-down +
  drop-through. Roll no longer needs it after AKP-2a.
- AKP-2d: keep our advantages — do **not** copy AK's floatier jump. Existing
  coyote/buffer/apex constants in `tuning.dart` stay as they are.
- **DoD:** every verb reachable on touch; bot script that dashes over the
  w1_l1 spike pit passes; repo bot tests extended to press the new buttons.

## 3. Animations & game juice (AKP-3) — M

**Current:** idle/run/jump/fall/roll/hit sheets (22×24), 3 attack sheets
(40×30), dust puffs + enemy-death flash + sparkle (`fx.dart`). No landing
squash, no swing arc, no damage numbers, no hit flash on the player sprite.
**AK:** landing squash-and-stretch, dust on run/land/dash, big readable white
swing arcs, floating damage numbers on every hit, enemy white-flash on hit,
brief screen shake on heavy hits, chest-open coin fountains.

**Plan (all in `fx.dart` / `player_component.dart`, no new art dependencies
except the swing arc):**
- AKP-3a: landing squash (scale 1.15x/0.85y for ~80 ms) + dust puff on land
  and on dash start. Reuse `PuffFx`.
- AKP-3b: swing-arc overlay per attack frame (one 3-frame white arc sheet,
  flipped for facing; tinted per weapon — see §4). This is the single biggest
  "reads like AK" win in combat.
- AKP-3c: floating damage numbers (pooled `TextComponent`s, respect
  `kMaxLiveParticles` budget); crits bigger + weapon-tinted.
- AKP-3d: enemy hit-flash (white overlay paint, 2 frames) — we already have
  `kHitPause` 0.040 s; flash + pause together match AK's hit feedback.
- AKP-3e: light camera shake (2–3 px, ≤120 ms) on: player hurt, combo hit 3,
  boss slam. Never on normal hits (motion-sickness + Android perf budget).
- **DoD:** side-by-side capture of one combat exchange vs the AK reference
  frames in the playtest archive; perf overlay shows no frame > 16.6 ms on the
  fire-pit stress scene.

## 4. Weapons (AKP-4) — M

**Current:** 6 weapons in `catalog.dart` (damage/range/crit/special) but they
are **stats-only** — the player sprite has one baked-in sword; every weapon
looks and swings identically. AK weapons are visually distinct in-hand, have
distinct swing FX, and AK adds a second **spell/projectile slot** beyond apples.
**Plan:**
- AKP-4a: render the equipped weapon. Split the weapon out of the attack
  sheets into per-weapon overlay sprites (6 idle sprites + swing tint). The
  existing skins system (`skins/` + `skinId`) already proves the overlay
  pattern works.
- AKP-4b: per-weapon swing identity: arc color/scale from §3b + per-special
  FX (burn = ember particles, lunge = dash streak, wallBreaker = rubble puff
  on wall hit — `PuffFx` reuse).
- AKP-4c: apples get AK-style lob feel: current `kAppleThrowSpeed` 220 with
  a 45° arc is close (VERIFIED in play); add arc-preview dots while the throw
  button is held (AK doesn't have this — it's a fairness win, keep it subtle).
- AKP-4d (stretch, owner call): a third loadout slot — one "spell" per run
  (e.g. ember burst), bought in the shop like AK's magic. New economy sink.
  Defer unless AKP-1..3 land before the 08-07 production gate. ASSUMED demand.
- **DoD:** switching weapons in the shop visibly changes idle + swing in-game;
  screenshot per weapon attached to the feature evidence.

## 5. Controls & HUD (AKP-5) — S

**Current:** left/right 52 px squares bottom-left (`_buildHud`); sword + jump
round buttons bottom-right; 41 px throw button floating **above** the sword
button over gameplay space; pause 20 px top-right. Playtest findings: player
spawns behind the left arrows (spawn x=40), throw button covered pickups,
pause is below Android's 48 dp minimum.
**AK layout (screenshot-verified):** arrows bottom-left; a **4-button diamond**
bottom-right — dash (left), apple (top), sword (bottom-left), jump
(bottom-right); huge pause top-right; buttons semi-transparent.

**Plan:**
- AKP-5a: rebuild the right cluster as AK's diamond: jump (bottom-right,
  biggest), sword (left of jump), dash/roll from §2a (top-left), apple
  (top-right, still auto-hides when pouch empty). All ≥ 52 logical px after
  the AKP-1 zoom; 6–8 px gaps.
- AKP-5b: pause button ≥ 44 logical px (48 dp equivalent).
- AKP-5c: button opacity ~0.55 idle / 1.0 pressed (AK-style), so buttons stop
  visually blocking pickups; plus fade the movement arrows to 0.25 for the
  first second after spawn **or** shift spawn right of the arrows in level
  data — whichever is less invasive per level.
- AKP-5d: boss HP bar moves below the timer (currently overlaps it).
- **DoD:** spawn frame of w1_l1 shows the player fully visible; all touch
  targets ≥ 48 dp; bot regression suite green with the new layout.

## 6. Onboarding parity (AKP-6) — S

AK teaches every verb on **safe flat ground with an icon popup before the
first hazard**. Our tutorial kills bots in <10 s (spike pit ~1 s from spawn,
chain-killing fire-pit floors). Already on the pre-gate fix list; folded in
here because AK-style onboarding is part of "play style":
- AKP-6a: w1_l1 — first pit moved ≥ 10 tiles right and shrunk to 3 tiles;
  jump taught before it via popup-style sign (icon, not text wall).
- AKP-6b: hazard pits eject the player upward/backward on damage (knockback
  currently doesn't escape the pit → chain deaths).
- **DoD:** naive hold-right touch bot survives ≥ 30 s in w1_l1; all three
  playtest bots clear the level.

---

## Sequencing & estimate

| Order | Item | Size | Why this order |
|---|---|---|---|
| 1 | AKP-1 camera zoom | S | Everything downstream is judged at the new size |
| 2 | AKP-5 controls/HUD | S | Unblocks touch testing of all later work |
| 3 | AKP-2 dash button + touchDown | M | Core play-style parity |
| 4 | AKP-6 onboarding | S | Cheap, blocks the 08-07 production gate |
| 5 | AKP-3 animation juice | M | Biggest visual-parity win |
| 6 | AKP-4 weapon identity | M | Depends on §3's swing FX |
| — | AKP-4d spell slot | M | Stretch, owner decision |

Total ≈ 6–9 working days single-agent. AKP-1/5/6 fit before the 2026-08-07
production gate; 2/3/4 target the following release.

**Non-goals (explicitly keeping our differences):** AK's floaty jump, ad-gated
respawns, energy/FOMO mechanics, its cluttered 6-counter HUD density (we scale
the HUD up but keep it minimal).

**Open questions for the owner:**
1. 384×216 (11.1 % char height, safer) vs 352×198 (12.1 %, exact AK match)?
2. Air-dash: yes/no? (AK has it; changes level difficulty balance.)
3. AKP-4d spell slot: in scope for beta or cut?
