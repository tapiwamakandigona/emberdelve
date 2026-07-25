# Apple Knight — Game-Feel & Animation Notes (measured)

Deep-dive companion to the [AK parity plan](../../ak-parity-plan.md) and the
[screenshot reference pack](README.md). Everything here was measured from a
**25 fps screen recording** (40 ms frame resolution) of the Poki web build of
Apple Knight, played hands-on with keyboard controls (Z jump / X melee /
C ability / V dash) on a Pixel-7-sized viewport (892×412 CSS px; visible game
area ≈ 550×290 px in the capture).

Method: frame-exact extraction with ffmpeg, then per-frame tracking of the
knight's red cape/plume pixels (color clustering + nearest-cluster association)
to get screen-space x/y trajectories. Numbers are screen px in that capture.
Claims are labeled **VERIFIED** (frame data / filmstrips) or **ASSUMED**.

Filmstrips for every verb are in [`feel-frames/`](feel-frames/).

---

## 1. Jump physics — VERIFIED

| Metric | Apple Knight (measured) | Emberdelve (`tuning.dart`) |
| --- | --- | --- |
| Full-jump airtime (hold) | **~0.72 s** (18 frames @25fps) | ~0.72 s equivalent (kJumpSpeed 292, kGravity 1150, 1.6× fall) |
| Rise : fall split | ~0.28 s : ~0.44 s → **fall ≈ 1.5× faster** | kFallGravityMultiplier **1.6** — same convention |
| Tap-jump airtime | ~0.68 s, apex visibly lower (~15–25 px) | kJumpCutMultiplier 0.45 (stronger cut) |
| Double-jump total airtime | **~1.44 s** (36 frames) | comparable (kAirJumpSpeed 265) |
| Double-jump apex hang | **~0.2 s near-zero vy at apex** (5 frames within ±2 px) | kApexGravityMultiplier 0.55, kApexHangSpeed 40 — same idea |
| Jump height (single, screen) | ~60 px ≈ **1.2× character height** | ~2.5 tiles ≈ 1.7× body height |
| Double-jump total height | ~88 px ≈ **1.7× character height** | similar ratio |

Read: **emberdelve's jump curve constants are already very close to AK.** The
felt difference comes from zoom (AKP-1), not from the physics. Do not retune
gravity/jump speeds chasing feel; fix camera scale first, then re-evaluate.

One real delta: AK's tap-vs-hold height difference is *smaller* than
emberdelve's (AK tap jump still reads as a "real" jump). If testers report
emberdelve tap jumps feel stubby, consider raising kJumpCutMultiplier
0.45 → ~0.55. ASSUMED — verify with testers after AKP-1.

## 2. Dash — VERIFIED

- Burst covers **~58 px in 0.16 s before the camera catches up** (≥360 px/s
  screen-space, roughly **3× run speed**); net displacement after camera
  settle ≈ 112 px ≈ **2.2 character heights**.
- Purely horizontal, no arc, usable in air (see 13_controls binding "Dash").
- FX: **large white smoke poof at the start point + horizontal motion streaks**
  along the dash path; knight sprite leans forward. No hit-stop, no i-frame
  flash visible.
- Emberdelve's roll: kRollSpeed 190 px/s for 0.38 s ≈ 72 px in world units —
  similar distance but **half the speed, double the duration**. AK's dash
  reads as a *teleport-adjacent burst*; emberdelve's roll reads as a tumble.
  AKP-2 should keep roll i-frames but consider a faster/shorter profile
  (e.g. ~300 px/s for 0.22 s) if playtests want AK-style snap. ASSUMED —
  tuning suggestion, not measured requirement.

## 3. Sword combo — VERIFIED (filmstrip `feel-frames/sword_combo.png`)

- Each slash draws a **huge white crescent arc overlay ≈ 1.5× character
  height**, semi-transparent, sweeping front-to-back. This single overlay is
  most of AK's melee "juice" — emberdelve currently renders none (AKP-3b).
