# Competitive depth + performance direction (2026-08-12)

Owner ask: *"How can we improve the game, 3d? look at competitors and out do
them, while still keeping the performance good and better and optimising."*

## Decision: dimensional 2.5D, not a full-engine 3D conversion

Classic should keep its deterministic Flutter game and gain **selective
dimensionality**:

1. physically convincing dice (perspective, thickness, cast shadow, lighting,
   throw/settle);
2. a layered combat diorama (far cavern, ember haze, floor plane, combatants,
   foreground silhouettes) with tiny relative parallax;
3. stronger hit lighting, contact shadows, and depth-scaled motion;
4. static/cached geometry and presentation-only motion — no physics engine,
   mesh loader, 3D scene graph, or additional game loop.

A full 3D conversion is the wrong trade for Classic. It would replace a tested,
small portrait UI with a second rendering stack, enlarge the build and asset
pipeline, introduce camera/occlusion/readability problems, and make the
Android-9 OpenGL fallback the hardest target. It would not fix the current
competitive gap, which is mainly **content breadth, build identity,
readability, and tactile cause→effect**, not polygon count.

This does not constrain Emberwood, the separately named action-game alpha.

## Competitor benchmark

Sources were checked on 2026-08-12. Counts below are store/developer claims,
not independently audited.

| Game | What it wins on | Exposed weakness / opening for Emberdelve |
|---|---|---|
| **Slice & Dice** | Real 3D dice physics; undo; everything visible; portrait + landscape; free demo/single purchase; 128 hero classes, 73 monsters, 473 items, many modes/modifiers. | Symbol density can become mentally expensive. Emberdelve can be the more immediately legible, cinematic one-thumb alternative while retaining explicit intent and resolved-value previews. |
| **Die in the Dungeon** | Dice-face customization plus a spatial placement board; four distinct frogs; 31 dice, 142 relics, 36 potions; character progression. | Reviews call out board illegibility when effects stack and slow runs. Emberdelve should make combinations large, staged and readable rather than stacking status glyphs on a matrix. |
| **Astrea** | Exceptional watercolor identity; Purification/Corruption creates a unique risk axis; 350+ dice, six Oracles, 170+ Blessings, 16 difficulties. | Information/load and early RNG are recurring friction. Emberdelve can beat it on compact mobile comprehension and fairness: intent, previews, deterministic resolution, exact post-action accounting. |
| **Dicefolk** | Hand-drawn monster-catching identity and 100+ recruitable Chimeras; control of both sides' dice is a memorable hook. | Reviews cite shallow/repetitive run decisions despite the creature count. Emberdelve needs fewer but more transformative choices and visibly evolving builds. |
| **Dicey Dungeons** | Six radically different characters, charming art/music, many episodes plus free Reunion content; excellent pick-up/resume mobile fit. | Some Android reviews report crashes/effect-animation issues; early patterns can feel repetitive. Emberdelve can win on stability, low battery use and daily/weekly replay structure. |
| **Peglin** | Aiming/peg contact gives every turn an unmistakable tactile toy; free first third + one unlock. | Current Google Play rating trails the leaders; randomness and mobile polish are openings. Emberdelve needs an equally ownable toy moment: the dice throw→select→weapon-charge→impact chain. |
| **Balatro** | Rule-breaking build identity, 150+ Jokers, extremely clear scoring escalation, distinctive CRT/pixel treatment, touch-remastered controls. | Android reviews include heat/battery complaints even on high-end phones. Emberdelve should treat cool-running/offline play as part of quality, not merely an implementation detail. |

### Sources

- Slice & Dice official: https://tann.fun/games/dice/ ·
  https://store.steampowered.com/app/1775490/Slice__Dice/ ·
  https://play.google.com/store/apps/details?id=com.com.tann.dice
- Die in the Dungeon:
  https://store.steampowered.com/app/2026820/Die_in_the_Dungeon/
- Astrea: https://store.steampowered.com/app/1755830/Astrea_SixSided_Oracles/ ·
  https://www.akuparagames.com/game/astrea-six-sided-oracles/
- Dicefolk: https://store.steampowered.com/app/1996430/Dicefolk/ ·
  https://www.goodshepherd.games/games/dicefolk
- Dicey Dungeons: https://store.steampowered.com/app/861540/Dicey_Dungeons/ ·
  https://play.google.com/store/apps/details?id=com.terrycavanaghgames.diceydungeons
- Peglin: https://store.steampowered.com/app/1296610/Peglin/ ·
  https://play.google.com/store/apps/details?id=com.RedNexusGamesInc.Peglin
- Balatro:
  https://play.google.com/store/apps/details?id=com.playstack.balatro.android
- Flutter performance: https://docs.flutter.dev/perf/impeller ·
  https://docs.flutter.dev/perf/best-practices ·
  https://docs.flutter.dev/perf/ui-performance

## Where Emberdelve was at the audit baseline

The current combat screenshot is readable and one-thumb friendly, but it is
visually flat: the combatants float in a large dark middle band, the dice read
as five independent icons rather than one physical tray, and the most valuable
object — the roll — has less visual mass than the static HP/header chrome.

