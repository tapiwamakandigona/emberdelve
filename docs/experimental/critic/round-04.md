## Emberdelve critic, round 4 (exp.5, 0.184.105, source commit baed9e9 / ddeb943)

**Verdict.** The three bundled fixes landed. The first-defeat screen is quiet, and the final kill now has a real victory beat: a banner, rising embers and a dimmed tray. The dimming is measured, not eyeballed. But the beat sits on a pile of other text: in 039 the stage shows "+5 EMBERS — EXACT!", then "VICTORY! -4", then STRAIGHT/TRIPLE/PAIR +2, plus a burn chip. The boss is still a flat white block for about 400 ms, and the fight itself (no foe approach, frozen white hero, blob sprites) is unchanged pixel for pixel.

**What changed vs round 3 (`cmp` on every frame):** only these differ:
- play_session 011, 012, 020, 021, 039, 040;
- the four C_*_kill sheets. The only difference there is the new 200 ms tray-dim ease on frames 044–046, which is fine and not a regression;
- the new boss_kill strips and plates.

Everything else is byte-identical to round 3: the fresh walk at 320/360/412, the enemy-turn and idle strips, all kill_readout frames, and audio_report.md.

### Scores
| Dim | Score | Why | Δ vs R3 |
|---|---|---|---|
| Art | 5 | Foe/hero pixel-scale mismatch, wireframe grid, black slab edges all unchanged. At 412 the hero is a small figure in an empty sky under the banner (victory_412x915_t1200) | = |
| Animation | 5 | The victory beat is a real gain: ease-out-back scale-in, embers, sword lift at t1200. But the boss holds pure white t0440–t0840, then hard-cuts to particles at t0880. Enemy turn still has no approach, and the hero still freezes white (slag_brute enemy-turn 032–038) | = (+ at run end only) |
| Audio | 5 | Report is byte-identical: 21 SFX, peaks up to −0.2 dBTP. The run_won sting still fires at the phase switch, not on the banner (maker disclosed). I cannot listen | = |
| Gameplay | 7 | Decisions are clear. HP still reads 0 before contact (exact_*_t360 unchanged) | = |
| Loop | 6 | Unchanged. The Warden unlock still reads 0/120 (004) | = |
| Menus/layout | 6 | The banner is inside the stage at all 3 sizes. But it overlaps the hero at 320 (victory_320x568_t0600/t1200). The title still scrolls. Toast problems (C3-01/02) and the ghost line behind the CTA (011/030) remain | = |
| Onboarding | 5 | The first defeat no longer gets a credit toast. The copy (cards of 50+ words, "ITS NEXT MOVE"), the unexplained chips and the missing End-turn cue are all unchanged | = |
| Accessibility | 6 | Reduced motion is honoured on the victory beat: 0 px shake (my offset search), no particles, fade-in. The yellow damage number still sits on white (039 "-4") | = |
| Stability | 7 | 4 runs, 569 steps, 0 violations, 0 problems | = |
| Overall | 5 | One S+M bundle that fixes the ending. The minute-to-minute fight is untouched | = |

### Must keep
- **Victory beat.** Banner scale-in (t0640→t0720), embers rising from the boss spot, raised-sword pose (t1200 vs t0000), tray and buttons dimmed.
  - My measurement on ember_tyrant_normal: die mean luma is 145/154/143 at t0000 and 32/65/60 at t1200, i.e. 22–42% of live. That meets the ≤50% target.
  - Reduced strip: 0 px screen offset on every frame, no particles.
- **Harness quality.** 40 ms boss strips in normal and reduced motion, plus plates at 3 sizes. Peak share of frame pixels at luma>230 is 2.1% (I confirmed it).
- **Quiet first delve** (011/012). The earlier strengths also still hold: CTAs clear of the toast, no white-out, the NEXT FOE split, the hero lunge.

