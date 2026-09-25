## Emberdelve critic, round 2 (exp.3 "The Last Blow", commit 659979e)

**Verdict.** The final kill is no longer whited out, and the "NEXT FOE" toast is gone from run-ending kills. Everything else a player sees is unchanged. The B_fresh_walk sheets and all C_*_idle and C_*_enemy-turn sheets are byte-identical to round 1 (I checked with `cmp`). So no onboarding, hit-reaction, foe-approach or idle item could have moved. What is left at the win is a still board, not a victory. Tray call-outs still pile up, and on the defeat, reward and shop screens a floating toast covers the main button.

### Scores
| Dim | Score | Why | Δ vs R1 |
|---|---|---|---|
| Art | 5 | Foe/hero scale mismatch, wireframe grid and hard-edged black ground slab unchanged (020, exact_412x915_t720) | = |
| Animation | 5 | Kill: no white-out, dissolve visible on normal foes (C_*_kill 054–066). Enemy turn identical to R1 (4-frame white hero, no approach) | = |
| Audio | 5 | Audio report unchanged: 21 SFX, several peaks −0.2…−0.9 dBTP, no telegraph or foe voice. I cannot listen | = |
| Gameplay | 7 | Clear decisions. Enemy HP reads 0 before the blow lands (t360) | = |
| Loop | 6 | Unchanged. The 120-ember first unlock is still far (002/004 show 0/120 after a run) | = |
| Menus/layout | 6 | The floating toast covers Delve again / Leave shop / the bottom CTA (011, 012, 029, 025) | = |
| Onboarding | 5 | Fresh walk byte-identical to R1 | = |
| Accessibility | 6 | Yellow "-6" on the white boss flash (020/039); dim micro text unchanged | = |
| Stability | 7 | Harness: 4 runs, 579 steps, 0 violations, 0 problems | = |
| Overall | 5 | One climax moment is fixed; the rest is unchanged | = |

### Must keep
- The kill no longer blows out the screen. I measured luma>230 on the boss plates: 020 = 2.0%, 039 = 1.8%. Every D_kill_readout frame is ≤1.25%.
- Run-ending kills show no NEXT FOE (020/021/039/040), while mid-run overkills keep it (overkill_* t720–t1200). That is the correct split.
- End turn, Attack, Block and Reroll are dimmed once the fight ends (021/040).
- The normal-foe dissolve (white hit flash → gold pixel scatter → ember dust, C_molten_maw_kill 054–066) reads well.
- The hero now moves forward on the attack (C_*_kill 052–056).

### Backlog verdicts
- **C0-12: closed.** 020/021/039/040 show no toast on the final boss. Mid-run overkill still shows it.
- **C1-01: partially fixed, not closed.**
  - Passes: no frame near 50% bright pixels, NEXT FOE absent, buttons dimmed.
  - Missing from the pack: a 40 ms boss-kill strip, so "boss dissolve on ≥4 frames" is unverifiable. On 020/039 the boss is one flat white silhouette. There is also no reduced-motion strip.
  - Still wrong at +1200 (021/040): the dice tray is at full brightness with its gold "MAX" rings still lit. There is no victory beat (new issue C2-02).
  - Rescoped below.
- **C0-03: not fixed.**
  - 039: "STRAIGHT! / TRIPLE! / PAIR +2" are stacked across the HP bar and "21/30".
  - C_*_kill 044–052: "FREE REROLL NEXT TURN" overlaps "STRAIGHT!", the HP numerals and the foe.
- **C1-02: not fixed.** exact_320x568_t720: "+5 EMBERS — EXACT!" is about 5 dp tall on the hero's helmet. overkill_320x568_t960: "» OVERKILL +1 → NEXT FOE" is the same.
- **C1-05: not fixed.** 040 shows "🔥11" and 021 shows "🔥9" on the dead boss, with the blood pool painted over the digits.
- **C0-13: partially fixed.** The hero is displaced forward on 052–056. But the arc trail is still drawn around the foe, not the blade, and is still visible at 058 and 060 (acceptance: gone by 058). Rescoped below.
- **Not fixed, unchanged sheets or plates:** C0-01, C0-04, C0-05, C0-06, C0-07, C0-08, C0-09, C0-10, C0-11, C0-14, C0-15, C1-03, C1-04, C1-06, C1-07, C1-08.
  - C0-05 and C1-06: enemy-turn 032–038 still has a white hero, and "-9" sits on the head.
  - C0-07: 000 still scrolls, with Weekly below the fold.
- **Regressions:** none observed.

