## Emberdelve Round 1 critique of exp.2 (0.184.102+213, c6e6e12)

**Verdict.** exp.2 makes two real improvements. The guided tour now runs all 5 beats with no text wall after it (C0-02 closed), and at 360 px and wider the kill moment is finally clean: the badge fades on the lethal hit, the number stays still, and the call-out has its own slot. Nothing else changed, though. Foes still hit from where they stand, the hero still freezes as a white statue, and the adult-level copy is still there. The final-boss kill is a full-screen cream white-out (020 and 039) followed by a live-looking board, which is the weakest moment in the game.

**What I looked at.** MANIFEST, audio_report, all 22 sheets. I zoomed into full-res frames 020, 021, 024, 026, 033, 040, the 320 frames 01 / 05_tour_beat_spend / 05_tour_beat_intent, and kill_readout exact/overkill at 320x568 (t360, t720, t1200, t960). I compared the round-00 and round-01 C_slag_brute kill and enemy-turn strips side by side. Read-only repo grounding: `git diff HEAD~3` (no `lib/audio` or sprite changes), `combat_screen.dart:757-781,1391-1403` (boss flash), `combat/stage.dart:335-405` (badge fade and burn chip), `readout_lanes.dart:116-133` (call-out fit scale), `tool/play_session_test.dart:564-575`. These are headless renders, so audio and device feel are inferred.

### Scores
| Dim | Score | Why | Δ vs R0 |
|---|---|---|---|
| Art | 5 | Same 16-px outlined blob foes beside the hero (C_* idle); wireframe grid stage (C0-10) | = |
| Animation | 5 | Kill readout is steadier at 360+ (no restarts). Foe strike still hits 030 before the foe slide peaks at 034 and never closes the gap. White statue 030–038. Boss kill whites out the whole screen | = |
| Audio (report only, not heard) | 5 | No audio changes in the diff; same 21 SFX | = |
| Gameplay | 7 | Intent, spent dice and combos readable. OVERKILL → NEXT FOE still shows on the final boss (021) | = |
| Loop | 6 | Easy win banks 12 embers against a 120-ember first unlock (06_summary, 004) | = |
| Menus/layout | 6 | Title still scrolls at 320 (Daily cut off); tip card still translucent (024) | = |
| Onboarding | 5 | Tour completes at all 3 widths and the board is clean afterwards. Still a 58-word map primer, a jargon boon screen, "ITS NEXT MOVE" typo, "resolves exactly as shown" | +1 |
| Accessibility | 6 | At 320x568 call-outs shrink to about 5 dp and sit on the hero; boss white-out ignores reduced motion | = |
| Stability | 7 | 0 violations over 579 steps. `summary_run_won` plates (021/040) still show the combat board 1.2 s after the kill | = |
| Overall | 5 | | = |

### Keep
- Kill readout at 360/412 in D_kill_readout_360x800 / 412x915: badge gone by t520, damage number stable beside the foe, call-out in its own top slot. Compare round-00 slag_brute kill 052–058, where the number restarted and clipped off the top.
- The tour itself: one idea per card, orange ring on the real control, "n of 5" pill, and a clean board after beat 5 (05_tour_after_done at 320/360/412).
- Everything carried over from round 0: dice rendering, type system, settings (reduce motion, blood toggle, analytics off by default).

### Backlog verdicts
- **C0-01 not fixed.** The foe does slide about a quarter of the gap, but only 032–036, after HP has already dropped at 030. This is identical to the round-00 strip.
- **C0-02 closed.** 05_tour_after_done at 320/360/412 shows the live board with no card. Beats 1–5 all render.
- **C0-03 partially fixed.** The stage lane is fixed at 320x640, 360 and 412. Three problems remain:
  - Tray lane: "FREE REROLL NEXT TURN" sits on top of "STRAIGHT!", the HP bar, the foe ring and the burn chip (026; C_*_kill 044–056).
  - At 320x568 the call-outs are shrunk to about 5 dp and drawn over the hero's helmet and sword (exact_320x568_t720/t1200, overkill_t960).
  - On the player side, "-9" now lands on the hero's head (C_*_enemy-turn 032–036). In round 0 it sat above the head.
  - I have re-listed C0-03 with this narrower scope.
