# Owner-directed PR #51 update (2026-07-25 09:30 DM)

Owner answers to open questions: zoom = AK exact (352×198), air-dash = YES,
spell shop = in scope for this PR. Plus new ask: HUD/button alignment pass
(icon centering + all screen sizes + gesture/button nav modes).

## Tasks (one per iteration, plan→act→verify→commit)
- [ ] T1 AKP-1 rev: 352×198 zoom (char ≈12.1% height, AK match); look-ahead
      recheck; readability guard (no leap-of-faith); tests green
- [ ] T2 HUD alignment pass: center icons on movement/dash buttons,
      safe-area-aware layout (notches, gesture vs 3-button nav),
      resolution-relative anchoring; tests
- [ ] T3 AKP-2b air dash: one per airborne period, gravity suspended,
      resets on landing, tuning-flagged; bot + unit tests
- [ ] T4 AKP-4d spell shop: spells in catalog + shop section + save/equip +
      in-game cast button + ember burst effect; tests
- [ ] T5 verify loop: analyze clean, full test suite, web-harness evidence
      screenshots; progress.md entry; push; PR #51 description update

## Evidence log
- Baseline before work: (to fill after first test run)