### Ranked issues (full detail in the JSON)
1. **C2-01 (P1, S):** The floating 1400 ms SnackBar covers the primary CTA.
   - "Ashes, Gently — first hearing" hides Delve again on 011/012.
   - "Nothing changed" covers Leave shop on 029.
   - "Forged into a stronger die" covers Roll on 025.
   - "Twin Bellows set" sits over the reward screen's bottom button on 009/036.
2. **C2-02 (P1, M):** No victory beat on the final kill. At +1200 the board is still, the tray is lit and there is no banner.
3. **C1-01 rescoped (P1, S):** Evidence gap. Needs a boss-kill strip and a reduced-motion strip, plus the tray dice dimmed.
4. **C2-03 (P2, S):** The enemy HP number drops to 0 before contact (exact_*_t360 at all sizes, with the foe still standing and its intent badge up).
5. **C2-04 (P2, S):** Yellow damage numbers sit on the white hit-flash silhouette (020 "-6", 039 "-4", C_*_kill 054–056).
6. **C2-05 (P2, S):** A song-credit toast fires on a brand-new player's first defeat screen (011, run0). This breaks the maker's own "Quiet First Delve" rule, because `runsPlayed > 0` is checked after the run is counted (controller.dart ~l.419).
7. **C0-13 rescoped (P2, S):** Trail from the blade tip, gone by 058.
8. **C2-06 (P2, M):** On 412x915 the stage is about 60% empty sky. The actors sit in the bottom band, and a hard-edged black ground rectangle is visible (exact_412x915_t720).

On the reward screen, 009/017/027/036 show blank diamond cards. `reward_screen.dart` staggers the reveal at 220 + i·240 ms, so these are mid-reveal captures, not a defect (verify).