The implementation is already unusually performance-conscious:

- idle title: 3 painted render objects/frame;
- idle combat: 2/frame;
- rapid die selection: 20/frame after scoping;
- full combat interaction storm: 96.2/frame;
- map drag: 9.5/frame after layer isolation.

Those are debug render-object proxies from the deterministic local probe, not
physical-device milliseconds. The profile integration test exists; physical
low-end evidence remains the honest final gate.

## Competitor-beating product pillars

### 1. The best dice *feel* on Android

Make the roll Emberdelve's recognizable toy:

- die thickness + top/side lighting and a grounded contact shadow;
- a perspective lean during flight, not just flat Z rotation;
- one crisp landing compression and per-die haptic;
- selected die visibly charges the character weapon;
- assignment ghost flies into ATTACK/BLOCK;
- impact shows the exact resolved contribution.

Slice & Dice owns generalized 3D physics. Emberdelve should own the **causal
chain from die to weapon to damage**, which is more useful to this combat.

### 2. Best-in-class mobile readability

- Never stack unrelated intent/status symbols.
- Keep previewed ATTACK/BLOCK values before commitment.
- Add tap/hold inspection everywhere a modifier appears.
- For future complex dice, print one dominant verb/value on the face and put
  detail in the inspector — do not reproduce the unreadable board problem.
- Keep portrait and one-thumb as the primary composition.

### 3. Builds that visibly become *yours*

The large content leaders are far ahead in raw counts, so do not try to catch
them through dozens of low-impact additions. Add a smaller set of
run-defining systems:

- forgeable **die faces**, not only die-size swaps;
- 8–12 transformative keystones that alter rules, with strong visual states;
- signature weapon evolution tied to the run's strongest die/synergy;
- victory recap showing the exact pool and combo engine the player built;
- enemy families that test different build axes rather than reskins.

### 4. Cool-running is a feature

Target the opposite of mobile ports that heat phones:

- 60 fps frame budget: UI p90 <8 ms and raster p90 <8 ms on the low-end test
  device; no frame >16.7 ms in ordinary idle/selection loops after warm-up;
- idle combat/title rebuilds: 0; preserve current 2/3 paint-proxy floors;
- 30 fps **eco mode** for always-on ambience, while input/roll/impact can burst
  at display rate;
- pause all animation tickers and audio ambience when app is backgrounded;
- no runtime blur in persistent animation; no `saveLayer()` in hot paths;
- cache static text, paths, gradients and background layers;
- texture atlas/page budget; no individual 4K textures;
- keep Play per-device download under 30 MB after audio recompression;
- memory target <180 MB peak on a 3 GB device; no growth across ten runs.

These targets must be recorded from a **profile build on physical hardware**.
Flutter's documentation explicitly warns that debug/emulator timing is not
representative.

## Iteration-1 result

Accepted after screenshot and repaint/rebuild critique:

- deterministic analytic pitch/yaw/squash now composes with the existing
  throw and settle motion;
- one existing die-face painter now supplies directional warm/cool light,
  d6 lower/right planes, face content and selection/mod rings;
- the combat middle band now has a static cached floor plane, converging
  seams, ember pool and foreground silhouettes;
- combatant contact shadows are darker and better grounded;
- no sim/save change, new asset, package dependency, blur, `saveLayer()` or
  continuously animated scene layer.

The first widget-heavy version was rejected: rapid die interaction went
20.1→23.2 paints/frame and the full combat storm 96.2→107.7. After collapsing
the treatment into the existing painter, the accepted debug proxy is
20.1→19.9 and 96.2→96.6; title/combat/map idle floors are unchanged. These are
render-object proxies, not physical-device frame milliseconds.

Screenshot critique also caught duplicate edge lines over the already faceted
d8/d10 art; those were removed before acceptance. The final evidence shows
the floor plane, grounded combatants, clean faceted dice and visible d6
thickness without reducing value readability.

## Next implementation sequence

1. ~~**Dimensional dice v1**~~ — complete in iteration 1.
2. ~~**Combat diorama**~~ — complete in iteration 1.
3. **Impact-light pass** — localized warm flash on contact and enemy shadow
   response, contained within stage boundaries.
4. **Power visibility** — weapon appearance evolves from run state; victory
   gets a “pool forged this run” strip.
5. **Mechanical differentiation** — face forging + a small keystone set,
   designed under a deliberate sim-version contract and balance run.
6. **Content multiplication** — more bosses/families/modes only after each
   choice creates a new decision pattern.
7. **Performance release gate** — physical low-end trace, thermal/battery
   session, memory soak, APK/AAB budget, and accessibility/overflow probes.

## Hard no's

- No Flutter↔Unity/Godot embedded view for a single screen.
- No live 3D physics deciding gameplay results; simulation resolves first.
- No always-running particle system outside a repaint boundary.
- No post-processing stack just to look “3D”.
- No tiny glyph soup, even if it increases nominal content count.
- No visual upgrade that changes sim hashes or autosave compatibility.
