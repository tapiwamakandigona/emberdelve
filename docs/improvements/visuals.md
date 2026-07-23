# Improvement backlog — Visuals ("stop looking like a Flutter app")

**Status:** proposal (Viktor, 2026-07-23), grounded in the v0.2.0 emulator evidence
(`checkpoints/03-assets-and-release.md`) and the current UI code (`lib/ui/`). Read
`docs/design-system.md` and PROJECT.md decision #7 (art direction: dark, high-contrast,
cartoony pixel-painterly, 48–64 px sprites, portrait; **no AI-generated animated sprites**;
paid packs need owner budget approval BEFORE purchase) before changing anything.

**Diagnosis:** v0.2.0 integrated real assets (backgrounds, sprites, node/relic/die icons,
choreography) and the wiring is sound (`lib/ui/art.dart`, `lib/ui/sprites.dart`). But the
overall *composition* still reads as "well-themed Flutter app," not "game": screens are built
from Material primitives (rounded rect cards, stock buttons, plain progress bars) laid over
art, and several screens use little or none of the art we have. The gap is no longer assets —
it's presentation. Caveat: emulator screenshots show decode failures that are **emulator-only**
(proven, see checkpoint 03); judge final visuals on a real device before/after each change.

## A. Screens that need the most love

1. **Title screen.** Currently: wordmark in a serif font + two stock buttons over `bg_title`.
   Needs: a real *logotype* (custom-drawn "EMBERDELVE" with ember glow/char treatment, shipped
   as an image, not a Text widget), slow ember-particle drift + subtle background parallax,
   and the delver sprite idling by a fire. This one screen sets the quality expectation.
2. **Map screen.** Currently: flat colored circles + 1 px lines; node icons exist
   (`assets/images/ui/nodes/`) but the scene has no depth. Needs: nodes as framed medallions
   (ring + icon + soft shadow), path drawn as a textured/dashed trail, fog-of-war or vignette
   on unreachable rows, a small "you are here" delver marker that walks node-to-node, and
   pulsing glow only on reachable nodes. Map should feel like a descent (darker + hotter per
   layer — tint shift per act).
3. **Combat screen.** Currently: HP bars + text panels + dice as `DieChip` rounded rects
   (die PNGs exist: `assets/images/ui/dice/die_d*.png` but chips read as buttons, not dice).
   Needs: dice rendered as actual die faces (pip layouts per value on the die art, not a
   number in a box), enemy grounded on a floor plane (shadow ellipse + slight scale by depth),
   intent shown as an icon badge above the enemy (not text), and HP bars skinned (segmented,
   ember-styled fill with damage "chip-away" ghost trail).
4. **Character select / rewards / shop / event screens.** All are Material card lists.
   Reuse one skinned "parchment/charcoal panel" container (9-slice or custom painter) with
   the character/enemy/relic art doing the talking; rewards should present as 3 physical
   cards you flip/pick, not a vertical list.

## B. Systemic look-and-feel (the "de-Flutter" pass)

5. **Replace Material chrome everywhere:** custom `ButtonStyle`/painters for the 3 button
   tiers (primary ember, secondary charcoal, ghost), skinned sliders in settings, custom
   page transitions (ember-wipe or fade-through-black instead of default route slide).
6. **One global palette + lighting rule.** Everything lit warm-from-below (ember light),
   cool shadows. Run all art + UI tints through the palette in `lib/ui/theme.dart`; kill
   any remaining default Material colors (the green map "start" node, stock focus colors).
7. **Typography:** the serif display face works for headers; body text is still default-ish.
   Pick the pair deliberately (display + UI face), embed both, and set a real type scale in
   `theme.dart` per `docs/design-system.md` §typography.
8. **Icon unification.** Node/relic/currency icons come from different packs (game-icons.net
   etc.) — normalize: same stroke weight, same 2-tone tint ramp, same padding inside their
   medallion frames. A batch retint script in `tool/` keeps this reproducible.

## C. Motion (overlaps gameplay-depth.md §D — coordinate, don't duplicate)

9. **Combat juice:** screen shake scaled by damage, ~80 ms hit-stop on big hits, damage
   numbers that pop/arc/fade, death dissolve into ember particles (current: flash/fade
   collapse tween), attack lunge already exists — add anticipation frame (squash) before it.
10. **Dice tumble:** on roll, dice physically tumble/settle (rotation + bounce + SFX + light
    haptic), stagger 40–60 ms per die. This is the single most-watched animation in the game.
11. **Ambient life:** ember particles drifting on title/map/rest, sprite idle loops already
    run at 8 fps — add occasional blink/flicker variants so idles don't feel metronomic.
12. **Transitions between phases:** map→combat should smash-cut with a flame wipe + boss
    fights get a name-plate splash ("SOOT SHADE — Layer 1"). Victory/defeat screens deserve
    a designed moment (embers rising / dying) — they're currently the plainest screens.

## D. Production notes for the implementing agent

- Asset provenance rules are strict: `PROVENANCE.md` + `CREDITS.md` must be updated for every
  new asset; licensed (non-CC0) files must never enter a public repo; no AI-generated
  animated sprites (owner decision #7). Static AI concept art was previously allowed only
  where PROVENANCE.md says so — check before adding.
- All PNGs are canonically re-encoded (PIL optimize) and covered by
  `test/decode_probe_test.dart` — run it after adding any image; add new files to the probe.
- Keep `FilterQuality.none` for pixel art; scale only by integer multiples where possible.
- Sprite sheets have no attack/death frames; choreography substitutes tweens (documented in
  progress.md). If buying packs with real attack/death frames, that needs owner budget
  approval first.
- Do visual work behind small PRs per screen; screenshot before/after on the emulator
  (accepting its known decode artifacts) and flag anything needing real-device confirmation
  as OWNER-GATED, matching the existing convention in `features.json`.

## Suggested priority

**#3 combat dice+juice → #2 map scene → #1 title → #5 de-Flutter pass → #12 transitions.**
Combat is where players spend 70% of their time; the title screen is what store visitors
screenshot. Everything else follows.