```json
{"round": 2, "scores": {"art": 5, "animation": 5, "audio": 5, "gameplay": 7, "loop": 6, "menus_layout": 6, "onboarding": 5, "accessibility": 6, "stability": 7, "overall": 5}, "closed": ["C0-12"], "regressions": [],
"issues": [
{"id": "C2-01", "dimension": "menus_layout", "severity": "P1", "title": "Floating toast covers the screen's primary button", "observed": "011/012_run_lost: '\"Ashes, Gently\" — first hearing' fully hides the DELVE AGAIN button (only its orange top edge shows). 029_run2_shop: 'Nothing changed' covers LEAVE SHOP. 025_run2_player_turn: 'Forged into a stronger die' covers ROLL. 009/036_reward: 'Twin Bellows set' sits over the bottom button. The toast is a default floating SnackBar (widgets.dart ~l.1463, 1400 ms) with a heavy black frame.", "why_it_matters": "For 1.4 s the one button the player needs is hidden or intercepts the tap, at the moments of highest intent (retry after a death, leave shop, roll). A child taps the toast and nothing happens.", "fix_direction": "Anchor the toast to the top, under the HUD bar, or give it a bottom margin equal to the bottom CTA height + 16 dp. Make it IgnorePointer so taps pass through. Restyle it as an in-theme pill (no black frame).", "acceptance": "Widget test over every play_session screen: the toast rect does not intersect any button rect at 320x568/360x800/412x915. Re-shot 011, 025 and 029 show the CTA fully visible with the toast present.", "effort": "S"},
{"id": "C2-02", "dimension": "animation", "severity": "P1", "title": "Final-boss kill has no victory beat — the board just goes still", "observed": "021 and 040 (+1200 ms after run_won): boss gone, hero in the same idle pose, dice tray at full brightness with gold 'MAX' rings and purple special rings still lit. Only the four buttons are dimmed. No word, banner or pose says the run is won. 040 still shows the stale '+5 EMBERS — EXACT!'.", "why_it_matters": "The climax of a 15–25 minute run lands as a paused fight. Slay the Spire and Balatro spend 1–2 s celebrating. Here the payoff is deferred to a stats screen.", "fix_direction": "On encounter end with the run won: fade the whole tray (dice too) to about 35% over 200 ms. Show a stage-scoped banner (e.g. 'THE KING FALLS', ≥22 sp, ember glow, 250 ms scale-in with ease-out-back). Hero plays a 300 ms raise-sword pose (2–3 frames or a transform on the existing sprite) and ember particles rise from the boss spot. Sync the victory sting to the banner. Reduced motion: banner fades in, no scale, no particles.", "acceptance": "Boss-kill plates at +600 and +1200 ms at 320/360/412 show the banner fully inside the stage. Every tray die has mean luma ≤50% of its live value. The reduced-motion plate shows the banner with no particles. A widget test asserts the tray is inert and dimmed on run_won.", "effort": "M"},
{"id": "C1-01", "dimension": "animation", "severity": "P1", "title": "(rescoped) Boss-kill fix is unverified: no boss strip, no reduced-motion strip, tray dice still lit", "observed": "Pass: 020/039 luma>230 = 2.0%/1.8%, no NEXT FOE, buttons dimmed on 021/040. The pack has no 40 ms boss-kill strip or reduced-motion strip (the C_*_kill strips are normal foes). On 020/039 the boss is a single flat white silhouette, so 'dissolve on ≥4 frames' is unproven. The tray dice stay fully lit (021/040).", "why_it_matters": "The acceptance was written for the boss; the normal-foe dissolve does not prove the boss path, which has a different sprite and size.", "fix_direction": "Add a C_anim_boss_kill strip (both final bosses) and a reduced-motion variant to the evidence pack. Dim the tray dice with the buttons (overlaps C2-02; take whichever ships first).", "acceptance": "40 ms boss strip at 360x800: no frame with >50% of pixels at luma>230, boss gold dissolve on ≥4 sampled frames. Reduced-motion strip: 0 such frames. +1200 plate: all tray dice dimmed.", "effort": "S"},
{"id": "C2-03", "dimension": "gameplay", "severity": "P2", "title": "Enemy HP reads 0 before the blow lands", "observed": "exact_320x568_t360 (and the same at 320x640/360x800/412x915, both exact and overkill): the enemy panel already reads '0 / 19' while the Flue Crawler is standing with its intent badge up. The '-5' is a ~5 dp spawn near the hero's feet. The hit and dissolve arrive at t520–t720.", "why_it_matters": "The number spoils the kill before the contact frame, so the strike reads as a replay of something already decided and loses its punch.", "fix_direction": "Hold the displayed HP numeral at its pre-hit value until the contact frame, then tick it down with the bar-drain. Spawn the damage number at the foe on contact, not mid-stage. Presentation only; sim untouched.", "acceptance": "t360 plates show the pre-hit HP ('5 / 19'); t520 shows 0. Widget test: the displayed HP equals the sim HP only at/after the contact timestamp. Determinism hashes unchanged.", "effort": "S"},
{"id": "C2-04", "dimension": "accessibility", "severity": "P2", "title": "Yellow damage number drawn over the white hit-flash silhouette", "observed": "020: '-6' yellow sits on the boss's pure-white flash body. 039: '-4' the same, inside the exact ring. C_slag_brute_kill / C_molten_maw_kill 054–056: '-5' overlaps the white foe. Yellow on white is about 1.5:1.", "why_it_matters": "The damage readout, the most important number of the hit, is least legible on the exact frame it appears.", "fix_direction": "Give damage numerals a 2 dp dark outline or shadow (#1a1016) and anchor them above the sprite bbox top + 8 dp, the same lane as the kill readout.", "acceptance": "Rect test on the kill strips for 4 foes + boss: the damage-number rect does not intersect the sprite bbox on any frame. A contrast sample of the number's fill vs its local background is ≥3:1 on 020/039 equivalents.", "effort": "S"},
{"id": "C2-05", "dimension": "onboarding", "severity": "P2", "title": "Song-credit toast fires on a brand-new player's first defeat screen", "observed": "011_run0_run_lost (the profile's first delve): '\"Ashes, Gently\" — first hearing' pops over the summary. controller.dart ~l.407–420 intends 'The Quiet First Delve' (no credits on run 1), but the defeat track is first heard after runsPlayed has already become 1.", "why_it_matters": "The first failure a child sees gets an unexplained adult jargon toast over the retry button. It is noise at the moment encouragement matters most.", "fix_direction": "Gate credits on a 'first delve finished and summary dismissed' flag (or runsPlayed > 1 when phase is run end), not on runsPlayed > 0.", "acceptance": "Unit test: a fresh profile losing or winning run 1 produces no credit flash. Fresh-profile defeat plate shows no toast. The credit appears on the run-2 map.", "effort": "S"},
{"id": "C0-13", "dimension": "animation", "severity": "P2", "title": "(rescoped) Lunge exists; slash trail is still a foe-side decal living ~280 ms", "observed": "C_*_kill 052–056: hero displaced forward (lunge present). The arc trail is drawn around the foe, far from the blade tip, and is still visible on 058 and 060. It is gone on 062.", "why_it_matters": "The trail reads as a sticker on the foe rather than the blade's path, which softens the contact.", "fix_direction": "Emit the trail from the blade tip along the swing (3–4 fading samples), total life ≤120 ms. Remove the foe-side arc.", "acceptance": "Kill strips for 4 foes: trail pixels overlap the blade on 052–054 and are fully gone by 058.", "effort": "S"},
{"id": "C2-06", "dimension": "art", "severity": "P2", "title": "Tall phones: stage is mostly empty sky; actors crammed into the bottom band on a hard-edged black slab", "observed": "exact_412x915_t720: the stage spans ~y300–940 @2x, but hero and foe occupy only ~y740–930. The upper ~60% is empty mountains, with the call-out floating far above. A black rectangle with hard vertical edges sits behind both actors (also visible left of the hero on 020/021).", "why_it_matters": "On the most common modern aspect the fight is small and bottom-heavy. The hard slab edge reads as an unfinished layer.", "fix_direction": "Scale the actor size from stage height (clamped), or cap the stage height and give the space to the tray. Replace the black slab with a feathered ground plane (can ship with C0-10).", "acceptance": "412x915 and 360x800 combat plates: actor bbox height ≥28% of stage height, no visible straight slab edge. 320x568 is unchanged or better.", "effort": "M"}
]}
```