### Backlog verdicts
**Closed (3):**
- **C1-01.** Both boss strips at 360x800 have 0/40 frames with >50% of pixels at luma>230 (the peak is 2.1% of the frame). The gold dissolve shows on t0880, t0960, t1040, t1120 and t1200 (≥4 frames). The reduced strip has 0 such frames. At +1200 every tray die is dimmed (measured above).
- **C2-02.** The banner is fully inside the stage on all six victory plates. Every die is at ≤50% of its live luma. The reduced plate (reduced t1200) shows the banner and no particles. test/victory_beat_test.dart exists (read, not run). Side effects are filed as new issues C4-01 to C4-03.
- **C2-05.** 011 (a fresh profile's first defeat) has no toast. There are 3 new tests in song_credit_test.dart, and the gate is in controller.dart (`firstDelve`). The run-2 map (014) shows no credit either. That is expected: the map track was already heard, so no plate proves "credit resumes on delve 2". Verify with a delve-2 new-track plate if you want it shown.

**Not fixed (pixel-identical to R3):**
- C0-01, C0-03, C0-04, C0-05, C0-06, C0-07, C0-08, C0-09, C0-10, C0-11, C0-13, C0-14, C0-15
- C1-02, C1-03, C1-04, C1-05, C1-06, C1-07, C1-08
- C2-03, C2-04, C2-06
- C3-01, C3-02, C3-03, C3-04

Re-checks inside the new frames:
- **C0-03:** 039 still has STRAIGHT!/TRIPLE!/PAIR +2 stacked over the HP bar, now also under the banner.
- **C1-05:** the burn chip "11" stays after the boss has dissolved (040) and a blood pool is painted over it; the same happens in 020 with "9".
- **C2-04:** "-5"/"-4" still sits on the white silhouette (victory_360_t0600, 039).
- **C3-04:** the ghost line is still behind the CTA on 011. 030 also has a ~25%-opacity mid-screen line ("The Bellows Knight hung by a thread — 15 HP") at y≈1030 @2x; probably mid-fade, verify.

**Regressions:** none.

### New issues, ranked by impact per effort
1. **C4-01 (P2, S): The victory moment is a pile-up of text.**
   - 039: "+5 EMBERS — EXACT!", then "VICTORY!" with "-4" butted against it so it reads "VICTORY! -4", then three stacked call-outs, the burn chip and the gold MAX ring, all inside a ~158 dp stage.
   - At 320x568 t0600 the "-5" is on the banner and the banner covers the hero's sword arm. At t1200 the "V" still overlaps the hero.
2. **C4-02 (P2, S): The boss death is a flat white block for ~400 ms, then a hard cut.**
   - There are ~20k px at luma>235 in the boss rect on every sample from t0440 to t0840. At t0880 it jumps straight to particles with no in-between frame.
   - The reduced strip is identical, so reduced-motion users get a 400 ms white slab.
3. **C4-03 (P2, S): The victory beat lasts about 1.1 s and the sting arrives late.**
   - Code: 260 ms + `_deathTime` 700 ms + 150 ms, then the phase switch fires the run_won sting.
   - So the banner plays with only boss_death under it, and the fanfare lands on the summary cut. This is inferred from code plus the maker's note; verify.
4. **C4-04 (P3, S): The boss-kill shake moves the whole screen, HUD included.**
   - At t0640 the frame is offset by −12/−8 px @2x, and a dark sliver shows past the top bar's right edge (x≈692).
5. **C4-05 (P3, S): The boss strips never show a real boss.**
   - The fixture re-dresses the seed-1 crawler: "/19" HP, and the Ember Tyrant and Ashen Colossus strips have identical white-pixel counts.
   - The only real-boss frames (020 Hearthless King, 039 Ember Tyrant) catch the boss as a white block. So no boss silhouette or dissolve has ever been reviewed.

### Build order
1. C0-01+C0-05: the enemy-turn choreography, the most-repeated animation in the game.
2. C0-06+C1-03+C1-07: the child copy pass.
3. C0-03+C1-02+C4-01: one call-out lane rule, including the victory moment.
4. C0-07: title with no scroll.
5. C4-02+C4-03+C4-05: boss death polish, sting sync, and a real-boss fixture.
6. C2-03+C2-04: HP timing and the damage number over the white flash.
7. C1-08: End-turn cue after the tour.

```json
{"round": 4, "scores": {"art": 5, "animation": 5, "audio": 5, "gameplay": 7, "loop": 6, "menus_layout": 6, "onboarding": 5, "accessibility": 6, "stability": 7, "overall": 5}, "closed": ["C1-01", "C2-02", "C2-05"], "regressions": [],
"fix_next": ["C0-01+C0-05", "C0-06+C1-03+C1-07", "C0-03+C1-02+C4-01", "C0-07", "C4-02+C4-03+C4-05", "C2-03+C2-04", "C1-08"],
"issues": [
{"id": "C4-01", "dimension": "menus_layout", "severity": "P2", "title": "Victory moment stacks banner, damage number, exact-kill line, tray call-outs and burn chip in one 158 dp stage", "observed": "play_session/039_run3_run_won (360x800 @2x): '+5 EMBERS — EXACT!' at y≈440, 'VICTORY!' at y≈520 with '-4' butted against its right edge so it reads 'VICTORY! -4', 'STRAIGHT!/TRIPLE!/PAIR +2' stacked at y≈620–715 across the stage floor and HP bar, the burn chip '11' at x≈640 y≈652 and a gold impact ring around the boss. 020 is the same with '-6' and chip '9'. boss_kill/victory_320x568_t0600: the '-5' sits on the lower middle of the banner and the banner's 'V' overlaps the hero's sword arm; t1200: the 'V' still covers the hero's forearm.", "why_it_matters": "The payoff of a whole run should read as one word. Right now it is a word salad, and at 320 the banner hides the hero doing the victory pose.", "fix_direction": "When _victoryBeat turns on: fade out over 150 ms, on the banner's first frame, the damage number, the tray-lane call-outs (_noteLife pops), the kill-readout line and every status chip. Place the banner by rect: centre it in the free stage area above the actors' heads (stage top + 8 dp to hero bbox top − 4 dp), and step the font down from 34 to 22 sp until it fits without intersecting the hero or boss bbox. Presentation only.", "acceptance": "Rect test at 320x568/360x800/412x915 at +600 and +1200 ms: the banner rect intersects no other visible Text rect (opacity >0.1) and not the hero sprite bbox. Re-shot 039/020 show only 'VICTORY!' plus the HUD numbers. Reduced-motion variant passes the same test.", "effort": "S"},
{"id": "C4-02", "dimension": "animation", "severity": "P2", "title": "Boss death holds a flat pure-white block ~400 ms, then hard-cuts to particles", "observed": "boss_kill/ember_tyrant_normal_360x800 and ashen_colossus_normal_360x800: 19–22k px at luma>235 in the boss rect (x420–720, y600–880 @2x) on every sample t0440–t0840, then 0 at t0880, where the gold dissolve starts with no mixed frame. ember_tyrant_reduced_360x800: identical 400 ms white hold. victory_360x800_t0600 shows it as a featureless white rectangle with '-5' on it.", "why_it_matters": "A 400 ms solid white box reads as a missing texture, not an impact. It is the last image of the boss the player sees, and reduced-motion players get the same bright slab.", "fix_direction": "Cap the white hold at ≤120 ms (3 frames at 40 ms), then over 160 ms lerp the silhouette from white to the sprite tinted ember orange (ColorFilter lerp), then start the dissolve from the tinted sprite. Reduced motion: no white; the sprite desaturates and fades over 300 ms. Presentation only.", "acceptance": "Boss strips (normal): ≤3 sampled frames with >10k px luma>235 in the boss rect, and ≥2 frames showing sprite pixels and dissolve particles together. Reduced strip: 0 frames with >2k px luma>235 in the boss rect.", "effort": "S"},
{"id": "C4-03", "dimension": "audio", "severity": "P2", "title": "Victory beat lasts ~1.1 s and its sting fires later, on the summary cut", "observed": "combat_screen.dart _enemyDeath: 260 ms + _deathTime (_pace(700)) + 150 ms, then the phase switch. The run_won music sting plays at the phase switch (maker's own 'Not verified' note in ddeb943). So the banner (visible from t0640) plays over boss_death only, and the fanfare lands with the summary. Inferred from code plus the maker note; verify.", "why_it_matters": "The emotional peak is split in two: a silent banner, then a sting over a stats screen. A slow child barely registers a 1.1 s banner before the summary cuts in.", "fix_direction": "Start the victory sting on the banner's first frame (duck boss_combat music over 200 ms) and do not replay it on the summary. Hold the beat to ≥1.8 s after the banner lands (a tap anywhere skips to the summary), then crossfade 250 ms to the summary. Presentation and audio only.", "acceptance": "Choreography log: victory sting start within ±50 ms of the banner intro start; no second sting at the summary. Harness: summary appears ≥1800 ms after the banner's first frame unless tapped. sfx_headroom.py passes with boss_death + victory overlapped.", "effort": "S"},
{"id": "C4-04", "dimension": "animation", "severity": "P3", "title": "Boss-kill screen shake moves the HUD and exposes the screen edge", "observed": "ember_tyrant_normal_360x800: best-match offsets vs t1600 are t0480 (−8,−2), t0560 (0,+12), t0600 (−10,+2), t0640 (−12,−8), t0680 (−10,−2) px @2x for the whole frame. At t0640 the top bar ends at x≈692 with a dark sliver to the right. The reduced strip correctly shows 0 offset.", "why_it_matters": "Shaking the gold/embers bar and the tray makes the UI feel loose. The exposed edge looks like a rendering bug on a phone.", "fix_direction": "Apply the shake transform to the stage (actors + backdrop) only, or overscan the background by 16 dp so no edge is revealed. Keep the HUD and tray fixed.", "acceptance": "Boss strips t0440–t0840: top bar, enemy panel and tray rects have 0 px offset vs t1600; stage content may move. No frame shows a background sliver at any screen edge.", "effort": "S"},
{"id": "C4-05", "dimension": "art", "severity": "P3", "title": "Boss-kill review strips re-dress the seed-1 crawler, so no real boss silhouette or dissolve has been reviewed", "observed": "C_anim_boss_kill_*: both bosses show the same crawler sprite (tinted), HP '/19', and identical white-pixel counts frame by frame between ember_tyrant and ashen_colossus normal strips. The only real-boss frames (020 Hearthless King /78, 039 Ember Tyrant /81) catch the boss as a white block.", "why_it_matters": "The final boss is the most important sprite in the run and the one players screenshot. Its death has never been judged.", "fix_direction": "In tool/boss_kill_frames_test.dart, load the real boss encounter's sprite key and max HP (a presentation fixture; no sim change), and add the third boss (Hearthless King).", "acceptance": "Three boss strips whose t0000 frames differ in silhouette and show the real max HP (/78–/81 class). The C4-02 acceptance numbers are re-measured on these.", "effort": "S"}
]}
```

**What I did (read-only):**
- Read MANIFEST.md, audio_report.md and the round-3 critic.md.
- Viewed D_victory_plates, all four boss strips (the ashen_colossus reduced strip only by pixel measurement), B_fresh_walk_320, A1, the slag_brute enemy-turn strip and the R3-vs-R4 kill-sheet crop.
- Viewed at full resolution: victory_360 t0600/t1200, victory_320 t0600/t1200, victory_412 t1200, boss strip frames t0000/t0560/t0640, and play_session 011, 014, 020, 030, 039, 040.
- `cmp` of every round-04 frame and sheet against round-03.
- Python/PIL measurements:
  - tray-die luma at t0000 vs t1200;
  - per-frame count of pixels at luma>235 in the boss rect across the normal/reduced strips;
  - whole-frame luma>230 share;
  - shake offsets by block matching;
  - 039 tray luma vs round 3.
- Read commit ddeb943 (message and the controller/combat_screen diffs) and lib/ui/victory_beat.dart.

**Gaps:**
- I did not run the maker's tests.
- The real play_session 039 shows the tray at the same luma as in round 3 (about 50% of live). That plate may have been taken before the 200 ms ease finished, so I judged tray dimming from the boss strip.
- I can't hear anything, so the audio findings come from the report and the code.
- The 030 mid-screen ghost line may be a mid-fade frame; verify.

---

## Maker verification notes (round 4, exp.5)

Closed ids (C1-01, C2-02, C2-05): accepted.
- VERIFIED, maker's own gates: 3 red-then-green tests in test/song_credit_test.dart; test/victory_beat_test.dart covers 3 sizes plus reduced motion; the full suite passes 1592/1592.
- VERIFIED, plate 011_run0_run_lost: no toast.

New issues:
- C4-01 (text pile-up at the victory moment): VERIFIED on 039_run3_run_won, viewed at full resolution. "+5 EMBERS — EXACT!", "VICTORY!" with "-4" butted against it, STRAIGHT!/TRIPLE!/PAIR +2 under the banner and over the HP bar, burn chip "11".
- C4-02 (white boss block ~400 ms): VERIFIED with PIL on ember_tyrant_normal/reduced_360x800, boss rect x420–720 y600–880 @2x. 19.4k–22.1k px at luma>235 on every frame from t0440 to t0840, then 0 at t0880. The reduced-motion strip is the same (19.5k–20.3k).
- C4-03 (sting lands on the summary cut): VERIFIED from code. `_enemyDeath` = 260 ms + `_deathTime` + 150 ms, and the run_won music sting only starts on the phase switch. As heard: ASSUMED, not listened to.
- C4-04 (boss-kill shake moves the HUD): VERIFIED with PIL block matching. The top bar at t0640 is offset (−12, −8) px @2x against t1600.
- C4-05 (the strips re-dress the seed-1 crawler): VERIFIED. This is the maker's own fixture; both "bosses" share the crawler silhouette and show "/19".

Critic's gap note:
- ASSUMED: plate 039's tray at ~50% of live may be caught mid-ease. The widget test measures 46–48% at +1200 ms, and the critic's strip measurement gives 22–42%.