- **Not fixed** (no relevant code changed, plates unchanged): C0-04, C0-05 (white frames 030–038, i.e. 5 sampled frames), C0-06 (03_map_fresh primer 58 words), C0-07 (01_title 320 still scrolls), C0-08 (024: "MOVE ON — FULLY RESTED" and "TEMPER A FACE" show through the card), C0-09, C0-10, C0-11, C0-12 (021), C0-13 (a small lunge peaks at 056 but the arc is still visible at 060; unchanged from R0), C0-14, C0-15.
- **Regressions:** none by id. The "-9" moving onto the hero's head is a small one inside C0-03's re-layout, filed as C1-06.

### Ranked issues (impact per effort)
1. **C1-01 (P1, S).** The boss kill is a full-screen opaque #FFE9C4 flash (020, 039) and it ignores reduced motion. At +1.2 s the board is live-looking, with a lit End turn and "NEXT FOE" (021, 040). Do this together with C0-12.
2. **C0-03 residual (P1, S).** Tray-lane call-outs stack on each other and on the HP row.
3. **C1-02 (P1, S).** At 320x568 call-outs shrink to about 5 dp and sit on the hero sprite.
4. **C1-03 (P2, S).** Intent beat copy: "ITS" typo, adult wording, and the two numbers (9 and 7) are never explained.
5. **C1-04 (P2, S).** "Tap anywhere to continue" is printed over the End turn label.
6. **C1-05 (P2, S).** The burn chip stays on the dead foe and the blood pool is painted over it (040 🔥11, 021 🔥9).
7. **C1-06 (P2, S).** The player's damage number sits on the hero's face.
8. **C1-07 (P2, S).** The spend beat shows "ATTACK +6 · BLOCK +6" and "PAIR +2" over the hero with no explanation.
9. **C1-08 (P2, S).** The tour never teaches End turn or that the foe hits back.

**Your question about the two known items:** I agree with both. Tray-lane stacking ranks #2. C0-12 should ship with C1-01.

**Suggested order for the next single iterations:** C1-01 + C0-12, then the C0-03 residual, then C0-01 (biggest game-feel gap), then C0-06 and C0-07 (for the child onboarding goal).

