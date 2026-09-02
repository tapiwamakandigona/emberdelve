# R9 — First-session teaching: reconciling R8 with the testers, and the smallest change (spec, no code)

Owner directive 2026-09-02c, item 1. Everything below is read from `progress.md`
(`PLAYER_FEEDBACK` entries) and the code at `legacy/dice-builder`; nothing is inferred from memory.

## 1. The two facts, and why both are true

**Fact A (R8):** the v0.179.0 teaching layer matches what Slice & Dice's and Shattered PD's
developers describe — non-forcing anchored tour, first-contact tips, re-readable How-to-play.

**Fact B:** every tester who left words asked for a manual or tutorial. Verbatim, with the
build they were playing:

| Date | Build on the tester's device | Quote (verbatim, `progress.md`) |
| --- | --- | --- |
| 2026-07-24 | v0.3.9+12, Play closed testing | "How is damage calculated?" |
| 2026-07-25 | v0.3.9/v0.3.10 closed testing (4 entries 4–5★ + one email) | "blocking isn't doing anything" · "some text is on the screen but it's so fast I can't quite read it" · "not sure how to see the telegraphs" · "hard time with even the easy difficulty" · "just add a manual or instructions or a tutorial" |
| 2026-08-23 | WhatsApp review, exact build **not recorded** (before v0.30.0 "The Delver's Primer", 08-24) | "I still don't understand what's a delve but it doesn't matter I enjoyed the gameplay" |
| 2026-08-31 | Play Console tester feedback, build not recorded (Play served 0.59.0) | "Add more delvers, I need more… give mee moreee. Good game tho" |

**Reconciliation:** every teaching ask came from a build that had none of the current layer.
The tips (`lib/game/tips.dart`) arrived in v0.10.0, the anchored tour (`lib/game/tour.dart`) in
v0.26.0 (2026-08-23), the delve premise tip in v0.30.0, First Words in v0.71.0, the gifted codex
entry on 2026-09-01. The one tester who has spoken since (31 Aug) asked for content, not
instructions. R8 compared today's code to the comparables; the testers judged July's code. Both
statements hold. What neither establishes is whether the current layer *works* — nobody has
watched a new player use it, and the game records nothing (by rule).

## 2. What delve one demands that only the codex explains

Walking the run screens for first-contact teaching (`grep tipDirector\|tour\. lib/ui/screens`):
combat, map, rest and title have moments; boon, shop, event, reward, keystone, summary have none
but carry their own plain copy ("Choose a boon — A blessing for this delve — or walk in
unaided.", "Spend your gold before the descent.", "Heal N HP", a RECOMMENDED badge). None of
those needs the codex.

**One thing does.** From layer 5 of a 9-layer delve (`map_gen.dart:41`, `enemies.dart:358,371`
`fromLayer: 5`) the Vent Ram and Cinder Urchin bring the *response-puzzle* intents `charge` and
`counter`. Their badge is icons and numbers only (`badges.dart:151–157`: flash-on 34 / flash-off
9; sync-alt 3). The words that decode them exist in the build — `_explainIntent`
(`combat_screen.dart:432`: "CHARGING 34 — DEAL 9 TO BREAK", "COUNTERING — EACH STRIKE COSTS 3")
— but fire **only on long-press** (`stage.dart:223`), and nothing in the tour, tips or How-to-play
deck says a long-press exists (`grep -rn "long press" lib/ui/screens/tutorial_overlay.dart
lib/game/tour.dart lib/game/tips.dart` → nothing; only the accessibility label knows). The
`blockFades` tip fires on a big `charge` too, but talks about block, not the break threshold.
The other place the answer lives is the codex foe entry ("Strike it hard mid-breath and the whole
engine stalls") — sealed behind embers. A first-run player who reaches layer 5 is meant to solve a
puzzle whose rules are printed nowhere they can see. This is the exact shape of "not sure how to
see the telegraphs", one layer deeper.

## 3. The smallest change — "The Spoken Badge"

**What it shows.** The existing `_explainIntent` call-out text, unchanged, for the intent kinds
that are *not* plain attack/block: `charge`, `counter`, `stagger`, `attack_block`. No new card, no
new overlay, no new copy beyond one sentence (below).

**When.** Automatically, the first time ever an enemy *declares* each of those kinds — at the
moment the badge appears, before the player rolls, so the answer is on screen while the puzzle is
live. One kind per turn; if another first-contact would collide it waits for its next
occurrence (the `TipDirector` "no queue, no wall" rule, `tips.dart` header). Never while a tour
beat is on screen (same suppression as tips).

**How it is dismissed forever.** It is a call-out, not a card: it fades on the existing
`_note` timer and needs no tap. Persistence is one entry per kind in the existing
`MetaState.tipsSeen` set (`intent_charge`, `intent_counter`, `intent_stagger`,
`intent_attack_block`) — union-merged in cloud like every other tip, seeded for veterans the way
`tipsSeen` was seeded from `tutorialSeen`. A player who wants it again long-presses, as today.

**One sentence of copy, once.** The tour's `ITS NEXT MOVE` beat (`tour_overlay.dart:69–73`)
gains a second line: "Hold the badge to hear it in words." That teaches the long-press to every
future player and costs one `tourVersion` bump — which re-shows the tour to veterans. If that is
judged too loud, add the line to the How-to-play `THE DARK FIGHTS FAIR` card instead and leave
`tourVersion` alone.

**What it does not touch.** `lib/sim` (pure Dart, untouched); no new screen; no scrolling; no
metric; no dependency on the codex. Save-format change is additive (`tipsSeen` strings only).

**Tests it would need** (for whoever implements, later): `tips_test.dart` — each kind fires once,
never during a tour beat, never twice across a cloud merge; a combat-screen widget test that the
call-out text equals `_explainIntent`'s for the same intent; the existing plate sweep at 320×568.

## 4. What would prove or disprove the need before building it

One observed session: a new player on a fresh install, easy or steered-easy, watched to layer 5
or death. If they read the charge badge and break it without prompting, this spec is unnecessary
and should be closed. If they turtle into a 34, build §3. That is a ten-minute owner task and
the only evidence that would settle it. Feature work stays frozen until then.
