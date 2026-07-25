# Legacy Feel Plan — dice-builder edition

**Goal (owner-directed, 2026-07-25):** the same treatment PR #48 gave the
platformer, applied to the **legacy dice-builder** (this branch, the build
that is live in Play closed testing): a hands-on playtest of the real game,
frame-level analysis of its animations and feel, comparison against the
genre's best mobile dice-builder, and a concrete, sequenced work plan.

**Evidence base:** hands-on playtest 2026-07-25 — Emberdelve legacy
(`legacy/dice-builder` @ `4d90237`, v0.3.10+13) built for web and played with
Pixel-7-class touch emulation (412×892). Beat the layer-1 fight (Ember
Beetle) and the layer-2 fight (Cinder Wisp) on Easy, sampled boon / reward /
map screens; the full 15-minute session was screen-recorded and the key
moments cut into the GIFs/filmstrips in `docs/reference/legacy-feel/`
(see its README for the index). Comparables, two of them: **Dicey Dungeons**
(Terry Cavanagh, 1M+ copies — the genre's biggest name) — **played hands-on**
2026-07-25 via the last free public web build (v0.9.1,
terrycavanaghgames.com/dice/9) on the same Pixel-7 rig, screen-recorded: a
full Warrior floor-1 fight vs a Rogue, won via tweak → sword → Fury limit
break (GIFs in `docs/reference/legacy-feel/dicey/`, findings in §0b).
**Slice & Dice** (tann, ~4.8/5, the premium mobile dice-builder benchmark) —
its demo is download-only, so comparison uses frame-by-frame analysis of the
official 3.0 trailer (contact sheet in the same folder) plus store-page
research. Code audit:
`combat_screen.dart` choreography constants, `fx.dart`, `weapons.dart`,
`widgets.dart` (DieChip), `haptics.dart`, `sprites.dart`, `enemies.dart`.
Claims are **VERIFIED** (played/recorded/code-read) unless marked ASSUMED.

Work items carry IDs (`LFP-#`) so they can be lifted into `features.json`
verbatim. Sizes: XS < 1h, S ≈ half-day, M ≈ 1–2 days.

---

## 0. What already lands — don't relitigate

The combat-feel passes (v0.3.4 → v0.3.10) show up on screen. VERIFIED in
play, matching the constants in code:

| Beat | Measured behaviour | Code anchor |
|---|---|---|
| Attack anatomy | raise 90 ms → swing 230 ms easeInCubic into the 250 ms contact frame → recover; smear arc trails the blade | `weapons.dart`, `_contact` 250 ms |
| Impact | 80 ms hit-stop, 140 ms knockback, 120 ms flash tail, damage pop, spark burst | `combat_screen.dart` consts |
| Death | 700 ms dissolve; boss kill gets white-hot freeze + full shake | `_deathTime`, feel-v2 notes |
| Dice roll | 520 ms tumble, 50 ms/die stagger, faces cycle mid-tumble, hop+rotate | `DieChip`, `tumbleDelayMs: (i-1)*50` |
| Max roll | golden halo on the die; selected pips heat the weapon (glow + sparks) | `d6 MAX` halo, `_weaponCharge` |
| Call-outs | PAIR/BLOCKED/etc. hold 2 s (tester-driven fix, v0.3.10) | `_noteLife` 2000 ms |
| Reward | offers auto-flip as 3D cards, 220 + 240·i ms stagger; RECOMMENDED default | `reward_screen.dart` |
| Map | 650 ms walk to the next node, 1600 ms intro sweep | `map_screen.dart` |
| Haptics | 18/38/70 ms direct-Vibrator beats (bypasses the Android touch-feedback gate) | `haptics.dart` |

Filmstrips: `filmstrip_attack.png` (full swing at 10 fps — anticipation,
smear, −4 pop, recovery), `filmstrip_tumble.png`, `filmstrip_enemyhit.png`.
GIFs: `attack_swing.gif`, `roll_tumble.gif`, `enemy_hit_block.gif`,
`kill_dissolve.gif`, `pair_kill_victory.gif` (reward flip),
`map_walk.gif`, `risky_reroll.gif`, `title_delve.gif`.

The plan below is therefore not "add juice" — that exists — it is about the
five places where the playtest showed the game still reads *flat or unclear*
next to the genre benchmark.

## 0b. What Dicey Dungeons does that we should steal (hands-on findings)

Played, not watched (VERIFIED, `docs/reference/legacy-feel/dicey/`):

1. **Dice are draggable objects, and slots are verbs.** Every action is
   "physically pick a die up and drop it into an equipment card"
   (`dd_slot_attack.gif`). The drag itself is the assignment preview — you
   see where the die will land before you commit, and an invalid slot just
   refuses it (Sword wants EVEN). This is the strongest possible version of
   LFP-2's cause→effect link; our tap-select/tap-verb keeps one-thumb reach,
   but the *die must visibly travel to the verb* to buy the same clarity.
2. **The enemy plays your game, face-up.** On its turn the Rogue's own dice
   roll on screen and its equipment cards (Lockpick, Dagger with "MAX 3 —
   reuseable") flip up and get used one by one (`dd_enemy_turn.gif`).
   Reinforces LFP-3: intent isn't a badge, it's *shared mechanics made
   visible*. Our cheap version stays the badge — but statuses must not
   contaminate that channel.
3. **Manipulation is a skill with a budget.** "Tweaks: 1 left" (±1 pip) and
   a one-shot Reroll button sit beside the dice; a *limit-break bar* (Fury:
   "double next action") charges as you take damage and cashes in on a
   drag (`dd_fury_kill.gif`). Direct ancestor of our risky-reroll — but DD
   shows the budget permanently on the skill panel, while ours hides the
   cost inside button copy (LFP-6b).
4. **Constraint slots create the puzzle.** EVEN/MAX-3/COUNTDOWN slots turn
   each roll into a matching problem. Our attack/block free-assignment is
   simpler by design (spec §3) — but face-constrained *dice* (min 3,
   +2 on max) already point the same direction; worth keeping in mind for
   act-2 content rather than a new workstream.
5. **What we already do better** (honest): DD v0.9's turn has zero
   choreography — damage applies with a text pop and a red tint flash,
   no wind-up/hit-stop/knockback (`dd_enemy_turn.gif` vs our
   `filmstrip_enemyhit.png`); no haptics; landscape two-hand layout vs our
   portrait one-thumb. The full commercial DD added juice later — the
   free build makes the gap measurable.

**Plan impact:** LFP-2a upgraded from "nice" to the highest-leverage item
(DD proves the die-travel metaphor carries the genre); LFP-3 unchanged;
LFP-6b gains "show the reroll budget on the panel like DD's Tweaks
counter". No new workstreams.

## 1. Physical dice (LFP-1) — M

**Current:** dice are flat UI chips in a fixed tray row. The tumble is good
(hop, rotate, cycling faces) but it happens **in place** — nothing is thrown.
**Slice & Dice:** the roll is the signature moment — 3-D-looking dice are
physically flung across the field, tumble with momentum, bounce and settle
scattered (trailer contact sheet, rows 1–2). That single effect carries most
of the game's tactile identity, and it's why "roll" feels like a *gamble*
there and like a *refresh button* here (VERIFIED play impression, both games).

**Plan:**
- LFP-1a: on roll, dice launch from a throw origin (bottom-center, where the
  thumb is) with per-die arc, spin, and 1 soft bounce, then settle into the
  existing tray slots. Reuse the current tumble face-cycling during flight.
  Pure presentation: result stays sim-determined before the animation starts
  (seam discipline unchanged); total flight ≤ 520 ms so pacing doesn't slow.
- LFP-1b: settle beats trigger the existing light haptic per die (stagger
  makes it a rattle — S&D does exactly this audio-side).
- LFP-1c: risky-reroll rerolls only the picked dice — only those re-fly.
- **DoD:** side-by-side capture roll vs `roll_tumble.gif` baseline; all
  `flutter test` + `tool/play_session_test` green (drain covers the flight);
  60 fps on the perf overlay with 8 dice.

## 2. Assignment legibility (LFP-2) — M

Playtest finding (and I *lost HP to this*): assign-time math is invisible.
- A spent die greys out **in place**; nothing flies to the verb or target, so
  cause→effect lives only in the HP bar (VERIFIED: `attack_swing.gif` — the
  die dims, the enemy bar drops, nothing connects them).
- Boon/die modifiers (`+1 attack`, `min 3`, `+2 on max`) apply silently. With
  16 incoming I assigned 5+2+1+1 expecting block 9, got 12 — right answer,
  unreadable arithmetic. Testers already said block "isn't doing anything";
  v0.3.10 fixed the *resolution* side, this is the *assignment* side.
- No undo: a fat-fingered assign is spent (S&D ships full in-turn undo, and
  its store page leads with it).

**Plan:**
- LFP-2a: die flight — on assign, the chip animates to the ATTACK/BLOCK
  button (200–250 ms, easeIn), which pulses and shows the running total:
  "ATTACK 9" / "BLOCK 12", *including* modifiers and pair/triple bonuses, so
  the number that will resolve is on screen before END TURN.
- LFP-2b: in-turn undo — tap a spent die before END TURN to reclaim it
  (sim: assignment only commits on end-turn, or add an unassign command —
  needs a sim-seam decision, see open questions). Deterministic, no
  information gained → ethics-clean fairness win.
- LFP-2c: modifier visibility — assigned die shows its contribution
  ("5+1") in micro text; boon dice get a subtle accent ring all the time.
- **DoD:** screenshot of a 3-die assign showing running totals; autoplay
  hash unchanged on seeds 1842571558 + 200-seed sweep (presentation-only
  unless 2b touches the sim, then golden-anchor test extended first).

## 3. Status vs intent separation (LFP-3) — S

VERIFIED confusion in play: after my TRIPLE ignited the beetle, its burn
stack rendered as a flame badge **directly beside its intent badge** — one
row reading "🛡 13 🔥 3", i.e. "it will shield 13 and burn me for 3". I
misread it live; the 4-card tutorial never covers it; testers won't parse it.

**Plan:**
- LFP-3a: intent badge keeps its slot; status stacks (burn, shield-remaining)
  move to a distinct strip anchored to the enemy sprite with different chip
  styling (small, rounded, sprite-tinted) — mirroring the player's own
  shield chip position for symmetry.
- LFP-3b: long-press any badge → 2 s tooltip call-out (reuses TextPop) naming
  it: "BURN 3 — ticks at turn start". Zero new systems.
- LFP-3c: tutorial card 2 gains one clause pointing at the intent badge
  *position* ("the badge above its head"), unchanged otherwise.
- **DoD:** screenshot with both burn stack and intent visible + distinct;
  replayable tutorial (? button) shows the updated card.

## 4. Idle life on the stage (LFP-4) — S

Between actions the stage is near-still: the weapon sways (2600 ms period)
and ambient particles drift, but the delver and enemy bodies read static at
combat scale (VERIFIED on video; `sprites.dart` has an idle-bob row, so
either amplitude or the static-frame path is the issue — root-cause first).
S&S/StS-likes survive minimal animation only because *something* always
breathes. **Plan:** LFP-4a: guarantee the idle row actually plays on the
combat stage and raise bob amplitude ~2 px at stage scale; LFP-4b: enemy
"tell" — reuse the existing 190 ms lean-back wind-up as a slow 1 px sway
while intent shows attack, so the badge has body language. **DoD:** 5 s
static-camera capture shows continuous motion on both sprites; perf flat.

## 5. Resolution pacing control (LFP-5) — S

The end-turn choreography (windup → contact → pops → 2 s call-outs) is
fixed-length; END TURN → next input is ~2.5–3.5 s (VERIFIED
`enemy_hit_block.gif`), and design-system §5 says never block input > 400 ms
on animation. Fine at fight 1, heavy by fight 30 (S&D resolves near-
instantly; its ceremony is all in the roll). **Plan:** tap anywhere during
enemy resolution = fast-forward (2× speed + call-outs to 1 s), second tap =
skip-to-state; never skips information, only duration. **DoD:** bot test
taps through a turn and reaches input ≥ 40% faster; no dropped FX/state.

## 6. Small fixes from the playtest (LFP-6) — XS–S

- LFP-6a: **Cinder Wisp spawned at 19/20** on Easy — `enemies.dart` HP 29 ×
  easy 0.68 = 19.7; current HP floors, max HP rounds. One-line rounding
  unification. VERIFIED on the `fight2.png` capture.
- LFP-6b: risky-reroll copy: "each lands −1 pip" reads as "−1 from current
  face"; actual rule is reroll-then-subtract (my 1 became 4). Show per-die
  preview text ("reroll, −1") in the picker, or change copy to
  "rerolls land −1".
- LFP-6c: the boon screen (run start) has no RECOMMENDED default; the reward
  screen does. Apply the same deterministic heuristic (design-system §1
  smart defaults). VERIFIED `map.png` vs `after_kill.png`.

---

## Sequencing & estimate

The Play production gate (~2026-08-07) ships **from this branch**, so cheap
clarity fixes land first, big feel work goes behind the gate:

| Order | Item | Size | Gate-relevant? |
|---|---|---|---|
| 1 | LFP-6 rounding + copy + boon default | XS–S | Yes — tester-visible polish, zero risk |
| 2 | LFP-3 status vs intent | S | Yes — directly answers tester confusion theme |
| 3 | LFP-2a/2c assignment totals | M | Yes if it fits; presentation-only |
| 4 | LFP-5 pacing control | S | Either side of gate |
| 5 | LFP-1 physical dice | M | Post-gate release headline |
| 6 | LFP-2b in-turn undo | M | Post-gate (touches sim seam) |
| 7 | LFP-4 idle life | S | Post-gate, pairs with LFP-1 capture |

Total ≈ 5–8 working days single-agent.

**Non-goals:** copying S&D's multi-hero party UI or pixel-art enemies-as-
buttons layout (our single-delver stage + portrait one-thumb reach is a
deliberate spec decision); any resolution randomness; any dark-pattern
"juice" (spec §Ethics).

**Open questions for the owner:**
1. LFP-2b undo: OK to add an `unassign` command to the sim (golden hashes
   regenerate), or keep assignments client-side until END TURN commits?
2. LFP-1 physical dice: programmatic 2.5-D (rotate/scale/shadow, decision-#7
   safe, free) vs. budgeting for a small pre-rendered die-face sheet?
3. LFP-5: is fast-forward enough, or do you want a persistent "fast mode"
   toggle in settings (S&D has one)?