```json
{"round": 1, "scores": {"art": 5, "animation": 5, "audio": 5, "gameplay": 7, "loop": 6, "menus_layout": 6, "onboarding": 5, "accessibility": 6, "stability": 7, "overall": 5}, "closed": ["C0-02"], "regressions": [],
"issues": [
{"id": "C1-01", "dimension": "animation", "severity": "P1", "title": "Final-boss kill is a full-screen opaque white-out, then a live-looking board with no victory beat", "observed": "020_run1_run_won and 039_run3_run_won are 100% flat #FFE9C4 frames (combat_screen.dart:1391-1403, opacity 1.0 for >=260 ms, not gated by Motion.instance.reduced). At +1200 ms (021, 040) the boss is simply gone, the dice tray and End turn are fully lit as if the fight continues, and 021 shows 'OVERKILL +3 -> NEXT FOE'.", "why_it_matters": "The run's climax is a blank screen that hides the boss's death. A full-field bright flash also ignores the reduced-motion/photosensitivity preference. Then the game looks as if it wants another turn.", "fix_direction": "Limit the flash to the stage rect at <=0.45 opacity with a radial falloff from the boss (none under reduce, where a 200 ms colour tint is enough). Keep the boss dissolve visible. On encounter_won, disable and dim the tray and End turn within 1 frame and hold the hero's victory pose until the summary. Fix C0-12 toast selection in the same pass.", "acceptance": "Boss-kill strip at 40 ms at 360x800: no frame has >50% of pixels at luma >230; the boss dissolve is visible on >=4 sampled frames; under reduce, 0 frames above that luma; the +1200 ms plate shows a disabled tray and no NEXT FOE toast (unit test on toast selection).", "effort": "S"},
{"id": "C0-03", "dimension": "menus_layout", "severity": "P1", "title": "(rescoped) Tray-lane call-outs still stack on each other and on the player HP row", "observed": "026_run2_keystone: 'FREE REROLL NEXT TURN' overlaps the foe ring, the burn chip and the hero's feet; 'STRAIGHT!' sits on the HP bar next to '21 / 30'. C_*_kill 044-056 (all 4 foes): the 'ATTACK +5 · BLOCK +5' chip, FREE REROLL and STRAIGHT! overlap each other and the HP numerals, and FREE REROLL ghosts over the dying foe at 054-056.", "why_it_matters": "The combo and reward reads that make a turn feel good are illegible exactly when they fire.", "fix_direction": "Give the tray lane the same ReadoutLanes slot plan as the stage: stack call-outs vertically in reserved slots above the HP label (or queue them 250 ms apart), never over sprites or the HP row. Include the assignment-preview chip in the plan.", "acceptance": "kill_readout-style rect test extended to tray-lane call-outs for 3 foes at 320x568/360x800/412x915: zero overlapping text rects, including against the HP label and the sprite bbox. Plate 026 equivalent shows both call-outs fully legible.", "effort": "S"},
{"id": "C1-02", "dimension": "accessibility", "severity": "P1", "title": "On short stages call-outs are shrunk to ~5 dp and drawn over the hero sprite", "observed": "kill_readout exact_320x568_t720/t1200: '+5 EMBERS — EXACT!' is about 9 px @2x cap height (~5 dp) and sits across the hero's helmet and sword. overkill_320x568_t960: 'OVERKILL +1 -> NEXT FOE' has the same size and position. readout_lanes.dart:116-133 scales call-outs down to fit the band with no minimum.", "why_it_matters": "320x568-class phones get unreadable reward text. The rect test passes only because text-over-sprite is not counted and shrinking is allowed.", "fix_direction": "Set a floor on call-out scale so text never goes below 12 sp. When the band cannot fit at that size, move the call-out to the top-bar/tray slot. Add the hero and foe sprite bboxes to the overlap test.", "acceptance": "At 320x568 every call-out renders >=12 sp and its rect does not intersect the hero or foe sprite bbox (test + t720/t1200 plates).", "effort": "S"},
{"id": "C1-03", "dimension": "onboarding", "severity": "P2", "title": "Intent tour beat: typo, adult wording, and the two numbers are never explained", "observed": "05_tour_beat_intent_tour_intent at 320/360/412: title 'ITS NEXT MOVE' (missing apostrophe); body 'The badge always resolves exactly as shown.' The highlighted badge shows red 9 and blue 7, but nothing says the foe will hit for 9 and guard 7.", "why_it_matters": "'Resolves' is well above a 7-9-year-old's reading level. The one fairness idea the game depends on (the foe does exactly what the badge shows) is not actually taught.", "fix_direction": "Copy only (no layout change): title \"IT'S NEXT MOVE\"; body \"It will hit you for 9 and guard 7.\" with inline target/shield icons, filled from the live intent values. Keep it <=12 words.", "acceptance": "String test: intent beat body <=12 words, FK grade <=3, apostrophe present, numbers match the live intent. Plates at 320/360/412.", "effort": "S"},
{"id": "C1-04", "dimension": "menus_layout", "severity": "P2", "title": "'Tap anywhere to continue' is printed over the dimmed End turn label", "observed": "05_tour_beat_intent_tour_intent and 05_tour_beat_next_tour_reroll at 320/360/412: the hint text overlaps the scrimmed 'END TURN' glyphs (clear in the 320 full-res crop).", "why_it_matters": "Text on text on the one instruction a non-reader needs. It also looks broken.", "fix_direction": "Put the hint inside the tip card (last line), or replace it with a pulsing tap-hand icon in the card corner. Never place it over another control.", "acceptance": "Tour plates for all 5 beats at 320/360/412: the hint rect does not intersect any button label rect (rect test).", "effort": "S"},
{"id": "C1-05", "dimension": "art", "severity": "P2", "title": "Burn status chip stays on the dead foe and the blood pool is painted over it", "observed": "040_summary_run_won: the '🔥 11' chip at the foe's feet has its digits half-covered by a dark red pool decal. 021: the '🔥 9' chip is fully smeared. 026: '🔥 1' sits on the dissolving foe. stage.dart:386-404 fades the intent badge at 0 HP, but the burn chip has no such rule.", "why_it_matters": "Stale UI on a corpse and a z-order bug. It reads as dirt on the final-boss victory frames.", "fix_direction": "Drive the burn chip from the same `dead` flag as the intent badge (140 ms fade, 0 under reduce), and make sure gore decals paint below status chips.", "acceptance": "Kill strips for all 4 foes with burn >0: the chip is gone by the frame the badge is gone. 040-equivalent plate has no chip and no decal over any text.", "effort": "S"},
{"id": "C1-06", "dimension": "animation", "severity": "P2", "title": "Player damage number now lands on the hero's face instead of above it", "observed": "C_*_enemy-turn 032-036 (all 4 foes): '-9' sits over the hero's head and white silhouette. In round-00 it rose clear above the head (round-00 slag_brute enemy-turn 032-038).", "why_it_matters": "The hit number collides with the hit reaction, so both read worse. Side effect of the C0-03 re-layout.", "fix_direction": "Plan the player-side number with the same ReadoutLanes zone: above the hero bbox with >=6 dp clearance, not over the sprite.", "acceptance": "Enemy-turn strips: the '-N' rect does not intersect the hero sprite bbox on any frame 030-042 at 320x568/360x800/412x915.", "effort": "S"},
{"id": "C1-07", "dimension": "onboarding", "severity": "P2", "title": "Spend beat shows unexplained 'ATTACK +6 · BLOCK +6' and 'PAIR +2' chips over the hero", "observed": "05_tour_beat_spend_tour_spend at 320/360/412: under the scrim, the assignment-preview chip and a gold 'PAIR +2' combo label float across the hero sprite and the '30 / 30' HP numerals, beside a card that says only 'ATTACK deals its value. BLOCK absorbs hits.'", "why_it_matters": "Two new numbers and a combo word the child was never taught appear in the step meant to teach one idea.", "fix_direction": "Hide the combo label and the preview chip while any tour beat is active, or make the preview chip part of the spotlight and word the card around it. Simplify the body to e.g. 'ATTACK hurts it. BLOCK keeps you safe.'", "acceptance": "Spend-beat plates at 320/360/412 with no text outside the card and spotlight except the dimmed board. Body <=12 words, FK <=3.", "effort": "S"},
{"id": "C1-08", "dimension": "onboarding", "severity": "P2", "title": "The tour never teaches End turn or that the foe answers", "observed": "Beats are roll, pick, spend, intent, reroll (05_tour_beat_* plates). In 05_tour_after_done, End turn and the 'Risky reroll · new face −1' bar are equally bright, and no step says that ending the turn lets the foe act.", "why_it_matters": "A child who has spent their dice has no cue what to do next, and the first foe hit comes as a surprise, which undercuts the intent lesson.", "fix_direction": "After beat 5, pulse End turn once (a glow ring, no card), or add a <=6-word beat 'Done? End turn. Then it moves.' anchored to End turn. Make the reroll bar visually secondary to End turn after the tour.", "acceptance": "Fresh-walk plates at 320/360/412 immediately after the tour show End turn highlighted as the single primary action. Tour test covers the new cue. Harness shows no stuck state.", "effort": "S"}
]}
```