- Swing visual lasts ~3–4 frames (**0.12–0.16 s**) — snappier than
  emberdelve's kAttackDuration 0.22 s.
- The sword itself is drawn extended horizontally during the active window
  (weapon is visible as a distinct sprite — supports AKP-4a "render equipped
  weapon").
- 3-tap chain accepted with generous buffering (combo chained from mashed
  X presses ~0.5 s apart). Matches emberdelve kComboWindow 0.38 s.

## 4. Apple throw & projectile feel — VERIFIED (filmstrip `feel-frames/apple_throw.png`)

- **Throw FX:** white cartoon poof at the hand on release; knight does a short
  arm-swing anticipation pose (1–2 frames).
- **Flight:** apple is a spinning red sprite; initial trajectory is *flat-ish*
  (slightly above horizontal), ~**225 px/s** horizontal in the capture, with
  gravity bending it down after ~0.3 s. Emberdelve kAppleThrowSpeed 220 px/s
  at a 45°-ish arc — **speed matches, launch angle doesn't**. AK throws
  flatter, which makes the apple usable as a straight poke; emberdelve's 45°
  lob is harder to aim. Recommend lowering launch angle to ~20–25° in AKP-4c.
- **Impact:** white poof burst on hit/ground contact (same smoke language as
  the throw). Emberdelve needs an impact particle on apple collision (add to
  AKP-3 scope).

## 5. Collision / hit animations — VERIFIED

Smoke-poof is AK's universal collision language:
- **Landing:** dust puff at the feet on every landing; small puff on takeoff.
- **Dash:** poof at origin + streaks (see §2).
- **Throw/impact:** poofs (see §4).
- **Enemy hits:** enemies flash and are knocked back; damage numbers pop
  (documented in the screenshot pack, 09_gameplay_sword).
- Emberdelve has none of these today. AKP-3's list (landing squash, hit-flash,
  camera shake) should explicitly add **white smoke-poof particles** as the
  shared vocabulary: land, dash/roll, throw, projectile impact. One reusable
  poof particle component covers 4 verbs.

## 6. Camera behavior — VERIFIED

- The camera keeps the knight **near-locked at x ≈ 29% of screen width**
  (left-of-center anchor with look-ahead in the facing direction) — while
  running, the knight's screen position barely moves; the world scrolls.
- Vertical follow is lazy/smoothed: during the double jump the ground line
  drifted ~26 px down over ~1 s rather than snapping.
- Emberdelve's kCameraLookAhead 24 → 32 (AKP-1b) is directionally right;
  consider also biasing the anchor toward the movement direction rather than
  pure center. ASSUMED — needs playtest.

## 7. Onboarding observations — VERIFIED

- Tutorial teaches with **inline popups** ("RUN", "DOUBLE JUMP" cards showing
  button glyphs) that appear in-world without pausing; gameplay continues.
- First hazard appears only after run + jump + double-jump have each been
  taught. Reinforces AKP-6 sequencing (teach jump before the first pit).

## 8. Level-1 completion status — honest report

Two scripted bot runs attempted level 1 end-to-end. The bot cleared the
opening section (enemies, pits, coins, first vertical wall) but stalled at a
mid-level **vertical climb section** requiring precise wall-platforming
(progress shots show it apple-spamming a cliff face). A second climb-capable
bot was launched; result noted in the PR comment. Level-1 *layout learnings up
to that point* (tutorial pacing, first-pit placement, checkpoint toast) are
reflected in §7 and AKP-6. **Claim "beat level 1": NOT yet VERIFIED.**

---

### Priority nudges for the parity plan (from this session)

1. AKP-1 (zoom) remains the highest-leverage change — jump physics already match.
2. Add **smoke-poof particle system** to AKP-3 as a named deliverable (4 verbs, one component).
3. AKP-4c: flatten apple launch angle to ~20–25°, keep 220 px/s.
4. AKP-2: consider AK-style dash profile (~2× roll speed, ~half duration).
5. AKP-6: adopt inline non-pausing tutorial popups with button glyphs.