**Files/commands used (read-only):**
- Viewed all A sheets, B_fresh_walk_320, the D sheets at 320x568 and 412x915, the slag_brute and cinder_wisp enemy-turn sheets, and the slag_brute and molten_maw kill sheets. At full resolution: 009, 011, 020, 021, 039, 040, exact_320x568_t360/t720, overkill_320x568_t960, exact_412x915_t720.
- Measured luma with PIL over play_session 020–039 and all kill_readout frames.
- Ran `cmp` between round-01 and round-02 sheets to find which changed.
- Read `backlog.json`, `critic/round-01.md`, `widgets.dart` (SnackBar), `controller.dart` (credit toast) and `reward_screen.dart` (staggered reveal).

**Gaps:**
- There is no boss-kill strip, reduced-motion strip, B_360/412 zoom or kill strips for the other two foes. The idle/enemy-turn/B sheets are identical to round 1, so I judged them from their R1 status.
- I did not listen to any audio.

---

### Maker verification (round 2, exp.3)
- **C0-12 closed**: VERIFIED. 020/021/039/040 show no NEXT FOE. Also pinned by the `overkillCallout` unit tests in test/boss_kill_moment_test.dart.
- **C1-01 "no white-out"**: VERIFIED. I measured luma>230 myself with PIL: 020 = 2.0%, 039 = 1.8%, 021/040 = 0.1%. Round 1 was 100%.
- **C1-01 "dice tray at full brightness on 021/040"**: NOT SUPPORTED by the pixels. Mean luma of the tray region (x60–660, y820–1140 @2x):
  - 021: 99.1 → 48.9, and max 249 → 131.
  - 040: 91.4 → 46.3.
  - A die face at (440,900) on 021 went from (226,214,194) to (96,89,97).

  The tray is drawn at 0.35 opacity and ignores taps, which the widget test asserts. It still *reads* as a lit tray, though, so a stronger fade or a victory overlay (C2-02) is a fair follow-up. I keep the rescope for the missing boss and reduced-motion strips.
- **C1-01 "boss is one flat white silhouette on 020/039"**: VERIFIED by eye. It is the existing enemy hit-flash silhouette at the moment of the kill.
- **C2-01 toast over the primary CTA**: VERIFIED on sheet A1 011/012 (the orange edge of DELVE AGAIN shows under the toast) and A2 025/029.
- **C2-03 enemy HP reads 0 before contact**: VERIFIED on exact_320x568_t360. The panel reads "0 / 19" while the foe stands with its 9/7 badge and the "-5" is small near the hero.
- **C2-04 yellow number on the white flash**: VERIFIED on 020 ("-6") and 039 ("-4").
- **C2-05 credit toast on the first defeat**: VERIFIED on 011 (run0). The code path matches: controller.dart checks `meta.runsPlayed > 0` when the defeat track is first heard. I have not re-checked when runsPlayed increments, so that ordering is ASSUMED.
- **C1-05 burn chip on the dead boss**: VERIFIED on 021 ("🔥9").
- **C0-13 trail at 058/060, C2-06 tall-phone stage**: ASSUMED. I did not re-inspect those frames this round.
- **Reward diamonds are mid-reveal**: ASSUMED, as the critic says (staggered reveal). Not listed as an issue.