---

## Maker verification of round 1 (2026-09-24)

Every claim was checked against the round-01 plates before merging. VERIFIED means I looked at the image, the pixel data or the code myself. ASSUMED means the critic's claim, not re-checked yet.

- **C0-02 closed: agreed. VERIFIED.** `05_tour_after_done` at 320 shows the live board with no card after beat 5.
- **C0-03 partly fixed: agreed. VERIFIED** on `026_run2_keystone`. "FREE REROLL NEXT TURN" runs across the hero's feet, the foe ring and the burn chip. "STRAIGHT!" sits on the player HP bar next to "21 / 30". The stage lane at 360+ is clean (`D_kill_readout_360x800`). Rescope to the tray lane accepted.
- **C1-01 VERIFIED.**
  - Plates `020_run1_run_won` and `039_run3_run_won` are both 99.7% flat #FFE9C4, with luma > 230 on 99.7% of pixels (pixel count).
  - Code: the flash is an `AnimatedOpacity` driven only by `_bossKillFlash`. `combat_screen.dart` has no reduced-motion reference at all.
  - `021` shows "» OVERKILL +3 → NEXT FOE" on the final boss (Hearthless King 0/78) with a lit End turn.
  - Caveat on "live-looking board": the harness takes its summary plate 1200 ms after it first sees phase `run_won`. The game's death sequence (260 ms freeze, dissolve, 150 ms tail) has not handed over to the summary by then. So this is the real UI during that window, not a stuck state. The fix is to make that window read as a victory.
  - ASSUMED: the exact handover timing on device.
