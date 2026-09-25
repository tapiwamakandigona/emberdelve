## Emberdelve critic, round 3 (exp.4 "Clear Buttons", commit 1a1f475)

**Verdict.** The toast no longer hides or blocks the main button, so C2-01 is closed. But the fix only moved the problem: for 1.4 s the pill now covers the screen title or the foe's name. It wraps to two lines at 360, and it often talks about the previous screen. Nothing else changed. Every C_* and D_* sheet, the audio report and every non-toast plate (fresh walk at 320/360/412, all kill_readout frames, play_session 020/021/039/040) is byte-identical to round 2 (`cmp`). So all other backlog items keep their round-2 verdicts.

### Scores
| Dim | Score | Why | Δ vs R2 |
|---|---|---|---|
| Art | 5 | Foe/hero scale mismatch, wireframe grid and black ground slab unchanged (025 full-res, 039) | = |
| Animation | 5 | Enemy turn still has no approach and the hero freezes white. Boss kill is a flat white silhouette (039) with no victory beat. All C sheets identical | = |
| Audio | 5 | audio_report.md is byte-identical: 21 SFX, peaks up to −0.2 dBTP, no telegraph or foe voice. I cannot listen | = |
| Gameplay | 7 | Decisions are clear. HP still reads 0 before contact (exact_*_t360 unchanged) | = |
| Loop | 6 | Unchanged. The Wardrobe's first delver unlock (The Warden) still reads 0/120 embers (004) | = |
| Menus/layout | 6 | CTAs are now clear (011/012/025/029). But the toast covers the title on 009/011/012/017/027/029/036 and the foe name on 025. The title screen still scrolls (000) | = |
| Onboarding | 5 | The fresh walk is byte-identical to R2. "ITS NEXT MOVE" typo, adult cards, and the credit toast still fires on the first defeat (011) | = |
| Accessibility | 6 | The pill has good contrast (light on #raised, 15 sp). But it holds for only 1.4 s whatever the length, and the yellow "-4" is still on the white flash (039) | = |
| Stability | 7 | Harness: 4 runs, 569 steps, 0 violations, 0 problems | = |
| Overall | 5 | One S-sized layout fix; no change a player would feel in the fight | = |

### Must keep
- **Clear, tap-through buttons.** "Delve again" (011/012), "Roll" (025), "Leave shop" (029) and "Skip" (009/017/027/036) are fully visible while the toast is up. `flash_toast.dart` wraps the pill in IgnorePointer. The widget test `test/toast_clear_of_buttons_test.dart` checks toast vs button rects at 3 sizes; I read the code but did not run it.
- **In-theme pill.** Rounded, ember hairline border, 0.96-alpha fill, 15 sp text. The black frame is gone. Reduced motion drops the slide and keeps the fade. The TalkBack live region is kept.
- **Round-2 strengths still hold:** no white-out on kill, the NEXT FOE split, dimmed buttons at run end, the normal-foe dissolve, and the hero's lunge.

### Backlog verdicts
- **Closed:**
  - **C2-01.** Both parts of the acceptance are met. The re-shot 011, 025 and 029 show the CTA fully visible with the toast present, and the widget test exists at 320x568/360x800/412x915. The side effects are filed as new issues C3-01 to C3-03, not as a regression, because the maker disclosed them and the original defect is gone.
- **Not fixed (pixel-identical to R2):**
  - C0-01, C0-03, C0-04, C0-05, C0-06, C0-07, C0-08, C0-09, C0-10, C0-11, C0-13, C0-14, C0-15
  - C1-01, C1-02, C1-03, C1-04, C1-05, C1-06, C1-07, C1-08
  - C2-02, C2-03, C2-04, C2-05, C2-06
  - Specific re-checks:
    - **C2-02 / C1-01:** 039/040 still show a white boss silhouette, lit tray dice with gold MAX rings, and no banner.
    - **C2-05:** 011 (run0, fresh profile) still shows "'Ashes, Gently' — first hearing".
    - **C0-03:** 039 still has "STRAIGHT! / TRIPLE! / PAIR +2" stacked over the HP bar.
    - **C2-06:** 025 still shows the black slab with hard vertical edges behind both actors.
    - **C1-03:** "ITS NEXT MOVE" is still missing its apostrophe (05_tour_beat_intent at 320/412).
- **Regressions:** none.

### New issues, ranked by impact per effort
1. **C3-01 (P2, S): The toast covers the screen title or foe name, and wraps at 360.**
   - Seen on 011/012 (it also wraps to two lines), 009/017/027/036, 029 and 025.
   - Cause: the pill is centred at safe-top + 72 dp with 64 dp gutters. That is exactly where every screen draws its title, and it leaves only 232 dp at 360 and 192 dp at 320.
2. **C3-02 (P2, S): The toast describes the previous screen and is gone before a slow reader finishes.**
   - "Twin Bellows set" (a keystone chosen on 008/035) appears on the next reward screen (009/036). "Nothing changed" (an event outcome from 028) appears over the shop (029).
   - The hold is a fixed 1400 ms for 3–6-word messages. A 7–9-year-old reads about 1–1.5 words/s.
   - There is also `maxLines: 2` with an ellipsis. At 320 (about 160 dp of text) a multi-part event summary such as "−15 gold · +14 embers · Relic: …" gets cut. This is inferred from the code; verify with a plate.
3. **C3-03 (P2, S): In-fight refusal messages appear far from the finger.**
   - Messages like "Assigned dice can't be rerolled", "Pick at least one die to reroll" and "Roll first" now show at the top, over the foe panel. The tap was on the tray or buttons at the bottom, roughly 500–600 dp away.
   - This is inferred from the placement code plus the 025 geometry. There is no plate of an invalid tap; verify.
4. **C3-04 (P3, S): Clipped ghost text behind the summary CTA.**
   - Defeat summary 011/012: a faded, half-cut line ("A first fall — every delve ends in one…") sits behind the top of "Delve again" and reads like clipped copy.

### What to fix next from the open backlog (no scope changes)
1. C2-05 (S; one gate that also removes the worst toast)
2. C2-02 + C1-01 together (the win still has no payoff)
3. C0-01 (foes strike from where they stand)
4. C0-05 (the hero's hit reaction is a frozen white silhouette)
5. C0-06 / C1-03 / C1-07 (the child-facing copy pass)
6. C0-07 (the title screen scrolls)
7. C0-03 / C1-02 (tray call-outs stack)

```json
{"round": 3, "scores": {"art": 5, "animation": 5, "audio": 5, "gameplay": 7, "loop": 6, "menus_layout": 6, "onboarding": 5, "accessibility": 6, "stability": 7, "overall": 5}, "closed": ["C2-01"], "regressions": [],
"issues": [
{"id": "C3-01", "dimension": "menus_layout", "severity": "P2", "title": "Top toast pill sits on the screen title / foe name and wraps to two lines at 360", "observed": "360x800 @2x: 011/012 '\"Ashes, Gently\" — first hearing' wraps to 2 lines and hides 'DARK CLAIMS' of the title. 009/036 'Twin Bellows set' and 017/027 'Ashen Edge set' cover the middle of 'CHOOSE A DIE' and the subtitle. 029 'Nothing changed' covers 'ASHMONGER'. 025 'Forged into a stronger die' hides the foe name, leaving only 'FLUE' visible at fight start. Cause (flash_toast.dart): Positioned(top: safeTop + 72, left/right: 64) is the title band on every screen, and the 64 dp gutters leave 232 dp at 360 and 192 dp at 320.", "why_it_matters": "For 1.4 s the player loses the one line that says where they are or who they are fighting, at the start of every fight after a forge and on every reward/shop screen. A two-line pill doubles the covered area.", "fix_direction": "Give the toast a lane that holds no text. Run screens: anchor it just under the header block, i.e. the bottom of the title/subtitle or enemy panel + 8 dp, via a per-screen GlobalKey anchor the host reads. Fall back to the current top value when there is no anchor. In combat that lands in the empty sky band above the actors. Cut the gutters to 24 dp (the '?' corner button is already cleared by sitting below the panel). Set maxLines: 1 and shorten any string that does not fit in one line at 320.", "acceptance": "Extend toast_clear_of_buttons_test: at 320x568/360x800/412x915 on all 10 screen kinds, the toast rect intersects no Text rect of the screen title, subtitle, enemy name or enemy HP, and no button rect. Every flash string renders on one line at 320 (string/layout test). Re-shot 011, 025, 029 and 036 show the full title/foe name plus the toast.", "effort": "S"},
{"id": "C3-02", "dimension": "onboarding", "severity": "P2", "title": "Toast reports the previous screen's action and holds 1.4 s regardless of length", "observed": "009/036: 'Twin Bellows set' confirms a keystone picked on the previous screen (008/035) but appears over the unrelated reward screen. 029: 'Nothing changed' (the outcome of the 028 event choice 'Admire and move on') appears over the shop, so it reads as if the shop did nothing. kFlashToastHold = 1400 ms fixed. controller.dart _eventSummary joins several parts ('−15 gold', '+14 embers', 'Relic: …', 'Gained …') and the pill clips at maxLines 2 with an ellipsis. Clipping at 320 is inferred from the code; verify with a plate.", "why_it_matters": "A 7–9-year-old reads about 1–1.5 words/s. A 5-word message needs 3–5 s, and one that names a screen they have already left is confusing ('nothing changed' in a shop?). Event outcomes are the only concrete feedback for event choices (F5 rule), so clipping them loses information.", "fix_direction": "(a) Hold = clamp(1200 + 350 ms × words, 1600, 4000). Under reduced motion hold the upper value. (b) Show event outcomes and keystone confirmations on the screen where the choice was made: delay the phase transition until the toast has been visible ≥1.2 s, or show the outcome inline on the event card before 'Continue'. At minimum, drop keystone_taken/'Nothing changed' toasts once the screen has changed. (c) Replace the ellipsis with shorter summary parts ('+14 embers, −15 gold').", "acceptance": "Unit test: hold duration for 'Relic acquired' (2 words) ≥1.6 s and for a 6-word summary ≥3.3 s. Harness plates: the keystone confirmation and 'Nothing changed' appear on the keystone/event screen, not on 009/029/036 equivalents. A string test renders every _eventSummary combination from the event table without ellipsis at 320.", "effort": "S"},
{"id": "C3-03", "dimension": "gameplay", "severity": "P2", "title": "Invalid-move feedback now appears ~550 dp away from the tapped die/button", "observed": "Inferred from flash_toast.dart plus the 025 geometry: refusals ('Assigned dice can't be rerolled', 'Pick at least one die to reroll', 'Roll first', 'Risky reroll already spent this turn') render at safeTop + 72 dp over the enemy panel. The tapped die or button sits at y≈1260–1540 @2x on 025, about 550 dp from the pill. No plate in the pack shows an invalid tap; verify.", "why_it_matters": "Children look at their finger. A refusal they don't see reads as 'the game is broken' and leads to repeated tapping. Refusals are the most important toasts to notice.", "fix_direction": "For invalid_command in combat, add a local cue: a 160 ms horizontal shake (±4 dp, 3 cycles; no shake under reduced motion, a 2-pulse red outline instead) on the offending die/button, plus the reason as a small label directly above the tray, IgnorePointer and not over any button. Keep the top pill for non-error toasts only. Presentation only; sim untouched.", "acceptance": "Harness: a scripted invalid tap (reroll an assigned die) at 320x568/360x800/412x915 produces plates at +80 and +400 ms showing the cue within 48 dp of the tapped die, with no button rect intersected. Reduced-motion plate shows the outline pulse and no displacement. Test asserts that invalid_command no longer routes to the top host during combat.", "effort": "S"},
{"id": "C3-04", "dimension": "menus_layout", "severity": "P3", "title": "Half-faded clipped line behind the summary CTA reads as broken copy", "observed": "011/012_run_lost at 360x800: a line ('A first fall — every delve ends in one…') is visible at ~15% opacity with its lower half cut behind the top edge of the DELVE AGAIN button. Same pattern at the bottom of 030/031 (the codex/tip card is cut by the CTA).", "why_it_matters": "It looks like a rendering bug, and it is the encouragement line a first-time loser should actually read.", "fix_direction": "Either end the scroll content above the CTA (bottom padding = CTA height + 24 dp, so the last line is fully visible when scrolled) and make the fade a solid gradient that fully hides text under it, or move the encouragement line above the stats card so it is read first.", "acceptance": "Plates of run_lost/run_won summaries at 320x568/360x800/412x915: no text line is partially visible between 5% and 95% opacity at the CTA edge. The encouragement line is fully legible without scrolling at 360x800.", "effort": "S"}
]}
```

**What I did (read-only):**
- Viewed A1–A3 and B_fresh_walk_320/412. At full resolution: 011, 025, 039, plus top crops of 009, 012, 017 and 029, and the title diff crop.
- Ran `cmp` of every round-03 sheet and frame against round-02. The only differing frames are the toast plates (009, 011, 012, 017, 025, 027, 029, 036) and the title screens, which differ only in the daily date (Sep 24 → Sep 25).
- Read the round-02 critic report, `lib/ui/flash_toast.dart`, the game_root toast wiring, and the flash strings in `lib/game/controller.dart`. `git diff --stat 659979e..1a1f475 -- lib` shows only the toast files changed.

**Gaps:**
- The play_session run is 360x800 only, so I had no toast plates at 320/412. The 320 wrap and clipping claims are inferred from code; verify.
- There are no invalid-tap plates.
- I did not run the maker's test.
- There was nothing new to judge for audio, animation or onboarding, because those are byte-identical.
- The parent asked me not to re-list open ids, so the JSON has only 4 new issues. That is below the 8–15 the critic contract asks for; the priority order for existing ids is in the markdown instead.

---

Maker notes (round 3, exp.4), checked against the round-03 images:
- C2-01 closed: VERIFIED. Plates 011, 025 and 029 at full resolution show DELVE AGAIN, ROLL and LEAVE SHOP fully visible with the toast up. The maker ran test/toast_clear_of_buttons_test.dart: red on the old code, green on new, at 3 sizes, and in the full suite (1584/1584).
- C3-01 (the toast sits on the title or foe name and wraps at 360): VERIFIED on 011 (two lines, over "DARK CLAIMS"), 025 (only "FLUE" of the foe name is visible), 029 (over "ASHMONGER"), and 009/036 top crops (over "CHOOSE A DIE"). The maker disclosed this trade-off in the release notes.
- C3-02 (the toast names the previous screen): VERIFIED for the keystone case. controller.dart line ~1068 sets flash '<keystone> set' on choose_keystone, and it renders over the next reward screen (009/036). The 1.4 s hold is VERIFIED in code. Ellipsis clipping at 320: ASSUMED (no 320 toast plate).
- C3-03 (refusals shown far from the finger): ASSUMED. It follows from the placement code, but there is no invalid-tap plate.
- C3-04 (half-faded line behind DELVE AGAIN): VERIFIED on 011.
- Everything else unchanged: ASSUMED from the critic's cmp (not re-run by the maker). It is consistent with the diff, which only touches the toast files, news.dart and pubspec.
