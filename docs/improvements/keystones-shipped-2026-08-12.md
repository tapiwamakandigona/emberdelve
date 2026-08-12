# Keystones — what shipped, and the golden re-anchor it forced

v7 Face Forge, iteration 06. The four keystones drafted in
`face-forge-keystones-2026-08-12.md` are now live in the sealed sim, with a
real acquisition point rather than a test-only seam.

## The four

| Keystone | Rule | Where the arithmetic lives |
|---|---|---|
| Ashen Edge | First attack each turn gains +1 per **other** die still unspent | `resolveAssignment` |
| Living Bastion | Half of **unused** block carries to next turn, floored, cap 8 | `combatEndTurn` |
| Crown of Twelve | Each assignment gains +1 per **extra die size** used this turn | `resolveAssignment` |
| Twin Bellows | Alternating attack/block pays +1, +2, +3 (cap); repeating a verb resets | `resolveAssignment` |

Three of the four are assignment-time, so they run through the single shared
resolver and the on-screen preview shows the same number combat emits. Living
Bastion is the one end-of-turn effect; it reads the block the shown intent
actually consumed, so a wall that was never tested carries, and one that
absorbed a hit carries only what was left.

Ashen Edge never counts the die being assigned. A lone final die therefore pays
nothing — the keystone rewards striking *early*, which is the decision it is
supposed to create. Its charge burns on the first attack whether or not any
other dice remained, so it cannot be banked by opening with a block.

## Acquisition

One keystone per run, offered after the **first won fight**, before that
fight's die reward. Three cards drawn from the `offer` stream — whose only
other consumer is `start_run`, so no other stream shifts — and declining is a
first-class button.

Early on purpose. These keystones reward a *pattern of play*, not a specific
die, so knowing yours on fight one gives the rest of the run a goal ("I am
building for variety") instead of being a reward for a build you already
finished. It is also the only spot that is effectively guaranteed: every run
that reaches the boss has won a fight.

The ledger holds up to three (`keystoneCap`), and `run['keystone_offered']`
makes the offering strictly once per run. Later acts can spend the remaining
two slots without a migration.

## Deliberate golden re-anchor

Adding an offering to every run adds events to every run, so every event hash
moved. This was expected, not a regression, and was re-anchored once with the
old → new values recorded in `test/sim_test.dart` beside each constant:

| Anchor | Old | New |
|---|---|---|
| `goldenV6` (seed 20260723) | 2013675017 | 1507173787 |
| ashen_colossus | 1729684958 | 201437516 |
| ember_tyrant | 2013675017 | 1507173787 |
| pyre_matriarch | 537528265 | 625118910 |
| cinder_hierophant | 1258842264 | 1042046624 |
| the_bellows | 1746127677 | 2005745586 |
| ashfall_twins | 1800621184 | 642212611 |

Every value was measured twice per seed and came back identical.

## Balance

`tool/keystone_balance_probe.dart`, 200 seeded autoplay runs:

- keystone declined (control): **64.0%**
- keystone taken: **66.0%**

A two-point lift is the right size for a single run-long rule that a greedy bot
can only partly exploit — the bot cannot plan alternation or size variety, so a
human should get more out of Twin Bellows and Crown of Twelve than this
measures. The ascension ladder stays monotonic: 67.5% at asc 0, 27.5% at asc 3,
9.2% at asc 6, 0% at asc 12 and 20.

## Visual sweep

`tool/keystone_visual_test.dart` captures the real screen inside a real run at
412×915, 360×640, and 412×915 @ 1.6× text. Widget tests ship no real font, so
these plates judge layout, not typography. One defect found and fixed: at 1.6×
the heading ran off both screen edges; it is now padded and wraps.

Known and accepted: at 1.6× only the first card is above the fold. The list
scrolls, and the boon and reward screens behave identically, so this is the
house pattern rather than a keystone-specific flaw.

No RECOMMENDED chip here, unlike the boon and reward screens. Those rank offers
by power, which is honest for dice and stats. Keystones are playstyle picks
with no correct answer, and stamping one of them "recommended" would be a
confidence the game has not earned.

## Still open

Rune marks on dice and combat rune feedback, the rest-node temper UI, and a
keystone indicator in the top bar. The chooser screen shipped with this
iteration so the phase is never a dead end.