- **C0-12** is folded into C1-01: its acceptance includes the toast-selection unit test, and both are the same final-kill moment.
- **C1-02 VERIFIED.** On `exact_320x568_t720`, "+5 EMBERS — EXACT!" is roughly 5 dp tall and sits across the hero's helmet.
- **C1-03 VERIFIED.** `tour_overlay.dart` beat 4 reads 'ITS NEXT MOVE' / 'The badge always resolves exactly as shown.' (plate `05_tour_beat_intent_tour_intent` at 320).
- **C1-04 VERIFIED.** On the same plate, "Tap anywhere to continue" is printed across the dimmed END TURN label.
- **C1-05 VERIFIED.**
  - `040`: the "🔥11" chip at the dead Ember Tyrant's feet has a dark red pool over its digits.
  - `021`: "🔥9" is smeared the same way.
  - `stage.dart` shows the burn chip only when burn > 0. It does not check `dead`, although the intent badge does (opacity 0 at 0 HP).
- **C1-06 VERIFIED: a regression from my C0-03 re-layout.**
  - Round-00 `C_anim_slag_brute_enemy-turn`: "-9" rises clear above the hero's head (032–042).
  - Round-01: "-9" overlaps the head and the white silhouette (032–036).
- **C1-07 VERIFIED.** On `05_tour_beat_spend_tour_spend` (320), the "ATTACK +6 · BLOCK +6" preview chip and "PAIR +2" are readable above the card, over the dimmed hero and HP numerals.
- **C1-08 PARTLY VERIFIED.**
  - Agreed: the five beats (roll / pick / spend / intent / reroll) never mention End turn or that the foe acts next.
  - Not agreed: "End turn and the reroll bar are equally bright." On `05_tour_after_done` (320), End turn is the only filled orange button; the reroll bar is a dark panel with white text. The item is kept for the missing "then it moves" cue.
- **Not-fixed verdicts** (C0-01, C0-04 … C0-15): consistent, because exp.2 changed no code for them. Each is re-verified on fresh plates before its own iteration.
- **Next pick:** C1-01, with C0-12 folded in (the critic's order: P1/S, the run's climax). Then the C0-03 tray lane, C1-02, and C0-05 / C0-01.
