# v1.0.0-alpha.15+27 — Crown Strike (w2_boss sign fix + boss design gate)

## For testers

- **The Kiln Golem's sign now tells you how to actually fight it.** The old
  sign said "Keep moving!" — ground-fight advice for a boss that ground
  attacks cannot reach: it is walled into its kiln pen, and no melee swing
  connects from the floor. The real route (the apples on the pillar tops
  were the breadcrumb) is to jump the fire moat, climb the vent pillars, and
  strike its crown from above. The sign now coaches exactly that.

## Why (design-intent review, not a nerf)

- The alpha.14 sweep left both bosses wiping the casual masher probe
  (pct 42-46). Review question: intended skill gate or unfair? Built a
  coached-strategy bot per each boss's fiction:
  - Grove Golem (w1): "watch its wind-up - then strike" — hit-and-run,
    retreat on telegraph, hop shockwaves/rocks. COMPLETED all 4 seeds,
    22 s, 1 death. VERIFIED fair as designed.
  - Kiln Golem (w2): every ground-play bot dealt **0/60 damage** — the pen
    (`###.M.###`, 48 px interior vs 44 px boss) blocks all floor melee.
    Perch bot (moat jump -> pillar crown -> head poke, sidestep mortars):
    COMPLETED all 4 seeds, 13 s, 0 deaths.
- So the fights stay untouched (hp, pacing, hazards unchanged; masher still
  wipes — fairness_test pins that as a skill check by design). The defect
  was information: the mandatory w2 strategy was never hinted, and the sign
  actively coached the wrong one.

## Implementation

- assets/levels/w2_boss.txt: sign1 rewritten (meta-line only, grid rows
  untouched, width uniformity asserted at 56).
- New permanent gate `test/boss_intent_test.dart`: the coached-strategy bot
  for each boss must COMPLETE the level on seeds 7/13/42/99 with deaths <= 2.
  Red if an edit breaks the w1 strike windows, the w2 fire-moat jump, the
  pillar climb, or the crown reach (e.g. taller pen walls, wider moat,
  reach nerf).

## Results

- boss_intent gate: w1 22 s/1 death, w2 13 s/0 deaths, all seeds.
- Suite 411 passed + 1 skipped, analyze clean.
- Look pass phone 915x412 + desktop 1280x800 at the sign site: new text
  renders in the bubble marquee, no clipping (a15 shots).

## Next candidates

- On-device perf (P-M7, hardware); Play beta (P-M10, owner call).
- w1_l1..w2_l5 + bosses now all have a green completion story — next
  gauntlet lens could be polish (audio/juice) or content.
