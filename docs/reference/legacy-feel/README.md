# Legacy feel — playtest capture index (2026-07-25)

Source: hands-on session, `legacy/dice-builder` @ `4d90237` (v0.3.10+13)
built with `flutter build web --release`, played headless-Chromium with
Pixel-7-class touch emulation (412×892), full session screen-recorded at
native speed. Analysis: `docs/legacy-feel-plan.md`.

## GIF clips (real-time captures)

| File | Moment | What to watch |
|---|---|---|
| `title_delve.gif` | Title → boon screen | Screen transition (320 ms fade-through) |
| `roll_tumble.gif` | Turn-1 roll | 520 ms tumble, 50 ms/die stagger, in-place hop — the LFP-1 baseline |
| `attack_swing.gif` | First attack (die → ATTACK) | Weapon raise → smear swing → −4 pop; note the spent die just greys out (LFP-2) |
| `enemy_hit_block.gif` | Enemy 16-hit vs block 12 | 190 ms wind-up, claw rake, BLOCKED call-out (2 s), HP loss |
| `kill_dissolve.gif` | Ember Beetle kill | Contact freeze, 700 ms dissolve, ember payout |
| `pair_kill_victory.gif` | Pair kill → reward | PAIR call-out; reward cards 3-D auto-flip, staggered |
| `map_walk.gif` | Node pick → descend | 650 ms walk, node glow states |
| `risky_reroll.gif` | Risky reroll picker | Picker mode, −1 pip copy (LFP-6b) |

## Filmstrips (frame-by-frame)

| File | Sampling | Shows |
|---|---|---|
| `filmstrip_attack.png` | 10 fps × 1.2 s | Full attack anatomy incl. smear + damage pop |
| `filmstrip_tumble.png` | 10 fps × 1.2 s | Dice tumble face-cycling |
| `filmstrip_enemyhit.png` | 5 fps × 2.4 s | Enemy wind-up → strike → feedback |

## Comparables

`dicey/` — **hands-on** Dicey Dungeons v0.9.1 (last free public web build,
terrycavanaghgames.com/dice/9), same rig, full Warrior floor-1 fight won:

| File | Shows |
|---|---|
| `dicey/dd_combat_open.gif` | Combat entry, roll, Sword EVEN slot, Warrior skill panel (Tweaks budget) |
| `dicey/dd_slot_attack.gif` | Drag die → equipment slot = attack (the die-travel metaphor, LFP-2 reference) |
| `dicey/dd_enemy_turn.gif` | Enemy rolls its own dice + plays its equipment face-up; our hit feedback comparison |
| `dicey/dd_fury_kill.gif` | Fury limit-break drag + killing blow + "Warrior wins!" payout |


`ditd/` — **hands-on** Die in the Dungeon CLASSIC (itch browser build,
4.7/5 × 2,700+ ratings), floor-1 tutorial fight won:

| File | Shows |
|---|---|
| `ditd/ditd_place_preview.gif` | Drag die to board → live "−N"/"+N" preview chips on enemy HP and player shield (LFP-2a reference) |
| `ditd/ditd_finish_resolve.gif` | FINISH commit → whole board resolves in one beat |
| `ditd/ditd_kill_reward.gif` | Kill + reward: DISCARD-a-die offered equal to GET-a-die |

`footage/` — premium lookalikes, frame analysis of gameplay videos
(© respective creators/devs, reference use):

| File | Source | Shows |
|---|---|---|
| `footage/snd_dice_throw.gif` | Slice & Dice gameplay (YouTube, no-commentary) | Thrown physical dice in real play (LFP-1 reference) |
| `footage/snd_target_lines.gif` | same | Dashed damage-preview lines die→victim + permanent Undo |
| `footage/ddfull_intent_preview.gif` | Dicey Dungeons full, NL Warrior ep.1 | Innate tip bar + ENEMY MOVES banner + enemy-next-move preview |
| `footage/ddfull_limit_break.gif` | same | Full-screen LIMIT BREAK banner moment |

`snd_trailer_sheet.png` — 20-frame contact sheet from the official
Slice & Dice 3.0 trailer (web demo is download-only). Rows 1–2: the thrown
physical dice roll (LFP-1 reference). Row 3: per-die tooltips + computed
totals (LFP-2 reference). Row 4: undo / 0-rolls-left affordances.
© tann — reference use for design comparison only, same precedent as
`docs/reference/apple-knight/`.
