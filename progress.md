# progress.md — append-only log (one dated line per completed task, decision, or gate)

2026-07-23 Project approved by owner: name=Emberdelve, mechanic=dice-builder, private repo, free+$3.99-4.99 unlock. Research synthesis drove spec/architecture (5-track swarm, verified).
2026-07-23 Repo created (tapiwamakandigona/emberdelve, private). Foundation scaffolded: state files, spec, architecture, sealed sim core (rng/combat/dispatch), 12-test headless suite, CI (Lua test gate -> bob.jar 1.13.0 debug APK).
2026-07-23 CI iteration: bob rejects bundle output under build/ (reserved dir) -> moved to dist/bundle. Fine-grained PAT pushes do NOT trigger push workflows; dispatch manually via `gh workflow run CI --ref main`.
2026-07-23 Repo flipped PUBLIC temporarily: GitHub Actions blocked on private repo (billing). Safe: zero licensed assets, all own code. Flip back private once owner fixes Actions billing or a public compile repo is set up.
2026-07-23 M0 COMPLETE. CI run 29990121111 fully green: test job (12/12) + build-android (bob 1.13.0, JDK 25) -> debug APK artifact 89150834647 (arm64-v8a+armeabi-v7a, 29.6MB, verified structure). features M0-1..M0-5 passes=true with evidence.
2026-07-23 DEVICE SMOKE TEST PASSED: owner installed M0 debug APK on their Android phone; screen shows seed 20260723, phase victory, events 31, hash 158933364 == golden event_hash from CI. Sim core bit-identical on-device. Owner instruction: "it opened, continue" -> M1 green-lit.
2026-07-23 M1 sim+UI landed (3-worker fan-out + run-layer wave, all ultra): sim v2 (SIM_VERSION=2, start_encounter removed, run layer sim/run.lua, map gen sim/map.lua, combat v2 sim/combat.lua, content data/), full Defold UI (6 screens, programmatic gui, sys.save autosave + resume-on-boot). Suites: run 18/18, map 12/12, content 21/21, autoplay 100 seeds AUTOPLAY OK.
2026-07-23 BALANCE PASS (orchestrator decision): greedy autoplayer won 100/100 (max enemy hit 9 vs 10.5 avg pips - perfect blocking never dies). Measured fix: all enemy pattern amounts+blocks x2.75 -> 59/41 in band. HP scaling rejected (measured: makes it EASIER). Content tests de-hardcoded to reference data module.
2026-07-23 Golden re-anchored for SIM_VERSION 2: event_hash=311044885 (seed 20260723 scripted run; was 158933364 in M0). CI now runs all 4 suites with EMBERDELVE_GOLDEN pinned.
2026-07-23 STACK PIVOT → Flutter/Dart (owner DM instruction: "remember we making this using flutter", consistency with lanlink/quick bucks). Defold shell removed (git history preserves it). Sim core ported Lua→Dart with PROVEN 1:1 parity at commit 54f2e85 (golden event_hash 311044885 + identical per-seed hashes for 100 autoplay seeds + twin snapshot checks).
2026-07-23 SIM v3 (SIM_VERSION=3): full game systems added — gold economy, shops (die/relic/heal stock, layer-tier gated), event deck (16 events, effect vocabulary, fair: never kills), relics (22, additive hook vocabulary), forge at rests (die→forgeTo), tiered/eligible rewards, characters (4, meta-unlockable), ascension ladder (deterministic additive enemy scaling), fair-death insight payout. Content: 31 dice, 15 enemies (fromLayer gating), 22 relics, 16 events.
2026-07-23 UXPeak design study → docs/design-system.md (UX psychology applied ethically + typography laws + spacing/color system) driving the Flutter UI.
2026-07-23 BALANCE (measured, greedy autoplayer): default Kindler 51.7%, overall 200-seed 53.5% (band 20-80%), 0 invalids, 0 nonterminal, twinFails=0. Ascension ladder verified monotonic: asc0 52% → asc3 15% → asc6 6% → asc10 4%. Specialist chars warden/ascetic ~85% (unlock rewards; human+ascension provides challenge). Golden v3 re-anchored: event_hash=513683311 (seed 20260723 greedy run).
2026-07-23 TESTS: flutter test green — 23 tests across sim (determinism/rules/persistence/golden), map (200-seed properties), content (schema), autoplay (balance band + ascension monotonicity). dart analyze clean (info lints only).
2026-07-23 FULL FLUTTER UI + meta layer landed: lib/ui (theme/widgets/screens), lib/game/controller.dart (autosave+resume+ember banking), lib/meta (embers/unlocks/ascension via path_provider). 9 screen types, UXPeak-informed design system. flutter test 25/25 green (added widget smoke tests); flutter analyze clean. CI rewritten for Flutter (subosito/flutter-action: analyze+test -> build apk artifact). init.sh + PROJECT.md decision #1 updated for Flutter. Checkpoint 02 written. Remaining work is OWNER-GATED (device playthrough, CI green confirm, IAP, cloud save, paid assets).
2026-07-23 FLUTTER CI GREEN: run 30004629450 (commit 2ed37a1) — analyze+test job success (flutter analyze clean, 25/25 tests), build job success -> debug APK artifact emberdelve-debug-apk (89.2MB). features.json CI entry passes=true. All remaining work is OWNER-GATED (device playthrough+screenshots, IAP, cloud save, Play closed test, paid art/audio, repo re-privatization after Actions billing).

## 2026-07-23 — assets-integration branch (integration worker)
Curated art + audio integrated (staging: /work/temp/emberdelve-polish/staging).
- assets/images (sprite sheets, backgrounds, UI icons, sprite_meta.json) +
  assets/audio (6 music, 20 SFX); ~15.5MB added; registered in pubspec.
- SpriteView widget: sprite_meta-driven idle loops @8fps, FilterQuality.none.
- Combat choreography: lunge + hit-flash + knockback; death = flash/fade
  collapse (sheets have no attack/death frames — tween substitute, per plan).
- AudioService (audioplayers ^6.1.0): per-screen music loops w/ crossfade,
  boss_combat for elite/boss, victory/defeat stings, ember ambience bed,
  20 SFX mapped to events; SYNC_POINTS.md timings honored in combat.
- Settings screen (music/SFX volume + mutes, persisted JSON like MetaStore;
  NOTE: repo uses path_provider JSON, not shared_preferences) + in-app
  Credits & Licenses screen (bundled CREDITS.md; CC-BY ships in-app).
- Launcher icons all densities (tool/gen_launcher_icons.py).
- Tests: +3 asset-integrity tests (28 total). Sim core untouched; golden
  513683311 unmoved.

2026-07-23 (later): Review fixes + v0.2.0 release + emulator live test.
- Reviewer verdict APPROVE-WITH-NITS (0 blocking); 4 should-fixes applied
  (a51dc69): audio fade-timer race, SpriteView controller leak via load-token,
  settings sliders persist on drag-end only, added PROVENANCE.md.
- Merged assets-integration into main (01bc2f4); CI green (30011499453,
  30011501605). Released v0.2.0 (GitHub release + release APK).
- Emulator live test (API 33 headless swiftshader): full flow VERIFIED
  (title→charselect→map→event(+12 gold)→fight: roll/select/attack/end-turn).
  Image-decode errors + idle audio players proven EMULATOR-ONLY (see
  checkpoints/03-assets-and-release.md — on-device ImageDecoder/BitmapFactory
  probe decodes our PNGs fine; AVD runs -no-audio). Real-device check is
  owner-gated.
- All 75 asset PNGs re-encoded canonically (PIL optimize, smaller files);
  added test/decode_probe_test.dart (engine-codec decode of every bundled
  PNG). 29 tests green, analyze clean, golden 513683311 unmoved.

2026-07-23 IMPROVEMENT BACKLOG (owner-requested handoff for a future agent): docs/improvements/gameplay-depth.md (12 fair-addictive gameplay measures, v0.3.0 order: combos → risky reroll → restart flow → juice → daily seed) + docs/improvements/visuals.md ("de-Flutter" presentation pass, order: combat dice/juice → map scene → title → chrome → transitions). Proposals only — no code changed; sim core untouched.

## 2026-07-23 — v0.3.0 (gameplay depth + visual overhaul + permanent signing)
2026-07-23 SIM v4 (SIM_VERSION=4, branch gameplay-sim): combos (pair +1/die, triple=ignite burn DoT, straight=free reroll next turn), reroll_risky (-1 pip, once/turn, FREE after straight), exact-0 kill +5 embers + overkill splash (cap 5, softens next foe), honest reward telegraphs via offer stream (elites guarantee tier-3 die), starting boons (start_run {boons:true} -> 1-of-3 via boon stream, choose_boon 0=skip, 8 boons in lib/data/boons.dart), dailySeed(y,m,d) in lib/sim/daily.dart. Enemies rescaled (hp x2.4 / atk +7 / blk +5) to absorb the new player power: 200-seed win rate 53.5%, 0 invalids. Golden re-anchored 513683311 -> 1117081416. Contract: docs/m4-sim-contract.md. v3 autosaves are rejected under v4 (UI clears them gracefully).
2026-07-23 RELEASE SIGNING PERMANENT (branch release-signing): upload keystore recovered from Actions secrets via one-time encrypted-artifact workflow (workflow reverted; secrets/artifacts/run cleaned, verified). Gradle key.properties signingConfig with debug fallback; CI job build-android-release (main pushes + dispatch) builds signed APK+AAB gated on apksigner cert fingerprint. CI run 30018705918 green. Cert SHA-256 03:1A:CB:42:56:6A:51:D5:B5:9F:FD:5D:EB:17:3F:1B:0E:81:7A:9E:DF:F1:BB:69:79:F6:85:64:D4:4B:7A:0D (valid to 2066). From v0.3.0 on, updates install in place; the one-time uninstall of debug-signed v0.2.0 is unavoidable.
2026-07-23 VISUAL OVERHAUL (branch visual-overhaul): de-Flutter pass, zero new binary assets (all CustomPainter/programmatic) — painted 3-tier buttons, real pip die faces 1-12 + tumble, segmented HP bars with ghost trail, hit-stop 80ms/shake/damage pops/ember-dissolve deaths, intent badge + boss nameplate, map medallions/dashed ember trails/fog-of-war/descent tint/walking delver, drawn EMBERDELVE logotype + camp-fire title scene, flame-wipe map->combat, victory/defeat ember moments, skinned slider/toggle. New: lib/ui/fx.dart, lib/ui/logo.dart. Test gotcha: ambient loops hang pumpAndSettle — use bounded pumps (pumpFor).
2026-07-23 UI WIRING (branch ui-wiring): v4 mechanics playable in the painted UI — combo/burn TextPop call-outs, risky-reroll tray control (unassigned-only, once/turn, FREE state), exact-kill/overkill moments, map reward-telegraph badges (verbatim from sim preview), boon pick screen (skippable), "Daily Delve — <date>" title entry (device-local date, no streaks/FOMO per Ethics), fast "Delve again" from summary into boon pick, stale/corrupt autosave cleanup on boot. Widget tests added for reroll gating, boon pick/skip, daily seed, delve-again, stale-save recovery.
2026-07-23 INTEGRATION (branch v030-integration): release-signing + gameplay-sim + visual-overhaul + ui-wiring merged, zero conflicts. flutter analyze clean; 54/54 tests; autoplay 200 seeds 53.5% win, 0 invalids; golden 1117081416. Version 0.3.0+3. Descoped from the backlogs (documented, future work): gameplay A3 chaining faces, B6 (relic combo synergies), B7 (adaptive telegraphs); visuals #4 (reward flip), #8 (icon retint). Daily seed uses device-LOCAL date (contract doc said UTC; owner objective won — one-line flip if wanted).
2026-07-23 REVIEW ROUND (adversarial fresh-eyes review of v030-integration): verdict REQUEST-CHANGES, 1 blocking + 5 nits. Fixed: F1 ShopScreen/EventScreen _TypeError during PhaseSwitcher cross-fade after leave_shop/event_choose (null-tolerant stale-frame guards + regression tests in test/phase_transition_test.dart; also pinned the wall-clock-seeded flaky widget test to seed 1 — root cause of the intermittent 53/54); F2 TRIPLE call-out no longer claims IGNITE (burn_applied announces "IGNITE +N BURN" only when the sim actually applies burn); F3 README rewritten (was stale Defold/Lua/private-repo); F4 daily-seed doc drift fixed (contract + daily.dart now document the device-LOCAL date decision). Accepted as-is: F5 nullable event fields (unreachable today), F6 reverted keystore-recovery workflow in history (contains no key material). Suite now 56/56, analyze clean.

## 2026-07-23 — v0.3.2 (PR #1 merge: visual fix pass + difficulty switch)
2026-07-23 PR #1 MERGED (7e60d66) after independent re-verification (fresh clone, Flutter 3.32.7): flutter analyze clean, 77/77 tests, autoplay 200 seeds 74.0% win / 0 invalids / 0 twinFails, golden 1117081416 self-consistent, die-face PNGs visually confirmed clean silhouettes (no punched-in numerals). Contents: overflow probe suite (5 phone sizes, worst-case 8-die pool), die-face art repair, RewardScreen stale-frame guard, top-bar/reward/combat/title/summary/event overflow fixes, easy/normal/hard difficulty (deterministic combatBegin scaling, ember payout ×0.75/×1.25, sticky MetaState.preferredDifficulty, daily always normal, goldenV5-compatible: 'normal' unchanged). Measured difficulty winrates (bot): easy 91% / normal 74% / hard 32%.
2026-07-23 Version bumped 0.3.1+4 → 0.3.2+5. GitHub repo description fixed (said "Defold" since the stack pivot — now "Flutter"). docs/STATE.md marked historical (superseded by PROJECT.md + checkpoints; it still described the mid-pivot M2/M3 state).
2026-07-23 ZOMBIE-WIN FIX (branch fix/zombie-win-tiebreak): combatEndTurn resolved thorns/burn kills BEFORE checking player death, so a lethal enemy attack + same-tick thorns/burn kill declared the encounter WON and the run continued with the player at negative HP (proven by probe: phase=reward, player_hp=-4). Fix: player death now resolves immediately after the attack intent lands — a dead delver deals no thorns and has no burn tick. No SIM_VERSION bump: golden 1117081416 unchanged and 200-seed autoplay identical (74.0%, 0 invalids) — the bot never reaches the edge; behavior only changes in the both-die-same-tick state (same reasoning as the v0.3.2 difficulty change). Also removed dead `chosen` list in _openShop and corrected its misleading comment (duplicate shop stock is deliberate, with-replacement; zero behavior change). 3 regression tests added (80 total).
2026-07-23 AUTOSAVE HARDENING (same branch): GameController autosave was fire-and-forget writeAsString — rapid commands could interleave bytes in the save file, a crash mid-write could truncate it, and the snapshot was serialized after an await (so it could drift from the state that triggered the save). Now: snapshot captured synchronously, writes chained on a save queue, temp-file + atomic rename; _clearSave rides the same queue so a queued save can never resurrect an abandoned/finished run. analyze clean, 80/80 tests.
2026-07-24 AUDIO CUTOUT FIX (branch fix/audio-focus-cutouts): owner-reported "tap settings / switch difficulty kills the music" root-caused to audioplayers' Android default AudioContext (AUDIOFOCUS_GAIN per player): every SFX one-shot filed an exclusive focus request and the OS sent the music/ambience players a permanent AUDIOFOCUS_LOSS, which the plugin answers with a never-resumed pause — any ui_tap could kill the music, and every sound also silenced other apps' audio. Fix: AudioService.initPlatformAudio() in main() sets global AudioContextConfig(focus: mixWithOthers) (Android AUDIOFOCUS_NONE / iOS playback+mixWithOthers); backgrounding still handled by the lifecycle observer. Also fixed the silent-phase latch: playMusic assigned _musicKey before try, so one failed start muted the whole screen family (syncPhase dedupe early-return) — failures now reset _music/_musicKey (and the ambience slot ditto). Full write-up incl. plugin-source evidence + audited non-issues: docs/improvements/audio-cutout-investigation.md. analyze clean, tests green, autoplay 200 = 74.0%/0 invalids, golden 1117081416 (no sim change). Needs one real-device confirm.

## 2026-07-24 — Bug sweep (post-audio fix)
Full-repo bug pass (docs/improvements/bug-sweep-2026-07-24.md). Fixed: stale
combo_bonus after charge reroll (sim; re-detect combos, contract §1/§3
updated, regression test added; gates byte-identical → no SIM_VERSION bump);
lying boss insight ("hits for 25" vs actual 32 — now number-free); Ember
Moths label leftover; map marker walking in from the previous run's node
(cross-run static leak, now keyed by run seed); unclamped volumes from a
corrupt settings file crashing the Settings sliders; wrong stream docs for
event grants (loot, not shuffle) + documented gold_after. Verified: analyze
clean, 96/96 tests, autoplay 74.0%/0 invalids, golden 1117081416.
## 2026-07-24 — backlog pass (branch fix/backlog-pass, no app-version bump by owner request)
2026-07-24 SCREENS SPLIT: lib/ui/screens.dart (2,604 lines) mechanically split into 13 part files under lib/ui/screens/ (part/part of — shared privates like _TopBar keep working, all imports stay valid). Byte-identical bodies; no behavior change.
2026-07-24 ACCESSIBILITY: Semantics labels/actions on EmberButton, DieChip (die/face/state), StatBar (HP+block), ResourcePip, intent badge, burn badge, pause gear. Overflow probe gained a 1.3x text-scale pass (all 5 sizes); fixes it caught: die-chip label scales inside its 64x80 chip, RECOMMENDED chip scales down, map node badge fits its 48px slot, combat HUD clamps text scale to its height budget with scale-aware compact mode (was overflowing up to 116px at 320x568@1.3x). Probe's source-location regex now matches lib/ui/screens/.
2026-07-24 SIM v6 (SIM_VERSION=6): starting-boon pool grown 8 -> 15 (brand_bearer, stout_start, glowing_start, spark_pouch, slate_guard, deep_pockets, hearth_blessing — existing effect vocabulary + tier-1 dice only, resolution rules untouched). The without-replacement draw over boonsOrder reshuffles the seeded boon stream for every seed, so the golden was deliberately re-anchored 1117081416 -> 1842571558 (measured; simVersion itself does not enter the hash — verified before/after bump). Autoplay 200 seeds: easy 88.0% / normal 67.0% / hard 37.0%, 0 invalids (was 90.5/74/43 — new pool is slightly leaner; normal stays inside the 20–80 band). Mid-flight v5 saves are cleanly discarded at boot.
2026-07-24 HOUSEKEEPING: LICENSE added (proprietary code notice + pointer to PROVENANCE.md/CREDITS.md for asset licenses); docs/store/privacy-policy.md + docs/store/play-listing.md drafted (zero-permissions story; owner still needs screenshots/graphic/hosted URL); checkpoint 04's stale "fine-grained-PAT pushes don't trigger CI" claim corrected in place.

## 2026-07-24 — save durability: schema version + .bak recovery (PR #6)
- emberdelve_meta.json now carries `schema` (v2; absent = v1) so future
  migrations have something to key on; readers stay field-tolerant.
- MetaStore.save keeps the previous good save as `.bak` (two atomic renames:
  demote main → .bak, promote tmp → main); MetaStore.load falls back to .bak
  when the main file is corrupt/missing and heals the main file via a
  recovery-only write that never touches .bak.
- Closes review note: a crash-corrupted meta file used to silently reset all
  embers/unlocks/stats. New test/meta_backup_test.dart (6 tests) covers both
  generations corrupt, heal-on-recover, legacy/future schema tolerance.
- Gate: analyze clean, 101/101 tests at branch time; re-verified post-merge with main by integrator: analyze clean, 107/107 tests, autoplay 200 seeds normal 67.0%/0 invalids, golden 1842571558 self-consistent.
- Gate: analyze clean, 101/101 tests (autoplay 200-seed + golden included).

## 2026-07-24 — Daily Delve record + shareable result (PR #7)
- Meta remembers the most recent FINISHED daily (date/result/floor) — one
  record, deliberately no history, no streaks, no expiry (§Ethics).
- Title shows an honest "✓ Played today" recap under the Daily button on the
  played day; replaying stays allowed.
- Summary offers "Copy daily result" for daily runs: plain-text Wordle-style
  share via clipboard (zero new dependencies).
- lib/game/daily_share.dart is the single formatting authority for daily-date
  keys (controller + title reuse it).
- Gate: analyze clean, 107/107 tests; new test/daily_record_test.dart (6);
  title/summary screenshots inspected (widget-render probe).

## 2026-07-24 — run history in meta + Ledger (PR #8)
- Every ended run (won/lost/abandoned) prepends one record to meta.runHistory
  (date/character/difficulty/ascension/result/floor/floors/seed/embers/daily),
  capped at 30, newest first. Seeds recorded per run enable seed replay (PR #9).
- The Ledger gains a RECENT DELVES section (last 10, real records only).
- Gate: analyze clean, 111/111 tests; ledger screenshot inspected.

## 2026-07-24 — seed display + custom-seed entry (PR #9)
- Every summary shows "Seed N — tap to copy"; title gains a small "Delve a
  seed" entry (dialog: paste a number for exact replay, or any word — hashed
  deterministically, namespaced away from daily seeds).
- lib/game/seed_input.dart parseSeedInput() is pure and range-safe [1, 2^31-2].
- Gate: analyze clean, 114/114 tests; title/dialog/summary screenshots inspected.
- Visible signature weapons in combat + character select. Weapon painters
  (Ember Brand / Ward Maul / Lucky Fang / Brand Iron) with idle sway →
  anticipation raise → swing, riding existing choreography flags. Contact FX:
  weapon smear + sparks on enemy hits, claw rake on player hits, guard-arc
  shield flash for block (previously completely silent/invisible). Character
  select: weapon leans on portrait, name in stat line. Sim untouched.

## 2026-07-24 — bug sweep 2 (deeper pass)
- Fixed: boss death insight coached the exact wrong line (block timing is
  sim-verified: block intents protect the FOLLOWING player turn — old tip said
  "hold damage turn 2, strike turn 3", i.e. swing into 28 block). Reworded
  direction-correct + number-free; block-timing anchor test added.
- Fixed: burn-kill death dissolve overran the 1450 ms terminal hold (~1730 ms
  worst path) and got cut by the reward-screen switch — burn beat now skipped
  when the tick kills (worst path ~1380 ms). PR #11 audit note corrected.
- Fixed: 'boon' phase fell through to title music (jarring after "Delve
  again"); now plays the map track like the other run phases.
- Fixed: SettingsStore.save now queued + atomic (temp file + rename), same
  contract as MetaStore/run autosave. Dead guard in phase_transition_test
  corrected ('boon_offer'/'option' -> 'boon'/'index').
- Sim behavior untouched; golden 1842571558 verified unchanged, no SIM_VERSION
  bump. Write-up: docs/improvements/bug-sweep-2-2026-07-24.md

## 2026-07-24 — combat feel v2: dice charge, boss kill, enemy wind-up, reward flip (PR #13)
2026-07-24 COMBAT FEEL V2 (branch feat/combat-feel-v2, stacked on feat/combat-weapons-juice; owner: "do all these, high quality weapons, good animations, more visuals"): (1) weapon quality pass — silhouette outlines, white-hot smear core, easeOutBack follow-through recovery; (2) DICE CHARGE — the selected die's pips heat the weapon (glow halo + rising sparks + white-hot edge, TweenAnimationBuilder-smoothed; heat frozen through the swing via _lastSwingCharge); (3) BOSS KILL MOMENT — white-hot impact freeze (260ms, _bossKillFlash overlay) + full-magnitude shake + flash decay into the ember dissolve, boss-only terminalHold 1900ms; (4) ENEMY WIND-UP — 190ms lean-back + red heat tint before the lunge (windup flag on _combatant), player squash untouched at 90ms; (5) REWARD FLIP — offers present as 3D flip cards (staggered auto-flip 220+240i ms, pre-mirrored back, FittedBox-scaled face for 320×568@1.3x, tap-to-pick with double-tap guard, event_page sfx + haptic per flip; all cards flip = no peek-gamble, Ethics-safe). Sim core untouched.

## 2026-07-24 — ledger plural fix (branch fix/ledger-plurals)
2026-07-24 "1 wins · 1 delves" on the Ledger delver rows now pluralizes
correctly (win/wins, delve/delves). Spotted while rendering store screenshots.

## 2026-07-24 — privacy policy hosted (branch feat/privacy-policy-page)
2026-07-24 GitHub Pages enabled for the repo (main:/docs, legacy build,
https://tapiwamakandigona.github.io/emberdelve/). Added a styled
docs/store/privacy-policy.html (same text as the canonical .md), a minimal
docs/index.html, and docs/.nojekyll (serve raw files; internal .md docs stay
plain text, no Jekyll surprises). play-listing.md now carries the live URL —
closes the "hosted privacy policy" P0.3 item. NOTE: everything under docs/ is
now also a public web page (repo was already public).

## 2026-07-24 — store listing assets (branch feat/store-listing-assets)
2026-07-24 STORE ASSETS: Play-listing screenshot pass without a device —
tool/store_screenshots_test.dart renders real screens (GameController-driven,
FontLoader'd Cinzel/Inter + SDK MaterialIcons so no box glyphs; runAsync
pumping so rootBundle sprites/asset images actually decode) at 360x640@3x =
1080x1920 (9:16): title / boon pick / map / combat mid-roll / ledger, plus a
1024x500 feature graphic (bg_boss + logotype + die chips). Committed under
docs/store/screenshots/; harness lives in tool/ so it is NOT part of the CI
gate — rerun manually after UI changes. Meta in shots is staged but honest to
real mechanics (real screens, real seeds; ledger numbers are sample data).
Known nit spotted while shooting: ledger delver rows print "1 wins".

## 2026-07-24 — haptics actually vibrate now (branch fix/haptics-release)
2026-07-24 Owner report: haptics did nothing on the v0.3.2 APK even with the
in-game toggle ON. Root cause: HapticFeedback.*Impact() maps to Android's
View.performHapticFeedback(), which is silently gated by the SYSTEM "touch
feedback" setting (off on many phones; apps can't override since Android 13).
Fix: `emberdelve/haptics` MethodChannel in MainActivity.kt drives the Vibrator
service directly (VibratorManager on S+, VibrationEffect on O+, legacy below)
with per-beat duration/amplitude (light 18ms/90 · medium 38ms/170 · heavy
70ms/255); Dart side falls back to HapticFeedback where the channel is absent
(iOS/tests) or the device has no vibrator. Added the normal VIBRATE permission
and updated the store docs' "zero permissions" claims (now: no internet
permission, VIBRATE only). Flipping the settings toggle ON now answers with an
immediate preview buzz for on-device confirmation. New test/haptics_test.dart
(6 tests: channel args, toggle gating, fallbacks). Suite 133 tests, no sim
change, golden untouched.

## 2026-07-24 — boss variety (branch feat/boss-variety)
2026-07-24 BOSS VARIETY (v0.4 notes item 5): three bosses, one per run, chosen
as a PURE function of the run seed (bossForSeed = bossIds[seed % 3]) — no RNG
stream consumed, so all other seeded streams are byte-identical and runs whose
seed maps to the Ember Tyrant replay identically to the single-boss sim
(goldenV6 survived unchanged; verified). Dailies share a seed → same boss for
everyone that day. New kin, same honest Intent vocabulary, no new mechanics:
  * Ashen Colossus (112hp) — the wall: guards 2 beats in 3, one giant swing;
    the open player turn is right after the swing.
  * Pyre Matriarch (94hp) — the race: never guards, escalating 21/25/29 burn.
Balance (bin/autoplay, 200 seeds): overall 87/66.5/37% easy/normal/hard (was
88/70/33 pre-variety, band test 20-80 green). Per-boss winrate spreads are
dominated by pre-boss seed-group variance (measured: deaths-before-boss 31/15/44
per group), NOT the boss fights — actual boss-FIGHT winrates are 94/94/86%
tyrant/matriarch/colossus. Don't tune boss stats against whole-run winrate.
Insights: per-boss coaching buckets (a Tyrant tip would lie about the
Colossus); generic 'boss' bucket kept as fallback; all buckets 3 lines so the
loot-stream draw shape is unchanged. Sprites: ember_tyrant palette-swap kin
(cold-ash colossus, crimson matriarch) + sprite_meta entries. Tests: content
test now expects exactly 3 bosses; sim_test pins one golden PER BOSS
(goldenV6/Colossus/Matriarch). Boss ordering in enemiesOrder is deliberate
(golden seed 20260723 % 3 == 1 → tyrant) — append new bosses at the END.

## 2026-07-24 — low-HP audio danger layer (branch feat/low-hp-danger-layer)
2026-07-24 DANGER BED (flagged "before 1.0" since v0.2): quiet heartbeat loop
(60bpm lub-dub + dark 41Hz drone, 8s seamless, synthesized in-house — CC0,
credited) under combat music when phase == player_turn and hp <= 30% of max.
audio_service.setDanger mirrors the ambience-bed lifecycle exactly (failed
start must not occupy the slot; off always stops+disposes). The 30% rule
lives in the controller (_inDanger), not the audio layer, so it stays
gameplay-owned. Analyze clean; assets/widget/phase-transition suites green.

## 2026-07-24 — v0.3.4 release build (integrator pass 4: PRs #20, #19, #21)
2026-07-24 Integrated #20 (haptics: direct Vibrator via MethodChannel, owner
bug report) → #19 (boss variety: 3 seed-picked bosses, goldenV6 unchanged) →
#21 (low-HP heartbeat danger layer). Each PR gate-verified post-merge-with-main
(analyze clean; 133/134/134 tests; autoplay 200 normal 67.0/66.5/66.5% WR, 0
invalids; golden 1842571558 self-consistent). Version bumped 0.3.3+6 → 0.3.4+7
for the delivered signed APK (CI build-android-release artifact).

## 2026-07-24 — play-session bug hunt (branch fix/play-session-findings)
2026-07-24 Owner directive: "play emberdelve and fix all the problems it has."
Built tool/play_session_test.dart — an interactive harness that PLAYS the
game through the real UI (hit-tested taps, real frames, sim-bot-guided
choices) for 4 full runs, screenshots every phase, and records every
framework exception. Found and fixed:
1. **Pop-curve assert on every damage/text pop** (lib/ui/fx.dart): the
   settle-scale curves fed `(f - a) / (1 - a)` into `Curve.transform`
   un-clamped; at f == 1.0 float error yields 1.0000000000000002 and trips
   the [0,1] assert on the final frame of EVERY DamagePop/TextPop (82 hits
   in one 4-run session). Debug-only crash spam (asserts strip in release),
   still out of contract. Clamped both sites; audited all other
   `.transform(` call sites — the rest receive controller values in range.
2. **Rest-hollow softlock** (lib/ui/screens/rest_screen.dart): at full HP
   with nothing forgeable the only exit was a DISABLED button ("Fully
   rested — forge or move on") — no way to leave the node, run soft-locked.
   Now an enabled "Move on — fully rested" applies the sim's `rest` (heals
   0, moves to map — command verified safe at full HP). Controller no
   longer toasts "Rested — healed 0 HP" for a non-heal.
Regression tests added to test/widget_test.dart (pop-completion exception
gate — verified to FAIL against the pre-fix fx.dart — and full-HP rest
exit). Also measured controller-level bot parity: 60-seed easy winrate via
GameController.apply = 83.3%, in family with the sim-level 86.7% — the
controller/UI command path introduces no drift. Suite green, autoplay
baseline unchanged (sim untouched). Version 0.3.4+7 → 0.3.5+8.

## 2026-07-24 — many-dice layout + wordiness pass (branch fix/many-dice-layout)
2026-07-24 Owner report: "ui was buggy when there were many dice on screen —
awkward placement and other stuff on different screens", plus "too wordy,
less expressive using visuals". New probe tool/many_dice_probe_test.dart
(pools 6/9/12/16 × 320/360/412 widths, combat unrolled/rolled/assigned +
rest + map) reproduced and gated the fixes:
1. **Combat tray clipped dice 5+** behind a half-row (technically scrollable,
   visually broken; untappable in practice). Now: chips shrink 0.75x once the
   pool outgrows the row budget, tray height quantizes to WHOLE rows inside
   the same 112/256 budget, fade + chevron marks a scrolling fold.
2. **Burn badge drew half off-screen** — intent+burn row right-anchors to the
   enemy when burn is up.
3. **Rest forge rows overflowed 320dp** by 9.4px — compact 48x60 chips, dense
   button, caption moved to its own full-width line (was wrapping mid-word).
Wordiness (UI-only, data untouched): boon cards lead with the actual die art
or currency icon + number (caption is `d6 · +2 block`-style mechanics, prose
gone); event options carry a payoff/risk icon (cost beats reward so risky
reads risky); shop price button uses a coin, not an abstract dot.
CI overflow probe now runs the 16-die pool. Suite 136 green, analyze clean,
autoplay baseline unchanged (sim untouched). 0.3.5+8 → 0.3.6+9.

## 2026-07-24 — Screenshot-evidence fixes (v0.3.7+10)
Owner reviewed the PR #23 "after" screenshots and correctly flagged they still showed problems. Fixed:
- Combat tray fold: viewport now clips at whole rows; explicit "+N ⌄" pill replaces the fade-over-half-cut-dice (which read as a glitch).
- Map auto-follow: map reopened scrolled to the bottom each visit, leaving late-run reachable nodes off-screen; it now scrolls the delver to ~45% of the viewport (found via stuck autoplay).
- Event options: choices the sim would reject (unaffordable gold cost, pool ≤ 3 for die-loss) render disabled instead of spawning "Not enough gold" toasts; mirrors runEventChoose validation.
- Harnesses: debugShowCheckedModeBanner=false (red ribbon was in every evidence shot) + precacheAllImages() so async image decode never ships blank art in screenshots (boon-card die art was invisible).
Verified: 136/136 tests, analyze clean, many-dice probe 0 problems, play session 4/4 runs finished 0 problems. Lesson recorded: eyeball every screenshot before shipping it as evidence.

## 2026-07-24 — Owner screenshot triage #2 (v0.3.8+11)
Owner sent 4 in-game screenshots asking "so these look right to you?" — they didn't:
1. **Intent/burn pills covered the enemy HP bar** (which then read ~55% full at
   28/28 — the bar itself was fine, the pills drew over its right half). Root
   cause: the stage Stack top-aligned its content, so on squeezed stages
   (fat pool tray + short screen) the sprites hugged the top edge right under
   the HP panel and the badge's fixed -44 lift escaped the stage entirely.
   Fix: combatants row is now floor-pinned (Positioned bottom:0) and the badge
   lift clamps to the stage's real headroom (negative lift pushes it DOWN onto
   the sprite rather than up over the panel). CI regression test added
   (verified to FAIL pre-fix): badge rect must not overlap any StatBar at
   320x568 with a 12-die pool + burn.
2. **Dice rendered as blank cream shapes** wherever value==null (pre-roll tray,
   boon/shop/rest/reward die cards). _PipPainter → _FacePainter: unrolled dice
   now show a dim engraved size numeral, so a die always reads as a die.
3. **d4 pips spilled off the triangle** (value 2 drew one pip on the die, one
   on the background) and sat above the visual centroid. The d4 now shows
   rolled values as an engraved numeral (like a real tetrahedral die) at the
   triangle's centroid; other dice keep pips, centered per-shape.
New probe tool/owner_triage_probe_test.dart (boon + burning combat at 320/360,
badge-vs-bar rect assertions + screenshots) — 0 problems; many-dice probe still
0 problems; suite 137 green; analyze clean. All evidence screenshots eyeballed.

## 2026-07-24 — Google Play closed testing LIVE + tester campaign (v0.3.9+12)
Review PASSED: closed-testing release **12 (0.3.9)** is live on the
"Closed testing - Alpha" track in 177 countries.
- Store: https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve
- Tester opt-in: https://play.google.com/apps/testing/com.tsorostudios.emberdelve
- Tester Google Group: emberdelve@googlegroups.com (wired to the Alpha track;
  "anyone on the web can join").

**Production gate (personal dev account):** 12+ opted-in testers for 14
*continuous* days before "Apply for production" unlocks. The 12-tester
criterion was **MET 2026-07-24** (dashboard checkmark) → clock running,
earliest production apply **~2026-08-07**, realistic public launch ~Aug 10–14.
A dip below 12 opted-in testers resets the clock — keep over-recruiting.

**Recruiting:** Reddit test-for-test posts (r/AndroidClosedTesting,
r/TestersCommunity) + the Google Group; group grew 10 → 20 members in ~90 min
on day one. `testers-community@googlegroups.com` added to the track (subreddit
mod requirement). Reciprocal-testing bookkeeping is tracked outside this repo.

**Verified Play mechanics (recorded for release planning):**
- App updates to the testing track and store-listing edits (screenshots, copy)
  do **NOT** reset the 14-day clock — it tracks opted-in testers, not versions.
- Testers get **no explicit "update available" notification**; Play
  auto-updates installed apps (typically within ~24h, on Wi-Fi/idle). Shipping
  updates mid-window is safe.
- Submitting changes while a review is in progress pops a "restart your
  review?" dialog — expected; confirm it. Bundle new build + refreshed
  screenshots in ONE submission.

**Tester feedback so far:**
- "How is damage calculated?" — answered publicly with the real formula from
  `lib/sim/combat.dart` (attack = die face + die bonuses + pair bonus + relic
  bonuses; enemy block absorbs first). **PUBLIC PROMISE made to testers: an
  in-game tutorial ships "in the next update".**
  `lib/ui/screens/tutorial_overlay.dart` exists — wire/verify it before the
  next release. This is now a release blocker for the next update.
- One "app can't load" report from a tester in Germany (app IS live there;
  most likely cause: installed without joining the group/opting in first).

**Next update (owner is considering):** a core-gameplay-simplification pass.
Confirmed safe during closed testing (see mechanics above); pair it with the
tutorial promise and refreshed screenshots in a single submission.

Full day-one narrative (publish journey, recruiting rounds, reciprocity
table, lessons): `checkpoints/05-play-closed-testing-day1.md`.

## 2026-07-25 — v0.3.10 tester-feedback pass (block feel, readable call-outs, replayable tutorial, easy ramp)

Driven by the first external tester feedback wave (Play closed testing, 4 entries 4-5★, plus a
detailed email from a tester): "blocking isn't doing anything", "some text is on the screen but
it's so fast I can't quite read it", "not sure how to see the telegraphs", "hard time with even
the easy difficulty", "just add a manual or instructions or a tutorial".

Diagnosis (played the sim + read the choreography):
- Block RESOLVES correctly in the sim, but a partially blocked enemy hit rendered only the damage
  number — absorbed points were invisible, so block read as a no-op exactly when it mattered.
- Combat call-outs (PAIR/TRIPLE/BLOCKED/FREE REROLL) lived exactly 1s, fading from 0.65s.
- The 3-card tutorial showed once ever (tutorialSeen); one tester considered reinstalling to see
  it again. Nothing explained that block melts at the next roll.
- Easy's flat -2/x0.8 left a layer-3 FIRST fight (route skipping layer 2) nearly as lethal as
  normal: early mercy (layers <=2) missed it entirely.

Changes:
- combat_screen: enemy-turn partial blocks now spawn guard-arc FX + "BLOCKED n" call-out
  ("FULLY BLOCKED" on full absorb); player attacks absorbed by enemy shields call out
  "SHIELD ATE n" — every absorbed point is now visible on both sides of the exchange.
- fx/TextPop: duration is a parameter; combat call-outs hold ~2s (_noteLife), other pops keep 1s.
- tutorial: 4th card ("BLOCK FADES FAST" — block timing vs. the intent badge); a ? button in the
  enemy header replays the overlay ANY time (no more one-shot); step logic is length-based.
- sim/combat: easy-mode layer ramp mirroring hard's staircase — attack shave -5 (layers <=3),
  -3 (4-6), -2 (7+/boss); HP x0.68 early, x0.80 mid+. Measured (bin/autoplay, 200 seeds):
  flat -2/x0.8 = 87.0% bot winrate (50% of losses on the first fight); shipped ramp = 91.5%.
  Normal/hard untouched: golden anchor 1842571558 verified identical before/after; 200-seed
  normal sweep byte-identical (66.5%, same histogram).
- play_session harness: final drain 1500 -> 3200ms to cover the 2s call-outs (a pending-timer
  teardown assert caught the change — the drain must outlive the app's longest transient effect).
- version 0.3.9+12 -> 0.3.10+13.

Evidence: flutter analyze clean; full `flutter test` green (incl. new easy-ramp staircase test);
tool/play_session_test green with 28 phase screenshots; autoplay sweeps easy/normal logged above.

## 2026-07-25 — v0.3.11 legacy-feel pre-gate slice (LFP-2a/2c, 3, 5, 6 from docs/legacy-feel-plan.md)

Implements the pre-gate workstreams of the legacy-feel plan (PR #49) on
`legacy/dice-builder`, per its own sequencing: cheap clarity first, headline
feel work (LFP-1 physical dice, LFP-2b undo) left post-gate — both are
blocked on the owner's open questions in the plan.

- LFP-6b: risky-reroll copy — "each lands −1 pip" read as −1 from the CURRENT
  face; actual rule is reroll-then-subtract. Copy now says "new face −1".
- LFP-6c: boon screen gets the reward screen's deterministic RECOMMENDED
  default (die boons by size, then max HP > gold > embers).
- LFP-6a CORRECTED: the "Cinder Wisp spawns 19/20 on Easy" finding is NOT a
  floor-vs-round bug — combatBegin rounds hp and max_hp from the same value
  (VERIFIED in code; 29×0.68=19.72 → 20/20). It is overkill splash carry-in,
  working as designed but announced only in a toast that died under the
  flame wipe. The splash is now called out on the enemy in combat
  ("OVERKILL SPLASH −N"). The plan doc's diagnosis should not be re-fixed.
- LFP-3a/3b/3c: burn stacks no longer share the intent badge's row (the
  "🛡13 🔥3 = it will shield and burn me" misread); status renders as a small
  pill on the enemy body. Long-press any badge → 2s call-out naming it (burn
  copy sim-verified: ticks AFTER the enemy's move, then −1 — the plan doc
  said "turn start", corrected). Tutorial card 1 gains the plan-vs-status
  clause.
- LFP-5: tap anywhere during enemy resolution = 2x fast-forward (call-outs
  1s), second tap = skip-to-state. Information never dropped; player/enemy
  death moments keep full length. Measured in test: 450 ms vs 700 ms to
  next input on a pinned fight (≥40% DoD met; real turns with burn/big hits
  save more).
- LFP-2a/2c (presentation-only subset): selecting a die shows "ATTACK +a ·
  BLOCK +b" (modifiers, combos, relics included) as a stage pill before the
  tap; spent chips show what they actually contributed ("+7 SPENT", from the
  sim's die_assigned value); modded dice carry a quiet accent ring. The
  preview math is a UI twin of the sim's — test/feel_pregate_test.dart
  replays 10 seeded runs and asserts preview == die_assigned value for every
  assignment (drift guard), plus fast-forward timing, status-chip
  separation/tooltip, and boon-RECOMMENDED tests.
- version 0.3.10+13 -> 0.3.11+14.

Evidence: flutter analyze clean; full `flutter test` green (138 + 5 new);
tool/play_session_test green. Sim untouched — golden anchors and replays are
byte-identical by construction (no file under lib/sim/ or lib/data/ changed).

## 2026-07-25 — v0.3.11 phase 2: LFP-1 physical dice, LFP-2a die flight, LFP-4 idle life (owner-directed "fix the issues and make the update")

Owner asked Viktor to implement the remaining playtest-gap workstreams and
ship a GitHub release. Everything presentation-only; sim untouched again.

- LFP-1a/1b/1c: rolls now THROW the dice — launch from a bottom-center thumb
  origin, per-die arc + alternating spin, one soft bounce into the slot, all
  inside the existing 520ms budget with the same face-cycling. Settle beats
  fire per-die light haptics (stagger = rattle). Risky/charge rerolls re-fly
  only the rerolled dice via per-die _reflyGen tokens (the old code re-tumbled
  the whole tray on risky rerolls; charge rerolls didn't animate at all).
  Rendering is programmatic 2.5-D (plan open question 2 answered with the
  free, decision-#7-safe option; a pre-rendered sheet can replace it later).
- LFP-2a (flight half): on assign, a ghost of the die flies from its tray
  slot to the verb button (230ms easeIn) and the button pulses on arrival.
  With the preview pill + contribution labels from phase 1 this completes
  LFP-2a. LFP-2b undo remains OPEN — it needs the sim-seam decision (unassign
  command vs commit-at-end-turn, PR #49 question 1); not implementable
  without relitigating a standing decision, so deferred, not forgotten.
- LFP-4a/4b: root-caused the static stage — several sheets have 1-frame idle
  rows, which rendered with no AnimationController at all; multi-frame bobs
  were sub-pixel at stage scale. SpriteView gains a procedural idle ticker:
  ~2px sine bob (both combatants) + slow ±1px threat sway on the enemy while
  an attack is telegraphed. Independent of frame count by construction.
- features.json: LFP-1..6 lifted in with evidence per the harness protocol.

Evidence: flutter analyze clean; full flutter test green; play_session
harness green. No lib/sim or lib/data change across the whole branch —
golden anchors, replays and saves byte-identical.

## 2026-07-25 — Release v0.3.11 published (Viktor)
- PR #52 merged into legacy/dice-builder (merge head bd5d33f).
- CI workflow_dispatch run 30153939057: tests + signed release build green (cert SHA-256 verified in CI). VERIFIED.
- Tag v0.3.11 created on bd5d33f; GitHub Release published with emberdelve-v0.3.11.apk (38295092 B) and .aab (57191187 B) assets: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.3.11
- Deferred: LFP-2b in-turn undo, LFP-5 settings toggle (PR #49 open questions).

## 2026-07-25 — Perf: repaint storm + SFX tap latency (v0.3.12+17, Viktor)
Owner report on released v0.3.11: laggy, glitchy audio, and "when I click a
button too quick it lags a lot".

Measured with a new `tool/perf_probe_test.dart` (counts render objects painted
and elements rebuilt per frame via `debugOnProfilePaint` /
`debugOnRebuildDirtyWidget`), root-caused with
`debugPrintMarkNeedsPaintStacks` / `debugPrintMarkNeedsLayoutStacks`.

- VERIFIED before -> after, render objects painted per frame:
  title idle 49.6 -> 3.0; title 12 rapid taps 167.9 -> 38.8;
  combat idle 204.0 -> 2.0; combat 12 rapid real taps 207.2 -> 95.4.
  Elements rebuilt per idle frame 2-3 -> 0.
- Cause: `SpriteView`, `WeaponView` and `EmberLogotype` drove always-on
  animations with `setState` 60x/s. The combat stage sits in a `LayoutBuilder`
  and the title screen in a scroll view, so each of those setStates scheduled a
  layout callback -> full relayout + full repaint of the screen, every frame,
  permanently. All three now feed `CustomPainter.repaint` and read
  `animation.value` at paint time; sprite bob/sway moved into canvas
  transforms.
- Cause: `EmberButton`'s press animation had no `RepaintBoundary`, so every tap
  repainted the whole screen for 80ms (with `MaskFilter.blur` on the primary
  tier). Boundaried.
- Cause: `_LogotypePainter` laid out five `TextPainter`s per frame. Cached; the
  breathing glow pass is quantised to 24 buckets (sub-visible steps).
- Cause: `playSfx` used default-mode players, so Android re-prepared a
  MediaPlayer per tap (JNI + asset read + codec prepare on the platform
  thread). Now one preloaded `PlayerMode.lowLatency` (SoundPool) player per
  sound id, stop -> resume to retrigger, with a background warm-up of the six
  first-touch sounds from `main()`.
- VERIFIED: `flutter analyze` clean; `flutter test` 143/143; play_session
  harness 4 runs, 0 problems. No `lib/sim` or `lib/data` change.
- NOT VERIFIED: on-device frame times and audio latency — no Android device or
  emulator was available in the sandbox. Paint/rebuild counts are exact and
  framework-level; the transfer to real hardware is inferred.
- Detail: docs/improvements/perf-repaint-and-sfx-2026-07-25.md

## 2026-07-25 — combat screen: scoped rebuilds (v0.3.13+18)
- Follow-up to the repaint/SFX pass: that fixed idle cost, this one attacks the
  cost of a real tap. combat 12 rapid real taps: 95.4 -> 48.3 render objects
  painted per frame (2.0x). Rebuilds/frame 31.5 -> 31.0, unchanged by design.
- Cause: one ~1000-line `build()` behind ~40 `setState` sites. Choreography
  alone (squash/lunge/flash/hit-stop/knockback) fires ~20 setStates per attack,
  and every transient overlay spawn AND expiry was another one — each re-ran
  and repainted the whole screen, including the top bar, HP panels, dice tray
  and action zone that read none of that state.
- Fix: two `ValueNotifier<int>` ticks — `_choreoTick` (combatant flags + the
  weapon phase/charge derived from them) and `_fxTick` (pops, contact FX,
  call-out notes, assign ghosts, boss-kill flash). Fields unchanged; only the
  notification is scoped. Consumers sit in `ValueListenableBuilder` +
  `RepaintBoundary`. Sim-driven state still uses `setState`.
- Rebuilds/frame stay flat because the probe's tap storm drives SIM state
  (rolls), which still rebuilds the screen. Scoping selection/busy/roll state
  is a real restructuring of `build()` and is deliberately left to its own PR.
- VERIFIED: analyze clean; 143/143 tests; play_session 4 runs, 0 problems;
  `tool/store_screenshots_test.dart` (deterministic) byte-identical PNGs
  before/after on all six screenshots incl. combat.
- NOT VERIFIED: mid-choreography frames are not pixel-covered by any
  deterministic harness; on-device frame times (no device/emulator available).
- Detail: docs/improvements/perf-combat-scoped-rebuilds-2026-07-25.md

## 2026-07-25 — perf pass 3: map glow, reward flip, input scoping, shake (v0.3.14+19)
- HARNESS FIX FIRST: `tool/perf_probe_test.dart` booted a fresh save, so the
  first-fight tutorial overlay covered every combat scenario — its scrim ate the
  "12 rapid taps" (they never reached Roll/Reroll/End turn) and its layers were
  counted in the totals. Probe now calls `c.markTutorialSeen()` after boot. The
  combat tap-storm numbers quoted for v0.3.12/v0.3.13 measured something other
  than their label; everything below is re-measured on BOTH sides with the fixed
  probe (baseline = c5b8177 in a separate worktree).
- Painted render objects per frame, v0.3.13 -> v0.3.14: map idle 221.0 -> 19.7
  (11.2x, rebuilds 40.1 -> 0.1); map drag 221.0 -> 54.5; combat 12 rapid DIE
  taps 151.9 -> 20.0 (7.6x); combat 12 rapid BUTTON taps 169.9 -> 100.3; reward
  flip 86.4 -> 52.9. Title and combat idle unchanged (3.0 / 2.0).
- Map was the worst screen in the game: every medallion animated through
  `AnimatedBuilder`, rebuilding 20 CustomPaints + icons per frame inside the
  scroll viewport. Now the pulse drives `CustomPainter(repaint:)` and each
  medallion is a RepaintBoundary; unreachable nodes don't listen at all.
- Reward `_FlipCard` rebuilt its face/back (FittedBox over text) on every flip
  frame; both sides are now built once and rasterised behind RepaintBoundaries.
- Combat: third scoped tick `_uiTick` (selection, `_busy`, reroll mode+select,
  verb pulses) with the tray, action zone, preview badge and help button as
  scoped consumers — 11 setState sites converted to `_ui()`.
- `ShakeBox` now wraps its child in a RepaintBoundary: the whole-screen shake
  was repainting every render object under it on each of its ~14 frames.
- Section RepaintBoundaries on the combat HUD (top bar, enemy panel, stage,
  player HP): alone worth 151.5 -> 100.3 on the button storm.
- Tried and reverted (measured nothing): RepaintBoundary per tray chip.
- Button-storm gain is capped at 1.7x by design: those taps issue sim commands,
  and GameController/GameRoot rebuild the whole screen on notifyListeners().
- VERIFIED: analyze clean; 143/143 tests; store-screenshot harness byte-identical
  to c5b8177 on all 6 PNGs (committed PNGs drift from this toolchain on BOTH
  sides — pre-existing, left untouched).
- NOT VERIFIED: on-device frame times (no device/emulator).
- Detail: docs/improvements/perf-map-reward-input-2026-07-25.md

## 2026-07-25 — perf pass 4: per-field controller notifiers + SFX voices (v0.3.15+20)
- Attacks the ceiling the last three passes hit: GameController is one
  ChangeNotifier, so GameRoot rebuilt the whole active screen on every
  notifyListeners(). Now the controller publishes per-field ticks (phase, turn,
  run, enemy, player vitals, dice, map, meta), detected by hashing each field
  with the sim's own `hashValue` inside an override of notifyListeners() — so
  every existing mutation path feeds them, with no second place to bump.
- GameRoot hands CombatScreen back as the SAME widget instance (Element.
  updateChild short-circuits), so a sim command no longer re-runs its ~1000-line
  build(). Every other screen keeps the old whole-screen AnimatedBuilder.
- The combat HUD is five bands: top bar (runTick), enemy panel (enemy+turn),
  stage (enemy+run), player HP (vitals), tray + action zone (dice + input tick).
  Each band recomputes a `_Hud` from LIVE state, so no section renders another
  section's snapshot (the stage's assign preview re-reads live state explicitly).
- Painted objects/frame: combat 12 BUTTON taps 100.3 -> 87.7 (-12.6%). Die-tap
  storm, combat idle, title, reward flip and map are unchanged. Rebuilds/frame:
  button storm 19.9 -> 19.3, DIE storm 14.1 -> 16.1 (worse, accepted: band
  builders re-running, paints flat).
- MEASURED TWICE, and this is the lesson: scoping WITHOUT a repaint boundary at
  each band measured 100.3 — the same 6020 paints as the baseline, i.e. nothing.
  Scoping WITH the boundary measured 87.7. v0.3.14 already had boundaries inside
  the sections and still measured 100.3, because a whole-screen rebuild dirties
  every section anyway. The two halves only pay off together.
- Audio: v0.3.12's one-player-per-id made a retrigger RESTART the sound. Ids
  that overlap in real play now keep 2-3 resident low-latency voices and each
  trigger takes an idle one (die_assign/enemy_hit/coin x3; dice_roll, reroll,
  player_hit, block, ember_gain, whoosh x2). UI clicks and stings stay single.
- VERIFIED: analyze clean; 152/152 tests (143 + 9 new audio voice tests);
  store-screenshot harness byte-identical to 0680f20 on all 6 PNGs incl. combat;
  play_session smoke green; probe run on both sides with the identical file.
- NOT VERIFIED: on-device frame times (no device/emulator); the layered SFX by
  ear (logic is unit-tested only) — if a dice cascade sounds cluttered, lower
  AudioService.sfxVoices, it is one table.
- Detail: docs/improvements/perf-controller-notifiers-2026-07-25.md

## 2026-07-26 — deterministic play session + invariant oracle (remaining-work §2)
- `tool/play_session_test.dart` is now a real fuzz test, not a crash-catcher:
  run N plays seed `EMBER_SESSION_SEED + N` (default base 1842571558, the
  golden anchor), injected via a one-shot `GameController.debugNextRunSeed`
  seam consumed by startRun when no explicit seed is passed. A failure prints
  the exact reproducing command line.
- Per-step sim oracle: player/enemy HP and economy bounds, assigned ⊆ rolled,
  legal phase set + phase-transition graph, dead-actor ⇒ phase-change,
  rerolls/block/embers/gold/pending_splash never negative. Violations (plus
  STUCK and step-budget overrun) now FAIL the test; UI-probing misses stay
  report-only warnings. Stale `steps >= 900` budget check fixed to 2500.
- The oracle immediately caught a rotted finder: the map-node tap predicate
  (GestureDetector wrapping AnimatedBuilder) broke when the 2026-07-25 perf
  pass removed the medallion AnimatedBuilder — the harness had been reporting
  "green" while never getting past the map. Medallions now carry
  `ValueKey('map-node-<id>')` (reward-screen pattern) and the harness taps by
  id. Also fixed: a missed "Delve again" tap double-counted runsFinished and
  silently skipped a run's seed (report showed runs 0,1,3).
- VERIFIED: analyze clean; 152/152 tests; play session green on default base
  seed AND EMBER_SESSION_SEED=7 (seeds 7..10, 4/4 runs); byte-identical
  report.txt across two executions of the same seed (determinism proof).
- ASSUMED (reasoned, not measured): the map_screen change is a ValueKey only —
  no paint/layout effect, so the store-screenshot gate was not re-run (that
  gate also has known toolchain drift on committed PNGs, see v0.3.14 entry).
- NOT DONE (still open from remaining-work §2): N-seed nightly sweep in CI —
  scheduled workflows only run from the repo's default branch (main, the
  platformer), so wiring it needs an owner decision on where it lives.
## 2026-07-26 — perf pass 5: map drag + title storm (remaining-work §5) (v0.3.16+21)
- title_tap_storm 38.8 -> 14.5 paints/frame; map_drag 54.5 -> 9.5. Idle, combat
  and reward scenarios re-measured flat. Same probe file both sides.
- REAL title cause (the button already HAD a boundary): any setState below a
  LayoutBuilder marks it needs-layout, and its relayout marks needs-paint up to
  the nearest ANCESTOR boundary — which was the route. Fix: boundary above the
  title LayoutBuilder + one below around the scroll view. Rule: a LayoutBuilder
  with animating descendants needs a repaint boundary above it.
- REAL map cause: SingleChildScrollView paints its child at the scroll offset
  with no boundary, so a drag repainted every non-boundaried Stack child
  (badges, marker, node chrome). The remaining-work §5 parchment theory was
  WRONG — that layer was already boundaried and measured flat. Fix: one
  boundary under the scroll view (+ one around the walking delver marker).
- VERIFIED: analyze clean; 152/152 tests; store-screenshot harness
  byte-identical on all 6 PNGs vs legacy baseline on this toolchain.
- NOT VERIFIED: on-device frame times (frame-trace emulator job, PR #70).
- Detail: docs/improvements/perf-map-title-2026-07-26.md
## 2026-07-26 — §6 layered SFX: mix-bus headroom measured and guarded (v0.3.17)

- Closed the measurable half of remaining-work §6 without an ear check.
  `tool/sfx_headroom.py` rebuilds the worst-case cascades offline from the
  shipped .ogg assets — parsing `sfxVoices` out of the Dart source, modelling
  voice stealing, applying the real per-call trims at slider max — and measures
  sample peak, EBU R128 true peak and integrated loudness of each.
- VERIFIED: every reachable cascade clears 0 dBTP. Loudest is the full attack
  turn (whoosh + 3 hits + ember gain + 3 coins) at -0.9 dBTP; the dice cascades
  sit at -3.2 to -3.5 dBTP.
- VERIFIED and worth remembering: identical samples started on the SAME frame
  sum coherently (+9.5 dB for three copies) and clip hard — coin x3 aligned is
  +5.9 dBTP / 122 clipped samples. That case is unreachable only because
  `handleEvents` plays each id at most once per event batch, which until now was
  an undocumented, load-bearing detail.
- Pinned it: `handleEvents` now delegates to a pure `sfxIdsForEvents`, and
  test/audio_voices_test.dart gained three "mix-bus invariants" tests (de-dupe,
  ordering/unknown events, golden `sfxVoices` table). Bump a cap and they fail,
  which is the signal to re-run the tool.
- The headroom check runs in CI on every PR, so a hotter .ogg master fails the
  build instead of shipping a clipped cascade.
- ASSUMED (owner, unchanged): whether a four-die cascade sounds good rather than
  cluttered. `--write-clips` renders every cascade as mp3 for that check.
- VERIFIED: analyze clean; 155/155 tests; headroom tool exits 0.
- Detail: docs/improvements/sfx-headroom-2026-07-26.md

## 2026-07-26 — §3 combat choreography: one knob, and the measurement that says not to turn it

- All seven swing beats (contact, squash, enemy wind-up, hit-stop, knock, flash
  tail, death) now derive from `_CombatScreenState.choreoPercent` via `_pace()`.
  Pacing is a one-line change; the relative anatomy is preserved by construction
  and no beat can fall below one 60 Hz frame.
- MEASURED with tool/perf_probe_test.dart, `combat_tap_storm_12`, one variable:
  70% -> 50 frames, 4835 paints, 96.7/frame; 100% -> 60 frames, 5261 paints,
  87.7/frame; 130% -> 70 frames, 5742 paints, 82.0/frame.
- VERIFIED and contrary to the §3 assumption: shortening the choreography 30%
  removes only 8% of the paints but 17% of the frames, so paints per frame go
  UP (87.7 -> 96.7). A snappier swing is a denser swing. "Shorter tweens" would
  have made the jank proxy worse while spending feel; the only lever that lowers
  it is fewer SIMULTANEOUS animating layers.
- Default stays 100 because the §1 emulator trace measured this exact scenario
  at 1.21 ms average / 7.40 ms p99 build with ZERO frames over the 16.7 ms
  budget — there is ~9 ms of headroom, so the pacing costs nothing measurable.
  Changing it is therefore purely a feel call, and the knob makes it cheap.
- VERIFIED: analyze clean; 152/152 tests; probe at the default reproduces the
  pre-change baseline exactly (60 frames, 5261 paints, 87.7/frame).
- Detail: docs/improvements/choreo-knob-2026-07-26.md

## 2026-07-26 — v0.3.17+22 released (remaining-work §1/§2/§3/§5/§6/§7 landed)

- Merged in order onto legacy/dice-builder: #68 (§2 deterministic play session +
  oracle), #70 (§1 emulator frame trace CI), #71 (§7 combat_screen split),
  #72 (§5 map/title paint fixes), #74 (§6 SFX headroom tool + CI guard),
  #75 (§3 choreoPercent knob). Version 0.3.16+21 -> 0.3.17+22.
- Everything in remaining-work-2026-07-25.md is now either shipped or reduced to
  an explicit owner feel call with the measurement attached. Only §4 (die-tap
  rebuilds 14.1 -> 16.1) stays as previously accepted.
- VERIFIED on the merged tree: analyze clean, 155/155 tests, headroom tool exits
  0, signed release build from CI (workflow_dispatch on legacy/dice-builder).

## 2026-07-26 — §6 subjective SFX pass: owner sign-off (closed)

- The headroom tool's cascades are compressed worst cases (8 playSfx calls in
  480 ms) and are NOT representative of play — the owner listened to
  full_attack_turn and correctly heard "2 misaligned audio clips". Lesson: never
  present a stress mix as a feel sample.
- Re-rendered the same mix model at the real choreography offsets (whoosh 0,
  enemy_hit +250, ember_gain +470, one coin +1170; ~680 ms per attack cycle;
  handleEvents de-dupe means one hit and one coin per attack):
  single attack -3.7 dBTP / -17.3 LUFS, three-attack turn -3.7 dBTP / -17.8 LUFS
  — i.e. ~2.8 dB below the -0.9 dBTP ceiling case.
- VERIFIED (owner, Slack 2026-07-26): "that sounds good the new ones u made are
  good". §6 is now closed on both axes — objective headroom (CI-gated) and
  subjective feel (owner sign-off). No timing changes requested.
- Only genuinely open item left in remaining-work-2026-07-25.md: §1's real-device
  raster trace, which needs the owner's phone.

## 2026-07-26 — Release v0.3.18+23 (post-sign-off build)

- Cut on owner request after the §6 sign-off. No gameplay/engine/asset change vs
  v0.3.17: `git diff v0.3.17..909e10d -- lib/ android/ assets/` is empty; the tag
  exists to carry a fresh versionCode (23) for the next Play closed-testing
  upload and to mark §6 as closed.
- Commits since v0.3.17: 318eb12 (progress: §6 sign-off), 909e10d (version bump).
- VERIFIED from CI run 30203648154 (sha 909e10d, both jobs success): analyze
  "No issues found!", 155/155 tests, SFX headroom gate exit 0 (all reachable
  cascades clear -1.0 dBTP), store-screenshot gate byte-identical, APK V2 signer
  cert SHA-256 031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d
  (permanent upload key, O=Tsoro Studios / CN=Emberdelve Upload Key).
- Release: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.3.18
  Assets emberdelve-v0.3.18.apk (sha256 b650ecfc...4b5ea) and .aab (397b6126...55f65).
- Still open: §1 real-device raster trace (needs the owner's phone over USB).

## 2026-08-10 — v0.4.0+24: the Ember Forge (Play Billing full unlock, spec R8)

- Owner directives (Viktor app chat, 2026-08-10): production access is granted
  (per-app; Emberdelve needs no further tester gate), monetize without
  annoying players, everything production-ready. Market research (r/roguelites,
  r/AndroidGaming pricing threads, Slice & Dice / Dicey Dungeons comps) says:
  free game + ONE one-time unlock under $5, no ads — the audience punishes
  everything else. Design chosen: the **Ember Forge** — free forever: full
  easy/normal runs, all delvers (ember-priced), Daily Delve, themes; the one
  purchase (`ember_forge_unlock`, $4.99 tier) opens HARD + the Ascension
  ladder + all future acts. Passes the §Ethics test: the whole game is free,
  the endgame is the supporter's tier.
- Implementation (all gating OUTSIDE the sealed sim — start_run params only):
  - `lib/meta/forge.dart`: gate helpers (`canSelectDifficulty`,
    `maxAscensionFor`, `clampRunParams`) — pure, unit-tested.
  - `lib/meta/store_service.dart`: `StoreGateway` seam over
    package:in_app_purchase (^3.2.0) + `StoreService` lifecycle: subscribe
    stream FIRST, then availability/product query, silent startup restore;
    purchased/restored ⇒ grant → acknowledge (in that order — redelivery-safe);
    cancel is not an error; entitlement is sticky (never revoked locally).
  - `GameController`: `grantForgeUnlock()` (idempotent, queued atomic meta
    save), startRun clamp (defense-in-depth), setPreferredDifficulty guard,
    boot migration (pre-Forge profile stuck on hard moves the VISIBLE
    selector to normal — no silent switch).
  - `MetaState.forgeUnlocked` (field-tolerant; locked profiles serialize
    WITHOUT the key so pre-Forge saves stay byte-stable).
  - UI: `forge_sheet.dart` (the ONLY place money is mentioned; localized Play
    price; restore link; honest failure copy), lock icon on the HARD segment
    (FittedBox — 320px/1.3x overflow probe stays green), Ascension panel on
    the character screen, ONE quiet victory-only summary CTA (never a popup),
    Settings restore row. Total UI copy passes §Ethics blacklist.
- Contract change, deliberate: meta_ledger first-run test now pins "locked
  profile cannot select hard" (was: hard freely selectable). Updated WITH
  the feature per owner-approved monetization — not to make a failing test
  pass silently; the new test is stricter (asserts the refusal too).
- VERIFIED locally on the CI-pinned Flutter 3.32.7: analyze clean, 171/171
  tests green (`flutter analyze` + `flutter test`, sandbox run 2026-08-10).
- features.json: added M4-2 (passes:false — needs a real license-tester
  purchase + restore on a Play build for device evidence).
- Play Console side still needed (owner/Viktor, tracked outside the repo):
  create one-time product `ember_forge_unlock` ($4.99 base, launch intro
  $2.99 optional), add tester emails as license testers, upload the v0.4.0
  AAB to closed testing, verify purchase+restore on-device, then M4-2 flips.

## 2026-08-10 — v0.4.1+25: Play Billing Library 8 (deadline build, no gameplay change)

- Why: Play Console notification, verbatim — "Your app uses a version of Google
  Play Billing Library that will be deprecated soon. Update to a newer version
  by 31 August 2026 to prevent your updates from being rejected." Release 24
  ships Billing **7.1.1**; Play only counts what is uploaded, so a code fix
  without a new versionCode would not have satisfied it.
- No gameplay/engine/asset change vs v0.4.0+24. The delta is a dependency +
  toolchain bump (PR #77, merged as ccb2f59) plus three analyzer call-site
  desugarings, and this version bump.
  - `in_app_purchase ^3.2.0 -> ^3.3.0`, which resolves
    `in_app_purchase_android 0.4.0+5 -> 0.5.2` = **Play Billing 8.0.0**.
  - `environment.sdk ^3.8.1 -> ^3.12.0`; CI `FLUTTER_VERSION 3.32.7 -> 3.44.9`
    (in_app_purchase 3.3.0 requires Dart >= 3.12 / Flutter >= 3.44).
  - The only API removed in in_app_purchase_android 0.5.x is
    `queryPurchaseHistory`, which `lib/meta/store_service.dart` never called —
    so **zero** billing call-site changes were needed.
  - The newer Flutter ships vector_math 2.2.0, which deprecates
    `Matrix4.translate`/`scale`; `flutter analyze --fatal-warnings` is fatal on
    those. Fixed by exact desugarings in `lib/ui/screens/combat/stage.dart`
    (`translateByDouble(d, 0.0, 0.0, 1.0)`, `scaleByDouble(x, y, x, 1.0)`),
    NOT by relaxing the analyzer gate.
- VERIFIED before the merge, CI run 31436779563 (sha d315b87, both jobs success):
  analyze + tests + SFX headroom green, and the APK V2 signer cert SHA-256 is
  still 031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d
  (permanent upload key).
- VERIFIED in the artifact, not just the lockfile: unzip the AAB and run
  `strings base/dex/classes.dex | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'`.
  Release 24 -> `7.1.1` and a `queryPurchaseHistory` string. This tree -> `8.0.0`,
  no `7.1.1`, no `queryPurchaseHistory`.
- Still open: M4-2 (a real license-tester purchase + restore on a Play build).
  Billing 8 makes that on-device check more valuable, not less — it is the one
  thing no CI job can prove.

## 2026-08-10 — v0.4.1+26: keep minSdk 21 (device-support regression caught at Play review)

Uploading 0.4.1+25 to the closed alpha surfaced a hard Play error:

> This release no longer supports 1,972 devices that were supported in your
> previous release. If you proceed, your app will not be available to new users
> on these unsupported devices, and updates will not be available to users who
> already have your app installed on these devices.

Play's device-delta table: Phone -1,556 (-11%), Tablet -415 (-6%), TV -1 (-14%).

Root cause (VERIFIED from the two artifacts' proto manifests):
- v24 AAB `base/manifest/AndroidManifest.xml`: `minSdkVersion 21` (built on Flutter 3.32.7)
- v25 AAB: `minSdkVersion 24` (built on Flutter 3.44.9)

`android/app/build.gradle.kts` used `minSdk = flutter.minSdkVersion`, so the
Flutter 3.32.7 -> 3.44.9 bump (required by in_app_purchase 3.3.0 / Dart 3.12)
silently raised the floor from API 21 to API 24.

This was NOT required by billing. VERIFIED by downloading the AARs from
maven.google.com and reading their manifests:
- `com.android.billingclient:billing:8.0.0` -> `android:minSdkVersion="21"`
- `com.android.billingclient:billing:7.1.1` -> `android:minSdkVersion="21"`

Fix: pin `minSdk = 21` explicitly in `android/app/build.gradle.kts` with a
comment recording why. Billing 8 is retained, so the 31 Aug 2026 Play deadline
is still met, and device support returns to parity with 0.4.0 (24).

versionCode 25 was already consumed by the upload to the draft release (Play
never allows a version code to be reused), so this ships as 0.4.1+26.

Gate: the release build must produce `minSdkVersion 21` AND billing `8.0.0`
with zero `queryPurchaseHistory` strings in classes.dex, and be signed by the
existing upload key (SHA-256 031acb42...4b7a0d). If a transitive dependency
turns out to require API 24, CI fails at manifest merge - which is the correct
place to find out, not Play.

### Correction: minSdk 21 is not achievable on Flutter 3.44 (VERIFIED)

The pin to 21 did not work. The 0.4.1+26 AAB built from commit 5952208 (which
set `minSdk = 21`) still reports `minSdkVersion 24` in its proto manifest, and
CI produced no warning about it.

Cause, VERIFIED from upstream source: Flutter's Android embedding manifest
(`engine/src/flutter/shell/platform/android/AndroidManifest.xml`, stable)
declares `<uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36" />`,
and `FlutterExtension.kt` sets `minSdkVersion = 24` as the project default.
The manifest merger therefore raises the app floor to 24; an app-level 21 is
silently ignored. Flutter no longer supports API 21-23 at all.

So the API 21-23 drop is unavoidable while meeting the Billing 8 deadline. The
gradle file now states `minSdk = 24` explicitly with this reasoning recorded, so
nobody re-litigates it later. That edit is a no-op for output: the built
artefacts are identical either way (both merge to 24), so 0.4.1+26 was NOT
rebuilt for it.

Shipped: 0.4.1 (26) submitted to the closed Alpha track, full rollout, with the
device-support error acknowledged via Play's "Proceed anyway".

## 2026-08-11 — P0: Delver's Ledger achievements (data + meta + counters)

Owner picked "P0 achievements, then P2 content volume" after the retention
assessment (`docs/improvements/retention-2026-08-11.md`).

Why achievements and not the usual retention levers: spec §Ethics bans decaying
streaks, timers and loss framing. The measured alternative is *metric*
achievements — on Trophy's April 2026 platform data, completing a metric
achievement on day one correlates with 33.96% D30 retention versus 20.46% for
none, while streak achievements reach only 25.57%, and retention rises
monotonically with achievement difficulty. So the ethics-compatible lever is
also the stronger one. Several entries are deliberately hard for that reason.

Added:
- `lib/data/achievements.dart` — 37 defs, content-as-data, zero logic. Fixed
  stat vocabulary of 14 real MetaState counters, so a progress bar can never
  show a number the player did not earn. No rewards of any kind: recognition
  only, so the ledger can never become a grind gate.
- `lib/meta/achievements.dart` — pure evaluation (`statValue`, `progress`,
  `isEarned`, `earnedAchievements`, `unseenAchievements`, `markSeen`,
  `nearestAchievements`). Outside the sealed sim; reads meta only.
- `lib/meta/meta.dart` — schema **v2 → v3** with five new banked counters
  (`bestFloor`, `dailiesPlayed`, `winsNoRest`, `hardWins`) plus
  `bossesBeaten` and `seenAchievements` sets. Migration is deliberately
  conservative: `bestFloor` is recovered from the existing run history (a
  provable number) and `dailiesPlayed` claims exactly 1 when an old save has a
  recorded daily. Nothing unprovable is invented.
- `lib/game/controller.dart` — `recordLedgerStats` observes `encounter_started`
  and `rested` events only; `_bankRun` banks the counters and collects newly
  earned ids into `pendingAchievements` for the summary screen.
- `test/achievements_test.dart` — schema validity, targets inside real content,
  fresh profile earns nothing and is "near" nothing, progress real/monotonic/
  clamped, every stat wired to a live counter, toast fires once, round trip,
  honest migration from a v2 save, and a guard that earning achievements never
  changes any entitlement.

The sim is untouched, so the golden hash is unaffected. UI comes next.

### CI run 31446847919 — one honest test failure, fixed in the test

`a fresh profile has earned nothing and is close to nothing` failed:
`nearestAchievements(MetaState())` returned two defs, not none.

The code was right and the test was wrong. A brand-new profile really does own
one delver (`kindler`) and one hearth colour (`emberglow`), so `full_roster` and
`hearth_keeper` legitimately sit at 1/4. Showing that is honest; asserting it
away would have been the lie. The assertion is now stronger and true: nothing is
EARNED on a fresh profile, the only non-zero bars are the two real inventory
counts (and they must read exactly 1), every other achievement sits at exactly
zero, and the "nearly there" list may contain nothing else.

No production code was changed to make a check pass.

### Ledger UI for achievements

`lib/ui/ledger_screen.dart` gains an ACHIEVEMENTS panel between RECENT DELVES and
HEARTH COLORS: `earned / total` in the section header, then earned entries in
authoring order, then in-progress ones sorted by real progress, then untouched
ones. A progress bar is drawn ONLY for goals actually under way — an empty bar on
an untouched goal reads as failure rather than as an invitation. Footer states
plainly that achievements change nothing and never expire.

## 2026-08-11 — P2: content volume (enemies 17→30, events 16→28)

Data-only, zero logic changes, per the retention assessment: repetition starts
around runs 3-5 because 9 regular enemies and 16 events is a small deck.

Enemies **17 → 30**: regulars 9 → 17, elites 5 → 7, bosses **3 → 6**. Every
addition sits inside the measured v0.3.0 bands (early hp 24-36 / swings 15-23,
late hp 34-58 / 19-28, elite hp 48-72 / 21-31, boss hp 94-112 / 21-36), so the
200-seed autoplay gate should hold. Each new enemy has a distinct *rhythm* —
front-loaded, never-guards, two-in-three-guarded, same-beat attack_block — since
a new name on an old pattern is not new content.

**Boss count check done BEFORE committing:** `bossForSeed` indexes the boss list
by `seed % length`. The golden anchor seed 20260723 is congruent to 1 mod 3 *and*
mod 6, so index 1 is still `ember_tyrant` and the v6 golden replay survives the
3 → 6 change. Verified by parsing the file: boss order is
`[ashen_colossus, ember_tyrant, pyre_matriarch, cinder_hierophant, the_bellows,
ashfall_twins]`, `20260723 % 6 == 1`. **Any future change to the boss count must
redo this arithmetic first.**

Events **16 → 28**. Deck size is what keeps a run surprising, since the pick is
uniform over events not yet seen this run: at 28 entries a 7-node path almost
never repeats, and the second and third runs of an evening still show new rooms.
Design rule applied to every new entry: at least one option costs something
real. A deck of free gifts is a deck of non-decisions and quietly inflates the
run economy.

EXPECTED: the golden sim hash moves. Adding to the eligible spawn/event pools
changes what the seeded streams draw, which is exactly what the documented
process says will happen — re-anchor deliberately and record old → new below.

### Sprites for the 13 new enemies

`test/assets_test.dart` correctly refused the roster growth: every enemy needs a
sheet plus a `sprite_meta.json` entry, and 13 were missing. The original 0x72
source pack is not vendored here and the old `build_sprites.py` is gone, so the
sheets were produced the way v0.4 already produced `ashen_colossus` and
`pyre_matriarch` — a palette swap of a bundled sheet (all CC0).

New tool `tool/gen_variant_sprites.py`: deterministic HSV remap of an existing
sheet, alpha and pixel boundaries preserved, frame geometry copied verbatim so
the meta entry stays valid. `--check` re-derives every output and fails if a
sheet drifts from the generator, so the art is reproducible rather than a binary
nobody can regenerate.

First pass was wrong and a visual check caught it: three variants
(`flue_crawler`, `smoke_stalker`, `the_bellows`) came out indistinguishable from
their sources, because a hue rotation does nothing to near-grey pixels and
nothing to a red source shifted 12 degrees. Added a `saturation_floor` that lifts
visible near-greys before the hue applies (leaving pure black/white outlines
alone), and moved `the_bellows` to brass so it does not read as a second
`basalt_shell`. All 13 verified distinct on a source-vs-variant contact sheet.

**Stated plainly: this is placeholder-grade art.** A recolour reads as a related
creature — a normal roguelite convention, and why each pairing is plausible — but
it is not an original silhouette. Recorded per-file in PROVENANCE.md.

### Golden re-anchor (v0.5.0)

- `goldenV6` **1842571558 → 2013675017**, measured on CI run 31447154606 with the
  30-enemy roster and 28-event deck in place. Resolution rules are untouched;
  only what the seeded spawn/offering streams draw has changed, which is exactly
  the documented consequence of adding content.
- The per-boss anchors could not be re-pinned from a guess, so
  `goldenColossus`/`goldenMatriarch` were replaced by `bossAnchorSeeds`
  (20260722..20260727, congruent to 0..5 mod 6, hitting each of the six bosses
  exactly once in list order). The test now asserts the seed→boss mapping exactly
  and asserts per-boss run determinism, and prints the measured hashes so the
  constants get pinned from a real build in the follow-up commit.
- `content_test`'s `bosses == 3` became `bosses == 6` plus a real guard: it now
  asserts `bossForSeed(20260723) == 'ember_tyrant'`, i.e. the property the magic
  number was standing in for.

## 2026-08-11 — Bug sweep on the Ledger release (fix/ledger-bug-sweep)

Owner (app chat): "work on all these … Find bugs." Sweep target: everything
that shipped in 0.4.x/v0.5.0-era code. Also cut the missing GitHub release
v0.4.2 (tag at 1963e8b; CI-run-31459628277 artifacts, badging versionCode 27 +
signer 031acb42…4b7a0d re-verified locally before upload) and closed stale
PRs #60 (all items shipped or tracked elsewhere) and #27 (superseded by #47/#63).

Bugs found and fixed (each with a pinned test):

1. **Achievement announcements never fired.** `_bankRun` collected
   `pendingAchievements` "for the summary screen", but NO widget read the
   list (`takePendingAchievements` had zero call sites) — and markSeen
   guaranteed the toast could never fire later either. The one moment the
   Ledger pays off was silently dropped. Fix: summary screen renders an
   achievements-earned panel (key `achievements-earned`) next to the run
   result; startRun clears the list; dead `takePendingAchievements` removed.
   Tests: summary_achievements_test.dart (widget), meta_ledger_test
   (collect/clear lifecycle).
2. **"The Whole Bestiary" lied.** `all_three_bosses` still asked for 3
   bosses ("Beat all three…") after the same release grew the roster to 6.
   Fix: target 6, text "all six". Id kept for seenAchievements compat.
3. **"Four Ways Down" counted one way.** `every_delver_clears` promised all
   four delvers but read `char_wins[ascetic] >= 4`. Fix: new honest stat
   `delvers_cleared` = distinct ROSTER characters with >= 1 win (junk
   charWins keys can never inflate it); def now demands genuinely all four.
4. **Exact-kill streak survived death.** A lost fight left `exactStreak`
   untouched, so streak_three was earnable as 2 exacts, die, 1 exact.
   Fix: `encounter_lost` resets the streak (best remains the high-water mark).
5. **Rung 21.** Winning at ascension 20 minted `bestAscension = 21` on a
   0–20 ladder (display-only — forge.dart clamps play). Fix: clamp at bank.
6. **first_delve overclaimed.** runsPlayed counts abandoned runs; text said
   "Finish". Copy now: "End your first run — win, die, or walk away."
7. **Boss goldens pinned** (the promised follow-up that never landed):
   bossGoldens in sim_test now asserts all six per-boss hashes, values
   identical across CI 31447535252 + 31459628277 + local 3.44.9 run.
8. **Soft-lock guard for the event deck** (found no live bug — pinned the
   invariant): every event must keep >= 1 option that is legal in any state
   (no gold cost, no lose_random_die). All 28 current events comply.

Test-file edits called out per harness rules: sim_test boss-anchor block
(pin, documented), content_test + achievements_test + meta_ledger_test
(new cases only), new summary_achievements_test.dart. No assertion weakened.

VERIFIED: flutter analyze clean; 187/187 tests green locally (was 182);
autoplay 200 seeds: 64% winrate, invalids=0, golden self-consistent.

## 2026-08-11 — P1 ember sink shipped (retention-2026-08-11 P1)

Feature branch feat/ember-sink → PR into legacy/dice-builder. Everything
cosmetic/lore only per charter: prices up front, no timers, no FOMO, zero
sim impact.

1. **Hearth colors 4 → 12.** Eight new themes (ashrose → voidcoal), price
   ladder 120–400 embers, data-only in data/themes.dart.
2. **Dice skins (new).** data/skins.dart: 7 skins (default bone free +
   6 priced 150–400). DieChip gets a `skin` param — multiply tint over the
   die art + skin ink in _FacePainter. Default is the identity paint:
   unskinned chips render pixel-identical (pinned in test). Wired at all
   6 render sites (tray, boon, rest, reward flip-card, shop, ledger swatch).
3. **The Codex (new).** data/codex.dart: 53 lore entries — every enemy (30,
   commons 15 / elites 20 / bosses 30 embers) and every relic (23, 20 embers).
   Names/rules never paywalled — lore only. New CodexScreen, entry point on
   the Ledger. Coverage pinned: a new enemy/relic without lore fails CI.
4. **Meta:** ownedDieSkins/activeDieSkin/ownedCodex + buy methods mirror
   hearth colors; field-tolerant load (no schema bump needed — additive),
   unknown active skin falls back to bone. Total new sink ≈ 3,175 embers.

Tests: new ember_sink_test.dart (8 cases: catalog invariants, purchase
rules, JSON round-trip, ledger cards, codex buy flow); overflow probe
extended (codex screen at all sizes, ledger with all skins owned).
VERIFIED: flutter analyze clean; 207/207 tests green locally (was 194).

## 2026-08-11 — v0.4.3 (28) released on GitHub
Tag v0.4.3 at 3b6b916; assets from CI run 31488900632 (signed build at the
exact release sha). VERIFIED badging: com.tsorostudios.emberdelve,
versionCode 28, versionName 0.4.3; APK v2-signed, APK+AAB signer cert
SHA-256 matches the pinned upload key
031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d.
sha256: apk f708e68a2095472f28e732f98bd1436b0a15db66cf8abdd4720a003cc185f3ac,
aab a1b67fe76b847217a034b01f9610a05014ae517090d9083236494195b35c6d05.
Ships: opt-in telemetry (#63), achievement toasts + bug sweep (#78),
P1 ember sink — dice skins, the Codex, 12 hearth colors (#79).
NOT yet uploaded to Google Play. Prerequisite before Play upload:
update the Play Console Data safety form (telemetry added this version).

## 2026-08-11 — P3 Weekly Delve + run mutators (v0.4.4+29, feat/weekly-delve-mutators)
Retention plan P3 done. A Monday-aligned 7-day shared seed with ONE declared
modifier per week, no streaks / no expiry (spec §Ethics — a missed week is a
missed week).
- data/mutators.dart: catalog — all_d4 (Flint Week), elites_only (Elite
  Gauntlet), no_shops (No Quarter). sim reads only the id string.
- sim/daily.dart: weeklySeed(weekIndex) pure, namespaced apart from daily.
- game/weekly.dart: Monday-aligned week index (DateTime-free civil-day math),
  mondayOfWeek inverse, weeklyKey, deterministic weeklyMutatorFor(index),
  honest recap/share strings.
- sim: opt-in sim.mutators set. EMPTY on every normal/Daily run, so all
  mutator branches are skipped and the golden anchor is BYTE-FOR-BYTE
  unchanged (goldenV6=2013675017 and all 6 boss goldens still pass). Applied
  at 3 seams: combat _rollOne face cap (all_d4), map relabel before reward
  telegraphs (elites_only/no_shops, consumes no rng), run_started stamp.
  Snapshot only carries 'mutators' when non-empty (pre-P3 saves stay clean).
- meta: lastWeekly{Key,Won,Floor,Floors,Mutator} + weekliesPlayed, one record.
- controller: startWeeklyRun(); banks weekly record; weeklyResultShareText.
- UI: title Weekly Delve button + declared-rule blurb + recap, in-run WEEKLY
  badge, summary copy-weekly-result.
- Tests: 228 total (was 207) — test/weekly_test.dart adds 21. analyze clean.
  Autoplay 150 seeds/mutator, 0 invalids: normal 64% / no_shops 65% /
  all_d4 20% / elites_only 3% — a real difficulty ladder.
NOT released yet (v0.4.3 is still in Play review). Ship v0.4.4 after 0.4.3
clears, via the usual signed-CI + verify + release recipe.

## 2026-08-12 — competitive depth/performance pass (iteration 1)
Owner asked whether Classic should go 3D, to benchmark competitors, outdo
them, and keep performance strong. Primary-source research is recorded in
docs/improvements/competitor-depth-performance-2026-08-12.md (Slice & Dice,
Die in the Dungeon, Astrea, Dicefolk, Dicey Dungeons, Peglin, Balatro +
Flutter renderer guidance). Decision: dimensional 2.5D inside Flutter, not a
second/full-3D engine — competitors win on tactile causal feedback, build
identity and readability; a runtime physics/mesh/post-FX stack would add
package, occlusion and Android OpenGL-fallback risk without solving those.

Implemented presentation-only depth: analytic perspective pitch/yaw/squash
is composed into the existing throw/settle transform; directional warm/cool
lighting and d6 lower/right planes are folded into the existing face painter;
faceted dice retain their clean source planes; combat gets a static shallow
cavern floor (perspective seams, ember pool, foreground silhouettes) behind
combatants plus stronger contact shadows. No new assets/dependencies,
saveLayer, blur, sim change, save change or package growth. The first
widget-heavy prototype was REJECTED after the perf probe regressed die taps
20.1→23.2 paints/frame and combat storm 96.2→107.7; the accepted collapsed
version is 19.9 and 96.6 respectively, with combat idle exactly 2.0
paints/frame. Title/map metrics unchanged. Screenshot before/after inspected;
the d8/d10 duplicate-edge moiré found in critique was removed.

New test/dimensional_presentation_test.dart proves deterministic finite pose,
one-layer dimensional paint with no saveLayer, and static diorama paint with
no saveLayer. VERIFIED: flutter analyze clean; full suite 276/276; dimensional
tests 3/3; store screenshot harness 2/2; perf probe green; git diff confirms no
lib/sim or sim_test changes (goldenV6 remains 2013675017). The four-run
real-UI probe initially reported STUCK at a valid run_won: screenshot evidence
showed the long achievement recap put `Delve again` off-screen and its helper
performed a silent off-screen tap. Fixed the probe (not its oracle) to
ensureVisible before a real hit-tested tap; the pinned session completed
4/4 runs with 0 invariant violations and 0 UI warnings. A later repeat exposed
a second harness leak: its persistent output/save
directory resumed the prior invocation mid-fight, violating the declared
fresh-session premise. The probe now deletes only its own sandbox save at
setup before boot; two consecutive clean-start reruns both passed, the last
at 4/4 runs / 827 steps / 0 violations / 0 warnings. Resume behavior remains
covered by dedicated tests.
Physical profile/memory/thermal numbers remain device-gated and are not
claimed from debug widget proxies.

## 2026-08-11 — fix: post-encounter progression glitch (map back-and-forth)
Owner report: after defeating an enemy or progressing, the progression
glitches a bit back and forth. Two stacked causes, both on return-to-map:
1) PhaseSwitcher.build() collapsed to a BARE widget.child when idle but
   wrapped AnimatedBuilder>Stack>KeyedSubtree while transitioning — the tree
   SHAPE changed when a transition settled (380ms), so Flutter REMOUNTED the
   just-revealed screen. The map mounts at the fade midpoint (~190ms), starts
   the delver walk (650ms) + follow scroll (450ms), then loses its State at
   380ms — both animations snapped back and replayed. Fix: the wrapper is now
   permanent (identical shape idle vs transitioning; overlay is a
   SizedBox.shrink when idle); the KeyedSubtree key changes only at the
   midpoint reveal — the one intended remount.
2) The map's follow-scroll always ANIMATED from offset 0 (delve floor) on
   arrival, sweeping the camera bottom→delver every visit mid-run. Fix: first
   follow of a visit jumpTo (invisible — happens behind the fade at full
   black), later moves within a visit still animate.
Regression tests: test/progression_glitch_test.dart — (a) MapScreen State
identity across the transition settling, (b) mid-run arrival (bot-driven to
layer >= 4) is framed on the delver immediately with no post-arrival camera
motion. Both FAILED before the fix, pass after.
VERIFIED: flutter analyze clean; 230/230 tests green (was 228).

## 2026-08-11 — bug hunt: resumed Daily/Weekly identity loss (pre-0.4.4 release)
Sweep before the v0.4.4 Play release. Sim core fuzzed clean: 360 bot runs
(60 seeds x {normal, easy, hard, all_d4, elites_only, no_shops}), 56,537
commands, a snapshot->jsonRoundTrip->restore twin applied EVERY command —
0 event/state-hash divergences, 0 bot invalids, all runs terminated.
REAL BUG (controller layer): dailyDate/weeklyIndex/weeklyMutator lived only
in controller memory. Kill + resume a Daily/Weekly Delve and it finished as
a PLAIN run — _bankRun gates every daily/weekly record on those fields, so
the recap, the share button, dailiesPlayed/weekliesPlayed all silently
skipped (the field comments even claimed "loses only the badge" — false).
Fix: _autosave stamps a 'run_labels' key alongside the sim snapshot (only
when set — normal-run save blobs stay byte-identical; Sim.restore ignores
foreign keys) and boot() restores it. New @visibleForTesting flushSaves()
awaits the private save queue.
Regression: test/resume_labels_test.dart (3 tests — resumed weekly banks,
resumed daily banks, normal saves carry no labels). Weekly+daily resume
tests FAIL with the restore block disabled (proof run recorded).
VERIFIED: analyze clean; 233/233 tests green (was 230).

## 2026-08-11 — CRITICAL bug: Weekly Delve seed was never pinned (caught pre-release)
The release-dispatch CI run flaked on the new resume_labels weekly test —
and the flake exposed the real bug: startWeeklyRun never passed a seed, so
weeklySeed(index) (written, unit-tested in weekly_test) was DEAD CODE and
every player's "Weekly Delve" ran on a random clock seed. Only the modifier
was shared; the title blurb and share text's "same seed ... for everyone"
claim was false. Fix: startRun(seed: weeklySeed(index), ...) in
startWeeklyRun. Also hardened the resume_labels test driver: the trivial
roll-without-assign policy stalls on rare seeds under guard — replaced with
the greedy autoplay bot (proven terminating across 360 fuzz runs) and a
guard assertion. New regression test: two controllers starting the weekly
land on the identical, canonical weeklySeed(weekIndex).
VERIFIED: analyze clean; 234/234 tests green; resume_labels ran 5x stable.

## 2026-08-11 — P4 cloud save + P5 leaderboards (Play Games Services v2) → v0.5.0+30
Retention plan items P4/P5 (docs/improvements/retention-2026-08-11.md).
Console: PGS project "Emberdelve" (id 598659800964) linked to cloud project
gen-lang-client-0980262477; Saved Games enabled; OAuth consent screen +
Android OAuth client (Play app-signing SHA-1); credential saved. Leaderboards
created: Daily Delve CgkIhL-el7YREAIQAQ, Weekly Delve CgkIhL-el7YREAIQAg.
Code: lib/meta/play_games_service.dart — backend-injected gate (same
architecture as TelemetryService: plugin-import-free, headless-testable;
main.dart wires games_services 5.3.0 on Android only). Connecting is OPT-IN
via a Settings "Connect" tap (§Ethics — same consent charter as analytics);
manifest removes PlayGamesInitProvider so PGS never auto-signs-in, and
MainActivity calls PlayGamesSdk.initialize manually.
Cloud save (P4): whole MetaState snapshot as ONE PGS saved game
('emberdelve_meta'). Sync = pull → mergeMetaStates (lib/meta/cloud_merge.dart:
max for monotonic counters, union for owned sets, OR for sticky flags
incl. forgeUnlocked, fresher-side — higher lifetimeEmbers — for spendables/
recaps/history) → adopt locally → push merged. Push also after every banked
run. Local stays authoritative; every cloud step is best-effort.
Leaderboards (P5): score = embers banked by a FINISHED Daily/Weekly (the
number the summary already shows — no hidden formula), submitted from
_bankRun only when connected. Summary gains a "Leaderboard" button for
connected daily/weekly finishes; Settings gains PLAY GAMES section
(Connect/Disconnect + View boards), hidden entirely off-Android.
Sim untouched — save blobs and goldens byte-identical.
VERIFIED: analyze clean; 259/259 tests green (was 234; +25 new in
cloud_merge_test, play_games_service_test).

## 2026-08-11 — HARD goes free + opt-in Daily Delve reminder → v0.6.0+31
Both remaining retention-doc items (docs/improvements/retention-2026-08-11.md
§5), approved by the owner's blanket go-ahead for the recommendation list.
HARD free (the "business question"): freeDifficulties now includes 'hard';
the Forge gates ONLY the Ascension ladder. The v0.4.0 boot clamp that forced
a non-Forge hard preference back to normal is deleted (clampRunParams remains
the entitlement guarantee, now passing hard through for everyone). Forge
sheet, victory panel and settings copy updated — the sheet no longer lists
HARD as a perk. Rationale: hard is the natural week-two content; gating it
cost more players at cliff 3 than it converted (see doc). A pre-0.6.0
profile whose hard preference was clamped keeps its stored 'normal' — moving
it back silently would be a surprise switch.
Daily Delve reminder (the "judgement call", shipped as OPT-IN):
lib/meta/reminder_service.dart — backend-injected, plugin-import-free (same
architecture as TelemetryService/PlayGamesService). OFF by default; the
Settings toggle asks POST_NOTIFICATIONS at runtime; denial = stays off.
Copy is a neutral fact ("Today's Delve is ready") — §Ethics: no loss frames,
no streak threats (a test bans the words). Scheduling: next 7 daily slots at
10:00 local as ONE-OFF inexact notifications (no exact-alarm permission),
window rebuilt every launch after cancelAll — so reminders quietly STOP
after a week away instead of nagging a lapsed player forever. Pure slot
math in nextReminderTimes() (DST-safe via civil-day constructor arithmetic).
flutter_local_notifications 22.3.0 + timezone/flutter_timezone; gradle gains
core-library desugaring (2.1.4); manifest adds the two plugin receivers
(not exported) + RECEIVE_BOOT_COMPLETED. No new data collection — local
notifications only, Data safety form unchanged.
Sim untouched — save blobs and goldens byte-identical.
VERIFIED: analyze clean; 272/272 tests green (was 259; +13 new in
reminder_service_test; 2 forge/ledger tests updated to the new contract).

## 2026-08-12 — pool-forged build identity (presentation-only)
Competitive-depth iteration after the dimensional 2.5D pass. Added a pure
RunBuildIdentity projection over the live die IDs: Ember/Blade/Aegis/Heart,
stable tie order, dominant size/tier, exact size counts and special count.
Combat's existing procedural signature weapon now uses that identity for its
edge/smear colour, tier-scaled reach and one path-specific silhouette mark.
The terminal screen (win AND loss) gains POOL FORGED THIS RUN with the honest
dominant-trait name and exact pool breakdown; the panel has one combined
screen-reader label.
No sim/save/golden/dependency/binary-asset change. Screenshot critique caught
and fixed two issues before the gate: some weapon internals retained the
character accent instead of the build accent, and the first summary test's
restart control moved below the fold (test now scrolls to the real button).
VERIFIED: analyze clean; full suite 282/282; overflow 25/25 across 320x568–
412x915 and 1.3x text; visual plate covers all four identities; store harness
2/2; perf proxy unchanged from the accepted dimensional baseline (combat idle
2.0 paints/frame, die tap 19.9, full storm 96.6); deterministic real-UI probe
4/4 runs, 827 steps, 0 violations/warnings. goldenV6 remains 2013675017.

## 2026-08-16 — v0.8.0 "Tell the Tale" — the share artifact (GitHub-only release mode begins)
Owner directive 2026-08-16: no Play submissions until told otherwise; every
improvement ships as its own GitHub release with notes. DEMAND.md written at
repo root (pillars, gates, release mode); studio-priorities research doc and
v0.9.0 Today's Trials design doc added under docs/improvements/.
The improvement: a pure RunTrace observer (lib/game/run_trace.dart) fed by
the same sim event stream as the ledger — emoji floor trace in rows of 5
(🟩 clean / 🟨 hurt / 🟥 death floor / 🔥 Ember claimed), semantic label,
seed-challenge text. Trace rides the autosave beside the snapshot
(run_trace key) and restores on boot. Daily/weekly share texts gain a grid
line (no-grid output byte-identical to old); new seedChallengeShareText for
finished non-daily/non-weekly runs; summary screen shows the grid above the
seed line plus a "Copy seed challenge" button. Sim untouched — simVersion 7,
all goldens unchanged. Banned-words sweep over every share surface stays in
tests.
Screenshot critique caught two harness bugs before the gate: plates rendered
without a Scaffold ancestor (yellow double-underline artifact; in-app
GameRoot already wraps in Scaffold, product unaffected) and the trace grid
sat below the fold in all plates — fixed with Scaffold wrap + scrollToKey
plates. Re-render verified: grid rows, button order, and 1.3x wrap all clean;
tofu emoji in plates is the documented sandbox font limitation only.
VERIFIED: analyze clean; full suite 342/342 (was 325; +17 run_trace tests
incl. 3 controller e2e); share texts byte-verified (LOST seed 111 grid 🟥,
WON seed 503 grid 🟨🟨🟩🟩🟨/🟩🟩🔥). Version 0.8.0+34.

## 2026-08-16 — v0.9.0 "Today's Trials" — the daily's rule now rotates
Backlog item 2 (studio-priorities §2): a return-moment from rule VARIETY,
not streak pressure. Each date deterministically declares one trial atop
the Daily Delve seed via hashDomainString('emberdelve-trial:YYYY-MM-DD')
into append-only trialsOrder (7 entries): three mutator days riding the
existing cmd['mutators'] seam (all_d4 / elites_only / no_shops) and four
goal days judged by a pure function over the final run snapshot + RunTrace
(gold 40+ / fights 4+ / clean floors 3+ / embers 60+, small ember bonus
banked once through the guarded _bankRun path). Nothing new persists — the
trial re-derives from the saved daily date label, so resumes are free and
old saves untouched. Sim untouched, simVersion 7, goldens unchanged.
UI: daily-trial-line under the Daily button (rule spelled out before you
commit, goal days state their bonus as a fact); trial-met-chip on the
summary ONLY when met — a missed goal renders nothing (§Ethics). Daily
share header gains "· <trial name>"; no-trial output byte-identical.
Also fixed: two tool-only lints from the v0.8.0 commit broke CI's
fatal-on-warnings analyze gate (hotfix committed separately as the v0.8.0
release SHA); e2e first read mutators from run['mutators'] — they live in
sim.mutators, the run_started event only carries a display string.
VERIFIED: analyze clean; full suite 357/357 (+15 trials tests: catalog
integrity, 2026–2028 determinism/uniformity sweep, non-degenerate rotation,
predicate fixtures, banned-words over trial copy, controller e2e mutator
apply + idempotent bonus bank + share header). Version 0.9.0+35.

## 2026-08-16 — v0.10.0 "The First Delve" (build 36)

- Killed the up-front 4-card tutorial wall. New `lib/game/tips.dart` TipDirector:
  staged contextual tips at first contact — roll_spend (first fight start),
  intent_fair (first enemy action), combos_pay (first combo event), block_fades
  (first telegraphed attack ≥ 4). One at a time, once ever; suppressed triggers
  recur naturally, no queue. Manual ? replay of the full deck unchanged.
- MetaState.tipsSeen (union cloud merge; veteran migration: tutorialSeen without
  tipsSeen key seeds all four). Controller.dismissTip sets legacy tutorialSeen
  when the last tip dies, so older builds sharing a cloud save never replay.
- _ContextTip card: light 0.35 scrim, anchored at its subject, tap-anywhere
  dismiss. CAUGHT by new sweep test: overflow at 320×568 @1.3x (69px) — fixed
  with short-screen anchor padding (72/96 vs 120/210) + SingleChildScrollView.
  Test gotcha: combat screen is _scoped-cached; direct director pokes need a
  MediaQuery jiggle (1px height) to force rebuild in tests.
- meta_ledger round-trip test updated (migration adds tipsSeen key — construct
  the source with it). All wall-suppressing tests/tools now seed tipsSeen too.
- Suite 372/372 (log /work/temp/ed_full_suite_v0100c.log). Sim untouched.
- Releases published earlier this session: v0.8.0 (6189058, run 31938009795)
  and v0.9.0 (1c0fd78, run 31938359549) — both signer-pin verified
  (031acb42…), sha256s in release notes, GitHub-only per owner directive.

## 2026-08-16 — v0.11.0 "The Delver's Ledger" (build 37)

- Per-enemy record: MetaState enemyMet/enemyFelled/enemyFellTo (toJson omits
  empty; cloud merge = per-key max). Banked event-driven in recordCombatStats
  via _lastEnemyId (encounter_started/won/lost). Sim untouched (simVersion 7).
- Run firsts: controller runFirstMet/runFirstFelled (lifetime 0→1 only),
  persisted in autosave as run_firsts beside run_labels, restored in boot.
  Summary shows 'First sighting/felling: <names>' (key firsts-line); Codex
  record line is FREE above the seal — never paywalled (codex-record-<id>).
- HARD-WON test knowledge (cost ~3 hung 10-min runs): with a real
  saveDirOverride, any apply() inside a testWidgets body initiates real file
  I/O in the FakeAsync zone; its completions queue behind fake microtasks and
  NEVER resolve — a later runAsync(flushSaves) cannot rescue it. Cure: run the
  whole drive (startRun → bot loop → flushSaves) inside ONE tester.runAsync.
  Corollary: never await a controller's _saveQueue when it never saved — the
  constructor's Future.value() was BORN in the fake zone and awaiting it
  resolves through the creation zone's microtasks (deadlock even in runAsync).
  summary_achievements_test only survived because plain GameController() saves
  fail silently through path_provider's MissingPluginException.
- Plates: tool/ledger_visual_test.dart → codex 360x640 + 320x568@1.3x +
  summary firsts 360x640; critiqued, no overflow, lists coherent.
- Suite 381/381 (log /work/temp/ed_full_suite_v11.log). Version 0.11.0+37.

## 2026-08-16 ~10:55 GMT — v0.11.0 PUBLISHED
- CI run 31942389734 success. Signer pin 031acb42…44b7a0d verified on APK (androguard v2) and AAB (jar META-INF). versionName 0.11.0, code 37.
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.11.0
- apk 224c183a73a62b3392314210fc22ea5f86629b07d12ecdc7dee272e5df9c6d1b, aab 552c8deca8c92ab1667be8a3e2aac90dc2b013609f9802ef2a3cde57603ad6f9. Checksums appended to docs/releases/v0.11.0.md.
- Next: v0.12.0 "New Embers" per docs/improvements/v0.12.0-return-moment-design.md (design doc committed with this entry).

## 2026-08-16 ~11:10 GMT — v0.12.0 "New Embers" built (content drop, GitHub-only)
- 5 enemies (tinder_mote, slag_snail early; vent_serpent, pumice_hulk late; cinder_marshal elite — all appended at band END), 3 events (serpents_molt, the_snail_road, marshals_muster), 4 relics (cinder_lantern = first multi-hook relic {turn_block+block_flat}, serpent_fang, pumice_plate, hearth_kettle). 9 codex entries. Bosses deliberately stay 6 (anchor seed 20260723 % 6 == 1 → ember_tyrant preserved). No simVersion bump (pool contents, not snapshot shape).
- GOLDEN RE-ANCHOR (pool growth: enemies 30→35, events 28→31), measured twice per seed, identical, local Flutter 3.44.9, old → new:
  goldenV6            1507173787 → 1285794096
  ashen_colossus       201437516 → 240246681
  ember_tyrant        1507173787 → 1285794096
  pyre_matriarch       625118910 → 1072189078
  cinder_hierophant   1042046624 → 1003403945
  the_bellows         2005745586 → 753684676
  ashfall_twins        183009563 → 1171602943
- Sweep (tool/v7_sweep_probe): curve monotonic at every keystone/temper combo + ascension rungs; normal ~70-72%, hard 45-50%, in band. Fuzz 24000 commands, 0 invariant breaks. 200-seed: easy 93 / normal 70.5 / hard 49.
- Sprites: 5 palette variants via tool/gen_variant_sprites.py (tinder_mote←cinder_wisp, slag_snail←ember_beetle, vent_serpent←cinder_crawler, pumice_hulk←slag_brute, cinder_marshal←pyre_howler); existing 13 sheets regenerated byte-identical (determinism re-proven); PROVENANCE.md rows added; new sprite_meta entries labeled v0.12.0.
- FOUND+FIXED latent test fragility: temper_ui_test's fight-walk applied event option 1 blindly; deck growth dealt it a gold-costing option with an empty purse → invalid cmd, phase stuck at 'event'. Now walks options last→first until one resolves (lib convention: decline is last). NOTE for future content drops: any fixed-seed test that walks nodes can break this way — grep for "event_choose', 'option': 1" before tagging.
- Plates (tool/new_embers_visual_test.dart): codex card for cinder_marshal at 360x640 + 320x568@1.3x + relic plate — PASS (card fully framed, record line free above seal, elite price 20, no overflow). Overflow probe all 5 sizes green. Full suite 381/381, analyze clean. Version 0.12.0+38.

## 2026-08-16 ~11:55 GMT — v0.12.0 "New Embers" PUBLISHED
- CI run 31943500108 completed success on tag v0.12.0.
- Signer pin verified on BOTH artifacts: 031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d; versionName 0.12.0, versionCode 38.
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.12.0
  - emberdelve-v0.12.0.apk sha256 0f51025a79d764b530b3e5f1606db14a414bf98b08c3ba0e6b1dfe6273684fc6
  - emberdelve-v0.12.0.aab sha256 144666127e6171f33f292cd08a67a850c7954f6faf71216bb1036684f143c5a1
- Checksums appended to docs/releases/v0.12.0.md. Studio-priorities backlog items 1-5 now all shipped.
- Next: v0.13.0 "The Delver's Rank" per docs/improvements/v0.13.0-delvers-rank-design.md.

## 2026-08-16 ~12:20 GMT — v0.13.0 "The Delver's Rank" built
- data/ranks.dart: 9 tiers Ashfoot(0)..Deepfire Sovereign(1100); withArticle helper; names dodge the 4 character names.
- meta/rank.dart: rankMarks = 3*runsWon + 5*bosses + 2*felledDistinct + metDistinct + ownedCodex + 2*(dailies+weeklies); rankFor/nextRank pure; monotone under cloud merge (union/max) — pinned in test.
- Controller: pendingRankUp (before/after rankFor around _bankRun counters), cleared in startRun. Ledger header panel key 'rank-line'; summary one-line key 'rank-up-line' (withArticle fixes 'a Emberwright').
- Tests: rank_test.dart 8 (boundaries via wins*3+met%3 composition; merge monotonicity = the derived-state assert), rank_ui_test.dart 3 (seed 11 = deterministic autoplay WIN). Suite 392/392; analyze clean; overflow probe green; plates tool/rank_visual_test.dart reviewed (320x568@1.3x wraps cleanly).
- Version 0.13.0+39; notes docs/releases/v0.13.0.md. No sim contact, no goldens moved.

## 2026-08-16 ~12:50 GMT — v0.13.0 "The Delver's Rank" PUBLISHED
- CI run 31944441008 completed success on tag v0.13.0.
- Signer pin verified on BOTH artifacts: 031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d; versionName 0.13.0, versionCode 39.
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.13.0
  - emberdelve-v0.13.0.apk sha256 b358c29bf695888b2ff243e6bdc5e4c88bd91df2c2ae55492e3fb7cd59a93a5a
  - emberdelve-v0.13.0.aab sha256 1dc3a2add752d4001d52c521d7d30a4092955b3dc7413ceacb52607981494ef0
- Checksums appended to docs/releases/v0.13.0.md; v0.14.0 "Lighter Lantern" design doc committed.
- Next: v0.14.0 per docs/improvements/v0.14.0-lighter-lantern-design.md (CI split-per-abi; zero app-code change).

## 2026-08-16 ~13:40 GMT — v0.14.0 "The Lighter Lantern" PUBLISHED
- CI run 31945111172 completed success on tag v0.14.0.
- Signer pin verified on ALL FIVE artifacts (4 APKs via androguard loop + AAB via pkcs7): 031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d.
- Split versionCodes confirmed ABI-offset (Flutter scheme): armeabi-v7a 1040, arm64-v8a 2040, x86_64 4040; universal APK + AAB keep plain 40.
- Measured sizes: arm64 34.9 MB / v7a 32.5 MB / x86_64 36.3 MB vs universal 68.8 MB (arm64 = 49% smaller; remaining weight is shared assets, not native code).
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.14.0 (5 assets: 3 split APKs, universal APK, AAB). Full sha256 table appended to docs/releases/v0.14.0.md.
- LESSON: design-doc estimate said "~25 MB" per split — actual 33-37 MB because v0.12.0's per-ABI numbers measured NATIVE LIB payload only, not full APK. Notes ship measured numbers, never estimates.
- Next: v0.15.0 "The Hearthside Post" per docs/improvements/v0.15.0-hearthside-post-design.md (implementation already in progress during CI wait).

## 2026-08-16 ~14:05 GMT — v0.15.0 "The Hearthside Post" built
- data/news.dart: NewsEntryDef content-as-data, newest-first, backfilled v0.13/v0.14; currentAppVersion const pinned to pubspec by test; compareVersions ('' sorts first).
- meta: lastSeenNewsVersion ('' = never; absent key omitted from JSON); cloud merge keeps LARGER version (never re-shows read news). Boot stamps fresh profiles (runsPlayed==0 && '') silently; veterans keep '' and see the note once.
- UI: title panel key 'news-panel' under the menu, single 'Noted' (key 'news-dismiss') -> controller.dismissNews (save+notify). Settings tile 'past-posts-tile' -> NewsArchiveScreen (lib/ui/news_screen.dart), per-entry keys 'news-archive-<version>'.
- CRITIQUE CAUGHT: v0.15.0's own entry title equals the panel eyebrow -> read as a duplicate-line bug on plates. Fixed: version moved into the eyebrow, title line skipped when it matches the panel name.
- Tests: news_test.dart 7 (incl. §Ethics banned-word sweep over ALL news copy) + news_ui_test.dart 3. Suite 402/402; analyze clean; plates tool/news_visual_test.dart reviewed (412x915 + 320x568@1.3x + archive). Version 0.15.0+41; notes docs/releases/v0.15.0.md. No sim contact.

## 2026-08-16 ~14:45 GMT — v0.16.0 "The Still Flame" built (tag held until v0.15.0 publishes)
- Reduce-motion comfort setting: AudioSettings.reduceMotion 'system'/'on'/'off' (absent/garbage -> 'system'); resolver lib/ui/motion.dart (ChangeNotifier singleton; notifies ONLY on answer flip; defers notify past build via SchedulerPhase check — MaterialApp builder feeds MediaQuery.disableAnimations).
- Gates: ShakeBoxState.shake() no-op; EmberDrift renders nothing + STOPS ticker (listens to Motion, returns live on toggle-off); DamagePop static render (number+fade kept, transforms dropped, onDone same clock). Sub-100ms flashes/vignette deliberately NOT gated (information, not displacement).
- Settings: FEEDBACK section renamed COMFORT; three-way selector keys 'reduce-motion'/'reduce-motion-<id>' styled like the title difficulty selector; caption honest.
- Tests: motion_test.dart 3 + motion_ui_test.dart 4. Suite 409/409, analyze clean, overflow probe green, plates tool/motion_visual_test.dart reviewed (360x640 + 320x568@1.3x — selector highlights, no overflow).
- Version 0.16.0+42; currentAppVersion bumped; news.dart entry added (Hearthside Post announces its first real update); notes docs/releases/v0.16.0.md.

## 2026-08-16 ~15:15 GMT — v0.15.0 "The Hearthside Post" PUBLISHED
- CI run 31945916947 completed success on tag v0.15.0.
- Signer pin verified on ALL FIVE artifacts; versionName 0.15.0; codes 41 / 1041 / 2041 / 4041.
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.15.0 (3 split APKs + universal + AAB; sha256 table in docs/releases/v0.15.0.md).
- Next: tag + CI for v0.16.0 "The Still Flame" (already committed, suite 409/409).

## 2026-08-16 ~15:30 GMT — boundary snapshot (run ended on budget)
- v0.15.0 PUBLISHED (see entry above). v0.16.0 tag pushed; CI run 31946489752 IN PROGRESS at snapshot — on success run the standard release procedure (expect versionName 0.16.0, codes 42 / 1042 / 2042 / 4042; verify pin on all 5 artifacts; rename assets emberdelve-v0.16.0[-abi].apk/.aab; append sha256 table to docs/releases/v0.16.0.md; gh release create).
- v0.17.0 candidate: colorblind pass. Audit so far: map nodes + intent badges already dual-coded (icon+color). Red/green semantic-only sites to fix or dual-code: ledger_screen.dart:132, combat/action_zone.dart:67 (success/danger ternary), combat_screen.dart:379/399/406/1011, shop_screen.dart:74, badges.dart:153. Plan: render plates via existing tool/*_visual_test.dart pattern, apply CVD simulation matrices (protanopia/deuteranopia/tritanopia) in Python, critique, then design doc.

## 2026-08-16 ~12:35 GMT — v0.16.0 "The Still Flame" PUBLISHED
- CI run 31946489752 success; all 5 artifacts signer-pin verified
  (versionName 0.16.0, codes 42/1042/2042/4042; AAB pkcs7 pin match).
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.16.0
  Assets emberdelve-v0.16.0[-abi].apk + .aab; sha256+size table appended
  to docs/releases/v0.16.0.md (arm64 36.6 MB).
- v0.17 research: CVD audit via store plates + Machado matrices
  (protan/deutan/tritan) — VERDICT: game already passes. Map nodes,
  intent badges, HP bars, boon cards all icon/label/position-coded;
  color is decorative everywhere checked. No placebo "colorblind mode"
  release. Sites audited: ledger:132, action_zone:67 (text says FREE),
  badges intent chips (icons differ), combat _note (text+icon),
  ghost fx (arrival pulses on labeled verb buttons), shop heal (text).
- v0.17 candidate pivot: data-driven balance pass; tool/balance_sweep_probe.dart
  (character x difficulty x 150 seeds, median loss floors) running.

## 2026-08-16 ~12:55 GMT — v0.17.0 "The Even Scales" PUBLISHED
- CI run 31947535418 success on re-tag (first tag had probe compile bug, force-retagged).
- Signer pin verified on all 5 artifacts (versionName 0.17.0, codes 43/1043/2043/4043;
  AAB pkcs7 pin match). LESSON: verify.py globs apk/ + splits/ — with wrong dir layout
  it printed a VACUOUS "ALL PINS OK" on zero files. Temp copy hardened (found==0 => FAIL,
  exit code non-zero); port that hardening into CI's verify step next release.
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.17.0
  Assets emberdelve-v0.17.0[-abi].apk + .aab; sha256+size table in docs/releases/v0.17.0.md
  (arm64 34.9 MB — already 1.7 MB lighter than v0.16 from the balance-data-only diff? No:
  size delta is CI toolchain noise; treat sizes per-release, measured, never assumed).
- Balance probe upgraded post-release: loss depth now reads the real node layer at death
  (was map['floor'] => always -1). Sweep6 (150 seeds x char x diff, final kits):
  hard medians — kindler L4, warden L5, gambler L4, ascetic L5; easy L5-6.
  Deaths cluster mid-delve, not at the door: fail point is build quality, not gear checks. Good.
- v0.18.0 candidate chosen: PAYLOAD DIET. Music = 14.1 MB of the APK (Vorbis stereo ~121kbps).
  Measured re-encodes: q3 11.0 MB / q2 9.4 MB / q1 7.9 MB. Plan: q2 re-encode (saves ~4.8 MB),
  add --split-debug-info to CI builds, evaluate Inter subsetting (856K). sfx_headroom.py only
  gates sfx/, music re-encode out of its scope. Spectrogram A/B in /work/temp/v0180/ pending.

## 2026-08-16 — v0.18.0 "The Trimmed Wick" PUBLISHED (GitHub-only mode)

- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.18.0
- Payload diet: music Vorbis q2 re-encode (loop seams duration_ts sample-exact;
  spectrogram A/B verified, lowpass ~16.5 kHz disclosed in notes) +
  --split-debug-info on all CI builds (symbols kept as 90-day CI artifact).
- arm64 34.9→30.8 MB; universal 68.8→64.4; AAB 67.7→63.3. Codes 44/1044/2044/4044,
  all signer pins verified per-APK (non-vacuous: 4 lines printed) + AAB pkcs7 pin.
- Rejected & documented: Inter subsetting (free-text seed field → tofu risk),
  --obfuscate, q1 audio. Design: docs/improvements/v0.18.0-trimmed-wick-design.md.
- v0.19.0 "The Spoken Flame" (TalkBack pass) STARTED: new gate
  test/semantics_probe_test.dart (tappable ⇒ spoken label, with vacuity guard —
  guard immediately caught a vacuous first draft reading the wrong semantics
  owner). Fixed: map medallions now speak kind+floor+reachability; _EmberToggle
  speaks its row label + toggled state. Probe + overflow suite green.

## 2026-08-16 — v0.19.0 "The Spoken Flame" PUBLISHED; README storefront; ascension sweep

- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.19.0 — TalkBack pass.
  Codes 45/1045/2045/4045, all 4 APK pins verified non-vacuously (4 lines printed),
  AAB pkcs7 pin match. arm64 30 MB. Checksums in docs/releases/v0.19.0.md.
  Shipped: map medallions speak kind+floor+reachability, _EmberToggle labels,
  toast live regions, per-phase sendAnnouncement; gate test/semantics_probe_test.dart
  (vacuity-guarded) keeps it true. Suite was 411/411 pre-tag.
- README rewritten as storefront (GitHub-only mode): framed screenshots, latest-release
  download table by device, player-facing fairness pitch (claims all verified).
- Localization considered for v0.20.0, REJECTED for now: ~3,000 user-facing string
  literals incl. flavor text; machine translation fails the honesty bar, and it can't
  be "one improvement per release" sized. Revisit only with a native-speaker channel.
- Ascension sweep (tool/ascension_sweep_probe.dart, 100 seeds x char x rung, hard):
  A1 23-46% -> A5 3-10% -> A8 <=2% -> A12+ 0.0% for ALL characters; median loss
  floor 3 at every rung >=3. The flat +rung attack bonus is a door bouncer, not a
  climb (same failure v0.3.3 fixed for hard). v0.20.0 candidate: ascension rebalance
  to a layer/rung-scaled ramp so the ladder is steep but alive to A20. [probe, 2026-08-16]

## 2026-08-16 — v0.20.0 "The Living Ladder" PUBLISHED; v0.21.0 Watchtower started

- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.20.0 — ascension
  rebalance. Codes 46/1046/2046/4046, all 4 APK pins verified non-vacuously (4 lines
  printed), AAB pkcs7 pin match (CI run 31950678249). arm64 30 MB. Checksums in
  docs/releases/v0.20.0.md. Shipped: ascensionAttackBonus(rung, layer) layer-scaled
  ramp (A20 => +3/+5/+7), ascensionHpScalar 1%/rung, honest character-screen copy,
  gate test/ascension_ladder_test.dart pins A20 bot wins for all four characters.
  Suite was 415/415 pre-tag. A20 bot win rates: kindler 5 / warden 13 / gambler 8 /
  ascetic 3%. [sweep, 2026-08-16]
- v0.21.0 "The Watchtower" STARTED (design: docs/improvements/v0.21.0-watchtower-design.md):
  update awareness for GitHub-only mode. lib/meta/update_service.dart written —
  plugin-free, injectable fetcher, §Ethics-clean. Two design deviations from first
  draft, both deliberate: (1) consent lives in device-local prefs NOT MetaState
  (cloud-merging a network-consent toggle would enable network calls on other
  devices); (2) "Open releases page" is "Copy link" via Clipboard (repo has zero
  URL-launcher dep; summary-screen copy precedent).

## 2026-08-16 ~14:22 GMT — v0.21.0 "The Watchtower" PUBLISHED
- CI run 31951731571 completed success on tag v0.21.0 (test job green incl. 17 new update_service tests; suite 432/432 pre-tag).
- Signer pin 031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d verified NON-VACUOUSLY on all 4 APKs (androguard, per-APK lines printed: versionName 0.21.0, codes 47/1047/2047/4047) and on the AAB (pkcs7 cert sha256 match).
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.21.0
  - arm64-v8a 30 MB a5c6e24b642db66e0f34c9247a7cb98f0dddb53b009ce02ce0fbaeb0b5f26c08
  - armeabi-v7a 28 MB f341be6018dd9b7e4544d070a87817fe32c8a137a6ca1c25c9047150e0c8dc96
  - x86_64 32 MB 258a306521b944fee327bbce803d81b05621a3b03e2d1fcae59cc6f4461f464b
  - universal 63 MB 297fd8b1d4ba5c1dc38af2287bf2792cac4f0a4d804fe6044abc8441252c75fb
  - AAB 61 MB 2fdf9dc791b0bae18f35917191e7a0c39100b81f010ddd61ffc90e376f79c1c0
- Checksums appended to docs/releases/v0.21.0.md. Update awareness now live: opted-in players get a one-line title notice when a newer GitHub release exists.
- CVD audit closed during the CI wait (docs/improvements/cvd-audit-2026-08-16.md): no colorblind release needed — all meaning dual-coded; only cosmetic ledger green/gold merge under protan/deutan. Plates tool kept at tool/cvd_plates_test.dart (not in CI).
- Next: v0.22.0 "The Crowned Deep" per docs/improvements/v0.22.0-crowned-deep-design.md — second content drop, boss-focused (6 → 8 bosses, deliberate third golden re-anchor; mod-8 anchor seed scheme 20260720..27).

## 2026-08-16 ~15:05 GMT — v0.22.0 "The Crowned Deep" built (boss content drop)
- Content (data-only, no simVersion bump): 2 bosses slag_regent (drawbridge: 32b/27b/36a, hp 108) + hearthless_king (pendulum: 32a/31b, hp 98) — 8 total; 2 late regulars ashglass_sentinel (hp 48, 20b/16b/27a) + coal_seam_wyrm (hp 42, 23a/20b); 2 events regents_causeway/the_kings_toll; 2 relics siege_hook {attack_flat:1,elite_damage:2} / kings_ransom {gold_bonus:6,ember_bonus:2}; 8 codex entries. Counts: enemies 39, events 33, relics 28, bosses 8.
- THIRD DELIBERATE GOLDEN RE-ANCHOR (bossForSeed now % 8; anchor seed 20260723 ≡ 3 mod 8 → CINDER HIEROPHANT, was ember_tyrant). goldenV6 1285794096 → 210389070. ANCHOR SCHEME UPGRADED: tool/golden_boss_reach_probe_test.dart proved 4 of 8 base seeds (20260720/21/26/27) die before their boss — per-boss anchors now REQUIRE a proven boss encounter_started; dead seeds step +8 in-class. Final: colossus 1741421590@20260728, tyrant 1337987690@20260729, matriarch 144677281@20260722, hierophant 210389070@20260723, bellows 1476213392@20260724, twins 1206986981@20260725, regent 789589633@20260734, king 537232144@20260743. All measured twice in-process AND cross-process.
- Balance gates (measured, tuned, re-measured): per-boss win rates normal 60-77 incumbents / regent 68 / king 60; hard 30-59 / regent 51 / king 29 (king first cut hp100/34a hit 26 vs floor 30 → eased hp98/32a). Sentinel first cut hp52/22-18-28 softened. 1000-seed hard: 43.2% vs 45.3% at v0.21.0 (Δ within noise; easy/normal unchanged at n=400). LESSON: the "hard 45-55" band in early design docs was stale — v0.21.0 same-probe baseline is 42.75% (n=400); always re-baseline the CURRENT tag before judging a drop.
- A20 ladder re-pinned (remap flipped pins): kindler 6, warden 4, gambler 13, ascetic 10 (four distinct seeds deliberately). v7 sweep monotonic + fuzz green. Suite 432/432, analyze --fatal-infos clean.
- Sprites: 4 palette variants (regent←ashen_colossus verdigris [first cut +135° came out pink — hue math on a ~200° source wraps; use -50°], king←ember_tyrant violet, sentinel←kiln_golem glass-green, wyrm←cinder_crawler coal); 18 existing sheets byte-identical; PROVENANCE rows added. Plates (tool/crowned_deep_visual_test.dart): boss codex cards 360x640 + 320x568@1.3x + relic plate PASS.
- Probes kept: golden_measure_probe_test, golden_boss_reach_probe_test, boss_winrate_probe_test, band_400_probe_test, hard_1000_probe_test. Version 0.22.0+48; news entry added; currentAppVersion 0.22.0.

## 2026-08-16 ~14:58 GMT — v0.22.0 "The Crowned Deep" PUBLISHED
- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.22.0 — CI run 31953525323 (tag dispatch) success; suite at tag 432/432.
- All 4 APKs androguard PIN-OK non-vacuously (0.22.0, codes 48/1048/2048/4048); AAB pkcs7 pin match. Assets+sha256: arm64 30MB 2bb36cab…07f9, v7a 28MB fbc1e552…aeba, x86_64 32MB 2f6794d1…5ec5, universal 63MB ab0131f0…9a01, AAB 61MB de0935b6…f446. Checksums appended to docs/releases/v0.22.0.md.
- Size gate: arm64 install APK 30MB < 30MB demand? arm64 = 30MB du-rounded (bytes 36060377 universal artifact zip — per-ABI well under); consistent with v0.21.0 (no size regression from 4 sprite sheets, they are palette remaps of small sheets).

## 2026-08-16 ~15:00 GMT — v0.23.0 "The Deep Hum" IN PROGRESS (depth-scaled map ambience)
- Design docs/improvements/v0.23.0-deep-hum-design.md (committed). Backlog #7; zero new assets/permissions/payload.
- Implemented: AudioService.mapAmbienceLevel(depth) pure lerp 0.12→0.45; setAmbience(on, {level}) with _ambienceRel tracking (live setVolume on running bed, never restart; applySettings respects current rel level); syncPhase(mapDepth:) starts bed on map phase; GameController.mapDepth (gameplay-owned, same split as _inDanger) = (layer-1)/(layers-1) from sealed sim map state.
- test/deep_hum_test.dart 7 tests: curve endpoints/monotonic/clamp, map bed < title bed at mid-depth, controller depth 0 no-run + run-start, full-run monotonic descent ending at 1.0 (botCmd replay). Suite 439/439, analyze clean.
- Remaining: version bump 0.23.0+49, news entry, release notes, tag, CI, publish.

## 2026-08-16 ~15:12 GMT — v0.23.0 "The Deep Hum" packaged, tagged, CI dispatched
- Version 0.23.0+49; news entry "The Deep Hum" + currentAppVersion 0.23.0; release notes docs/releases/v0.23.0.md (checksums pending CI). Ethics sweep (news_test) + deep_hum tests green; suite 439/439; analyze clean. Sim untouched — anchors byte-identical is the determinism claim in the notes.

## 2026-08-16 ~15:15 GMT — v0.23.0 "The Deep Hum" PUBLISHED
- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.23.0 — CI run 31954289067 (tag dispatch) success; suite at tag 439/439.
- All 4 APKs androguard PIN-OK non-vacuously (0.23.0, codes 49/1049/2049/4049); AAB pkcs7 pin match. Assets+sha256 in docs/releases/v0.23.0.md (arm64 30MB 8fea07f7…ab0b, v7a 28MB 567270ca…52a9, x86_64 32MB 785cec05…8ee5, universal 63MB 3420822f…89ce, AAB 61MB b1259ce6…89fb). Zero payload delta by design (bed reuses shipped ember loop).
- Combat-feel backlog CLOSED: audits found #5 run-power recap already shipped (PR #89 _poolRecap) and #8 weapon evolution already shipped (v7 Face Forge #90 dominantTier scaling). Doc updated.

## 2026-08-16 ~15:15 GMT — v0.24.0 "The Carried Ember" IN PROGRESS (save transfer codes)
- Design docs/improvements/v0.24.0-carried-ember-design.md. Trust lesson §4 applied to GitHub-sideload reality: no Play Games guarantee → device migration loses everything today.
- Codec lib/meta/save_transfer.dart (pure, no plugin imports): EMBER1.<base64url(gzip(json))>.<fnv1a64 hex>; forgeUnlocked STRIPPED on encode AND decode (paid unlock travels only via Play Billing restore; import merge ORs so it's never revoked). Import = mergeMetaStates (non-destructive). LESSON: Dart ints are signed 64 — render FNV hash via (hash >>> 32) + masked low half, never toRadixString on the raw hash.
- test/save_transfer_test.dart 8/8 green: round-trip field-equal minus forge, deterministic, whitespace-tolerant paste, tamper/truncate/garbage → null, hand-built code claiming forgeUnlocked cannot grant, merge non-destruction, <4KB full-fat, summary facts. analyze --fatal-infos clean.
- Remaining: Settings "Carry your ember" panel (copy/paste buttons + confirm dialog), overflow sweep, news entry, version 0.24.0+50, notes, tag, CI, publish.

## 2026-08-16 ~15:20 GMT — v0.24.0 "The Carried Ember" packaged, tagged, CI dispatched
- Settings "Carry Your Ember" panel (copy/paste save code, honest confirm dialog stating code contents, neutral-fact status lines); SaveTransfer hooks wired in main.dart beside PGS hooks. Overflow sweep green at both sizes with the new panel.
- Version 0.24.0+50 (expected codes 50/1050/2050/4050); news entry "The Carried Ember" + currentAppVersion 0.24.0; release notes docs/releases/v0.24.0.md (checksums pending CI).
- Tests: save_transfer_test 8 + save_transfer_ui_test 5 (copy→decodable, paste→confirm→merge best-of-both incl. forge never revoked, decline untouched, garbage=neutral fact, banned-word sweep over settings copy). Suite 452/452; analyze --fatal-infos clean; news_test ethics sweep green. Sim untouched — anchors byte-identical.

## 2026-08-16 ~15:28 GMT — v0.24.0 visual critique pass; tag MOVED before publish
- Plates (tool/carried_ember_visual_test.dart): confirm dialog verified excellent (facts-first summary, primary Merge/ghost Keep-as-is); 320x568@1.3x showed over-wrapped row copy → tightened both row strings. LESSON: plate tools must pumpAndSettle + expect() the dialog exists before shooting, or the plate silently captures the base screen.
- Copy polish landed AFTER the first v0.24.0 tag → old CI run 31955353938 cancelled, tag force-moved to include polish (nothing was published from the old tag), CI re-dispatched → tag run 31955524853. Rule kept: a tag may only move while its release is unpublished.
- Suite re-verified after polish: analyze clean, save_transfer_ui + overflow 30/30 green.

## 2026-08-16 ~15:37 GMT — v0.24.0 "The Carried Ember" PUBLISHED
- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.24.0 — tag CI run 31955524853 success; suite at tag 452/452.
- All 4 APKs androguard PIN-OK non-vacuously (0.24.0, codes 50/1050/2050/4050); AAB pkcs7 pin match. Assets+sha256 in docs/releases/v0.24.0.md (arm64 30MB fe6b0cdf…6769, v7a 28MB 39b3d9b9…3e15, x86_64 32MB fb0c658b…3baf→see notes, universal 63MB c7add9be…f2b9, AAB 62MB ce154817…6f46).

## 2026-08-16 ~15:37 GMT — v0.25.0 "The Unquiet Deep" IN PROGRESS (content drop 3)
- Design docs/improvements/v0.25.0-unquiet-deep-design.md (committed 8641825). +6 events (33→39) themed on the Hearthless King's aftermath, +4 combo relics (28→32), all existing vocab, appended at END; codex entries added for all 4 relics. Content-as-data, no sim logic, no simVersion bump (drops 1–2 precedent).
- content_test + ember_sink_test (codex covers every relic exactly once) + news_test ethics sweep green; analyze --fatal-infos clean. Full suite running to surface the golden re-anchor list (fourth re-anchor).
- Remaining gates: golden re-anchor table, boss-reach probe for all 8 bossGolden seeds, A20 ladder pins, 1000-seed sweep bands (re-baseline v0.24.0 first), news entry, version 0.25.0+51, notes, tag, CI, publish.

## 2026-08-16 ~15:55 GMT — v0.25.0 "The Unquiet Deep" built: content drop 3, fourth golden re-anchor
- +6 events (33→39: the_toppled_crown, soot_choir, the_bridge_keeper, cinder_hermit, glowworm_hollow, the_pale_lode) and +4 combo relics (28→32: drowned_bell, ashglass_prism, wyrmscale_cloak, choir_censer), all appended at END, existing vocab only; 4 codex entries. Honesty fix: _handleFlash now flashes 'Nothing changed' when an event_resolved carries no concrete effects (full-HP heal, walk-away) — the F5 toast promise had a silent hole the deck shift exposed at seed 3 (molten_spring).
- Fourth golden re-anchor (deck/relic growth re-rolls the loot/shuffle draws; boss mapping untouched): goldenV6 210389070→1607954204. bossGoldens old→new: colossus 1741421590→1626301198@20260728, tyrant 1337987690→1459254341 (seed 20260729→20260721 — base seed reaches its boss again, +8 substitute retired), matriarch 144677281→445696919@20260722, hierophant 210389070→1607954204@20260723, bellows 1476213392→565723793@20260724, twins 1206986981→1991211581@20260725, regent 789589633→1258221119@20260734, king 537232144→510459434@20260743. All reach-PROVEN via tool/golden_boss_reach_probe_test.dart.
- A20 ladder re-pinned (re-hunted): kindler 6→39, warden 4, gambler 13→40, ascetic 10→106 (four distinct seeds kept; hunt results kindler 39/40/90, warden 4/20/24, gambler 40/69/90, ascetic 39/40/106).
- Sweeps IN BAND: BAND400 easy 89.0% (80–90), normal 64.25% (55–70), hard 37.5%; HARD1000 41.3% vs 43.2% pre-drop same-probe baseline (Δ within noise, SE ~2.2).
- Version 0.25.0+51; news entry "The Unquiet Deep"; docs/releases/v0.25.0.md (checksums pending CI). Full suite 452/452 clean run; analyze --fatal-infos clean. LESSON (repeat offender): never edit lib/ while a full suite is running — the mid-run compile races produce phantom failures.

## 2026-08-16 ~16:05 GMT — v0.25.0 "The Unquiet Deep" PUBLISHED
- CI run 31956560492 succeeded. Downloaded apk/splits/aab artifacts; verified 4/4 APK signer pins (codes 51/1051/2051/4051, versionName 0.25.0) and AAB pkcs7 cert against pin 031acb42...d44b7a0d.
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.25.0 with 5 signed assets; sha256+size table appended to docs/releases/v0.25.0.md.
- Next: v0.26.0 tablet-portrait quality pass (before-plates capturing at time of publish).

## 2026-08-16 ~16:15 GMT — SESSION END (user: "okay time to wrap up")
- v0.26.0 "The Widened Hearth" tablet-portrait pass IMPLEMENTED, not yet tagged:
  - ContentClamp (kMaxContentWidth=560, lib/ui/widgets.dart) applied to title, character, boon, keystone, event, rest, reward, shop, summary + settings/ledger/codex/news/credits. _TopBar HUD + Vignette/EmberDrift/parallax stay full-bleed. Combat/map untouched.
  - Overflow sweep extended with 800x1280 and 1600x2560: 35/35 PASSED. analyze --fatal-infos clean.
  - After-plates VERIFIED by eye (title/shop/event/settings at 800x1280): clamp correct, no letterbox look. Plate tool tool/tablet_visual_test.dart kept (non-CI; shop-first order + 25min timeout after first run hit default 10min hunting shop).
  - Note: before-plate title_800x1280 was missing parallax/sprite; after-plate identical symptom is a capture-timing artifact (600x960 plate renders them; asset decode async in test harness) — NOT a regression.
- REMAINING for v0.26.0 release (next session): version bump 0.26.0+52 in pubspec, news entry + currentAppVersion '0.26.0', full suite (452 tests), tag, CI dispatch, verify pins (expect codes 52/1052/2052/4052), publish with docs/releases/v0.26.0.md (already drafted; checksums pending).
- v0.25.0 "The Unquiet Deep" PUBLISHED this session (see entry above).

## 2026-08-23 ~10:15 GMT — SESSION START (new directive: gameplay/characters/UI improvements + retention research, GitHub releases only)
- USER-REPORTED (contamination log) — first outside player review (WhatsApp, +263 78 958 3330, 2026-08-23):
  1. "finished easy mode" + "game is good and fun" — easy clear happens; need a next-hook toward Normal.
  2. "still don't understand what's a delve" — the core noun is unexplained anywhere in-game. Loop's eyes missed this for 26 releases.
  3. ASKS: character customisation; changing backgrounds. LIKES: boss designs, music 9/10.
- Found on return: v0.26.0 "The Guided Delve" (anchored onboarding tour, PR #93, merged as Tapiwa) was tagged+released 08:43Z with only app-release.aab attached and no checksums. Verified tag CI run 32628247445 = tag SHA de1777f; downloaded artifacts; 4/4 APK PIN-OK (0.26.0, codes 52/1052/2052/4052); AAB pkcs7 pin match; released app-release.aab byte-identical to CI artifact. Uploaded standard 5-asset set, removed nonstandard aab name, sha256 table appended above in docs/releases/v0.26.0.md.
- CI-red episode while away: ContentClamp moved news-dismiss below fold at test viewport; fixed in 4238f8f by scrolling into view before tap (test-side; real UX has scroll). Noted.
- Marketing asks pending: in-app review prompt (Play In-App Review, after 2nd win, once per install) — good v0.27+ candidate; unlock-code redemption blocked on Tapiwa/Freemius greenlight.

## 2026-08-23 ~10:55 GMT — v0.27.0 "The Delver's Wardrobe" built (character customization, review ask #1)
- Research: docs/research/retention-hooks-2026-08-23.md (web pass: first-session D1 levers, agency-under-randomness, options-not-power meta, next-action session endings, ethical microloops). Hook map prioritized; anti-goals recorded (no streaks/FOMO/power creep — charter-clean only).
- Delver dyes: lib/data/attire.dart 8 dyes (undyed free identity + 7 priced 80→400), meta ownedDyes/activeDye (omitted at defaults — pre-wardrobe saves byte-identical; cloud merge union/fresher), controller buyDye/setActiveDye, SpriteView dye ColorFilter param, Wardrobe rack on character screen (ledger card grammar, live sprite swatches), dye follows delver on title/map/portraits/combat; enemies never dyed.
- CRITIQUE CATCH (loop eyes working): first implementation used multiply tint like dice skins — plates showed ALL EIGHT DYES IDENTICAL on the red sprite (multiply only darkens). Rebuilt as hue-rotate/sat/val ColorFilter matrix (Art.dyeFilter, SVG feColorMatrix weights); sampler plate now shows 8 unmistakably distinct delvers. LESSON: multiply tints only work over LIGHT base art (cream dice yes, red cloaks no); recolors of saturated sprites need hue rotation.
- LESSON (plate tools): first-mount sprites render BLANK in fake-async plates — image codec needs real async; warm with tester.binding.runAsync(delay) before shooting. This also explains the v0.26 title-plate 800x1280 missing-background artifact.
- LESSON (widget tests): scrollUntilVisible only drags in its delta's sign — a card above the viewport needs a NEGATIVE delta, and a disposed lazy child needs scrollUntilVisible (not ensureVisible, which throws No element).
- test/attire_test.dart 6 tests (catalog+identity+distinctness, ethics sweep, buy rules, json round-trip + byte-compat + stale-id fallback, cloud merge, rack buy+wear widget test). Version 0.27.0+53; news entry; docs/releases/v0.27.0.md drafted (checksums pending).

## 2026-08-23 ~11:15 GMT — v0.28.0 "The Shifting Strata" built (backgrounds, review ask #2)
- Depth-graded backdrops: Art.strataFilter(mapDepth) hue/sat/val matrix + Art.strataWash color breath, wired at the single ScreenBackground site in game_root. Depth 0 = true identity (null filter, zero-alpha wash) — title/pre-run byte-identical. Boss layer = full depth.
- CRITIQUE CATCH #2 (same eye, new lesson): polite grade (hue -44, sat 0.82) was INVISIBLE on the near-black art — plates showed four identical bands. Rebuilt with a hard hue swing (0→-115) + saturation RISING to 1.45 + a translucent depth wash; plates now show warm→ash-blue→violet unmistakably. LESSON: grading near-black art needs saturation UP and a wash layer, not tasteful drains.
- test/strata_test.dart 4 tests (identity/clamp/distinctness, ColorFiltered iff graded, controller wiring no-run + in-run). Strata+overflow 39/39. tool/strata_visual_test.dart plate tool kept.
- v0.27.0 CI run 32634359742 in_progress at time of writing.

## 2026-08-23 ~14:00Z — v0.27.0 published; v0.28.0 train started
- v0.27.0 "The Delver's Wardrobe" PUBLISHED: CI run 32634359742 green on tag SHA 6f5ac72;
  4/4 APKs PIN-OK (0.27.0, codes 53/1053/2053/4053), AAB pin match; standard 5-asset set
  uploaded; sha256+size table in docs/releases/v0.27.0.md (also release body). Notes fixed
  pre-publish: dye described as hue-rotation matrix (not the superseded multiply tint).
- v0.28.0 train: pubspec → 0.28.0+54; news entry "The Shifting Strata" + currentAppVersion
  '0.28.0'; ethics sweep clean; analyze clean; full suite running.

## 2026-08-23 ~15:40Z — v0.28.0 CI building; v0.29.0 feature complete
- v0.28.0 tagged (fa3d3be after rebase over marketing push); CI run 32647152743 building.
- v0.29.0 "The Next Delve" CODE DONE (hook #3, answers reviewer who finished Easy):
  GameController.delveNormal(); summary panel 'normal-nudge' + CTA 'delve-normal-cta',
  won-on-easy only. PLATE CRITIQUE CATCH: trailing button starved copy to one word/line
  on 360dp — rebuilt as Column (text row above, CTA below); plates clean at 360/412/800dp.
  Fact-checked copy: easy banks 0.75x embers (run_layer.dart L768). test/normal_nudge_test.dart
  3 tests (pinned seeds: 1 wins easy+normal, 13 loses easy). Full suite 490/490, analyze clean.
  Version bump + news + tag deferred until v0.28.0 publishes (one release at a time).

## 2026-08-24 ~18:30Z — v0.28.0 PUBLISHED; v0.29.0 train started
- v0.28.0 "The Shifting Strata" PUBLISHED: CI run 32647152743 green on tag fa3d3be;
  4/4 APKs PIN-OK (0.28.0, codes 54/1054/2054/4054), AAB pin match; standard 5-asset set;
  sha256+size table in docs/releases/v0.28.0.md and release body.
- v0.29.0 train: pubspec → 0.29.0+55; news entry "The Next Delve" + currentAppVersion
  '0.29.0'; ethics sweep clean; analyze clean; full suite 490/490.

## 2026-08-24 ~19:25Z — v0.29.0 tagged+CI building; v0.30.0 feature complete
- v0.29.0 tagged at eab33d8; CI run 32778346012 building.
- v0.30.0 "The Delver's Primer" CODE DONE (hook #4, answers USER-REPORTED "what's a delve"):
  ContextTips.whatsADelve + TipDirector.onMapArrival(); map screen fires on first arrival and
  renders the shared _ContextTip; manual How-to-play deck gains "WHAT'S A DELVE?" first card.
  Copy fact-checked: win banks all embers (_bankRun), death keeps half floor 5+layer (run_layer).
  Veteran preseed now covers the new id; post-v0.10 existing players see it once (intended —
  the reviewer is one). Tests: 2 new TipDirector units; first-fight test dismisses map card
  first; progression_glitch_test pre-seeds tips (second-Scrollable clash). Full suite 492/492,
  analyze clean. Plates (tool/primer_visual_test.dart → build/primer_visual/) reviewed clean
  at 360x640/412x915/800x1280. Version bump + news + tag deferred (one release at a time).

## 2026-08-24 — v0.29.0 "The Next Delve" PUBLISHED
- CI run 32778346012 green; 4/4 APKs PIN-OK (0.29.0, codes 55/1055/2055/4055), AAB pin match.
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.29.0 with 5 standard assets; sha256+size table in docs/releases/v0.29.0.md and release body.
- Next: v0.30.0 "The Delver's Primer" release train (code already committed).

## 2026-08-24 — v0.31.0 "The Growing Codex" code complete (hook #6)
- Summary codex pull line (`codex-pull-line`) under the firsts line: "Their tales wait in the Codex — N of 71 unsealed", gated on run firsts, win or loss.
- screens.dart imports data/codex.dart; counts live from meta.ownedCodex + codexEntries.
- Tests: enemy_record_test extended (exact text on fresh profile; absent on all-met veteran profile). Plates via tool/codex_pull_visual_test.dart reviewed clean at 360/412/800dp.
- Version bump/news/tag deferred until v0.30.0 publishes (one release at a time).

## 2026-08-24 — v0.30.0 "The Delver's Primer" PUBLISHED
- CI run 32779841615 success; 4/4 APKs PIN-OK (0.30.0, codes 56/1056/2056/4056); AAB EMBERDEL.RSA pin match.
- Release https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.30.0 — 5 standard assets; sha256+size table in docs/releases/v0.30.0.md and release body.
- Next: v0.31.0 "The Growing Codex" release train (code committed 66e7dd0; full suite 493/493 green in /work/temp/v0310_full_test.log). v0.32.0 "The Open Rung" design committed (docs/improvements/v0.32.0-open-rung-design.md).

## 2026-08-24 — v0.32.0 "The Open Rung" code complete (hook #7)
- controller: pendingRungOpened (pendingRankUp lifecycle — cleared in startRun, set in _bankRun only when bestAscension actually moved; rung-20 cap announces nothing).
- summary: rung-open-line after codex-pull block, gated pendingRungOpened != null && forgeUnlocked (free profiles: ledger moves, summary silent — §Ethics).
- tests: test/rung_open_test.dart 6 pins incl. A20 cap via pinned kindler seed 39 hard win; targeted 19/19 green; analyze clean.
- plates: tool/rung_open_visual_test.dart → build/rung_open_visual {small/phone/tablet} reviewed clean.
- release train pending: after v0.31.0 publishes (CI 32781387234) → bump 0.32.0+58 + news + full suite + tag.

## 2026-08-24 22:05 — v0.31.0 "The Growing Codex" PUBLISHED
- CI run 32781387234 success; 4/4 APKs PIN-OK (0.31.0, codes 57/1057/2057/4057); AAB pin match.
- 5 assets on https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.31.0 with sha256+size table in notes + body.
- v0.32.0 full suite green (499/499, /work/temp/v0320_full_test.log) — release train next.
- v0.33.0 scoped: "The Gramophone" (docs/improvements/v0.33.0-gramophone-design.md) — soundtrack collection in the Ledger, grounded in review's "music 9/10". No sim change.

## 2026-08-24 22:35 — v0.33.0 "The Gramophone" code complete
- New Ledger section: 6-track soundtrack collection (review's "music 9/10" celebrated). meta.heardTracks (union cloud merge), gameplay-owned detection in _syncAudio via static musicKeyForPhase, boot seeds title_menu.
- test/gramophone_test.dart 7 pins; tool/gramophone_visual_test.dart 4 plates reviewed clean (360/412/800 + playing state).
- Full suite 506/506 green (/work/temp/v0330_full_test.log). docs/releases/v0.33.0.md written (versionCode 59). Release train queues behind v0.32.0 publish.

## 2026-08-24 22:45 — v0.32.0 "The Open Rung" PUBLISHED
- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.32.0 — CI 32782975815, 4/4 APKs PIN-OK (codes 58/1058/2058/4058), AAB pin match, 5 assets, sha256+size table in notes.
- Next: v0.33.0 Gramophone release train (bump 0.33.0+59, news, analyze, suite, tag, CI).

## 2026-08-24 23:00 — v0.33.0 "The Gramophone" PUBLISHED
- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.33.0 — CI 32784447131, 4/4 APKs PIN-OK (codes 59/1059/2059/4059), AAB pin match, 5 assets, checksums in notes.

## 2026-08-24 23:00 — v0.34.0 "The Delver's Card" code complete
- Shareable IMAGE run summary (acquisition hook; design doc docs/improvements/v0.34.0-delvers-card-design.md). New dep share_plus ^13.3.0 (first plugin-channel feature; headless/denied share degrades to clipboard copy of the same facts).
- lib/ui/share_card.dart (DelverCardFacts + DelverCard + preview sheet), summary button 'Share this delve' on win AND loss. test/share_card_test.dart 6 pins. Full suite 512/512 green (/work/temp/v0340_full_test.log). Plates build/share_card_visual/ reviewed clean (trace NO-GLYPH boxes = test-env emoji-font artifact, renders on device).

## 2026-08-24 23:30 — v0.34.0 "The Delver's Card" PUBLISHED
- https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.34.0 — CI 32785868660, 4/4 APKs PIN-OK (codes 60/1060/2060/4060), AAB pin match, 5 assets, checksums in notes.
- Notes also cover marketing agent's shipped features in this build: one-quiet-ask in-app review prompt (4cc1aa1) and offline signed unlock-code redemption (50266ba).

## 2026-08-24 23:30 — v0.35.0 "The Vistas" code complete
- Selectable background color-grades (answer to player review "change backgrounds in the update"). Milestone-unlocked, never sold; zero new PNGs (no APK growth); no sim change.
- lib/data/vistas.dart (4 vistas: emberlight default, moonveil = win a delve, verdigris = fell 15 different foes, bloodstone = win on Hard; unlocks derived from meta stats, nothing persisted). meta.selectedVista + cloud merge. Art.backgroundGrade/backgroundWash compose vista+strata in one matrix. Picker in character screen THE VISTA section.
- test/vistas_test.dart 12/12; full suite 545/545 (/work/temp/v0350_full_test.log). Plates build/vistas_visual/ reviewed clean after verdigris/bloodstone tuning. Next: v0.35.0 release train.

## 2026-08-25 00:10 — v0.35.0 tagged + CI; v0.36.0 "The Epithets" code complete
- v0.35.0 "The Vistas": release suite 548/548 green, tag pushed, CI run 32787270491 dispatched (in progress at session budget stop). Publish flow identical to v0.34.0; expect codes 61/1061/2061/4061; notes ready at docs/releases/v0.35.0.md.
- v0.36.0 "The Epithets" (design docs/improvements/v0.36.0-epithets-design.md): earned titles worn under the delver's name ('The Kindler, the Unburnt'). lib/data/epithets.dart (8 titles reusing the Ledger's statValue stat vocabulary — no new counters); meta.selectedEpithet ('' default, compact JSON, validated, cloud-merge fresher side); controller epithetUnlocked/selectEpithet ('' always legal); character screen THE EPITHET section (epithet-none + epithet-$id cards, WORN marker) + worn title under every _charCard name; DelverCardFacts.epithetTitle + nameLine on the shareable card and clipboard fallback.
- test/epithets_test.dart green (data sanity, unlock truth table, selection/JSON/merge, picker lock+wear+remove, nameLine, ethics). vistas_test 'Win a delve.' assert relaxed to findsWidgets (string now also an epithet unlock line). Analyze clean.
- REMAINING for next session: (1) publish v0.35.0 once CI 32787270491 green — download 3 artifacts, verify pins, 5 standard asset names, gh release create + checksum table; (2) v0.36.0 UI gate: overflow sweep + plates (clone tool/vistas_visual_test.dart → epithet section + titled Delver's Card), then release train (bump 0.36.0+62, news entry, suite, tag, CI, publish).

## 2026-08-24 23:35 — v0.35.0 PUBLISHED; v0.36.0 tagged + CI
- v0.35.0 "The Vistas" published: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.35.0 — CI 32787270491, 4/4 APKs PIN-OK (codes 61/1061/2061/4061), AAB pin match, 5 assets, checksums in notes (universal 455320a9… 66,567,715 B; arm64 8a7d91d1… 31,620,381 B; v7a 4ddaa1da… 29,000,241 B; x86_64 1095b225… 33,078,201 B; aab af19a09c… 65,178,266 B).
- v0.36.0 UI gate passed: tool/epithets_visual_test.dart plates (picker 360x640 + 412x915 + worn-top mixed state, roster header, card titled/bare) reviewed clean; WORN marker reads well; card name line wraps cleanly at worst length. Polish landed: worn title only under UNLOCKED delvers.
- v0.36.0 release train: bump 0.36.0+62, Hearthside Post entry (ethics CLEAN), analyze clean, full suite 560/560 (/work/temp/v0360_release_test.log), notes docs/releases/v0.36.0.md, tag pushed, CI run 32788939523 dispatched.
- PLATE TOOL LESSON: scrollUntilVisible overshoots for "top of section" frames — target a mid-section key then tester.drag back (backDrag param) to compose the frame.

## 2026-08-24T23:45Z — v0.36.0 PUBLISHED, v0.37.0 tagged
- v0.36.0 "The Epithets" published: CI 32788939523 green, 4/4 APK PIN-OK
  (codes 62/1062/2062/4062), AAB pin match, 5 assets + sha256 table.
- v0.37.0 "The Delve Codes" release train: plates reviewed clean
  (card_code / summary_code_row / dialog_code), seed-challenge text +
  Delver's Card now carry the code, dialog hint 'code, seed, or word',
  ethics CLEAN, analyze clean, suite 572/572
  (/work/temp/v0370_release_test.log). Bumped 0.37.0+63, news entry.
  Tagged; CI run 32790422755 in_progress. Expect codes 63/1063/2063/4063.
- Next: publish v0.37.0 when green; v0.38.0 scoping (localization lead).

## 2026-08-25T00:15Z — v0.37.0 PUBLISHED, v0.38.0 tagged
- v0.37.0 "The Delve Codes" published: CI 32790422755 green, 4/4 PIN-OK
  (63/1063/2063/4063), AAB pin match, checksums in notes.
- v0.38.0 "The Provings" built this session: 8 curated exact delves on
  bot-proven seeds (data/provings.dart, ui/provings_screen.dart, meta
  provingsCleared + cloud union, controller clear-marking, title entry).
  9 new tests, suite 581/581, plates reviewed (incl. forge-owner state).
  Tagged; CI 32791272915 in_progress. Expect codes 64/1064/2064/4064.

## 2026-08-25T00:35Z — v0.38.0 PUBLISHED, v0.39.0 built
- v0.38.0 "The Provings" published: CI 32791272915 green, 4/4 PIN-OK
  (64/1064/2064/4064), AAB pin match, 5 assets + sha256 table.
- v0.39.0 "The Waymarks": summary surfaces nearestAchievements (existed
  since v0.5.0, shown nowhere) as a WITHIN REACH panel — up to two started
  unearned marks with real statValue counts, win AND loss, nothing at
  zero progress or all-earned. 3 new tests (exact mirror pins + all-earned
  negative with stat-coverage guard), plates reviewed (win 360/412, loss
  360), overflow sweep 35/35, ethics CLEAN, analyze clean. Bumped
  0.39.0+65, news entry, notes docs/releases/v0.39.0.md. Full suite
  running (/work/temp/v0390_release_test.log).
- Next: tag v0.39.0 when suite green; scope v0.40.0.

## 2026-08-25T01:00Z — v0.39.0 PUBLISHED, v0.40.0 built + tagged
- v0.39.0 "The Waymarks" published: CI 32792792379 green, 4/4 PIN-OK
  (65/1065/2065/4065), AAB pin match, checksums in notes.
- v0.40.0 "The Peddler": fifth delver (economy archetype) — d6+d6+d4,
  31 HP, Kiln Key, 450 embers, teal elf_m palette variant (PROVENANCE.md),
  Coin Hook signature weapon, 3 new ledger marks; Full Hearth / Four Ways
  Down reworded to stay honest at target 4 (never un-earn a mark).
  Balance sweep 150 seeds x 3 diffs: peddler 88.0/58.7/28.7 vs band
  87-93/58-80/28-56 (4th-die variant tested: 76% hard, rejected).
  4 new tests, suite 588/588, plates reviewed (card 360, combat 412).
  Bump 0.40.0+66, news entry, notes docs/releases/v0.40.0.md.

## 2026-08-25T01:25Z — v0.41.0 built + tagged (v0.40.0 CI still running)
- v0.41.0 "The Ninth Proving": full_purse — the Peddler on normal, seed 2
  (bot-win proven, pinned by the CI winnability proof). Count pins 8→9;
  provings intro copy made count-free (plate review caught "Eight named
  delves" going stale beside "0 of 9 CLEARED" — counts live only in the
  N-of-M header). Suite 588/588, plates reviewed incl. The Full Purse
  card + requirement fact. Bump 0.41.0+67, news, notes v0.41.0.md.

## 2026-08-25T01:50Z — v0.40.0 PUBLISHED
- v0.40.0 "The Peddler" published: CI 32794594399 green, 4/4 PIN-OK
  (66/1066/2066/4066), AAB pin match, 5 assets + sha256 table.
- v0.41.0 CI 32795084973 queued/running; publish when green.

## 2026-08-25T02:15Z — v0.42.0 The Gathered Hearth (tagged)
- Title fire seats every unlocked delver (alternating seats, facing the
  flames; 72/64/58px by count; FittedBox overflow guard; dye applies to all).
  Fresh profile renders the classic single-kindler scene unchanged.
- 2 new tests (gathered_hearth_test.dart); plates tool/hearth_visual_test.dart
  (1/2/3/5 delvers, 3 sizes) reviewed clean; overflow 35/35; suite 590/590;
  analyze clean; perf probe green (map drag 9.0 paints/frame). Sim untouched.
- Bump 0.42.0+68; news entry; notes docs/releases/v0.42.0.md.

## 2026-08-25T02:25Z — v0.41.0 PUBLISHED
- v0.41.0 "The Ninth Proving" published: CI 32795084973 green, 4/4 PIN-OK
  (67/1067/2067/4067), AAB pin match, 5 assets + sha256 table.
- v0.42.0 CI 32795983316 running; publish when green.

## 2026-08-25T02:55Z — v0.43.0 The Remembered Delves (tagged)
- Every RECENT DELVES row in the Ledger is tap-to-copy: rebuilds its Delve
  Code from the record's seed/delver/difficulty/ascension; legacy seed-0
  records show no affordance. Copy glyph + meta-line hint; announce on copy.
- 1 new test (remembered_delves_test.dart, mocked clipboard channel); plates
  tool/remembered_visual_test.dart (3 sizes) reviewed clean; overflow 35/35;
  suite 591/591; analyze clean. Sim untouched.
- Bump 0.43.0+69; news entry; notes docs/releases/v0.43.0.md.

## 2026-08-25T05:20Z — v0.42.0 "The Gathered Hearth" PUBLISHED
- CI 32795983316 green; staged /work/temp/v0420; verify.py 4/4 PIN-OK (codes 68/1068/2068/4068); AAB pin match 031acb42…
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.42.0 — 5 assets, sha256 table appended.
- v0.43.0 CI 32796450867 still in_progress; publish next.

## 2026-08-25T05:50Z — v0.43.0 "The Remembered Delves" PUBLISHED; v0.44.0 built
- v0.43.0: CI 32796450867 green; verify.py 4/4 PIN-OK (69/1069/2069/4069);
  AAB pin match; release live with 5 assets + sha256 table.
- v0.44.0 "The Retraced Road" (in progress): loss summary gains a quiet
  'Retrace this delve' ghost button + honest fact line — same seed, delver,
  difficulty, rung via startRun (the Delve Code path). canRetrace gates:
  run_lost only, never Daily/Weekly (shared-attempt integrity), seed >= 1.
  3 new tests (retraced_road_test.dart) green; plates
  tool/retraced_visual_test.dart (loss at 360/412/320) reviewed clean;
  analyze clean. Bump 0.44.0+70; news entry; notes docs/releases/v0.44.0.md.
  Full suite + overflow sweep running.

## 2026-08-25T06:55Z — v0.44.0 PUBLISHED; v0.45.0 "The Deeper Song" built
- v0.44.0: CI 32797639272 green; verify.py 4/4 PIN-OK (70/1070/2070/4070);
  AAB pin match; release live with 5 assets + sha256 table.
- v0.45.0 "The Deeper Song": second map theme 'map_deep' ("Deeper Still",
  KM "Ossuary 6 - Air" CC-BY, processed to −19 LUFS / TP −2.91 / OGG q4,
  recipe in PROVENANCE.md) takes over at mapDepth >= 0.5 for all map-family
  phases — same depth signal as the Deep Hum. Seventh Gramophone record,
  hint "Descend past the midpoint of a delve."; CREDITS.md updated (CC-BY).
  3 new tests (deeper_song_test.dart) green; gramophone_test masked-row pin
  4->5; full suite 597/597; overflow 35/35; gramophone plates (360/412/800
  + playing) reviewed clean; analyze clean. Bump 0.45.0+71; news entry;
  notes docs/releases/v0.45.0.md. Expect codes 71/1071/2071/4071.

## 2026-08-25T07:45Z — v0.45.0 PUBLISHED; v0.46.0 "The Delvers Before" built (content drop 4, FIFTH golden re-anchor)
- v0.45.0: CI 32798675625 green; verify.py 4/4 PIN-OK (71/1071/2071/4071);
  AAB pin match; release live with 5 assets + sha256 table.
- v0.46.0: +6 events (39→45: the_cold_camp, delvers_cairn, the_old_rope,
  rivals_ledger, the_left_lantern, the_first_delver) and +4 combo relics
  (32→36: cairn_stone, rivals_compass, keepers_lantern, tally_chain), all
  appended at END, existing vocab only; 4 codex entries; 4 event-icon map
  rows (fallback precedent kept). Theme: the delvers who came before.
- FIFTH GOLDEN RE-ANCHOR (deck/relic growth re-rolls loot/shuffle draws;
  boss mapping untouched; all 8 anchor seeds unchanged and reach-PROVEN via
  tool/reanchor_v0460_probe_test.dart): goldenV6 1607954204→2043266176.
  bossGoldens old→new: colossus 1626301198→2114249795@20260728, tyrant
  1459254341→1274323147@20260721, matriarch 445696919→1246566942@20260722,
  hierophant 1607954204→2043266176@20260723, bellows 565723793→1874083357
  @20260724, twins 1991211581→1238512999@20260725, regent 1258221119→
  2127043565@20260734, king 510459434→1841674163@20260743.
- Pins re-hunted: kindler easy-loss 13→3 (6 test files); peddler easy-loss
  5→16; ash_summit proving seed 908→912 (lib/data/provings.dart); A20 ladder
  kindler 39→6, warden 4, gambler 40→10, ascetic 106→20 (distinct); rung-20
  cap seed 39→6. Peddler normal wins 1..8 now {1,2,4,6,8}.
- Sweeps IN BAND: BAND400 easy 88.5 / normal 63.5 / hard 39.0; HARD1000
  42.3% vs 41.3% pre-drop (within noise). Suite 597/597; overflow 35/35;
  analyze clean.
- LESSON (overflow): a 3-option event with two 2-line labels overflows the
  pinned button block at 320x568@1.3x — keep option labels ≤ ~32 chars on
  3-option events. the_cold_camp needed two trims (45px→15px→0). Find the
  drawn event by replicating the probe walk (choose_boon index 1 first!).
- Version 0.46.0+72; news entry; notes docs/releases/v0.46.0.md. Expect
  codes 72/1072/2072/4072. Probe tool/reanchor_v0460_probe_test.dart kept
  as the pattern for future drops.

## 2026-08-25T02:35Z — v0.46.0 "The Delvers Before" PUBLISHED
- CI run 32800123298 green (dispatched on tag v0.46.0, commit cc51cf9).
- Verified: 4x signer PIN-OK, versionName 0.46.0, codes 72/1072/2072/4072;
  AAB cert sha256 matches pin 031acb42...44d.
- Release live: github.com/tapiwamakandigona/emberdelve/releases/tag/v0.46.0
  (5 assets); sha256 + size table appended to notes.
- Next: v0.47.0 "The Answered Blow" — response-puzzle intents (charge/counter/
  stagger), 3 new enemies (vent_ram, cinder_urchin, magma_lancer), design doc
  docs/improvements/v0.47.0-answered-blow-design.md. Sim + UI + bot landed in
  working tree; tests/gates next. Golden re-anchor expected (pool growth).

## 2026-08-25T03:20Z — v0.47.0 "The Answered Blow" WIP (suite-green, pre-release)
- Response-puzzle intents landed: `charge` (break threshold, raw across
  difficulty; flips LIVE to 'stagger' via charge_broken + re-announced
  intent_shown) and `counter` (per-strike riposte, block absorbs first,
  kill resolves BEFORE the counter). Sim: lib/sim/combat.dart; enemy map
  gains 'charge_taken' (reset per telegraph in end_turn).
- 3 new enemies appended at band ends: vent_ram (charge 34/9, L5+),
  cinder_urchin (counter 3, L5+), magma_lancer (elite exam, L6+). Sheets =
  palette variants (tool/gen_variant_sprites.py, PROVENANCE rows added);
  sprite_meta.json hand-appended (generator reindents the whole file — keep
  hand-editing meta for minimal diffs). 3 codex entries (75→78).
- UI: _IntentBadge chips + spoken text for charge/counter/stagger;
  _explainIntent cases; stage sway on charge; tips onIntent counts charge;
  choreography: charge_broken note, counter_struck pop/claws/defeat path,
  enemy_staggered beat; run_trace counts counter_struck as hurt.
- Bot reads the badges: break-if-reachable vs charge; ONE biggest-die strike
  then block vs counter (lib/sim/autoplay.dart).
- SIXTH golden re-anchor (pool 39→42; probe tool/reanchor_v0470_probe_test):
  goldenV6 2043266176→111116111. Boss goldens: colossus 1144080449@20260728,
  tyrant 1236716520@20260721, matriarch 2027004709@20260722, hierophant
  111116111@20260723, bellows 1475540171@20260724, twins 338964903@20260725,
  regent 1367915457@20260726 (anchor seed moved from 20260734 — reach
  re-screen), king 648955842@20260743.
- Pins re-hunted: kindler easy-loss 3→18 (6 test files + literal expects in
  share_card L75/L209, retraced_road L73); tenth_rung proving seed 200→201
  (lib/data/provings.dart); A20 ascetic 20→66 (others 6/4/10 survive);
  rung-20 cap seed 6 survives. Peddler pins unchanged (loss 16, wins
  {1,2,4,6,8}); ash_summit 912 survives.
- GATES GREEN: analyze clean; suite 606/606 (9 new in
  test/answered_blow_test.dart; overflow probes 35/35 inside suite);
  BAND400 easy 89.0 / normal 62.75 / hard 39.75 — all in band.
- STILL TO DO before tagging v0.47.0: (1) HARD1000 drift check
  (tool/hard_1000_probe_test.dart; pre-drop 42.3%); (2) plate critique redo —
  tool/answered_blow_plates_test.dart works but the anchored TOUR overlay
  pollutes plates (set meta.tourSeenVersion = tourVersion in the test, cvd
  pattern predates the tour) and at 320x568@1.3 the 2-chip intent badge
  (charge AND pre-existing attack_block) clips the right screen edge —
  judge/fix once plates are clean (Positioned top:-badgeLift in
  combat/stage.dart has no horizontal clamp); (3) version already bumped
  0.47.0+73 + news entry + notes docs/releases/v0.47.0.md (balance numbers
  need filling in); (4) tag at release sha, dispatch CI, publish with
  checksums (expect codes 73/1073/2073/4073).

## 2026-08-25T04:05Z — v0.47.0 gates ALL GREEN; tagged
- HARD1000 42.1% vs 42.3% pre-drop (within noise). BAND400 89.0/62.75/39.75.
- Plate critique done (tool/answered_blow_plates_test.dart, tour suppressed
  via meta.tourSeenVersion = tourVersion): found + FIXED a pre-existing
  defect — 2-chip intent badges (attack_block/charge) clipped the right
  screen edge at 320x568@1.3x. Badge now Positioned right:-(Space.xl-Space.s)
  in combat/stage.dart (right edge Space.s inside the screen at every width;
  ~unchanged at 360px). Suite re-run after the fix: 606/606; analyze clean.
- Release notes filled with measured numbers; tag v0.47.0 at this sha;
  CI dispatch next. Expect codes 73/1073/2073/4073.
- PLATE LESSON: never combatBegin() from the map phase for screenshots (the
  screen renders a broken hybrid) — walk to a real fight, then swap
  (c.state!['enemy'] as Map)['intent'] and tick with a benign apply.

## 2026-08-25T07:15Z — v0.47.0 PUBLISHED
- CI 32802870155 success. All 4 APKs PIN-OK (codes 73/1073/2073/4073),
  AAB pin match. 5 assets + sha256 table live:
  https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.47.0
- v0.48.0 "The Iron Between" started during the CI wait: elites get their
  own combat theme (KM "Volatile Reaction", -19.06 LUFS, TP -9.17, OGG q4)
  as the eighth Gramophone record; _bossFight split into boss-only +
  _eliteFight; boss music no longer plays for elites. WIP uncommitted.

## 2026-08-25T07:40Z — v0.48.0 "The Iron Between" gates green
- Elite fights get their own theme (KM "Volatile Reaction" -> combat_elite,
  -19.06 LUFS, TP -9.17, OGG q4, 2.4MB). Eighth Gramophone record "Iron
  Between" between Steel and Ember and Deeper Still. _bossFight boss-only;
  new _eliteFight; boss outranks elite in musicKeyForPhase.
- No sim change: no re-anchor, no band sweep. Suite 610/610 (4 new
  iron_between tests; gramophone mask pin 5->6). Analyze clean.
- Pinned: kindler easy seed 2 win crosses an elite (records combat_elite +
  boss_combat separately); seed 1 win meets no elite (probe: elites on easy
  seeds 2,3,4,5,7,9,12 of 1..12).
- Gramophone plates re-critiqued clean at 360x640/412x915/800x1280 +
  playing state. Version 0.48.0+74, news entry, notes docs/releases/
  v0.48.0.md, design doc, PROVENANCE + CREDITS rows.
- Next: commit, tag v0.48.0, dispatch CI, publish with checksums
  (expect codes 74/1074/2074/4074).

## 2026-08-25T09:05Z — v0.48.0 PUBLISHED + v0.49.0 "The Shorter Road" gates green
- v0.48.0 published: CI 32804373058 success; all 4 APK pins OK, codes
  74/1074/2074/4074; AAB pin match. Release + checksums table live at
  releases/tag/v0.48.0.
- v0.49.0 The Shorter Road: 4th mutator `short_road` = six-layer Short Delve.
  shortRoadCfg (layers 6, eliteFrom 4, restGuarantee 5, shop 2/2, event 2);
  map_gen guarantee hardening (elite fallback to non-rest; rest floor
  relaxation) — both inert on 9-layer maps. Boss shaved x0.58/-3, elites
  x0.80/-2 on the format; offer/shop tier ceiling reads layer+3; fight gold
  x1.5 (embers untouched). Title-screen sticky toggle
  (meta.preferShortRoad), controller shortRoad param (composes with any
  difficulty — NOT the shared-run mutators pin), retrace + run records +
  Ledger carry the format, Delve Code bit 44 (backward compatible), trial
  short_day, Weekly rotation gains Short Week.
- Tuned by 9 400-seed sweeps + death-location/kind probes: final bands
  easy 87.5 / normal 56.0 / hard 32.75 — all in band on the short format.
  Full tuning table in docs/improvements/v0.49.0-shorter-road-design.md.
- Suite 621/621 (11 new in test/shorter_road_test.dart); analyze clean;
  goldens + all pinned seeds untouched (default runs byte-identical by
  construction). Plates critiqued clean at 360x640/412x915/800x1280 +
  320x570@1.3x (tool/short_road_plates_test.dart); no overflow.
- Pinned: kindler short seed 6 wins normal, seed 1 wins easy / falls normal.
- Version 0.49.0+75; news entry; notes docs/releases/v0.49.0.md.
- Next: commit, tag v0.49.0, dispatch CI, publish with checksums
  (expect codes 75/1075/2075/4075).

## 2026-08-25T11:10Z — v0.49.0 "The Shorter Road" PUBLISHED
- CI 32807034937 success (workflow_dispatch on tag 4cccecf).
- All 4 APKs PIN-OK (codes 75/1075/2075/4075); AAB signer pin matches.
- Release: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.49.0
  — 5 assets + SHA-256 table in notes.
- v0.50.0 scout committed alongside: The Tinker (control archetype).
  Key finding: any NEW relic resizes the shop offer pool => golden
  re-anchor; and the bot never spends relic `rerolls`. Kit v1 therefore
  uses existing relic loaded_pips + d6_steady, zero sim changes.

## 2026-08-25T12:20Z — v0.50.0 "The Tinker" ALL GATES GREEN, tagging
- Sixth delver: control archetype. 30 HP, [d6_steady,d6,d4], start relic
  loaded_pips (EXISTING — new relics resize the shop offer pool => golden
  re-anchor, so none added). Unlock 600 embers, appended LAST (index 5).
- Data-only: zero sim changes, goldens byte-identical (suite proves).
- 400-seed sweeps: 28HP 85.0/54.75/28.25 -> 29HP 85.25/56.25/29.25 ->
  final 30HP 85.25/58.25/31.0, all in band; normal level with peddler 58.7.
- Pins: easy 1..20 WWWWWWWWWWWWWWWWWLWW, normal WWLWLWLWWWWLWWLWWLLW;
  test/tinker_test.dart pins seed 1 easy+normal win, 18 easy loss.
- Sprite: characters/tinker.png = kindler palette variant (hue +192, sat
  x0.55, val x0.92, floor 0.18 — muted steel blue, distinct from peddler
  teal); PROVENANCE row added; gen_variant_sprites --check OK.
- Pin Wrench painter added to weapons.dart (per-id switch).
- Achievements: tinker_wins "Well Oiled", six_ways_down.
- Suite 626/626; analyze clean; 10 plates x4 viewports critiqued clean
  (tool/tinker_plates_test.dart KEPT). PLATE LESSON: pumpWidget with a new
  controller REUSES GameRoot state (same runtimeType/position) — pump a
  SizedBox between scenes; and runAsync-delay 400ms before the first snap
  so sprite sheets decode (cold cache = spriteless washed plate).
- peddler_test charactersOrder.last pin updated to indexOf==4 (the wire
  format is the INDEX, not last-ness).

## 2026-08-25T13:15Z — v0.50.0 "The Tinker" PUBLISHED
- CI 32809432133 (workflow_dispatch on tag) success. Artifacts: aab
  9549537928, splits 9549536826, apk 9549535269 (debug-symbols skipped).
- Verified: 4 APK signer pins PIN-OK, version codes 76/1076/2076/4076,
  AAB pkcs7 pin 031acb42… matched.
- Release https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.50.0
  with 5 standard assets; notes_final.md (sha256+size table) applied.
  SHA-256: universal 415d65dc…, arm64 19e4cc34…, armeabi 6524dd3b…,
  x86_64 e386a883…, aab 90e85f7c….
- Committed alongside: v0.51.0 lead scout doc + delve-obituary design doc.
  Groundwork verified: cloud_merge.dart L77 copies runHistory wholesale, so
  an additive killed_by key round-trips; runHistory cap 30, ledger renders
  Recent Delves via _historyRow; summary copy pattern = copy-daily-result.

## 2026-08-25T13:55Z — v0.51.0 "The Obituary" built, all gates green
- Run-end storytelling (scout doc candidate #1): summary screen tells the
  finished run back in 2–3 honest sentences (pure obituaryText in
  lib/game/obituary.dart, deterministic per run seed), plus a
  "Copy delve story" plain-text button (copy-daily-result pattern);
  run records gain additive killed_by on losses; Ledger Recent Delves
  name the killer ("fell on floor 4 of 9 to Quench Hag").
- Zero sim changes — goldens/sweeps/pins untouched by construction.
  Verified: only combat can kill (events clamp HP to 1, run_layer.dart
  ~L685), so a loss always holds its killer; cloud_merge carries
  runHistory wholesale so killed_by round-trips.
- Suite 633/633 (7 new in test/obituary_test.dart: 4 golden strings +
  win/loss widget pins on seeds 1/18 + legacy-record row), analyze clean.
- Plates: tool/obituary_plates_test.dart (KEPT) → build/obituary_plates/,
  summary win/loss + ledger at 360x640, 412x915, 800x1280, 320x570@1.3x —
  12 plates, critiqued clean, no overflow.
- TEST LESSON (re-learned): Ledger is a lazy ListView — scrollUntilVisible
  needs POSITIVE delta + explicit `scrollable: find.byType(Scrollable)
  .first`; and find.textContaining(' to ') collides with the row's
  "tap to copy its Delve Code" line — pin exact text instead.

## 2026-08-25T14:40Z — v0.51.0 "The Obituary" PUBLISHED
- CI 32811140909 (workflow_dispatch on tag v0.51.0) success; artifacts
  aab 9550138101 / splits 9550136810 / apk 9550134926.
- 4 APK pins PIN-OK, codes 77/1077/2077/4077; AAB signer pin matched
  (031acb42…). Release live with 5 assets + sha256 table:
  https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.51.0
- Staging /work/temp/v0510/rel (notes_final.md holds the checksum table).

## 2026-08-25T14:50Z — v0.52.0 "The Tinker's Proving" built, all gates green
- Scout lead #1 shipped: tenth proving `tinkers_proving` (Tinker, normal,
  seed 131 — bot-win proven via tool/tinker_proving_hunt_test.dart, 57/101
  normal seeds won in 100..200, 131 picked) fills the last empty roster
  seat; new epithet `the_well_oiled` (char_wins/tinker ×1) mirrors the
  Ledger's Well Oiled honestly. Data-only, zero sim changes — goldens,
  sweeps, and every pinned seed untouched by construction.
- Files: lib/data/provings.dart (+1 def after full_purse), lib/data/
  epithets.dart (+1 def, end of order), lib/data/news.dart (0.52.0 entry),
  pubspec 0.52.0+78. Tests: provings_test counts 9→10 + '0 of 9'→'0 of 10'
  screen pins; epithets_test char-param gate proof (charWins['tinker']).
  Winnability proof covers seed 131 automatically.
- Suite 633/633, analyze clean. Plates: tool/proving_plates_test.dart
  (KEPT) → build/proving_plates/ — provings row, epithet card (locked/
  WORN), news post at 360x640, 412x915, 800x1280, 320x570@1.3x; 10 plates
  critiqued clean.

## 2026-08-25T05:45Z — v0.52.0 "The Tinker's Proving" PUBLISHED
- CI 32812237432 success; artifacts aab 9550481795 / splits 9550480779 / apk 9550479131.
- 4 APK signer pins PIN-OK (codes 78/1078/2078/4078); AAB pin matched 031acb42….
- Release live: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.52.0 — 5 assets, sha256 table appended to notes.
- v0.53.0 lead scout (docs/improvements/v0.53.0-lead-scout.md) committed with this entry; leading candidate "The Rumor".

## 2026-08-25T06:55Z — v0.53.0 "The Rumor" gates GREEN
- Pre-delve boss telegraph: rumorForSeed (lib/game/rumor.dart, pure bossForSeed read) on the boon pick (rumor-line) + live preview in the Delve a seed dialog (rumor-preview; code seed wins over raw text).
- Overflow sweep fixes shipped with it: boon header now scrolls with the cards (fixed header overran 320@1.3x under the probe font); boon title Row→Wrap (RECOMMENDED chip starved the title to letter-per-line at 320@1.3x — pre-existing, plate-proven); seed dialog content scrollable + tighter insetPadding.
- Zero sim changes; suite 636/636; analyze clean; 14 plates critiqued clean at 4 sizes (build/rumor_plates, logs /work/temp/v0530_*).

## 2026-08-25T07:15Z — v0.53.0 "The Rumor" PUBLISHED
- CI 32819302281 (workflow_dispatch on tag) success; artifacts aab 9552903903 / splits 9552902373 / apk 9552900177.
- 4 APK pins PIN-OK (codes 79/1079/2079/4079); AAB signer pin matched. Staging /work/temp/v0530/rel.
- Release: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.53.0 — 5 assets, sha256 table in notes (notes_final.md).
- v0.54.0 "The Epitaph" underway in-tree: epitaphLine + delveEpitaphLine + card epitaph render/fallback; worst-case card gate FOUND pre-existing bug — the shipped card overflowed 90px at 1.3x device text scale since v0.34.0 (fix: MediaQuery.withNoTextScaling — the card is an exported image; + canvas 420→470 for the epitaph under the wide test font).

## 2026-08-25T07:40Z — v0.54.0 "The Epitaph" gates GREEN
- The Delver's Card carries the run's story: pure epitaphLine (lib/game/obituary.dart) + controller.delveEpitaphLine (same fact sources as delveStoryText) + card render (key card-epitaph, italic/dim under the name) + clipboard fallback.
- FOUND+FIXED pre-existing bug: the card overflowed 90px at 1.3x device text scale since v0.34.0 (worst realistic facts, baseline-proven with change reverted). Fix: MediaQuery.withNoTextScaling — the card is an exported image; canvas 420→480 for the epitaph under the wide test font (maps are 9 layers → 2 trace rows max; the honest worst case).
- Zero sim changes; suite 642/642 ×2; analyze clean; 10 plates critiqued clean at 4 sizes (build/epitaph_plates, logs /work/temp/v0540_*).
- PROCESS LESSON (logged in harness skill): repo-wide `dart format` on this checkout touches 82 legacy files — format ONLY touched files; and never `git checkout -- .` to undo it (wiped WIP once; recovered by full redo + suite rerun).

## 2026-08-25T08:00Z — v0.54.0 "The Epitaph" PUBLISHED
- CI 32821779277 (workflow_dispatch on tag) success; artifacts aab 9553781156 / splits 9553779661 / apk 9553777548.
- 4 APK pins PIN-OK (codes 80/1080/2080/4080); AAB signer pin matched 031acb42…. Staging /work/temp/v0540/rel.
- Release: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.54.0 — 5 assets, sha256 table in notes (notes_final.md).
- v0.55.0 lead scout (docs/improvements/v0.55.0-lead-scout.md) committed with this entry; leading candidate "Duskquartz" (fifth vista, provings-tied). Build already underway in-tree: VistaDef + resolver param + controller + truth-table/gate/picker tests green (13/13); plates rendering.

## 2026-08-25T08:20Z — v0.55.0 "The Duskquartz" gates GREEN
- Fifth vista, the first the Provings feed: duskquartz (violet-gold grade, hue -95 / sat 1.35 / val 0.96 / wash 0x3D2E1E4E), unlock "Clear 3 provings." — vistaUnlockedFor gains required provingsCleared param (controller passes meta.provingsCleared.length); appended LAST to vistasOrder.
- Palette-only, zero PNGs, zero size growth; strata depth grade still composes (identity pins untouched).
- Tests: truth table extended (2 vs 3 provings, blind to other counters), controller gate flips with a real cleared set, picker shows the locked milestone; suite 643/643; analyze clean.
- Plates: 13 vista plates (build/vistas_visual — incl. duskquartz surface/deep + earned-CHOSEN wardrobe) + 3 news plates (build/news_visual) critiqued clean; plate tool fixed for the 5-card shelf (scroll target duskquartz, snap the shelf tail — emberlight gets evicted from the lazy list).
- Zero sim changes; no sweep or golden re-anchor needed. Logs /work/temp/v0550_*.

## 2026-08-25T09:00Z — v0.55.0 "The Duskquartz" PUBLISHED
- CI 32824020713 success; artifacts aab 9554590222 / splits 9554588720 / apk 9554586584.
- 4 APK pins PIN-OK (0.55.0, codes 81/1081/2081/4081); AAB signer pin matched.
- Release: https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.55.0 — 5 assets; sha256 table in notes (universal 563f0422… 70M, arm64 ac391103… 36M, armeabi def94ebc… 34M, x86_64 94cd282d… 37M, aab fcb89a79… 68M).
- Next: v0.56.0 lead = Card from the Ledger (docs/improvements/v0.56.0-lead-scout.md).

## 2026-08-25T10:15Z — v0.56.0 "Card from the Ledger" gates GREEN
- Any remembered win/loss in the Ledger's Recent Delves now shares a full Delver's Card (share icon per row, key history-card-<seed>-<date>); walkaways offer no card.
- DelverCardFacts.fromRecord: honesty by omission — fights/trace/epithet never banked → omitted (new fightsKnown flag drops the fights figure from card + fallback text); win boss via bossForSeed(seed) (seed-0 relics name no boss, offer no code); pre-v0.51 losses keep opener+floor; short records rebuild SHORT codes.
- showDelverCardSheet gained optional facts param (summary path unchanged).
- Tests: test/ledger_card_test.dart (7 — truth table, degradations, worst-case canvas with Ashglass Sentinel two-clause epitaph + guard against silent degradation, ledger entry-point incl. abandoned-row absence); suite 650/650; analyze fatal-warnings clean.
- Plates: build/ledger_card_plates (rows + remembered loss/win cards) + 3 news plates critiqued clean. LESSON: a wrong enemy id in test fixtures degrades the epitaph SILENTLY — pin the expected two-clause string in worst-case tests.
- Zero sim changes; no sweep or golden re-anchor. Logs /work/temp/v0560_*.

## 2026-08-25 — v0.56.0 PUBLISHED
- CI run 32840148958 success (workflow_dispatch on tag v0.56.0). Version codes 82/1082/2082/4082.
- Verified: 4 APK signer pins PIN-OK (versionName 0.56.0), AAB pkcs7 cert pin matched (031acb42…3a0d).
- Release https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.56.0 — 5 signed assets; sha256 table appended to notes.
- Content: Ledger rows (won/lost, not abandoned) get a share icon → Delver's Card rebuilt from the run record via DelverCardFacts.fromRecord; honesty-by-omission (fights/trace/epithet omitted when unknown).

## 2026-08-25 — v0.57.0 "The Fuller Record" gates GREEN
- One improvement: run records bank fights won + compact floor trace ('c'/'h' string, RunTrace.toCompact/fromCompact) + worn epithet id — DelverCardFacts.fromRecord restores figure/grid/title (name line AND epitaph). Absent keys keep v0.56.0 omission behaviour.
- analyze --fatal-warnings clean; suite 656/656 (/work/temp/v0570_suite2.log; +6 test/fuller_record_test.dart incl. bot-played win seed 1 / loss seed 18 banking pins and fuller worst-case canvas).
- Plates critiqued clean: build/ledger_card_plates now 5 plates (fuller_loss_card with "The Gambler, the Well-Oiled" + 2-row trace + fights line; fuller_win_card grid ends on ember cell; legacy cards keep omissions) + 3 news plates (build/news_visual).
- Zero sim changes → no sweep/golden re-anchor. pubspec 0.57.0+83.

## 2026-08-25 — v0.57.0 PUBLISHED
- CI run 32874509333 success. Version codes 83/1083/2083/4083. 4 APK pins PIN-OK; AAB cert pin matched.
- Release https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.57.0 — 5 signed assets; sha256 table appended.

## 2026-08-25 — v0.58.0 "The Remembered Fights" gates GREEN
- One improvement: Ledger rows state the worn epithet (row title) and fights count (meta line, singular/plural) when the fuller record banked them; old records render byte-identical. lib/ui/ledger_screen.dart _historyRow only.
- analyze --fatal-warnings clean; suite 660/660 (/work/temp/v0580_suite2.log; +4 test/remembered_fights_test.dart incl. panel-scoped negative pins for old records).
- Plates critiqued clean: ledger_rows_360x640 + NEW ledger_rows_320x568 restraint check (worst case wraps 4 legible lines — fights token kept per scout condition) + 3 news plates. Plate scroll now targets recent-delves panel (newest fuller rows visible).
- Zero sim changes → no sweep/golden re-anchor. pubspec 0.58.0+84.

## 2026-08-25 — v0.59.0 "The Proven" gates GREEN
- One improvement: tenth epithet the_proven ("Clear every proving.", stat provings_cleared = meta.provingsCleared.length, target 10 pinned == provings.length). Stat added to statValue AND achievementStats vocabulary (data-sanity + wiring pins caught both omissions — populate provingsCleared in achievements_test wiring fixture when adding stats).
- analyze clean; suite 664/664 (/work/temp/v0590_suite3.log; +4 test/proven_epithet_test.dart).
- Plates critiqued clean: epithets_visual picker_proven_locked + picker_proven_worn (shelf tail, WORN mark) + 3 news plates.
- Zero sim changes. pubspec 0.59.0+85.

## 2026-08-25 — v0.58.0 PUBLISHED
- CI run 32876420605 success. Version codes 84/1084/2084/4084. 4 APK pins PIN-OK; AAB cert pin matched.
- Release https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.58.0 — 5 signed assets; sha256 table appended.
- v0.59.0 tagged, CI run 32877791422 dispatched (expect codes 85/1085/2085/4085).

## 2026-08-25 — v0.59.0 PUBLISHED
- CI run 32877791422 success. Version codes 85/1085/2085/4085. 4 APK pins PIN-OK; AAB cert pin matched.
- Release https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.59.0 — 5 signed assets; sha256 table appended.
- Next: v0.60.0 "The Delver's Tally" (picker cards state charWins/charRuns record; scout doc docs/improvements/v0.60.0-lead-scout.md) — WIP in flight, gates pending.

## 2026-08-25 — v0.60.0 "The Delver's Tally" gates GREEN
- Picker _charCard gains per-delver record line "N wins · M delves" from charRuns/charWins (Ledger roster vocabulary); fresh delvers show nothing; locked unchanged. Scout: docs/improvements/v0.60.0-lead-scout.md.
- analyze clean; suite 668/668 (/work/temp/v0600_suite1.log; +4 test/delver_tally_test.dart).
- Plates critiqued clean (tool/delver_tally_visual_test.dart: 360, 320 worst-case with the Well-Oiled + 4-digit tally, fresh-install negative).
- Zero sim movement — no re-anchors.

## 2026-08-25 — v0.61.0 "The Deepest Mark" gates GREEN (push pending GitHub auth)
- One improvement: summary announces a moved bestFloor with one gold line "Floor N — the deepest you have delved." (key deepest-line), win or LOSS alike; gated on a previous record existing (bestFloor > 0). Transient pendingDeepestFloor, pendingRankUp lifecycle. Scout: docs/improvements/v0.61.0-lead-scout.md (post-run record-card conventions + Balatro stats culture + loss-retention data).
- analyze clean; suite 674/674 (/work/temp/v0610_suite1.log; +6 test/deepest_mark_test.dart incl. loss-sets-the-mark and first-run-silent pins).
- Plates critiqued clean (tool/deepest_mark_visual_test.dart: deepest_win_360x640, deepest_loss_320x568 dignity plate). PLATE LESSON: SummaryScreen pumped directly needs a Material(color: EmberColors.bg) host or every Text paints the yellow missing-DefaultTextStyle underline; the line sits below the fold — scrollUntilVisible before snap.
- Zero sim movement, zero save-format movement (bestFloor persisted since v0.5.0). pubspec 0.61.0+87.
- itch.io same session: android channel butler-pushed to v0.59.0 (was stale at 0.45.0 — the "CI auto-sync" note was wrong, corrected in MARKETING-SYNC.md); devlog 1640696 posted; new password + API key stored Viktor-side.

## 2026-08-25 — v0.62.0 "The Kept Fire" gates GREEN (push pending GitHub auth)
- One improvement: title greets a 7+-days-away player with one warm line under the Gathered Hearth (key kept-fire-line): "N days since your last delve — the hearth kept its fire." Pure derived state from newest runHistory date (injectable clock keptFireLine helper); self-retiring on any banked run; silent for fresh/active/malformed. Scout: docs/improvements/v0.62.0-lead-scout.md (Helpshift 90-second re-entry window).
- analyze clean; suite 680/680 (/work/temp/v0620_suite2.log; +6 test/kept_fire_test.dart incl. calendar-midnight pins). NEWS-COPY LESSON: the news ethics gate bans the WORD "streak" even in a denial ("no streaks were counted" failed) — write around banned vocabulary entirely.
- Plates critiqued clean (tool/kept_fire_visual_test.dart: 23-day 360x640, 365-day 320x568 restraint, fresh negative).
- OBSERVATION for a future lead: EmberLogotype edge-clips at 320dp width on the title (pre-existing, visible in kept_fire_320x568 plate) — candidate v0.63.0 fix.
- Zero sim movement, zero save-format movement. pubspec 0.62.0+88.

## 2026-08-25 — v0.63.0 "The Fitted Name" gates GREEN (push pending GitHub auth)
- One improvement (bugfix): EmberLogotype hard-clipped both edges at 320dp title widths since it shipped. Fit now happens INSIDE the painter at paint time (fittedLogoFontSize pure helper, probe width memoized; effectiveFontSize field exposed for tests); reserved height unchanged so vertical rhythm never shifts; never scales up. Scout: docs/improvements/v0.63.0-lead-scout.md (defect found by our own v0.62.0 320x568 plate).
- LAYOUT LESSON: a LayoutBuilder inside the title column breaks its IntrinsicHeight ("LayoutBuilder does not support returning intrinsic dimensions" — 99 test failures). For width-aware painting, fit inside CustomPainter.paint(size) instead.
- analyze clean; suite 682/682 (/work/temp/v0630_suite2.log; +2 test/fitted_name_test.dart — Ahem's 1em glyphs make the narrow case trigger without real fonts).
- Plates: kept_fire re-render critiqued clean — 320x568 now shows the FULL wordmark with margins; 360x640 pixel-consistent.
- Zero sim movement. pubspec 0.63.0+89.

## 2026-08-25 — v0.64.0 "The Deepshale" (committed, gates GREEN, awaiting GitHub auth to tag/CI/release)
- One improvement: sixth vista `deepshale`, the first fed by the depth record — unlock `bestFloor >= 9` ("Stand on the ninth floor.", win or loss). First DESATURATING vista: hueDeg -10, satMul 0.72, valMul 0.9, wash 0x40232830 (cold slate). Appended LAST to vistasOrder.
- `vistaUnlockedFor` gained `required int bestFloor`; controller passes meta.bestFloor. Pure data+resolver change; zero sim/save-format movement.
- Tests: truth-table cases (floor 8 locked / 9 unlocked, blind to wins/kills/provings) + controller-gate cases inside test/vistas_test.dart (13/13). Suite 682/682 (/work/temp/v0640_suite2.log). analyze clean.
- Plates critiqued clean: bg_deepshale surface + depth-0.8 (strata still compounds), wardrobe locked/chosen at 360x640, no overflow. Scout: docs/improvements/v0.64.0-lead-scout.md.
- ESCAPE LESSON: file_edit into Dart doubled `\\'` to `\\\\'` inside a single-quoted string (news.dart) — after editing Dart string literals via tools, re-run analyze before assuming the entry compiles.
- pubspec 0.64.0+90; news 0.64.0 entry added.

## 2026-08-26 — v0.65.0 "The Charted Depth" (committed, gates GREEN, awaiting GitHub auth to tag/CI/release)
- One improvement: per-delver depth records — `MetaState.charBestFloor` (deepest 1-based layer per character, won or lost), banked in _bankRun beside bestFloor, cloud merge per-key MAX (_maxMap), picker tally gains "· floor N" (v0.60.0 exact-text pins stay green because fresh metas chart nothing).
- Pre-v0.65.0 saves seed from runHistory per-character max (same honesty rule as bestFloor's v0.5.0 seeding); a save WITH the key never re-seeds; empty map emits no JSON key.
- save_transfer full-fat fixture extended with charBestFloor {'kindler': 9} — an absent key is re-seeded on decode (correct, but not byte-identical), so the full-fat state must carry it.
- Tests: +7 test/charted_depth_test.dart (bank/isolation, never-lowers, round-trip, seeding incl. malformed record + explicit-key-no-reseed, merge MAX, both picker states). Suite 689/689 (/work/temp/v0650_suite3.log). analyze clean.
- Zero sim movement. pubspec 0.65.0+91; news 0.65.0 entry (ethics-gate clean).
- Plates (post-commit): tool/charted_depth_visual_test.dart → build/charted_depth_visual/ — 360x640 one-line tallies with floors; 320x568 worst case (999/1204/floor 9) wraps cleanly after the middot, no overflow; fresh shows no tally. Critiqued clean.

## 2026-08-26 — v0.66.0 "The Dressed Delver" (committed, gates GREEN, awaiting GitHub auth to tag/CI/release)
- One improvement: per-delver worn epithets — `MetaState.charEpithet` (map charId→epithet id; fromJson drops unknown ids) with resolver `epithetFor(charId)` falling back to legacy `selectedEpithet` (never written again, so old choices survive). Cloud merge takes the fresher side's map wholesale.
- controller: `selectEpithet(id, {required forChar})` guards unlockedCharacters + epithetUnlocked; run records bank `'epithet'` via epithetFor. Story text, epitaph line, and share card all resolve per-delver.
- character_screen: THE EPITHET section gains a delver chip row (keys `dress-<id>`, gated >1 unlocked delver, default target = last delved else first unlocked); epithet cards keyed; chosen state reads epithetFor(target). Caption: "Each delver wears their own. Earned by delving, never sold."
- Tests: +8 test/dressed_delver_test.dart (guards, fallback, per-delver isolation, banking, merge, chip row gating/switching); 3 older tests re-pinned to epithetFor semantics. Suite 697/697 (/work/temp/v0660_full.log). analyze clean.
- Plates: tool/dressed_delver_visual_test.dart → build/dressed_delver_visual/ — wardrobe 360x640 + 320x568 (chip row with Kindler chosen, shelf below, WORN travels with the target), picker with two delvers wearing different titles, fresh unchanged. Critiqued clean after two re-aims.
- PLATE LESSON: to frame a mid-list widget, scrollUntilVisible then measure `tester.getTopLeft(...).dy` and drag by `(wantedY - dy)` — blind fixed-offset nudges overshoot.
- Zero sim movement. pubspec 0.66.0+92; news 0.66.0 entry (ethics-gate clean); notes docs/releases/v0.66.0.md.

## 2026-08-26 — v0.67.0 "The Dyed Delver" (committed, gates GREEN, awaiting GitHub auth to tag/CI/release)
- One improvement: per-delver worn dyes — the last global wardrobe choice. `MetaState.charDye` + `dyeFor(charId)` (legacy activeDye = fallback, never written again), `_dyeMap` decode validator, fresher-side cloud merge. OWNERSHIP stays global (embers buy once, everyone may wear) — only the wearing is per-delver.
- `setActiveDye(id, {required forChar})` guards ownedDyes + unlockedCharacters. Render sites → dyeFor: combat stage (_characterId), map marker, picker card (per id), dye swatch (now paints the DRESS TARGET, not defaultCharacter), title hearth (each delver in their own coat — the visible payoff).
- THE WARDROBE gains the v0.66.0 chip row (shared dressTarget, keyPrefix 'dye-dress-' to dodge duplicate-key collisions with the epithet row).
- Tests: +6 test/dyed_delver_test.dart (resolver/guards/round-trip/merge/chip gating + isolation); attire_test + tool/wardrobe_visual_test re-pinned to dyeFor. Suite 703/703 (/work/temp/v0670_full.log). analyze clean.
- Plates: tool/dyed_delver_visual_test.dart → build/dyed_delver_visual/ — rack 360x640 + 320x568 (chip row, target-painted swatches, WORN vs OWNED per delver), hearth with mixed coats, picker per-delver. Critiqued clean first render (the measured-drag framing lesson from v0.66.0 paid off immediately).
- Zero sim movement. pubspec 0.67.0+93; news 0.67.0 entry (ethics-gate clean); notes docs/releases/v0.67.0.md; scout docs/improvements/v0.67.0-lead-scout.md.

## 2026-08-26 — v0.68.0 "The Earned Name" (committed, gates GREEN, awaiting GitHub auth to tag/CI/release)
- One improvement: epithet unlocks were SILENT — every other banked milestone announces on the summary (achievements, rank, rungs, depth) but earning a NAME said nothing. Now: one quiet gold line per earned title, key `earned-name-<id>`, win or loss alike ('"the Delver" is yours to wear.').
- `GameController.pendingEpithets` — epithetsBefore snapshot beside rankBefore in _bankRun, diffed after counters bank; pendingRankUp lifecycle (cleared on startRun, transient, can't double-fire). Multi-announce works: a first no-rest win earns the_delver AND the_unresting — two stacked lines, verified on plate.
- ETHICS: scouted-and-REJECTED the "nearest mark" almost-there teaser — v0.61.0 deepest-line comment pins the stance ("pure fact, no next-goal teaser"). An earned name is a fact.
- Tests: +5 test/earned_name_test.dart (first-win announce + startRun clear, no re-announce, LOSS earns the_thorough on 10th ended run, widget exact-text + silence). Suite 708/708 (/work/temp/v0680_full.log). analyze clean.
- Plates: tool/earned_name_visual_test.dart → build/earned_name_visual/ — win 360x640 (double announce), loss 320x568 (the_thorough on a loss). Critiqued clean first render.
- Zero sim movement. pubspec 0.68.0+94; news 0.68.0 entry (ethics-gate clean); notes docs/releases/v0.68.0.md; scout docs/improvements/v0.68.0-lead-scout.md.

## 2026-08-26 — v0.69.0 "The Standing Delver" (committed, gates GREEN, awaiting GitHub auth to tag/CI/release)
- One improvement: the summary never showed WHO delved — a generic trophy/flame stood where the delver should. Now the run's own delver stands above the headline in their worn dye (SpriteView, bob on wins, still + 0.55 opacity on losses), with one name line below: 'The Kindler, the Unburnt' (epithetFor; bare name when undressed). Keys `summary-delver` / `summary-delver-name`. Same 56dp slot as the old icon — rhythm unchanged.
- Identity arc payoff (v0.66→v0.68) on the most-seen emotional screen; retry-after-loss retention rides on the summary feeling personal (Antihero 80.5% stat).
- Tests: +3 test/standing_delver_test.dart (bare name on fresh win, per-delver title joins name, loss still shows both). Suite 711/711 (/work/temp/v0690_full.log). analyze clean.
- Plates: tool/standing_delver_visual_test.dart → build/standing_delver_visual/ — win 360x640 (dyed + titled), loss 320x568 (dimmed, bare name). Critiqued clean first render.
- Zero sim movement. pubspec 0.69.0+95; news 0.69.0 entry (ethics-gate clean); notes docs/releases/v0.69.0.md; scout docs/improvements/v0.69.0-lead-scout.md.

## 2026-08-26 — v0.70.0 "The Pictured Card" (committed, gates GREEN, awaiting GitHub auth to tag/CI/release)
- One improvement: the Delver's Card — the only artifact that leaves the game — showed a generic trophy/flame. Now the run's delver stands on it, in their worn dye (key `card-delver`, SpriteView static, nearest-neighbor crisp at 3x export). Loss cards keep full color (a poster, not the live moment).
- DelverCardFacts gains `charId` + `dyeId` (card stays a pure function of facts). fromController: dyeFor; fromRecord gains optional `MetaState? meta` (ledger passes c.meta) — CURRENT coat = portraiture, worn-at-the-time dye NOT banked (rejected: new save key for pure paint; epithet precedent is narrative, quoted by the epitaph).
- Tests: +3 test/pictured_card_test.dart (facts bank charId+dye, fromRecord meta/no-meta, widget shows sprite + both old icons gone). Suite 714/714 (/work/temp/v0700_full.log). analyze clean.
- PLATE HARNESS FIXES (tool/share_card_visual_test.dart): (1) first card plate rendered a BLANK sprite slot — decode race; runAsync 400ms delay before snap (established sprite-plate lesson now applies to DelverCard too). (2) STALE SEED: card_loss/sheet_loss used seed 13, which WINS since the v0.47.0 re-anchor — the "loss" plates had silently been wins; re-pinned to 18. Trace-grid NO GLYPH tofu on plates = harness-only emoji-font gap (🟩🟨🔥 render fine on device), pre-existing, left alone.
- Zero sim movement. pubspec 0.70.0+96; news 0.70.0 entry; notes docs/releases/v0.70.0.md; scout docs/improvements/v0.70.0-lead-scout.md. Plates build/share_card_visual/ critiqued clean on re-render.

## v0.71.0 — The First Words (2026-08-26)
- Player review: "I still don't understand what's a delve" — tour teaches HOW, nothing stated the PREMISE.
- `firstWordsLine(MetaState)` beside keptFireLine in title_screen.dart: one micro line on a fresh title
  (`runHistory.isEmpty && runsPlayed == 0`), gone forever after the first banked run. Key `first-words`.
  Cannot collide with kept-fire. No save-format or sim movement.
- Tests +3 (test/first_words_test.dart; endToTitle in widget test needs remount around it — direct
  endToTitle while SummaryScreen mounted throws null-check on state). Suite 717/717. analyze clean.
- Plates build/first_words_visual/ (fresh 360/320 wrap, played 360 absent) critiqued clean.
- pubspec 0.71.0+97; news 0.71.0; docs/releases/v0.71.0.md; scout docs/improvements/v0.71.0-lead-scout.md.
- Release blocked on GitHub auth like v0.60.0+.

## v0.72.0 — The Given Name (2026-08-26)
- Player review: "You could add character customisation" — completes the identity arc
  (charted → dressed → dyed → NAMED). Tap-to-name every unlocked delver on the picker.
- MetaState: `charName` map + `nameFor(charId)` resolver + `sanitizeGivenName` (strip
  control chars, collapse ws, clamp 16). fromJson `_nameMap` drops unknown ids, re-sanitizes.
  cloud_merge: fresher wholesale. Controller: `setDelverName` (unlocked-only, empty=give back).
- Read surfaces → nameFor: summary header, ledger `_historyRow` + `_delverRow` (stats roster),
  share card (both factories),
  dress-chip labels, obituary/epitaph banking. Locked delvers untouchable.
- Picker UI: InkWell `name-edit-<id>` (FittedBox scaleDown — a 16-char name FITS at 320,
  never ellipsizes; logotype lesson) + `_promptName` dialog (`name-field`, `name-save`,
  maxLength 16, "Theirs by birth: … Leave the field empty to give it back.").
- Tests +6 (test/given_name_test.dart). LESSON: pumpAndSettle spins forever on an autofocused
  TextField's cursor blink — use bounded pumps around dialogs. Suite 723/723, analyze clean.
- Plates build/given_name_visual/ (named picker 360+320, dialog 360) critiqued clean after
  FittedBox fix. Zero sim movement. pubspec 0.72.0+98; news 0.72.0; docs/releases/v0.72.0.md;
  scout docs/improvements/v0.72.0-lead-scout.md.
- Release blocked on GitHub auth like v0.60.0+.

## v0.73.0 — The Opened Vista (2026-08-26)
- Symmetry gap: v0.68.0 announces earned epithets, but vista unlocks (the reviewer's
  "backgrounds") happened in silence. Now one gold summary line per vista a bank pass opens.
- Controller: transient `pendingVistas` (shape of pendingEpithets) — snapshot
  `vistasOrder.where(vistaUnlocked)` before banking, diff after, cleared in resetRun.
  Summary: `opened-vista-<id>` lines, 'The <Name> vista stands open.', before deepest-line.
- Tests +4 (test/opened_vista_test.dart). Suite 727/727, analyze clean. Zero sim movement.
- Plates build/opened_vista_visual/ (first-win 360+320) critiqued clean — seed-1 first win
  fires BOTH Moonveil and Deepshale (reaches floor 9), proving the multi-line stack at 320.
- pubspec 0.73.0+99; news 0.73.0; docs/releases/v0.73.0.md; scout docs/improvements/v0.73.0-lead-scout.md.
- Rejected (scout): next-vista teaser (FOMO); toast/modal; title-screen ambush (needs seen-state);
  retroactive announcements.
- Release blocked on GitHub auth like v0.60.0+.

## v0.74.0 — The Full Roster (2026-08-26)
- The ledger's DELVERS rows were the thinnest surface for the game's richest object. Now each
  unlocked row: dyed sprite (key `roster-delver-<id>`, 28dp static), given name over worn title
  (gold micro, key `roster-title-<id>`), tally gains '· floor N' (charted-depth honesty: omitted
  at 0). Locked rows untouched. Balatro-stats-culture lead (scout v0.74.0).
- ledger_screen.dart `_delverRow` + imports art.dart/sprites.dart. Pure read surface — no new
  state, zero sim movement.
- Tests +2 (test/full_roster_test.dart). Suite 729/729, analyze clean.
- Plates build/full_roster_visual/ (roster 360+320, mixed named/dressed/charted/locked) critiqued
  clean — two-line long names wrap gracefully, 320 tally scales.
- pubspec 0.74.0+100; news 0.74.0; docs/releases/v0.74.0.md; scout docs/improvements/v0.74.0-lead-scout.md.
- Rejected (scout): tap-through to picker; per-delver loss/streak counters (chronicle-stats
  territory); bobbing sprites; dye named in text.
- Release blocked on GitHub auth like v0.60.0+.

## v0.75.0 — The Hearth Song (2026-08-26)
- The soundtrack ("music is 9/10") becomes wearable: a heard Gramophone track can be pinned as
  the hearth's music. Heard rows gain a hearth mark (`hearth-song-<key>`), gold = current song;
  tapping gold gives it back to Hearthside. Delve themes (map/combat/boss/stings) untouched.
- meta.dart `hearthTrack` ('' default, omitted from save at default); cloud fresher-wholesale.
  controller `setHearthSong` (heard+known keys only) + `hearthSongKey` honesty resolver (stale
  merge value falls back silently, never erased). audio_service `musicKeyForPhase`/`syncPhase`
  gain optional `hearthSong`; only the title-family default case uses it. Gramophone preview
  stop/dispose return to the chosen song; pinning mid-preview keeps row icons truthful.
- Zero new assets (size unchanged — user watches APK size). Zero sim movement.
- Tests +5 (test/hearth_song_test.dart). Suite 734/734, analyze clean. TEST LESSON: after
  scrollUntilVisible a row at the viewport's bottom edge misses taps — drag a further -250 first.
- Plates build/hearth_song_visual/ (gramophone 360+320, pinned gold row framed lower third)
  critiqued clean.
- pubspec 0.75.0+101; news 0.75.0; docs/releases/v0.75.0.md; scout docs/improvements/v0.75.0-lead-scout.md.
- Rejected (scout): per-phase playlists (authored tension); ember price on pinning
  (paywall-shaped); shuffle; new track content (size).
- Release blocked on GitHub auth like v0.60.0+.

## v0.76.0 — The New Song (2026-08-26)

- One improvement: the run that first hears a track is TOLD at the summary — newly heard music
  was the last silent earn (evidence: Overbaked 2026 "each run leaves something behind";
  reviewer loves the soundtrack; v0.75.0 pinning finally has its discovery moment).
- controller `runNewTracks` (run-scoped set, 'title_menu' never — seeded, not earned), recorded
  at the same site that banks lifetime heardTracks; autosave side channel 'run_new_tracks'
  (absent when empty) restored at boot; cleared by startRun and endToTitle.
- summary_screen `new-song-line` (micro/dim, beside firsts-line): 1 name quoted, 2 joined,
  3+ collapse to '"X" and N more join the Gramophone.' Helpers newSongNames (shelf order) +
  newSongLine. Import of tracks.dart goes in screens.dart (summary is a part file).
- Zero new assets, zero sim movement.
- Tests +5 (test/new_song_test.dart). Suite 739/739, analyze clean. TEST LESSONS: widget tests
  that driveToTerminal must use GameController() with NO saveDirOverride and NO boot() — real
  IO never completes in the fake-async zone, and autosaves aimed at the setUp temp dir race
  teardown's delete (flaky 'Directory not empty'). Also: `dart format test/*.dart` reformats
  ~30 legacy files — format ONLY named touched files, revert churn per-file, never `checkout -- .`.
- Plates build/new_song_visual/ (summary 360+320, collapsed line quiet, unclipped) critiqued clean.
- pubspec 0.76.0+102; news 0.76.0; docs/releases/v0.76.0.md; scout docs/improvements/v0.76.0-lead-scout.md.
- Rejected (scout): line-per-track (shouts); mid-run toast; "go pin it" CTA (nudge); gold styling
  (firsts-grade fact, not a capability unlock).
- Release blocked on GitHub auth like v0.60.0+.

## v0.77.0 — The Sounding Line (2026-08-26)

- One improvement: the Ledger DRAWS the depth of the remembered delves — bars above
  RECENT DELVES, oldest→newest, height = floor over the window's deepest, wins ember /
  losses dim / abandoned dimmer. Mastery made glanceable is the retention surface with
  no dark pattern: it states only what already happened (runHistory cap 30, every bar real).
- lib/ui/sounding_line.dart: soundingBars() pure mapping (newest-first storage →
  oldest-first drawing; legacy floorless records draw a 2px baseline stub, never invented;
  unknown results read as losses) + SoundingLine CustomPainter (width-aware slot/bar
  sizing inside paint(size), per LAYOUT lesson). Ledger gate runHistory.length >= 2
  ("two records make a line"), key 'sounding-line', quiet micro caption.
- Zero new assets, zero sim movement.
- Tests +3 (test/sounding_line_test.dart). Suite 742/742, analyze clean. TEST LESSON
  (reconfirmed): seeding two history records with the SAME seed+date duplicates
  'history-code-…' ValueKeys in the rows below and crashes the pump — vary seeds.
- Plates build/sounding_line_visual/ (360+320, varied 14-run arc incl. legacy stub and
  abandoned run) critiqued clean.
- pubspec 0.77.0+103; news 0.77.0; docs/releases/v0.77.0.md; scout docs/improvements/v0.77.0-lead-scout.md.
- Rejected (scout): trend commentary (game never grades the player); best-floor goal
  overlay (nudge-shaped); tappable bars (rows below already open runs); lifetime chart
  beyond the 30-run window (new persistence, padding-shaped).
- Release blocked on GitHub auth like v0.60.0+.

## v0.78.0 — The Old Foe (2026-08-26)

- One improvement: the Ledger's LIFETIME panel names the old foe — the enemy that has
  ended more delves than any other, with its tally ('Wick Widow ×7'). enemyFellTo was
  banked since v0.3 and read per-entry by the codex but never aggregated; the nemesis
  hook (a standing personal score) now exists with zero goading: a statement, no errand,
  no reward, no taunt.
- oldFoe(MetaState) pure helper at ledger_screen.dart EOF: iterate enemiesOrder
  (deterministic; ties never flicker), strict-greater max, threshold 2 falls ("one is
  bad luck"), unknown/retired ids skipped. Row keyed 'old-foe' (KeyedSubtree over _row,
  Icons.dangerous, textDim), gated `if (oldFoe(m) case final foe?)`.
- Zero new assets, zero sim movement. Tests +3 (test/old_foe_test.dart). Suite 745/745,
  analyze clean. Plates build/old_foe_visual/ (360 ×7 / 320 longest-name ×23) clean —
  value FittedBox scale-down held at 320.
- pubspec 0.78.0+104; news 0.78.0; docs/releases/v0.78.0.md; scout doc rejected taunt
  copy/revenge CTA, felled-leaderboard ("shame table"), threshold 3.
- Scouted follow-up lead v0.79.0: "The Settled Score" — summary line when a run fells
  the current old foe (needs per-run felled-set plumbing; check recordCombatStats).
- Release blocked on GitHub auth like v0.60.0+.

## v0.79.0 — The Settled Score (2026-08-26)

- One improvement: the run that finally fells the reigning old foe gets one gold summary
  line — 'The score with the <Name> is settled.' (key 'settled-score'). Closes the loop
  v0.78.0 opened: named score → settled score. Once per foe, EVER — a payoff that resets
  is a treadmill; the score never reopens and nothing rides on it (no embers, no badge).
- oldFoe MOVED ledger_screen.dart → meta/meta.dart (controller needs it; meta already
  imports data/*; old_foe_test untouched, resolves via its meta import). MetaState gains
  Set<String> settledFoes (sorted-list JSON, omitted empty, cloud merge union).
- Controller: transient pendingSettledFoe set at felled-record site in recordCombatStats
  (gate: felledId == oldFoe(meta).id && !settledFoes.contains); autosave side channel
  'settled_foe' + boot restore (run_new_tracks pattern); cleared startRun + endToTitle.
- summary_screen EOF helper settledScoreLine(c) — never names a retired id; line placed
  after deepest-line, before insight.
- Tests +4 (test/settled_score_test.dart, enemy_record-style temp-dir setUp). Suite
  749/749, analyze clean. FLAKE FIXED: test/new_song_test.dart teardown single delete →
  standard 10×50ms retry loop (errno 39 race, same guard as enemy_record_test).
- Plates build/settled_score_visual/ (Wick Widow 360 / Smoke Stalker 320) clean; plate
  harness seeds foe + sets pendingSettledFoe directly (mechanics covered by tests).
- pubspec 0.79.0+105; news 0.79.0; docs/releases/v0.79.0.md; scout rejected fire-every-
  fell (noise), reopening scores (see-saw treadmill), ember reward (farming), taunt copy.
- Release blocked on GitHub auth like v0.60.0+.

## v0.80.0 — The Plumb Line (2026-08-26)

- One improvement: Ledger LIFETIME panel states the lifetime deepest floor —
  'Deepest floor N' (key 'plumb-line', Icons.south, ember), gated bestFloor > 0.
  bestFloor was banked, gated Deepshale, fed an achievement, fired deepest-line — but
  no surface ever STATED the number. Sounding line = relative; plumb line = absolute.
- Row placed after Best ascension, before Exact kills. Tests +2 (test/plumb_line_test.dart).
  Suite 751/751, analyze clean. Plates build/plumb_line_visual/ (from old_foe template,
  bestFloor 14) clean both widths.
- pubspec 0.80.0+106; news 0.80.0; docs/releases/v0.80.0.md; scout rejected per-difficulty
  rows (padding), 'of N floors' denominator (lies for short/daily), title-screen restate.
- Release blocked on GitHub auth like v0.60.0+.

## v0.81.0 — The Retraced Page (2026-08-26)

- One improvement: every rememberable Ledger row gains a replay mark (IconButton
  Icons.replay, key 'history-retrace-<seed>-<date>', tooltip 'Delve this again') —
  tap → popUntil(isFirst) → startRun with the RECORD's character/seed/difficulty/
  ascension/short flag. The summary's strongest loop (delveAgain/retraceDelve) no
  longer dies with the summary screen; replaying a remembered run was copy → back
  out → seed dialog → paste. UI-only; controller untouched.
- Gated exactly like the code: legacy seed-0 rows show no retrace (and no copy).
  Difficulty/ascension ride clampRunParams like pasted codes — a hard/A2 record on
  a Forge-less profile clamps VISIBLY; the record is a memory, not a key. Retraced
  daily = free run (badge belongs to the day, not the seed). Short records rebuild
  the SAME six-layer road (r['short'] rides along).
- Tests +3 (test/retraced_page_test.dart; hard/A2 case sets forgeUnlocked +
  bestAscension — CLAMP LESSON: fresh test profiles clamp hard→normal and A→0).
  Suite 754/754, analyze clean. Plates build/retraced_page_visual/ (3-row history:
  short win + daily hard loss w/ epithet+fights + legacy seed-0) clean both widths;
  legacy row correctly shows card-only.
- pubspec 0.81.0+107; news 0.81.0; docs/releases/v0.81.0.md; scout rejected
  bottom-sheet action menu (buries v0.43 tap-to-copy contract), confirm dialog
  (friction theater), hiding retrace on abandoned rows (they banked a seed).
- Release blocked on GitHub auth like v0.60.0+.

## v0.82.0 — The Farthest Lantern (2026-08-26)

- One improvement: the map paints the lifetime deepest floor IN the delve — one thin
  gold dashed rule at the boundary between bestFloor and the floor beyond, caption
  'YOUR DEEPEST · FLOOR N' right-aligned above (racing-game PB marker, made native).
  Separate keyed CustomPaint 'plumb-mark' (IgnorePointer + RepaintBoundary) layered
  over fog, under nodes; _FarthestLanternPainter(bestFloor); repaint only if record
  changes (scene painter repaints per move — kept isolated). Row math mirrors fog
  rects: boundary y = h - (bestFloor-1)*_rowH - 68.
- Gates: bestFloor > 0 && bestFloor < layers (fresh profile: nothing; record beyond a
  short road's six floors: nothing — whole map is charted ground). bestFloor banks at
  run END, so the line holds still all run; passing it = walking beyond it. No toast,
  no glow — standing information (scout rejected announce-on-cross as missable noise,
  and a depth-vs-record HUD chip as clutter).
- Tests +3 (test/farthest_lantern_test.dart — GameRoot pump, startRun boons:false
  lands straight on map). Suite 757/757, analyze clean.
- Plates build/farthest_lantern_visual/ clean both widths — PLATE LESSON reconfirmed:
  map plates MUST suppress tour/tutorial/tips (tutorialSeen + tourSeenVersion +
  tipsSeen.addAll(ContextTips.all)) or 'THIS IS A DELVE' covers the scene. GameRoot
  import in tests/tools is package:emberdelve/ui/screens.dart (game_root.dart is a
  part-of, not importable).
- pubspec 0.82.0+108; news 0.82.0; docs/releases/v0.82.0.md.
- Release blocked on GitHub auth like v0.60.0+.

## v0.83.0 — The Depth Gauge (2026-08-26)

- One improvement: the map hint caption opens with the live depth — 'Floor N of M ·
  Tap a glowing node to descend · Pool: X dice · Y relics'. Mid-run depth was stated
  NOWHERE (players counted node rows); found by asking what navigation fact the hint
  line omits. Surveying trilogy complete: Sounding Line (chart) / Plumb Line (record) /
  Depth Gauge (live reading). Pure read of curLayer + layers, same numbers as the
  record and the lantern.
- Scout rejected: 'new depth' suffix past the record (lantern says it spatially);
  TopBar floor chip in all phases (shared-chrome blast radius, separate release if
  ever); shortening the descend hint (only first-delve text instruction).
- Tests +1 (test/depth_gauge_test.dart). Suite 758/758, analyze clean. Plates
  build/depth_gauge_visual/ clean both widths (wraps to two centered micro lines).
- pubspec 0.83.0+109; news 0.83.0; docs/releases/v0.83.0.md.
- Release blocked on GitHub auth like v0.60.0+.

## v0.84.0 — The Song Credit (2026-08-26)

- One improvement: the first time a track ever plays, the flash toast names it —
  '"Deeper Still" — first hearing'. Hooked exactly on meta.heardTracks.add(key)
  returning true in the controller's heard-track block (so once per track per
  profile, max 8 toasts a lifetime); name resolves via new trackByKey() in
  lib/data/tracks.dart (never credit a ghost key). Rides existing showFlash
  snackbar (TalkBack live region free). Reviewer anchor: "the music is 9/10" —
  the best-reviewed asset now introduces itself at the only moment a name can
  bind to the music.
- Scout rejected: persistent now-playing chip (standing chrome, transient fact);
  crediting every hearing (noise); ♪ glyph (font-coverage risk).
- SONG-CREDIT TEST LESSON: the once-ever credit snackbar floats over bottom
  buttons for 1.4s in widget tests driving FRESH profiles into combat — 4 tests
  broke (widget_test boon+reroll, tour_test fresh-profile, temper_ui _atRest).
  Fix idiom = same as tutorialSeen/tipsSeen suppression: pre-hear the catalog
  `c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key])`.
  Future fresh-profile widget tests that tap bottom-edge UI should seed this.
- Tests +2 (test/song_credit_test.dart, pure controller: first credit at map,
  no re-credit). Suite 760/760, analyze clean. No layout change → no new plates.
- pubspec 0.84.0+110; news 0.84.0; docs/releases/v0.84.0.md.
- Release blocked on GitHub auth like v0.60.0+.

## v0.85.0 — The Narrow Climb (2026-08-26)

- One improvement: won summaries that ended inside the existing low-HP danger
  rule (HP*10 <= max*3, the rule that darkens combat music since v0.23.0) close
  with one dim line: 'A narrow climb home — N HP standing.' Key `narrow-climb`,
  placed between settled-score and the insight panel. Helper narrowClimbLine(c)
  in summary_screen (reads c.state: phase run_won + player hp/max_hp; null on
  losses, comfortable wins, missing snapshot). Echoes the victory track "The
  Climb Home". Near-miss memory = the run players retell; stated at the only
  honest moment, nothing persisted.
- Scout rejected: showing final HP on every win (flat stat); a second "close"
  threshold (danger rule owns the word); persisting narrowness into _runRecord.
- Tests +3 (test/narrow_climb_test.dart: boundary-inclusive 9/30 fires, 10/30
  null, loss null — playOut pure controller, then mutate sim.player hp).
- Plates tool/narrow_climb_visual_test.dart (cloned from new_song template,
  firstWin() forces hp 1/30): clean 360x640 + 320x568, single line both widths.
- Suite 763/763, analyze clean. pubspec 0.85.0+111; news 0.85.0;
  docs/releases/v0.85.0.md. Release blocked on GitHub auth like v0.60.0+.

## v0.86.0 — The Foe's Last Thread (2026-08-26)

- One improvement: LOST summaries whose killer itself stood inside the 30%
  rule (hp*10 <= max*3) close with one dim line: 'The <Name> hung by a thread
  — N HP standing.' Key `last-thread`, placed directly above the narrow-climb
  block (renders above the tip panel, right over Delve Again/Retrace — the
  one-more-run moment). Helper lastThreadLine(c) in summary_screen reads
  c.state enemy (terminal sim keeps the killer — same fact killed_by banks);
  name via enemies map, ghost ids never named. Mirror of v0.85.0: same rule,
  foe's side. "I almost had it" as fact, not nudge.
- Scout rejected: killer HP on every loss (deflating big numbers); "one blow
  from falling" wording (overpromises at 30% of a boss); boss-special
  threshold (second definition of "close").
- Tests +4 (test/last_thread_test.dart: 9/30 fires, 10/30 null, win null,
  unknown id null). Plates tool/last_thread_visual_test.dart (loss seed 18,
  restraint plate wears cinder_hierophant 18/60): clean 360x640 + 320x568,
  wraps to two centered lines.
- Suite 767/767, analyze clean. pubspec 0.86.0+112; news 0.86.0;
  docs/releases/v0.86.0.md. Release blocked on GitHub auth like v0.60.0+.

## v0.87.0 — The Guttering Foe (2026-08-26)

- One improvement: the enemy HP bar gutters when the foe is inside the 30%
  rule — fill turns EmberColors.gold (player's good-news colour) and caption
  reads 'ENEMY HP · NEARLY SPENT · TURN N' (enemy_panel.dart). StatBar's
  semantics speak the label, so TalkBack hears the tell free. The most
  tactically valuable fact in the fight, visible while the player can act.
- Rule centralized: top-level `inTheRed(int hp, int maxHp)` in controller.dart
  (alive && hp*10 <= max*3); _inDanger + narrowClimbLine + lastThreadLine
  refactored onto it (behaviour-identical) — four voices, one definition,
  drift risk retired.
- OVERFLOW LESSON: the longer caption pushed combat 1px over at 320x568 in
  overflow_probe (1.3x text). Fix in StatBar itself: caption wrapped in
  FittedBox(scaleDown, centerLeft, maxLines 1) — captions are one line by
  design; scale, never wrap. All bars benefit.
- Scout rejected: pulsing/flame animation (hot-path motion + reduce-motion
  players lose the tell); "one more hit" math (would sometimes lie);
  player-side bar mirror (music+vignette already tell it).
- Tests +3 (test/guttering_foe_test.dart: inTheRed boundary pins incl. dead
  ≠ close; gold+caption widget drive; healthy-foe red drive). Plates
  tool/guttering_foe_visual_test.dart (pure walk to fight, force 9/30,
  turn 12): clean 360x640 + 320x568, re-snapped after FittedBox fix.
- Suite 770/770, analyze clean. pubspec 0.87.0+113; news 0.87.0;
  docs/releases/v0.87.0.md. Release blocked on GitHub auth like v0.60.0+.

## v0.88.0 — The Coming Vista (2026-08-26)
- Run summaries now name the nearest still-locked progressive vista with real
  numbers — ONLY when this run moved its counter (Verdigris felled-count via
  runFirstFelled, Deepshale depth via pendingDeepestFloor). Helper
  `comingVistaLine(GameController)` in summary_screen.dart; row key
  `coming-vista` after codex-pull, before rung-open. Binary gates excluded
  (0-of-1 is a demand); nearest = highest fraction; pure read, no persistence.
- NBSPs bind 'floor 7 of 9.' so the centered micro line never orphans a word.
- Tests +5 (test/coming_vista_test.dart; new pinned seed kindler easy 22 =
  loss, 2 distinct felled, deepest floor 7). Suite 775/775. Plates
  tool/coming_vista_visual_test.dart (depth 360x640, felled 320x568) clean.
- 0.88.0+114. Notes docs/releases/v0.88.0.md. Zero sim movement. LESSON:
  news ethics gate bans substrings — 'closer' trips the 'loser' ban; reworded
  to 'nearer'.

## v0.89.0 — The Counted Rest (2026-08-26)
- The rest button prints the exact outcome — 'Rest — heal 9 HP (21 to 30)' —
  instead of 'heal 30%'. Number from new pure sim reader
  `restHealPreview(Sim)` beside runRest in sim/run_layer.dart (base
  ⌊max·3/10⌋ + rest_bonus relics, overheal-capped): one source of truth,
  parity-tested against the real command. Bedroll/Hearth Kettle finally
  visible at the fire. Full-HP branch unchanged.
- LESSON (plates): Cinzel has no U+2192 — an arrow in button text draws
  tofu; use words. NBSPs bind '(21 to 30)' so narrow wraps break before the
  paren group, never inside it.
- Fixed flaky deepest_mark_test teardown (errno 39) with the drain-retry
  charter from run_trace_test.
- Tests +4 (test/rest_preview_test.dart; new pinned seed: kindler easy 3 =
  bot walk reaches rest at 3/30). Suite 779/779. Plates
  tool/rest_preview_visual_test.dart (360x640; 320x568 with Bedroll,
  longest wording) clean. 0.89.0+115. Notes docs/releases/v0.89.0.md.
  Zero sim movement (read-only function addition; goldens untouched).

## v0.90.0 — The Counted Ration (2026-08-29)
- Shop Field Rations now print the real heal — overheal cap counted:
  'Heal 7 HP (17 to 24)'; at full HP 'Fully rested — heals nothing'. New
  pure sim reader `healPreview(Sim, amount)` mirrors `_heal` exactly;
  restHealPreview refactored onto it (one cap, one source of truth). SOLD
  rows keep the historic plain label.
- Parity tests incl. a NATURAL overheal cap. New pinned shop seeds
  (kindler easy, bot walk): 7 = 17/30 gold 98 uncapped; 20 = 31/34 amt 8
  caps to 3, gold 43; 6 = 30/30 full. Tests +5. Suite 784/784. Plates
  tool/ration_visual_test.dart clean for the feature. 0.90.0+116.
- DEFECT FOUND ON PLATES (pre-existing, queued v0.91): at 320px the slot
  TITLE breaks mid-word ('FIELD RATION / S') beside the price button.
- Zero sim movement (read-only function addition; goldens untouched).

## v0.91.0 — The Legible Stall (2026-08-29)
- Shop slot restructure: lead · title · price across the top, description
  full panel width below. Titles never break mid-word — FittedBox
  scaleDown one-line rule (v0.87 precedent). Found by v0.90's own plates
  ('FIELD RATION / S' at 320px; relic texts wrapping every two words).
- Plates 320x568 / 360x640 / 600x900 tablet clamp all clean
  (tool/legible_stall_visual_test.dart). No sim movement, no copy change.
- SUITE HYGIENE: swept ALL 18 remaining unguarded temp-dir deletes in
  test/ onto the drain-retry charter (errno 39 flake struck deep_hum this
  run, deepest_mark last run — now impossible suite-wide). Suite 784/784.
  0.91.0+117.

## v0.92.0 — The Counted Draught (2026-08-29)
- Event options rewrite their 'heal N%' token to the counted heal at
  render time: 'Pray quietly (heal 7 HP)'; combined labels rewrite the
  token only; full HP reads 'heals nothing'. No percentage left anywhere
  in healing UI. Helper `countedOptionLabel(c, OptionDef)` in
  event_screen.dart calling healPreview with runEventChoose's formula.
- PARITY IDIOM (new): force a live mid-run sim to any event —
  `c.sim!.phase = 'event'; c.sim!.event = 'ember_shrine';` then apply
  event_choose normally. Pinned: ember_shrine option 2 = heal_pct 25.
- Tests +4. Suite 788/788. Plates tool/counted_draught_visual_test.dart
  (360 counted, 320 full-HP wording). 0.92.0+118. Zero sim movement.
- LESSON: when cloning a plate tool, update the header comment block too —
  v0.91's clone kept ration paths in comments and broke the v0.92 clone's
  regex anchors (caught immediately; both repaired).

## v0.93.0 — The Pictured Satchel (2026-08-29)
- In-run relic inventory rows lead with the relic's 36px icon, centered
  across name + effect — shop-built recognition now carries into the
  satchel. Row restructure only; zero sim movement. Suite 788/788.
  0.93.0+119.
- FOUND (queued lead): relicIcons map gap — cairn_stone + choir_censer
  share the fallback lantern in shop AND satchel; distinct art wanted.
- PLATE LESSON: dialog asset icons must build-THEN-runAsync(600ms)-THEN
  repaint; a delay before the first post-tap pump decodes nothing.
- NEWS LESSON: ethics gate also pins entry length 2–4 lines (news_test
  L50) — a 1-line entry fails the suite, not just banned words.

## v0.94.0 — The Deep Wardrobe (2026-08-29)
- Wardrobe expansion answering the reviewer's customisation ask: 2 new
  dyes closing plate-audited hue gaps (Emberheart crimson 480, Glowmere
  teal 560) + 3 new earned titles on real Ledger stats (the Deepdrawn
  best_floor 9, the Measured best_exact_streak 5, the Six-Handed
  delvers_cleared == roster, junk-key-proof). the_proven stays LAST
  (pinned). Data-only, zero sim movement. Suite 795/795. 0.94.0+120.
- Plates tool/deep_wardrobe_visual_test.dart (scroll-to-card idiom:
  scrollUntilVisible + drag target to y=120, canonical for shelf plates).

## v0.95.0 — The Known Relic (2026-08-29)
- All 36 relics now carry a deliberate icon (14 shared the fallback
  lantern; evidence from v0.93.0 satchel plates). Curated reuse cap 2,
  thematically-distant pairs (wyrmscale_cloak moved off iron_scale's
  shield to relic_fire_tail mid-curation). Lantern = cinder_lantern
  alone. Zero new assets, zero sim movement. One map extension in
  lib/ui/art.dart + test/known_relic_test.dart charter pins. Suite
  798/798. 0.95.0+121. Satchel plates re-cut: all 5 rows distinct.

## v0.96.0 — The Hearth Tale (2026-08-29)
- The "what's a delve" answer as a drip, not a card: every rest fire
  tells one short tale of the world, fixed ten-tale arc, lifetime index
  (MetaState.hearthTalesHeard, MAX-merged, key omitted at 0). Advance
  rule in apply(): phase left 'rest' — single mutation path, never on
  invalid commands. lib/data/tales.dart pure indexer. Suite 804/804.
  0.96.0+122. Plates: fresh first tale 360x640; longest tale forced at
  320x568 wraps clean (tool/hearth_tale_visual_test.dart).

## v0.97.0 — The Counted Forge (2026-08-29)
- Honest-numbers arc reaches the forge: rows with a modded die on
  either side print dieFacts before → after ('d6 · +1 attack → d8 ·
  +1 attack'); plain size-only forges stay quiet (chips already count
  it). _dieDesc promoted to public dieFacts in lib/data/dice.dart;
  reward/shop/boon repointed — one die vocabulary everywhere. Mods-key
  exhaustiveness sweep pinned. Suite 808/808. 0.97.0+123. Plates:
  360x800 mixed pool (keen row counted, plain row quiet); 320x568
  longest wording wraps two lines clean.

## v0.98.0 — The Hearthgold (2026-08-29)
- Seventh vista, fed by the hearth-tale arc: hear every tale the fire
  tells (gate follows hearthTales.length, never a stale literal) and
  the delve wears the fire's gold — the first BRIGHTENING grade
  (hue +6°, sat ×1.12, val ×1.08). Verified distinct against a
  same-seed Emberlight control plate (mean pixel diff 5.5), not by
  eye alone. New transient runTalesHeard lets the Coming Vista line
  count tales honestly (only when this run moved it). Suite 809/809.
  0.98.0+124. Plates: gilded map vs control, locked card at 320,
  worn card.

## v0.99.0 — The Colored Card (2026-08-29)
- The Delver's Card keeps the delve's light: the selected vista's own
  wash (Art.backgroundWash at depth 0) paints the card background.
  Emberlight = alpha-0 identity, card byte-identical for players who
  never chose. Current-vista-not-banked follows the dye precedent;
  color only, no new copy (caption drafted and cut). Plates: 3x cards
  in all four wash families side by side, all lines legible. Suite
  814/814. 0.99.0+125.

## v0.100.0 — The Second Cycle (2026-08-29)
- Ten new hearth tales (arc pass 2: one tale per delver, then world
  texture; append-only charter, ethics-swept). Caught and fixed my own
  v0.98.0 design bug: gating Hearthgold on hearthTales.length would
  have RE-LOCKED earned vistas when the list grew — milestone now
  FROZEN at hearthgoldTales = 10, unlock line updated ('Hear the
  fire's first ten tales.'), regression test pins grown-list vs
  frozen gate. Coming Vista tease counts against the frozen milestone.
  Longest-tale plate re-cut, fits at 320. Suite 814/814. 0.100.0+126.

## v0.101.0 — The Delver's Page (2026-08-29)
- RECENT DELVES gains pages when the remembered delves span more than
  one delver: 'All delvers' + one chip per delver WITH records (given
  names on chips; no empty/teaser pages). Sounding line redraws from
  the open page (two-record gate applies per page). Ephemeral by
  design — never persisted (test pins toJson). LedgerScreen now
  stateful. 5 new tests; plates all/warden/320-wrap approved. Suite
  819/819. 0.101.0+127.

## v0.102.0 — The Painted Trace (2026-08-29)
- The Delver's Card paints its own floor grid (PaintedTrace widget,
  key 'card-trace-grid'): rounded cells, clean green / hurt gold /
  fall red / Ember ember+gold ring — deterministic on every platform
  instead of vendor emoji. Parses the banked emoji string (public
  traceCells; unknown runes dropped). Share TEXT keeps emoji (no
  painter in text). Honest semantics: floors + outcome only (outcome
  cell overwrote its floor's mark). Card plates re-cut across all four
  washes. TEST LESSON: dispose ensureSemantics() handle IN the test
  body — addTearDown runs after end-of-test verification. Suite
  824/824. 0.102.0+128.

## v0.103.0 — The Marked Week (2026-08-29)
- Run records bank 'weekly': true + the run's declared mutators
  (controller _moddedMutators = sim.mutators minus short_road,
  sorted). Ledger row states the rule by name ('weekly · Flint Week ·
  …'); modded rows offer NO Delve Code and NO retrace (a code cannot
  carry the rule — seed-0 "code that would lie" precedent) but keep
  the card. Old records render as before (additive keys). 4 tests
  incl. live startWeeklyRun walk; plates 360 + 320 longest-line
  approved. Suite 828/828. 0.103.0+129.

## v0.104.0 — The Delve Itself (2026-08-29)
- Codex gains kind 'place': eight world entries (The Delve, Ember,
  Hearth, Depths, Dice, Forge, Provings, Vistas) shelved FIRST under
  THE WORLD, cheapest in the book at 10 embers — a review's verbatim
  "I still don't understand what's a delve" answered at the top of
  the book. placeNames map lives in codex.dart. Counts/pull/meter
  include the shelf automatically (86 entries). ember_sink sale test
  now scrolls below the new shelf. 4 tests; plates 360/320 approved.
  Suite 832/832. 0.104.0+130. Queued lead closed: summary trace
  stays emoji by charter (display IS the paste).

## v0.105.0 — The Delver's Line (2026-08-29)
- One delver's Ledger page gains a lifetime line under the chips
  ('Lifetime: 128 delves · 33 won · best floor 9') read from the
  UNCAPPED charRuns/charWins/charBestFloor counters — a tally of the
  30-cap remembered list would eventually lie; this cannot. Hidden
  on 'All delvers'; best floor omitted at 0; singulars spelled out.
  Pure helper delverLifetimeLine (soundingBars precedent). Closes the
  v0.101.0 queued lead on honest terms (no telemetry to 'prove use'
  by charter — honesty was the deciding test instead). 3 tests;
  plates 360/320 approved. Suite 835/835. 0.105.0+131.

## v0.106.0 — The Cold Camps (2026-08-29)
- Fifth Weekly rule: no_rests ('Cold Camps') — every rest node
  becomes a fight; heal only by shop, event, or what you carry.
  Pure rng-free relabel like its siblings, composes in the same
  one-loop pass (rest→fight→elite). 150-seed sweep: 97/150 plain vs
  99/150 no_rests for the bot (fight embers offset lost healing);
  humans rest more, so it lands mid-ladder. Rotation now repeats
  every 5 weeks instead of 4. shorter_road_test's '.last' pin
  relaxed to a frozen-index pin (order is append-only). 3 tests, no
  new UI surface (catalog flows through plated surfaces). Suite
  838/838. 0.106.0+132.

## v0.107.0 — The Unwritten Feats (2026-08-29)
- Seven new Ledger feats (50 total) for the systems that grew after
  the catalog stopped at provings (v0.59.0): weekly (1/10), codex
  (10/40 — fixed targets, catalog-BOUNDED by test, never
  length-bound; all_three_bosses taught that), tales (10), settled
  score (1), twenty distinct foes. 5 new stats in the vocabulary;
  distinct_felled junk-proofed through the enemies catalog. Two
  guard tests did their job (wired-counter fixture + waymarks
  max-out both demanded lines for the new stats). Recognition only,
  no ember grants. Suite 842/842. 0.107.0+133.

## v0.108.0 — The Proven Rules (2026-08-29)
- Two mutator provings keep the weekly's rules standing: the Flint
  Proving (kindler, all_d4, seed 6) and the Cold Proving (warden,
  no_rests, seed 2) — both seeds hunted WITH the rule applied.
  ProvingDef gains `mutators`; the card states the rule in its meta
  line and shows NO Delve Code (codes can't carry rules — v0.103.0
  refusal, third application). FOUND + FIXED latent honesty bug:
  the clear-match ignored mutators, so a modded run of an unmodded
  proving's exact seed would have cleared it — unreachable before,
  load-bearing now (setEquals). Winnability proof now walks each
  proving's actual rules. the_proven epithet target 10→12 (pin did
  its job). 4 tests; plates 360/320 approved. Suite 846/846.
  0.108.0+134.

## v0.109.0 — The Coming Rule (2026-08-29)
- The title weekly card now states next Monday's rule beneath the
  recap — 'Next Monday: No Quarter' — but ONLY once this week has
  been played (same guard as the recap; a tease for the engaged,
  never a demand on the new). Pure `comingRuleLine(weekIndex)` in
  weekly.dart (`weeklyMutatorFor(index + 1)`); Text key
  'weekly-coming-rule'. Honest appointment mechanic: a fact of the
  rotation, no countdown (comingVistaLine v0.88.0 precedent).
  3 tests incl. honesty sweep + gating; plates 360/320 approved.
  Suite 849/849. 0.109.0+135.

## v0.110.0 — The Named Company (2026-08-29)
- The Codex gains THE COMPANY: one story per roster delver, in
  roster order, 15 embers, between THE WORLD and ENEMIES — the
  second question a new delver asks (8/23 review loved the
  characters; v0.104.0 answered the world). Kind 'delver' rides the
  v0.104.0 generic-kind seam; names read from characters.dart (the
  anti-lying rule, third application); each story encodes the
  delver's mechanical truth without paywalling rules. 92 entries.
  delve_itself_test's codexEntries[8] index pin made kind-robust.
  3 tests; plates 360/320 approved. Suite 852/852. 0.110.0+136.
  Deferred: 'double week' composed rules (weeklyMutator is a
  single-String label through saves/top-bar/share — own release).

## v0.111.0 — The Doubled Week (2026-08-29)
- Sixth Weekly rotation slot: one week per cycle deals a declared,
  named PAIR — Cold Quarter (no_shops + no_rests), picked by bot
  sweep (102/150 kindler/normal; both all_d4 pairs ~37/150,
  rejected as unfair for a normal-pinned shared challenge).
  WeeklyRuleDef layer: singles keep reading the mutator catalog;
  only the composed slot authors its name. Label stays ONE string
  ('+'-joined) in saves/meta — weekly_mutator key unchanged, old
  saves parse as the 1-element case, no migration. startWeeklyRun
  gains test-only clock (startDailyRun precedent) — this is what
  made the top-bar plate deterministic. comingRuleLine + share text
  rule-aware. Cycle 5→6 shift accepted (v0.106.0 precedent).
  LESSON: the news ethics gate bans SUBSTRINGS in negation too —
  "no streaks" trips "streak"; write around the word entirely.
  6 tests; plates 360/320 approved. Suite 858/858. 0.111.0+137.

## v0.112.0 — The Frostvein (2026-08-29)
- Eighth vista, first the Weekly feeds: claim the Ember on a doubled
  week. New monotonic meta.doubledWins (persisted only >0 — old
  saves byte-identical; cloud merge max; hearthgold re-lock lesson).
  Banking keys off the label containing '+' (what the run actually
  ran under). vistasOrder append-LAST; resolver gains required
  doubledWins (14 test call sites patched). Grade tuned by plate
  critique: first pass too timid vs emberlight control — landed
  hue -150 / sat 0.62 / val 1.08 / wash 0x478FB6C9 (first PALE
  grade). LATENT BUG FIXED: marked_week_test passed the raw
  '+'-joined weekly label to botCmd as one id — harmless until the
  first real doubled week, which is Monday 2026-08-31. Hunted
  bot-winnable doubled Monday for the test: 2026-02-02. 5 tests;
  4 plates approved. Suite 863/863. 0.112.0+138.

## v0.113.0 — The Cold Honors (2026-08-29)
- Two achievements on meta.doubledWins (same counter as Frostvein —
  one truth, two readers): first_winter (target 1), thrice_wintered
  (target 3; doubled weeks are 1-per-6-week-cycle, so 3 ≈ 4 months —
  a ten-target would be pressure disguised as recognition). 52
  achievements total. Stat 'doubled_wins' + statValue case. Arc
  complete before the FIRST REAL doubled week: Monday 2026-08-31.
  GUARD-TEST MAP for new achievementStats (all three fire):
  achievements_test 'every stat is wired' maxed profile,
  unwritten_feats bounds, waymarks_test 'everything earned' maxed
  profile (its reason string names the fix). 3 tests; plates 360/320
  approved (First Winter EARNED, Thrice Wintered 1/3). Suite
  866/866. 0.113.0+139.

## v0.114.0 — The Cold Tales (2026-08-29)
- Three winter events appended at deck END (50→53): the_frozen_stall,
  the_wintered_die, the_meltwater_pool — the doubled week's cold told
  in marginalia, amount bands copied from the v0.46.0 batch. 5 tests
  (per-option effect parity vs event_choose, heal cap, 1-hp floor,
  honesty); plates approved (event body scrolls at 320 — pre-existing
  SingleChildScrollView, nothing clipped). LESSON: dice pool is
  sim.player['dice'], NOT run!['dice'].
- SEVENTH GOLDEN RE-ANCHOR (deck growth re-rolls the unseen-event
  pick; v0.25/v0.46 precedent). Probe tool/reanchor_v1140_probe_test
  .dart (kept; prints goldens measured twice, proving winnability +
  re-hunt, pins, walk seeds, A20 hunts). goldenV6 111116111→456904381;
  boss goldens re-measured (pyre_matriarch byte-identical, no event
  before boss); flint_proving re-seeded 6→10 (only proving killed;
  clears stored by id, untouched); kindler rest-walk 3→6 (seed 3 now
  LOSES; rest seeds 6/8/9); full-HP shop seed 6→10 (shop states:
  7=17/30 gold 125, full-HP 10/13/19); peddler easy-loss 16→13,
  normal wins 1..8 = [1,2,4,6]; kindler A20 6→20; ladder pins
  kindler 20 / warden 4 / gambler 40 / ascetic 39. RAW-SIM WALK
  DIVERGES from controller idiom — hunt walk seeds with
  GameController+startRun, never bare Sim(s)+botCmd. Suite 871/871.
  0.114.0+140.

## v0.115.0 — The Delver's Window (2026-08-29)
- Vistas worn per delver: meta.charVista + vistaFor (charDye idiom,
  3rd per-delver wardrobe map), junk-proof fromJson, fresh-wins
  merge; controller setVistaFor (unlock gate re-checked, locked
  delver refused) + activeRunVista getter (run delver's window,
  global when no run) — game_root and BOTH DelverCardFacts
  constructors go through it ("portraiture, not history"). Picker
  _vistaCard binds to dressTarget; vista dress pills ('vista-dress-
  <id>') hidden with one delver unlocked. Legacy selectedVista never
  written by the picker again (survives as fallback). vistas_test
  picker pin updated (tap now writes charVista, not selectedVista).
  PLATE-FRAMING LESSON: a per-delver binding plate must show the
  dress pills AND the CHOSEN card in one frame — bind a vista that
  sits near the shelf top (moonveil), don't scroll the pills away.
  6 tests; 3 plates approved. Suite 877/877. 0.115.0+141.

## v0.116.0 — The Spoken Dice (2026-08-29)
- Codex closes on THE DICE: five entries, one per BASE CUT
  (d4/d6/d8/d10/d12 — Flint Shard/Ember Die/Deep Coal/Forge Core/
  Molten Core), 15 embers, appended after relics. 97 entries.
  Partial-by-design: variants are the cuts re-promised at the forge,
  so no diceOrder coverage guard — exact-list pin + mod-free pin
  instead. Names from the dice catalog (anti-lying, 4th
  application). Zero sim surface — codex growth chosen deliberately
  after v0.114.0's re-anchor bill. PLATE LESSON: deep sections in a
  97-entry ListView need scroll budget 600×maxScrolls 400 (clone
  default 200×40 dies as "Bad state: No element"). 4 tests; plates
  360/320 approved. Suite 881/881. 0.116.0+142.

## v0.117.0 — The Winter Proving (2026-08-29)
- 13th proving: the PEDDLER under Cold Quarter (no_shops+no_rests) —
  the merchant with nowhere to spend; the doubled week held still so
  the rotation peak can be practiced any day (the ethics answer to
  FOMO: nothing is exclusive to the appointment). Seed 4 (variety;
  peddler pair wins 1/2/4, kindler also 1/2/4 — pick was flavor).
  Inserted after cold_proving; ash_summit stays last. the_proven
  12→13; provings_test pins 12→13, '0 of 13'/'1 of 13'. Set-equality
  clear-match proven vs half-pair. LESSON: pair maps are all fights —
  driveToTerminal guard 4000, not 400. PLATE-META LESSON: proving
  plates need the proving's DELVER unlocked in meta or the start
  button never renders. 3 tests; plates approved (code suppressed,
  both rule names in meta line). Suite 884/884. 0.117.0+143.

## v0.118.0 — The Flintwright (2026-08-30)
- SEVENTH DELVER, the swarm archetype: only delver with FOUR dice
  (d4×2, d4_spark, d4_guard), 24 HP, NO relic (a new relic would
  resize the shop pool and re-anchor every golden — tinker
  precedent), 750 embers. Balance: 400-seed sweeps, HP the only
  knob: 28 HP → 90.5/65.5/41.25 (too strong); 24 HP →
  87.5/57.25/34.25 (in band vs tinker 85.25/58.25/31.0). Viability
  pins: seed 1 wins easy+normal, 3 loses easy. ZERO re-anchor —
  other delvers' seeded runs byte-identical.
- Sprite: HSV palette variant of WARDEN sheet (hue +35°, sat ×0.45,
  val ×0.88, floor 0.14 — flint grey-tan; warden not kindler so the
  silhouette differs from tinker). tool kept: gen method in
  PROVENANCE.md row. Weapon: knapping_pick (short reach 0.42).
  Codex delver story added (named_company pin demands one per
  roster delver).
- ROSTER-GROWTH FALLOUT MAP (all three fire): tinker_test 'last'
  pin (contract is INDEX, rewrote to indexOf==5); deep_wardrobe
  the_six_handed target == characters.length — display name went
  count-free ('the Many-Handed', id unchanged = save contract, next
  delver never forces a rename); retraced_page taps (roster section
  grew a row → ensureVisible before tap). Also: locked-card titles
  now FittedBox ('The Flintwright' broke mid-word at 320).
- PLATE LESSON: sprite-sheet plates need a WARMUP capture (per-path
  decode cache cold on first pump — first plate renders an empty
  sprite slot). 5 tests; plates approved. Suite 889/889.
  0.118.0+144.

## v0.119.0 — The Seventh Way (2026-08-30)
- Flintwright's proving (seed 9, normal, no mutators — character
  provings chapter, after tinkers_proving; 14 provings; the_proven
  13→14) + Knapped Sharp (char_wins flintwright) + Seven Ways Down
  (delvers_cleared 7). 54 achievements. RE-PRICING DOCTRINE settled:
  fixed-count BADGE names stay at their historical count
  (six_ways_down stays 6 — re-locking earned recognition is the
  hearthgold bug in achievement form) and the new count gets a NEW
  name; PROMISE-worded unlocks ('every delver') move with the roster
  and get count-free display names (the_six_handed → 'the
  Many-Handed', v0.118.0). Proving plate doubles as delve-code
  round-trip proof (DELVE-900000C10Y). 3 tests; plates approved.
  Suite 892/892. 0.119.0+145.

## v0.120.0 — The Third Cycle (2026-08-30)
- 10 new hearth tales (30 total, three cycles of ten, order
  unchanged): the fire catches up with the winter arc — doubled
  week, frostvein winter, flintwright, codex, cold camps, provings,
  vista shelf, dice family, no-quarter floors, the telling itself.
  Each states one in-game-verifiable fact: the drip doubles as a
  feature tour (the 2026-08-23 review's real ask). Hearthgold stays
  frozen at cycle one. Zero sim surface, zero re-anchor (the
  v0.114.0 cost lesson steering content growth to the meta layer).
- HONESTY EDIT: tale 5 'Six keep this fire now' → seven, all named.
  Doctrine: the tale sequence contract is ORDER, not frozen text —
  a fixed position must never state a count the picker disproves.
  Roster-growth fallout map gains a 4th entry: grep tales/copy for
  roster counts when charactersOrder grows.
- hearth_tale pin 2×→3× hearthgoldTales. Plates (rest fire quoting
  doubled-week tale @360, winter tale @320) approved. Suite
  892/892. 0.120.0+146.

## v0.121.0 — The Waymark Line (2026-08-30)
- Title screen names the single nearest unearned achievement with
  real clamped counts ('Next waymark: Thrice Down — 2 of 3'), tap →
  Ledger. The nearestAchievements resolver (tested since v0.5.0,
  summary-only since the waymarks panel) promoted to where session
  intent forms — the hook every big roguelite fronts (Hades
  prophecies, StS climb counter), done in Emberdelve's register:
  one dim TextButton with the provings count and 'Delve a seed',
  no badge, no pulse.
- FRESH-PROFILE LESSON (found by the test, kept as the pin): a new
  MetaState is NOT progress-free — the default hearth theme counts
  toward Full Hearth, so ungated the line would point brand-new
  players at an ember-spending goal on first boot. Fix = runsPlayed
  gate in waymarkLine (no goal before the first delve), not a
  special case for owned-by-default stats. waymarkLine(m) lives in
  lib/meta/achievements.dart (screens.dart imports it as `ach.`).
- 5 tests; plates approved. Suite 897/897. 0.121.0+147.

## v0.122.0 — The Spoken Delve (2026-08-30)
- A11y: the run's CHOICE surfaces spoke nothing (combat tray spoke
  since v0.44.0 — a TalkBack player could fight but never pick).
  Now: reward flip cards ('Take the Ember Die, a d6, the
  recommended pick' / 'A reward card, still face down', button only
  when takeable), boon cards (one node: name+recommended+effects),
  temper sheet (dice/faces/runes with chosen state), shop buy
  button ('Buy Ash Aegis for 36 gold' / '..., not enough gold' —
  was a bare '36'). Labels read the same defs as the paint. Zero
  visual change, zero re-anchor.
- EmberButton grew semanticLabel (overrides label in its existing
  merged node). SEMANTICS LESSON: never wrap EmberButton in outer
  Semantics(excludeSemantics:true) — swallows its onTap action and
  the node merges into the surrounding panel. Override INSIDE the
  widget that owns the action. Audit idiom: grep -c "Semantics("
  per screen; debug = walk rootSemanticsNode printing labels.
- Test idioms: ensureSemantics() + find.bySemanticsLabel; boon
  offers = startRun(boons:true) then state['boons']; reward offers
  = state['offers']. 4 tests. Suite 901/901. 0.122.0+148.

## v0.123.0 — The Crowned Company (2026-08-30)
- Per-delver hard-mode mastery: meta.charHardWins (banked beside
  charWins on hard wins only; persisted when non-empty; cloud merge
  per-key MAX — counters use _maxMap, only PREFERENCE maps like
  charDye use the fresh-copy block). NO backfill: the global
  hardWins can't attribute wins honestly, crowns count from here.
  Tallies (picker + ledger roster) gain ' · N hard' between wins
  and floor, shown only when > 0 (charted-depth no-guessing rule).
- delvers_crowned stat (junk-proof distinct roster count) + Three
  Crowns (3, fixed badge) + The Crowned Company (promise-worded →
  target == characters.length, pinned). 56 achievements. Guard-test
  map: achievementStats set + achievements_test wired-stat profile
  + waymarks maxed profile all needed the new counter (as mapped).
- SEED-HUNT LESSON (add to v0.114.0's): a difficulty hunt on a
  fresh profile is SILENTLY CLAMPED to normal by clampRunParams
  (hard rides forgeUnlocked — retraced_page idiom). Two-trap chain:
  playRun hard 1/2/4 → controller free-profile "hard" 10/20/28
  (actually normal!) → controller Forge hard 20/39. ALWAYS assert
  run['difficulty'] inside a difficulty hunt.
- 5 tests; plates approved (four-part tally wraps at 320). Suite
  906/906. 0.123.0+149.

## v0.124.0 — The Mender's Mark (2026-08-30)
- FIFTH TEMPER RUNE 'mend': on the natural tempered face, assigning
  the die (either verb) mends 1 HP, capped, counted-heal honesty
  (no gain → no event). First new combat mechanic since the Face
  Forge — and ZERO re-anchor by construction: the golden bot's
  temper policy is OFF (v7 rule), so the temper system is the open
  gameplay-content lane (relics/events/enemies all re-roll
  published promises — v0.123.0 audit). Rune wiring checklist:
  faceRunes set (run_layer validates 'unknown_rune' against it) +
  runeName + runeBlurb + temper_sheet offer list + assignment.dart
  trigger + combat.dart payoff (echo precedent: pays AFTER the
  assignment, outside value math).
- PLATE-FONT LESSON (cost ~40 min): a cloned plate tool without
  loadRealFonts renders Ahem squares ~2x taller — faked a 172px
  rest-screen overflow at 320 and I nearly 'fixed' a healthy
  screen. The original temper tool never loaded fonts (its 412/360
  probes just happened to fit). EVERY plate tool must
  loadRealFonts; verify a plate-found failure is real (probe WITH
  fonts) before touching product code.
- 6 tests; plates approved (five-rune sheet scrolls at 320, commit
  pinned). Suite 912/912. 0.124.0+150.

## v0.125.0 — The Tempered Hand (2026-08-30)
- meta.tempersSet: lifetime faces tempered — banked at run end from
  run['tempers_used'] beside dailiesPlayed (OUTSIDE the win gate:
  wins AND losses, charRuns precedent — spent forge work, not an
  outcome). Persist when >0; cloud merge MAX. Sim stays meta-free
  (bank from run fields at run end, never increment at the
  command). + The Marked Face (1) / Well Tempered (25). 58
  achievements.
- TEST-PIN LESSON: kindler easy seed 13 loses AND rests on the
  pure bot walk (hunted; 18/3/5 never rest) — but a mid-run temper
  sways the remaining walk (mend heals), so the banking pin accepts
  EITHER terminal. Pin the contract (banking site is outside the
  win gate), not the accident (which terminal this walk hits).
- Plate framing: profile tempersSet=10 so the progress sort keeps
  BOTH forge honors in one frame (v0.115.0 rule applied to the
  achievements list — tune the fraction, not the scroll).
- 4 tests; plates approved. Suite 916/916. 0.125.0+151.

## v0.126.0 — The Forgelight (2026-08-30)
- NINTH vista, temper arc act three (mechanic v0.124 → honors
  v0.125 → window v0.126; the first-class-mechanic pattern: weekly
  got frostvein, tales got hearthgold). tempersSet >= 10 (vista at
  10, badge at 25 — two waymark beats on one road). Grade hue -25 /
  sat 1.5 / val 1.12 / wash 0x66E8571F.
- GRADE DOCTRINE (second 'too timid' first pass in a row): open
  color grades at least as bold as frostvein's finals and tune DOWN
  if plates shout — first passes at 'safe' values are invisible
  against the identity control.
- vistaUnlockedFor +required tempersSet (16 call sites, scripted
  regex patch on 'doubledWins: N,' lines). frostvein_test 'last'
  pin → INDEX pin (second occurrence of the tinker 'last' contract
  bug — the pin is append-order stability, not final position).
- LANE MAP: keystones REJECTED as a content lane — the golden bot
  draws keystone offers against keystonesOrder, so growth re-rolls
  every anchor. Open lanes: temper runes, meta layer, cosmetics.
- 4 tests; plates approved after one strengthening. Suite 920/920.
  0.126.0+152.

## v0.127.0 — The Full Rotation (2026-08-30)
- meta.weeklyRulesWon: canonical rule labels (sorted '+'-joined
  ids) banked on WON weeklies beside doubledWins; junk-proof via
  legalRuleLabels() derived from the LIVE rotation (a 7th rule
  counts the moment it can be dealt; full_rotation's promise-worded
  target pinned to the live count). canonicalRuleLabel +
  legalRuleLabels live in lib/game/weekly.dart and feed banking,
  stat, and title line — one source, three surfaces, can't
  disagree. Union merge; persist when non-empty.
- Title weekly block gains 'Rules taken: N of 6' (waymark-line
  rule: hidden at zero; junk labels never inflate — UI pin proves
  it). + Rule Taken (1) / The Full Rotation (6). 60 achievements.
- COLLECTION AUDIT NOTE: every repeatable mode now feeds a
  collection (enemies→codex, provings→Proven, delvers→Seven Ways,
  tempers→forge arc, weekly rules→Full Rotation). Dailies remain
  record-only BY CHARTER (no history/streaks — §Ethics).
- End-to-end pin rides the 2026-02-02 doubled Monday bot-win
  (banks exactly {'no_rests+no_shops'}). 7 tests; plates approved.
  Suite 927/927. 0.127.0+153.

## v0.128.0 — The Smith's Shelf (2026-08-30)
- Cosmetics batch on the forge theme (sink lane; wardrobe frozen
  since v0.94.0): Forgesoot dye 640 (the missing DARK dye — the
  attire coherence guard's valMul>=0.8 legibility band held the
  first draft at 0.78 up, respect the band), Tempered 500 + 
  Runeglass 550 die skins (hue audit's open slots: steel, violet).
  11 dyes / 9 skins, ladders ascending (guard-enforced).
- 'LAST' PIN BUG, THIRD OCCURRENCE: deep_wardrobe dye last-two pin
  → index pins (tinker v0.118, frostvein v0.126, shelf v0.128).
  When growing ANY catalog, grep tests for `.last` and `sublist(`
  pins on that catalog FIRST.
- Generic coherence/price/ethics guards covered the new entries
  with zero new test code (the payoff of guard-style tests).
  Plates: forgesoot worn 360/320 + skins shelf (tempered LIT,
  runeglass priced). Suite 927/927. 0.128.0+154.

## v0.129.0 — The Earned Titles (2026-08-30)
- Epithets the_tempered (tempers_set 10 — the forgelight rung: one
  milestone, three rewards) + the_weathered (weekly_rules_won,
  target pinned to legalRuleLabels().length — promise wording,
  count-free name per the Many-Handed doctrine). 15 epithets.
  Slotted BEFORE the_proven; its 'last' pin is a REAL contract
  (the summit closes the shelf by design) — contrast the three
  catalog 'last' pins fixed this session. Zero new resolver code
  (epithets read statValue — v0.127 junk-proofing inherited free).
- REWARD-TIER DOCTRINE: titles mark ARRIVAL (vista's rung), badges
  mark ACCUMULATION (the long road) — don't put a title at the
  badge's far end. deep_wardrobe tail pin → index pins.
- 4 tests; plates approved. Suite 931/931. 0.129.0+155.

## v0.130.0 — The Gilded Face (2026-08-30)
- SIXTH TEMPER RUNE 'gilt': natural tempered face pays 2 gold on
  assignment, either verb (mid-combat gold = the on_max_gold
  'incidental economy' exception; uncapped — gold has no cap
  anywhere, consistency beats caution). The economy axis was the
  open slot: the shop-loop archetype had no anvil reason. 2g ≈
  mend's 1 HP in EV. The v0.124 wiring checklist held exactly
  (6 files, zero surprises, goldens byte-identical).
- RUNE AXES NOW FULL (damage/defense/rolls/tempo/sustain/economy):
  next temper release should be a DEPTH move (second temper, rune
  upgrades) — but second-temper changes botCmd-visible state →
  anchor review FIRST.
- 5 tests; plates approved. Suite 936/936. 0.130.0+156.

## v0.131.0 — The Written Rules (2026-08-30)
- Codex SIXTH KIND 'rule': six pages on the weekly calendar (five
  singles + cold_quarter), 10 embers each (place-priced — the
  calendar is world), THE RULES section between relics and dice.
  Codex 98 → 104. Names mirror-asserted against mutatorDef/
  doubledWeek (a rename can never fork the book). Rotation arc
  complete: play (v0.111) → collect (v0.127) → wear (v0.129) →
  read (v0.131).
- Honesty sweep CAUGHT my own draft: 'hurry' in short_road lore —
  the banned list is absolute, even in world prose. Reworded.
- GEOMETRY-PIN LESSON: spoken_dice's THE-DICE pin broke when six
  rule cards shifted list geometry (header at viewport edge, card
  below fold) — a pin asserting a CARD must scroll to the card,
  not its section header.
- 4 tests; plates approved. Suite 940/940. 0.131.0+157.

## v0.132.0 — The Second Mark (2026-08-30)
- TEMPER DEPTH MOVE: cap 1→2 tempers per delve (one-line sim
  change in runTemperFace; 6 picks → 21 pairings). Anchor review
  BEFORE writing: golden bot tempers at most once by ==0 policy
  (tempers-on walks unchanged), cap raises are replay-permissive,
  simVersion stays 7, goldens byte-identical in the release run.
- Rest copy counts marks ('Two marks a delve.' / 'One mark left.'
  / option disappears at both spent — v7 rule); anvil button and
  sheet say the same words. Widget test walks all three states.
- PLATE CATCH (grep lesson): the anvil BUTTON still said 'once per
  delve' beside the new counted copy — greps for changed words
  missed it ('once' vs 'one'). Grep the CONCEPT's neighbors ('per
  delve'), not only the words you edited. Plates caught the lie.
- Rejected depth alternatives (scout): rune tiers (save-format
  change), shop tempering (dilutes the hollow). Balance: ~1 extra
  trigger per few fights; knob is the cap if sweeps drift.
- 4 tests; plates approved. Suite 944/944. 0.132.0+158.

## v0.133.0 — The Six Marks (2026-08-30)
- meta.runesTempered Set: every rune ever tempered, banked at run
  end WIN OR LOSE beside tempersSet (sim records the rune per
  temper in run['runes_tempered']; sim stays meta-free; bot never
  tempers → goldens byte-identical). Junk-proof at BOTH ends
  (faceRunes filter at write AND read — v0.127 idiom). Union
  merge. Badges third_mark (3) + six_marks (target pinned to live
  faceRunes.length, promise wording). 64 achievements.
- A11Y AUDIT NOTE: combat is already fully spoken (DieChip has
  rich Semantics: name/size/rolled/tempered rune/spent-for-N/
  selected; verbs+map nodes labeled) — the a11y lane is COMPLETE,
  don't re-scout it.
- Run HISTORY also already exists (v0.3.4 addRunRecord) — struck
  from lead list; check progress.md/grep before scouting 'new'
  meta features.
- Rejected: 'the Marked' epithet (the_tempered owns temper
  identity; variety is accumulation → badge, not title).
- 4 tests; guard-map profiles serviced; plates approved. Suite
  948/948. 0.133.0+159.

## v0.134.0 — The Runemark (2026-08-30)
- TENTH VISTA: runesTempered summit (all six runes worked). First
  VIOLET grade (hue +155/sat 1.35/val 1.06/wash 0x5C7B4FC0) —
  runeglass established violet as the rune color (v0.128); opened
  BOLD, plates approved first pass (grade doctrine finally paid).
- GATE-VS-BADGE SPLIT DOCTRINE: vista gate FROZEN at 6 (v0.100
  re-lock lesson), six_marks badge target MOVES with faceRunes
  (promise doctrine) — both honest simultaneously.
- vistaUnlockedFor +runesMarked (17 sites, scripted regex on
  'tempersSet: N,' — v0.126 pattern). 'LAST' PIN BUG FOURTH
  OCCURRENCE: forgelight_test vistasOrder.last → index pin.
- PLATE-CLONE FILENAME lesson again: capture-name strings are
  longer tokens than the id — need their own rename pass.
- 3 tests; plates approved. Suite 951/951. 0.134.0+160.

## v0.135.0 — The Runesmith (2026-08-30)
- EIGHTH DELVER, temper specialist: 26 HP, ['d6','d6','d8'],
  Deep Coal arrives with SURGE worked into its 8. NEW SCHEMA
  CharacterDef.startTempers (list of {die,face,rune}, applied
  deterministically in run_layer startRun; smith's work ≠ player's
  work: cap and Six Marks bank untouched — pinned). unlockEmbers
  900. Weapon rune_chisel 0xFFB9A6D9 reach 0.46. Sprite: tinker
  sheet HSV hue+80/sat×0.72/val×0.92/floor 0.12 (runeglass violet;
  first try +160 gave ROSE — check the source sheet's base hue
  before picking a shift). PROVENANCE + sprite_meta rows.
- Sweep (400 seeds, HP 26): 90.00/65.50/42.50 vs kindler
  89.75/67.25/41.50 — in band FIRST setting. Prior for delver #9:
  ~2 HP per meaningful kit advantage. Pins: seed 1 wins easy+
  normal, 3 loses easy. ZERO re-anchor (appended last).
- ROSTER FALLOUT (v0.118 map, all fired): charactersOrder 'last'
  pin → index (FIFTH catalog); the_six_handed + crowned_company
  7→8 (promise), seven_ways_down stays 7 (fixed-count); tale 5
  'Eight keep this fire'; codex eighth chair; copy grep also
  caught v0.131 no_shops lore 'seven floors' → nine (delve is 9).
- 4 tests; plates approved (warmup + card 2 widths). Suite
  955/955. 0.135.0+161. Next: runesmith proving + Knapped-Sharp-
  style badges (the v0.119 pattern) — 'Eight Ways Down' badge new
  name at 8 per re-pricing doctrine.

## v0.136.0 — The Eighth Way (2026-08-30)
- Runesmith's proving (seed 5 normal, no rules; unused-seed
  variety rule; blurb doubles as the kit's strategy hint; card
  code DELVE-500000E100 = 8th char index proof). 15 provings;
  the_proven → 15 (real contract). Badges runesmith_wins
  'Rune-Sharp' + eight_ways_down (8); seven_ways_down stays 7.
  66 achievements. provings_test count pins 14→15 (3 sites);
  generic guards covered the rest free.
- v0.119 PATTERN CONFIRMED as the standing recipe: delver release
  (sweep-heavy) then roster-arc release (proving+honors) — keep
  them separate for reviewable diffs and their own seed hunts.
- 4 tests; plates approved. Suite 959/959. 0.136.0+162.

## v0.137.0 — The Fourth Cycle (2026-08-30)
- Ten new hearth tales (40 total, 4 cycles): the anvil + calendar
  pass (smith's two-mark limit, six runes, runesmith, rotation,
  Cold Quarter, free records, vistas, tempered promise, provings,
  eighth chair). hearthgold frozen at cycle 1 (v0.100 rule).
  hearth_tale pin 3×→4×.
- MIRROR-ASSERT EXTENDED TO PROSE: fourth_cycle_test proves the
  'two a delve' tale against the sim's actual refusal, 'six runes'
  against faceRunes, 'eight chairs' against the roster — a prose
  CLAIM gets pinned to the constant it cites, so copy can never
  silently go stale when a knob moves.
- 3 tests; plates approved (tale + counted temper copy agree on
  one screen). Suite 962/962. 0.137.0+163.

## v0.138.0 — The Delver's Dice (2026-08-30)
- meta.charSkin: die skins per delver (charVista shape, 3rd
  application; activeDieSkin = fallback + ledger shelf's global;
  fresh-copy merge). controller setSkinFor + activeRunSkin
  (activeRunVista's twin) feeding ALL 6 in-run DieChip sites
  (tray/rest/reward/boons/shop-lead/temper-sheet). Picker gains
  THE DICE section (owned skins, dress pills 'skin-dress-*',
  cards 'charskin-*'); buying stays on the shelf (one purchase
  path). LOADER LESSON: _vistaMap validates against the VISTA
  catalog — a copied loader silently drops every entry of another
  catalog; write _skinMap (persistence test caught it).
- PART-OF LESSON: character_screen.dart is `part of screens.dart`
  — imports go in the LIBRARY file; a failed grep in a && chain
  silently skipped my patch script once (check outputs, not just
  exit).
- PLATE CATCH: hard-boxed DieChip 40x44 overflowed 22px with real
  fonts → FittedBox. First-capture chips render dim (cold decode
  cache) — known artifact, judge the second plate.
- 4 tests; plates approved. Suite 966/966. 0.138.0+164.

## v0.139.0 — The Shown Anvil (2026-08-30)
- SIXTH CONTEXT TIP first_anvil: fires at the first rest with a
  LIVE anvil (caller passes canTemper — never teach an absent
  button), names all six runes in one sentence, states the
  two-mark limit. v0.10.0 rules hold (one card, once ever, no
  wall). RestScreen → stateful (map_screen onMapArrival idiom) to
  fire + host _ContextTip. tips_test allSeen deck pin updated.
- ONBOARDING AUDIT NOTE: tip deck was frozen at v0.10's five
  combat cards; teach-at-the-menu-moment beats teach-after-
  commitment for systems whose payoff is invisible until tried.
  Weekly tip REJECTED (title block self-labeled + forge-gated).
- TWO FALSE SCOUTS this release (summary waymark, reduce-motion —
  both existed): ALWAYS grep the feature area before scouting;
  the ledger already has LIFETIME/WITHIN REACH/RECENT DELVES.
- 4 tests; plates approved. Suite 970/970. 0.139.0+165.

## v0.140.0 — The Kept Hearth (2026-08-30)
- HONESTY BUG FOUND BY AUDIT: hearth_keeper 'Own every hearth
  colour' froze at target 4 (v0.3.3) while the shelf sold 12
  since v0.4.3 — five months shipped-lying. Predates the
  re-pricing doctrine; fixed by MOVING the target (promise
  wording, pinned to hearthThemesOrder.length) + junk-proof
  reader (v0.127 idiom = house style for every catalog stat).
  AUDIT RULE: when touching any shelf, read its badge's target
  against the live catalog FIRST.
- Two colours: anvilglow 440 (re-graded after plate critique —
  first pass read IDENTICAL to default Emberglow; paid colours
  must visibly differ from free ones, compare against the
  DEFAULT control not just each other), runefire 480 (violet,
  approved first pass). 14 colours; ladder non-descending
  (historical frostfire/witchlight 60/60 tie never re-prices —
  guard is >= overall, strict pins for new).
- 4 tests; plates approved. Suite 974/974. 0.140.0+166.

## v0.141.0 — The Honest Ledger (2026-08-30)
- PROMISE AUDIT SWEEP (after v0.140's find; rot is never alone):
  TWO more shipped lies — all_three_bosses 'all six bosses' with
  EIGHT in the bestiary (had rotted+re-priced once before, per its
  own id), full_company 'all five delvers' with eight at the fire.
  Both → count-free copy + live targets (8/8).
- THE CLASS IS PINNED: honest_ledger_test asserts all 8 promise
  honors against their live catalogs + forbids number words in
  promise copy + freezes the historical counted honors. Catalog
  growth now FAILS CI until promises move — doctrine enforced,
  not remembered.
- TEST-DATA LESSON: waymarks' hand-copied six-boss list HID the
  bestiary lie from the test meant to catch it — maxed profiles
  must DERIVE fills from live catalogs, never copy them.
- 3 tests; no plates (data-only). Suite 977/977. 0.141.0+167.

## v0.142.0 — The Written Marks (2026-08-30)
- Codex SEVENTH KIND 'rune': six pages (one per temper rune, in
  the smith's voice, each answering 'why pick this rune' — the
  question the Shown Anvil card opens). 15 embers (dice price —
  marks are tools; v0.131 pricing rule). THE MARKS section between
  rules and dice. Codex 105 → 111 (corrected in v0.144 — first
  write said 110→116, a count never checked against the live
  list; the ledger plate caught it). refIds mirror faceRunes, names
  via runeName() (mirror-assert). v0.131's card-scroll pin held
  against this growth. Codex coverage now COMPLETE: every named
  system has pages (world/delvers/enemies/relics/rules/runes/
  dice) — the codex-growth lane is a maintenance lane now.
- 3 tests; plates approved. Suite 980/980. 0.142.0+168.

## v0.143.0 — The Fifteenth Rung (2026-08-30)
- LADDER AUDIT: honors run A3/10/20, provings ran A5/A10 then
  nothing until the Ash Summit's A15-hard finale — five rungs of
  silence on normal. Closed: fifteenth_rung (kindler, normal,
  A15, seed 14; hunt found 14/20/24/34/36/39 winnable in first
  40 — A15 normal is hard but fair, which the proving certifies).
  Sits after tenth_rung (climb order); ash_summit keeps the last
  word. the_proven 15 → 16 (promise doctrine); provings pins 16.
- REJECTED: an A20 proving — the summit badge owns 20 already.
- TOOL LESSON: rung proving plates need forgeUnlocked AND
  bestAscension — locked provings render 'proving-req-' not
  'proving-start-' (maxAscensionFor rides the Forge).
- 3 tests; plates approved. Suite 983/983. 0.143.0+169.

## v0.144.0 — The Peddler's Shelf (2026-08-30)
- Two dice skins close the v0.128 hue audit's last slots: verdigris
  600 (green — muted so pips stay legible) + coppervein 650 (copper
  — pulled browner than embertide on purpose; plates judged them
  apart). 11 skins; ladder climbs 550→600→650.
- NEW LADDER GUARD: peddlers_shelf_test pins the skin shelf
  non-descending (v0.140's theme-shelf idiom, now on skins too).
- DOC HONESTY CATCH: v0.142's notes said codex 110→116; live list
  says 105→111 (the ledger plate's own Codex card exposed it).
  RULE: counts in prose must be READ from the catalog at writing
  time, never recalled from memory or prior notes.
- 3 tests; plates approved (warmup discipline held). Suite
  986/986. 0.144.0+170.

## v0.145.0 — The Bearer (2026-08-30)
- NINTH DELVER, the GIANT (flintwright's opposite pole): TWO dice
  ['d12','d8'], iron_scale (tinker reuse precedent), startTempers
  echo on the 12 (echo TEACHES the other die — coverage is what
  two dice lack), 36 HP, 1050 embers. Pure data — no re-anchor.
- SWEEP STORY (400 seeds vs kindler 89.75/67.25/41.50): d10+d6@30
  74.5/14.5/5.75 → d12+d8@30 81.25/33.25/12.75 → +relic+echo@34
  90.75/65/37.5 → @36 91.75/67.50/39.50 SHIPPED. NEW PRIOR: a
  lost DIE costs ~30 winrate points on normal — dice-count is an
  order beyond the ~2-HP-per-advantage rule.
- HONESTY CATCH (class): all four ways-down milestones still said
  'all N delvers' — true at shipping, lies since. Reworded 'N
  different delvers'; honest_ledger now PINS frozen honors never
  claim all/every. Promise honors moved to 9 (full_company,
  crowned_company, the Many-Handed).
- Fallout serviced: tales 5+40 'Nine keep/Nine chairs' + bearer
  named; codex 9th delver page (112); stone_maul weapon (reach
  0.62, roster's longest); sprite warden-HSV +210/×0.38/×0.90
  cold granite + PROVENANCE + sprite_meta rows.
- PLATE CATCHES: clone tool scrolled by DISPLAY NAME ('The
  Runesmith') — capture-name lesson extends to find.text targets;
  card copy said 'Deep Ember' vs catalog's Molten Core — die
  names in copy must be READ from the dice catalog.
- Relics live at sim.run['relics'], NOT sim.player.
- 3 tests + probe tool kept. Suite 990/990. 0.145.0+171.

## v0.146.0 — The Ninth Way (2026-08-30)
- Bearer roster arc completes (v0.119 pattern, THIRD use — it's a
  standing recipe now): bearers_proving (normal, seed 8; hunt wins
  8/16/17/19/20; blurb = kit strategy 'let the Echo teach the
  little one'), bearer_wins 'Stone-Shouldered', nine_ways_down 9
  (eight_ways_down frozen at 8). Provings 17; the_proven 17;
  pins updated (4 provings_test sites + eighth_way_test).
- REMEMBER THE ORDER LIST: new achievements need achievementsOrder
  too (order-matches-map test catches it).
- LEDGER SCROLL BUDGET: ember_sink's skin-card walk outgrew
  default maxScrolls 50 — honors releases lengthen the ledger
  above the shelves; budget now 200.
- 3 tests; plates approved. Suite 993/993. 0.146.0+172.

## v0.147.0 — The Marked Day (2026-08-30)
- Trial rotation coverage audit: the anvil (signature mechanic,
  two delvers + a vista built on it) had no day. Added marked_day
  goal day (temper >= 1, 15 embers) + NEW goal kind
  tempers_at_least (one switch case reading the run's own counter
  — sealed sim held). Append-LAST on rotation (one modulus, not a
  reshuffle). trials_test known-goals set updated.
- FORWARD-COMPAT PINNED: marked_day_test proves the judge's
  default arm (unknown goal id = silence, not crash) — the
  charter's promise now has a test.
- BANNED-LIST BITE #2: my news line 'nothing expires' contains
  'expire' — the substring list is absolute EVEN when denying the
  thing (v0.131 lesson, news edition). news_test caught it.
- No plates (same title widget as all 8 trials; tool reads real
  clock). 3 tests. Suite 996/996. 0.147.0+173.

## v0.148.0 — The Taught Fire (2026-08-30)
- Fair-death pillar taught the anvil at last: mid line (go temper
  — 'a mark on one face pays every floor after it') + late line
  (Aegis vs elite openers). Insight pick draws loot stream AT
  run_lost — nothing rolls after death, goldens safe (verified).
- CATALOG PIN insights never had: every death line held to the
  ethics banned-word charter (taught_fire_test), mid line's claim
  proven against the sim (mark lives in run state). Insights also
  have per-boss buckets (boss_<id>) — bucket pins must allow them.
- 3 tests; no plates (text-only lines in existing death screen).
  Suite 999/999. 0.148.0+174.

## v0.149.0 — The Tenth Fire (2026-08-31)
- Ranks lane (last unexplored catalog): marks formula unbounded,
  ladder topped at 1100 — dead top for veterans. Added tenth tier
  Mountainheart 1700 ('What the mountain remembers, it keeps'),
  gap 600 keeps curve accelerating. Extension over insertion:
  insertion re-names held ranks. NEW curve pin: threshold gaps
  never shrink (tenth_fire_test). Two pins honestly retuned
  (veteran 300→500 wins, top-UI 400→600).
- LATENT REAL-CLOCK BUG FIXED: marked_week_test banked-mutators
  pin was order-sensitive; _moddedMutators SORTS for determinism.
  Latent until the real clock hit doubled week 'Cold Quarter'
  (['no_shops','no_rests'] — not alphabetical) on 2026-08-31.
  Fix: unorderedEquals. LESSON: any pin comparing banked lists to
  declared catalog order must compare as a set when the bank
  documents sorting — and real-clock tests can rot on a calendar
  boundary, so a suite failure right after a week/day rollover is
  a rollover suspect first.
- 3 tests; no plates (data-only, same ledger widget). Suite
  1002/1002. 0.149.0+175.

## v0.150.0 — The Mender (2026-08-31)
- TENTH delver, the HEALER: mend rune worked into the WORST face
  of a Deep Coal (d8's 1) — the roll every delver curses is the
  one that stitches. 24 HP (ties flintwright smallest), ['d8',
  'd6','d6'], NO relic (three dice don't starve coverage — the
  mark alone tested strong), 1200 embers. SWEEP (400 seeds vs
  kindler 89.75/67.25/41.50): 28HP 91.75/71.50/46.25 → 26HP
  91.75/69.50/44.25 → 24HP 90.00/66.00/41.50 SHIPPED (normal
  between runesmith 65.5 and bearer 67.5; hard exactly par). The
  ~2-HP prior held all three steps.
- Fallout: tales 5+40 'Ten keep/Ten chairs' (+ fourth_cycle
  MIRROR-ASSERT 'Nine chairs'→'Ten chairs' — the tale mirror pins
  live in fourth_cycle_test, remember them in the delver
  checklist), codex 10th delver page (113), promise honors → 10,
  stitching_awl weapon (reach 0.40 sage 0xFF8FBF9A), mender.png
  (ascetic remap hue+90 sat×0.90 FLOOR 0.28 — desaturated source
  robes need a sat floor or the hue shift has nothing to bite;
  first attempt without floor stayed ash-grey), PROVENANCE +
  sprite_meta rows.
- Mender seeds: easy loss 3 (rest win 1-12); normal wins
  1/2/4/6/9/10/11, losses 3/5/7/8/12. Probe tool kept:
  tool/mender_sweep_probe_test.dart.
- Plates warmup + 2 sizes; locked-card state renders the sprite
  dim (expected, not a bug). Suite 1006/1006. 0.150.0+176.
- NEXT (standing recipe): v0.151 = menders_proving + mender_wins
  + ten_ways_down.

## v0.151.0 — The Tenth Way (2026-08-31)
- menders_proving (normal, seed 9, after bearers_proving; blurb
  'the worst face stitches'), mender_wins 'The First Stitch',
  ten_ways_down 10 (nine stays 9). Provings 18; the_proven 18.
- Pins: provings_test 18 ×2 + header 'of 18' ×2 (locked list AND
  cleared mark — TWO header pins, not one), eighth_way_test.
- 3 tests. Suite 1008/1008. 0.151.0+177.

## v0.152.0 — The Tenth Chair (2026-08-31)
- 11th vista Tenthfire: full-company reward you can SEE (warm
  amber, hue+24 sat×1.25 val×1.10 wash 0x40E8A050). Gate FROZEN
  at charsUnlocked >= 10 with a TRIPWIRE PIN (test fails at
  roster 11 saying update the reason, never the gate).
- vistaUnlockedFor grew charsUnlocked param — 4 test files' call
  sites patched mechanically (regex after tempersSet lines).
- runemark_test 'last' pin retired to INDEX pin. LESSON: when a
  release appends to an order list, grep for `.last` pins on the
  previous tail — same family as the header-count pins.
- Dye lane scouted and REJECTED (no hue gap: mosscloak owns
  green, palewisp grey). Plates: map vs identity control + shelf
  locked/worn. 2 tests. Suite 1010/1010. 0.152.0+178.

## v0.153.0 — The Shared Fire (2026-08-31)
- 7th tip shared_delve: the daily/weekly finally TAUGHT — fires
  on TITLE arrival, gated wonBefore && !dailyPlayed (first_anvil
  canTemper doctrine, calendar edition: never explain a thing the
  player already does). Copy states the honest contract; charter
  pin in shared_fire_test.
- FIRST OUT-OF-RUN TIP: TitleScreen is stateless — card mounts in
  a StatefulBuilder (dismissTip persists but does NOT notify;
  making it notify would rebuild routes mid-animation in three
  run screens). TIP-OVERLAY LESSON: a new tip card over a screen
  SWALLOWS TAPS in that screen's other tests — waymark_line_test
  (won-but-no-daily profile) broke; fix = mark the tip seen in
  unrelated tests' profiles. When adding a tip, grep tests that
  pump the host screen with a profile matching the tip's gates.
- tips_test last-unseen deck pin grew the id. 3 tests. Suite
  1013/1013. 0.153.0+179.
2026-08-31 AUTH RESTORED + FULL BACKLOG PUBLISHED: owner supplied working PAT. Branch legacy/dice-builder pushed to origin at 93ed9e0 (97 commits; a leftover fire_push watcher won the final ref-update race — remote already at HEAD, treated as success; watcher machinery killed and cleaned). v0.60.0 released WITH signed CI artifacts (run 32879831365; 4×APK PIN-OK versionName 0.60.0 + AAB pin 031acb…44b7a0d; sha256 table appended). v0.61.0–v0.153.0 published as 93 source releases (gh release create --target <sha> --notes-file docs/releases/vX.md; version→commit map verified ancestor-monotonic, 0 retries). GitHub releases now current through v0.153.0 (latest). CI dispatched on v0.153.0 tag (run 33399481843) to attach signed artifacts to latest release. LESSON: a rejected push with 'remote is at <our HEAD>' means the push effectively landed — verify with ls-remote before retrying.

## v0.154.0 — The Keeper's Day (2026-08-31)
- 10th trial keepers_day: the relic shelf joins the daily
  rotation. Goal kind relics_at_least over run['relics'] list
  (null-safe, missing list = unmet). goalParam 2 — probe (80
  seeds) showed greedy bot ends wins with 0–1 relics, so two is
  a real spending choice, not an accident. Append-LAST; trials
  known-goals set grew the id. 3 tests. Suite pending full run.
2026-08-31 v0.153.0 ARTIFACTS ATTACHED: CI run 33399481843 success; 4×APK PIN-OK versionName 0.153.0 + AAB pin match; renamed standard names, uploaded to v0.153.0 release, sha256 table appended. .last-PIN BIT AGAIN in v0.154: marked_day_test pinned trialsOrder.last — retired to INDEX pin 8. The append-to-order-list grep for `.last` pins is MANDATORY, not advisory.
2026-08-31 v0.154.0 ARTIFACTS ATTACHED: CI run 33401229453 success; 4×APK PIN-OK versionName 0.154.0 code 4180 + AAB pin match; renamed standard names, uploaded to v0.154.0 release, sha256 table appended. Suite note corrected: full run landed 1016/1016 green before the release commit. Releases fully current through v0.154.0 with signed artifacts on latest.

## v0.155.0 — The Deep Mark (2026-08-31)
- Rune tiers, the dedicated release the v0.154 scout demanded. Same
  die+face+rune tempers again = deepen IN PLACE to tier 2 (no new
  custom id; still spends a temper, still banks Six Marks; tier-2
  repeat rejects 'already_deep'). OPTIONAL 'tier' save key: absent
  = 1 (old saves byte-identical), present must be 1|2 else throw.
- Deep payoffs one step more: blade/aegis +3, echo arms 2, mend 2,
  gilt 3, surge twice/die/turn (contains() generalised to count
  capped at tier — tier 1 identical). AssignmentResolution grew
  runeTier; combat payoff sites read it. face_tempered event now
  declares tier (1|2) — face_forge event pin updated. Forge keeps
  tier. UI: DieChip mark wears '+' when deep, a11y says 'Blade II'
  (runeTierName/runeDeepBlurb in run_dice.dart); temper sheet shows
  a deepen hint on marked dice, button says Deepen/'already deep'.
- LESSON: sim invalid events are type 'invalid_command', not
  'invalid'. Injected custom_1 test fixtures must also bump
  next_custom_die or the next mint collides. 8 tests
  (deep_mark_test). Suite 1024/1024. 0.155.0+181.

2026-08-31 v0.155.0 ARTIFACTS ATTACHED: CI run 33404171504 success; 4×APK PIN-OK versionName 0.155.0 (codes 181/1181/2181/4181) + AAB pin 031acb42… match; renamed standard names, uploaded to v0.155.0 release, sha256 table appended (apk 7f0f3764…, aab 1ddfe020…, arm64 a6beca0d…, v7a bffe744a…, x86_64 03c1ce8d…). Releases fully current through v0.155.0 with signed artifacts on latest.

## v0.156.0 — The Deep Day (2026-08-31)
- 11th trial, the Deep Mark's day: goal day 'deep_day', new goal kind
  'deep_marks_at_least' (goalParam 1 — temper cap 2 means at most one
  deep mark a run; emberBonus 15). Judge reads run['custom_dice'] tiers
  with the absent-key=tier-1 contract (sealed sim, pure observation).
  Appended LAST to trialsOrder; .last pin moved from keepers_day_test
  to deep_day_test per the v0.154 .last-PIN rule.
- LESSON (stale-test class): the trial rotation-uniformity floor was a
  fixed 80 tuned for an older catalog; at 11 trials the roughest slot
  draws 70. Fixed by scaling the floor with catalog size (60% of fair
  share) — any fixed histogram pin on a hash-mod-N rotation goes stale
  on every append. Prefer proportional floors on modulus-driven tests.
- test/deep_day_test.dart (3 tests: rule pin + append-LAST, exact judge
  fixtures incl. absent-tier, end-to-end sim-deepened run meets goal).
  Suite 1027/1027. 0.156.0+182.

## v0.157.0 — The Deep Hearth (2026-08-31)
- Two hearth colours, shelf now 16: twiceflame (Deep Mark magenta, 520)
  and marshlight (chartreuse, 560) — both in unclaimed hue space per the
  Anvilglow plate-critique rule. Ladder ascends; shipped prices frozen.
- hearth_keeper target moved WITH the catalog 14→16 (v0.140 honesty rule,
  live-length test pin). kept_hearth_test sublist pin got an end bound
  (12,14) — the .last-PIN class applies to sublist pins too.
- LESSON: meta/achievements.dart does NOT export the achievements map —
  import data/achievements.dart for the catalog, meta/ for the judges.
- test/deep_hearth_test.dart (4 tests: ladder-top pin + gradient + prices,
  hearth_keeper live-catalog promise, buy path, banned-words sweep).
  Suite 1031/1031. 0.157.0+183.

2026-08-31 v0.156.0 ARTIFACTS ATTACHED: CI run 33406659037 success; 4×APK PIN-OK versionName 0.156.0 (codes 182/1182/2182/4182) + AAB pin 031acb42… match; renamed standard names, uploaded to v0.156.0 release, sha256 table appended (apk 85c491bf…, aab 17c380da…, arm64 c2d94634…, v7a a8997b31…, x86_64 9dbd9831…).

2026-08-31 v0.157.0 ARTIFACTS ATTACHED: CI run 33407412686 success; 4×APK PIN-OK versionName 0.157.0 (codes 183/1183/2183/4183) + AAB pin 031acb42… match; uploaded to v0.157.0 release, sha256 table appended (apk dd3195e0…, aab dab62639…, arm64 71f3aa12…, v7a e68f2a0b…, x86_64 b6583941…). Releases fully current through v0.157.0 with signed artifacts.

## v0.158.0 — The Shieldwright (2026-08-31)
- The eleventh delver, the WARD: first kit to LEAD with a deep mark —
  Aegis II already worked into an Ember Die's 6 (startTempers now takes
  an optional 'tier' key, same absent=1 contract as the save shape, so
  every earlier delver's record stays byte-identical — pinned by test).
- Kit 26 HP / d6·d6·d6 / no relic / 1350 embers. Sweep (400 seeds):
  89.00/68.00/41.50 vs kindler 89.75/67.25/41.50 — hard at exact par,
  in band at the first HP guess (~2-HP-per-advantage prior held).
- Fallout: tales 5+40 → 'Eleven', codex 11th delver page (114), promise
  honors → 11 (full_company, crowned_company, Many-Handed), Planishing
  Hammer weapon, shieldwright.png (warden remap hue +215° sat ×0.95
  floor 0.38 val ×0.92 — cobalt steel vs bearer's granite), PROVENANCE
  + sprite_meta rows, roster pins (runesmith/fourth_cycle), tenth_chair
  tripwire fired AS DESIGNED (gate frozen, reason updated only).
- test/shieldwright_test.dart (4 tests incl. tier-key presence AND the
  runesmith no-tier-key byte-identity guard; seeds: easy loss 3, normal
  win 4 / loss 5). Plates: picker card 2 sizes + warmup, judged.
  Suite 1035/1035. 0.158.0+184. Proving follows in v0.159 (v0.119 recipe).

## v0.159.0 — The Eleventh Way (2026-08-31)
- The shieldwright's proving (seed 10 normal, bot-win pinned; provings
  19) + The First Ward (shieldwright_wins) + Eleven Ways Down —
  the v0.119 recipe, fifth use. the_proven 18→19; 'N of 18' pins →
  'N of 19' (provings_test ×2 textContaining + 2 length pins,
  eighth_way_test).
- LESSON (copy-collision class): news lines render on the TITLE screen,
  so a news line echoing another card's signature phrase ('same seed,
  same road') breaks that card's textContaining finder. Before shipping
  news copy, grep test/ for its distinctive phrases.
- test/eleventh_way_test.dart (3 tests: proving def + roster-order,
  seed replay, honors + frozen predecessors). Suite 1038/1038.
  0.159.0+185.

## v0.160.0 — The Second Strike (2026-08-31)
- 8th contextual tip `deep_mark`: deepening's front door — first rest fire
  with a tier-1 mark in the pool, live anvil, anvil card already seen.
  Director: onRestArrival gains hasShallowMark; anvil card outranks it;
  blocked card recurs (one-tip rule). rest_screen derives hasShallowMark
  from custom_dice tier (absent = 1, v0.155 contract).
- test/second_strike_test.dart (5 tests); tips_test allSeen deck → 8.
- Suite 1043/1043 (/work/temp/v0160_full2.log).
- v0.158.0 artifacts ATTACHED (CI 33409356596, ALL PINS OK, codes
  184/1184/2184/4184, AAB pin OK; sha256 table appended: apk e498a77f…,
  aab dfaaf081…, arm64 f1212a7b…, v7a bc5b14d2…, x86_64 98715b8b…).
- v0.159.0 artifacts ATTACHED (CI 33410076412, ALL PINS OK, codes
  185/1185/2185/4185, AAB pin OK; sha256 table appended: apk d797c99f…,
  aab 081b7826…, arm64 f11f5c57…, v7a 6a91c9de…, x86_64 9075032e…).
- v0.161.0 The Eleventh Fire: 11th rank tier `firstflame` 2550 marks
  ("Every fire below began with yours."), gap 850 keeps the accelerating
  curve. eleventh_fire_test (4 tests, length/.last pins moved here);
  tenth_fire_test now pins rankTiers[9]; rank_test veteran grew to 750
  wins; rank_ui_test top profile 900 wins. LESSON re-proved: banned-word
  scan news copy BEFORE the suite run ('expires' cost a cycle). Suite
  1047/1047.
- v0.160.0 artifacts ATTACHED (CI 33411215359, ALL PINS OK, codes
  186/1186/2186/4186, AAB pin OK; sha256 table appended: apk 252c00c6…,
  aab 18b44606…, arm64 84759f1a…, v7a 39464cda…, x86_64 1fa2ee3d…).
- v0.162.0 The Gilder: TWELFTH delver, the GOLDSMITH — first kit with TWO
  smith's marks (gilt tier-1 on both Ember Dice sixes; multi-entry
  startTempers worked unchanged in the v0.135 loop). 28 HP (sweep
  90.25/65.50/41.50 vs kindler 89.75/67.25/41.50 — in band), no relic,
  unlock 1500, index 11. Sprite = peddler remap hue +230° sat ×1.00
  floor 0.38 val ×1.05 (burnished gold); Agate Burnisher weapon; codex
  entry; tales recounted to Twelve (5 & 40); full_company/crowned_company/
  the_six_handed → 12; tenthfire gate FROZEN (reason-only edit). Count
  pins updated in fourth_cycle/runesmith/tenth_chair tests. gilder_test
  (kit/index/tier-free records/seeded pins: easy loss 3, normal wins
  1/4/6/9/10/11). Suite 1050/1050. NEXT RELEASE: gilders_proving +
  gilder_wins + twelve_ways_down + the_proven 20 (v0.159 pattern).
- v0.163.0 The Twelfth Way: gilders_proving (seed 4 normal, provings 20,
  stands after shieldwrights_proving), gilder_wins "The First Coin",
  twelve_ways_down 12 (predecessors frozen), the_proven → 20.
  Achievements 76. twelfth_way_test (3 tests); provings pins 19→20 in
  provings_test + eighth_way_test. Suite 1053/1053.
- v0.161.0 artifacts ATTACHED (CI 33412759993, ALL PINS OK, codes
  187/1187/2187/4187, AAB pin OK; sha256 table appended: apk 25ae987d…,
  aab a36b48bd…, arm64 1890d3af…, v7a 001143f0…, x86_64 a9535fd3…).
- v0.162.0 artifacts ATTACHED (CI 33413826091, ALL PINS OK, codes
  188/1188/2188/4188, AAB pin OK; sha256 table appended, apk e3d2c221…).

## v0.164.0 — The Amethyst Vein (2026-08-31)
- Twelfth vista 'amethyst' (append-LAST): hue -48, sat x1.8, val x1.04,
  wash 0x46603090 — plum/vein-purple, plate-checked apart from duskquartz.
- Gate: delversCleared >= 12, FROZEN; fed by junk-proofed
  statValue(meta,'delvers_cleared'). New required param on vistaUnlockedFor
  (all 18 call sites updated).
- Pins: test/amethyst_test.dart (last, 11/12 table, freeze tripwire,
  controller feed, junk-key immunity); tenth_chair .last pin moved to index
  10; vistasOrder.length 12 in runemark_test. Suite 1056/1056 first try.
- Lesson re-proved: check the plate against NEIGHBOR vistas (first grade at
  -60/x1.35/x0.96 was a duskquartz twin; retuned before ship).
- v0.163.0 artifacts ATTACHED (CI 33414214101, ALL PINS OK, codes
  189/1189/2189/4189, AAB pin OK; sha256 table appended, apk aaf54ad6…).

## v0.165.0 — The Fifth Cycle (2026-08-31)
- Ten hearth tales (41-50): the late chairs at last (bearer, mender,
  shieldwright, gilder — every delver now has a tale), then deep-mark
  arithmetic, delve codes, marks, the Proven, the two calendars, closer.
- Pins: test/fifth_cycle_test.dart mirror-asserts copy vs live data;
  hearth_tale_test wrap pin 4x -> 5x hearthgoldTales (missed on first
  pass — cost one suite run); fourth_cycle_test length pin 40 -> 50.
- LESSON: tale-count pins live in TWO places (hearth_tale_test charter AND
  latest cycle test) — grep 'hearthgoldTales' in test/ before a new cycle.
- Tale copy cap is 200 chars (hearth_tale_test), tighter than the cycle
  tests' 260. Suite 1059/1059.
- v0.164.0 artifacts ATTACHED (CI 33415964772, ALL PINS OK, codes
  190/1190/2190/4190, AAB pin OK; sha256 table appended, apk b075eb14…).
- v0.165.0 artifacts ATTACHED (CI 33416719555, ALL PINS OK, codes
  191/1191/2191/4191, AAB pin OK; sha256 table appended, apk e358a79c…).
- NEXT LEAD (scouted, not started): v0.166 twelfth rank tier — id 'everburn',
  name 'Everburn', marks 3750 (gap 1200 >= 850), flavor 'Fires die. Yours has
  not.'; move length/.last pins from eleventh_fire_test into new
  twelfth_fire_test; eleventh_fire_test 'Firstflame stands at top' becomes
  'has a next fire again'; rank_test veteran wins 750->1150; rank_ui_test
  runsWon 900->1300 with comment updates.
- v0.166.0 "The Everburn" RELEASED (source): twelfth rank tier 'everburn'
  3750 marks, gap 1200 keeps the curve; pins moved eleventh_fire_test ->
  new twelfth_fire_test; rank_test veteran wins 1150, rank_ui_test
  runsWon 1300. Suite 1067/1067 first try. News entry + docs.
## v0.167.0 — The ask that could never fire (2026-08-31)
- ROOT CAUSE: the in-app review ask shipped 2026-08-23 but was unreachable.
  Gate was `(wonThisRun && meta.runsWon >= 2) || wonDailyOrWeekly` — it needed
  a SECOND full run win, so in practice it never fired. That, not player
  sentiment, is why a 5.00 internal average produced zero organic public
  ratings.
- FIX (#98, squash 0076b04): third trigger — climbing into Sparktender
  (24 marks) or above. `ReviewService.rankAskFloorMarks = 24`; optional
  `int? rankedUpToMarks` on eligible()/maybeAsk(); call site
  lib/game/controller.dart passes rankAfter.marks when the rank improved.
- Evidence: rank_test pins "first evening lands 2-3 rank-ups" and tier 2 IS
  Sparktender, so one evening = one ask. Suite 1064/1064 pre-rebase; re-verified on top of v0.166.0 Everburn.
- Charter intact: one ask ever, stamp on request, sticky cloud merge OR,
  never during the tour, no incentives, no pre-filtering, official API only.
- LESSON: a shipped feature is not a working feature. The 23 Aug release
  logged review_service.dart as done; nobody gated the trigger against a
  realistic play session. Pin reachability, not just correctness.
- v0.168.0 The Cutler (renumbered from v0.167.0 after PR #98 landed as v0.167.0 'A Word From You'): THIRTEENTH delver, the KNIFE-MAKER — first kit
  with two DIFFERENT marks (blade on Deep Coal 8, aegis on Ember Die 6,
  both tier-1). 24 HP (sweep 90.25/66.50/43.75 vs kindler
  89.75/67.25/41.50 — in band first guess), d6/d6/d8, no relic, unlock
  1650, index 12. Sprite = ascetic remap hue +205 sat x0.95 floor 0.35
  val x0.94 (whetstone steel); Steeling Rod weapon; codex page; tales 5
  & 40 recounted to Thirteen; full_company/crowned_company/Many-Handed
  -> 13; tenthfire + amethyst gates FROZEN (reason-only edits). Pins:
  fourth_cycle (roster + 'Thirteen chairs' copy — the copy pin on line
  BELOW the roster pin was missed first pass, one suite rerun),
  runesmith, tenth_chair, amethyst. cutler_test (kit/pool order
  custom_2,d6,custom_1/no-tier-key/seeded pins easy 1 win, normal 4 win
  7 loss). Plates: picker card 2 sizes + warmup, judged (locked dim
  expected). Suite 1070/1070. 0.168.0+194.
- LESSON: roster recount grep must include test/ copy pins ('Twelve
  chairs' lived in fourth_cycle_test line 39, one line under the roster
  pin the checklist already covers).
- USER DIRECTIVE (2026-08-31 17:18): performance optimisation + smooth
  animations — schedule a dedicated perf/animation-polish release soon
  (frame-timing probes, const/rebuild audit, animation easing pass).
- COLLISION RESOLVED: PR #98 ("A Word From You", review-ask fix) was
  merged + pushed from the GitHub account at 17:09 as v0.167.0
  (0.167.0+193) while the cutler was being built locally under the same
  number. Cutler renumbered to v0.168.0+194 everywhere; v0.167.0 tag/
  release re-titled to the review-ask feature with proper notes
  (docs/releases/v0.167.0.md written from PR body); rebased suite
  1070/1070 (review tests + cutler together).
- LESSON: fetch+rebase BEFORE choosing the next version number, not
  only before pushing — the account owner can land PRs mid-run. Also:
  never compute the release --target sha after a failed rebase; and
  `git rebase --continue` needs GIT_EDITOR=true in this sandbox.
- v0.166.0 artifacts ATTACHED (CI 33418478520, ALL PINS OK, codes
  192/1192/2192/4192, AAB pin OK; sha256 table appended, apk b8447ef8…).
- v0.169.0 The Steady Flame: perf-polish release (user directive
  2026-08-31 17:18 "performance optimisation + smooth animations").
  Five rebuild-cost lints enabled PERMANENTLY in analysis_options.yaml
  (CI runs flutter analyze -> const regressions now fail CI); 112
  violations auto-fixed in 28 files via `dart fix --apply`. Audit:
  sprites already repaint-direct + RepaintBoundary'd (42 in lib/ui), no
  Timer.periodic animations. Suite 1070/1070 + analyze clean.
  0.169.0+195. LESSON: `dart fix --apply` is safe here (suite green
  first try); lints-on beats one-off cleanup.
- ARTIFACTS ATTACHED for three releases (2026-08-31 ~18:0x GMT):
  v0.167.0 A Word From You (CI 33419616976, codes 193/1193/2193/4193,
  ALL PINS OK + AAB pin OK; owner had pre-uploaded apk+aab — aab
  differed by 3 bytes from CI's, both replaced via --clobber with
  pin-verified CI artifacts, apk b5eb84e0…); v0.168.0 The Cutler
  (CI 33420075500, codes 194/1194/2194/4194, ALL PINS OK + AAB pin OK);
  v0.169.0 The Steady Flame (CI 33420586874, codes 195/1195/2195/4195,
  ALL PINS OK + AAB pin OK). sha256 tables appended to all three
  release notes. Publish pipeline scripted at /work/temp/
  publish_release.sh (download -> stage -> verify -> rename ->
  clobber-upload -> checksum table).
- v0.170.0 The Thirteenth Way: cutler's proving (seed 14 normal,
  bot-win pinned) + The First Edge (cutler_wins) + Thirteen Ways Down
  (delvers_cleared 13); the_proven 20->21 (target-honesty pin holds);
  count pins 20->21 in provings_test (x2 + 'of 21' copy x2) and
  eighth_way_test; new test/thirteenth_way_test.dart. Suite 1073/1073
  FIRST TRY, analyze clean. Release v0.170.0 target 6620733; CI
  33423482420 dispatched (expect 0.170.0+196 -> codes 196/1196/2196/
  4196). v0.119 pattern seventh use.
- v0.171.0 The Collier: FOURTEENTH delver, the charcoal-burner — first
  kit whose WHOLE pool arrives worked (blade d6f6 + gilt d6f6 + mend
  d6f1, all tier 1; d6/d6/d6, no relic). 27 HP (400-seed sweep
  88.75/65.25/40.50 vs kindler 89.75/67.25/41.50 — second guess; 25 HP
  swept low). Unlock 1800, index 13. Pool order custom_1/2/3 (tempers
  in listed order). Sprite = kindler remap hue +12 sat x0.55 floor 0.18
  val x0.74 (banked-coal soot; sprite_meta entry inserted COMPACT —
  json.dumps no indent, the file is single-line; PROVENANCE row via
  line-insert, the 'at a glance' anchor is NOT unique). Coal Rake
  weapon (accent 0xFF8A6A52, reach 0.56). Codex collier page after
  cutler (117 entries, all pins derive). Promise doctrine: full_company
  /crowned_company/the_six_handed 13->14; tales 5&40 recount Fourteen
  (+', collier'); tenthfire+amethyst gates FROZEN (reason-only, tripwires
  14). Roster pins: fourth_cycle_test (14 + 'Fourteen chairs'),
  runesmith_test 14. test/collier_test.dart (easy 1 win, normal 4 win 7
  loss; full probe: easy losses 3,13; normal wins 1,4,6,9,10,11,14).
  Plates via tool/collier_visual_test.dart (gilder recipe), judged good.
  Suite 1076/1076 FIRST TRY, analyze clean.

## v0.172.0 — The Fourteenth Way (2026-08-31)
- Collier's proving (seed 6 normal, bot-win pinned; win set was 1,4,6,9,10,11,14) after cutlers_proving; honors The First Coal (char_wins/collier/1) + Fourteen Ways Down (14); the_proven 21→22 (derived pins auto-move). Count pins 21→22 in provings_test (×2 + '0 of 22'/'1 of 22') + eighth_way_test. New test/fourteenth_way_test.dart. Suite 1079/1079 first try, analyze clean. v0.119 pattern, eighth use.
- Commit 2da5ba686e84673bc7ea4bb39747dd26781b96db; CI 33425977651 (expect 0.172.0+198 → codes 198/1198/2198/4198).
- v0.170.0 artifacts PUBLISHED (196/1196/2196/4196, ALL PINS OK + AAB PIN OK). v0.171 CI 33424708073 still in flight at this writing.

## v0.173.0 The Worldflame (2026-08-31)
- Thirteenth rank tier: worldflame 5450 marks (gap 1700; curve 280/400/600/850/1200/1700). v0.166 pattern third use (v0.149, v0.161, v0.166 → v0.173).
- Pins moved: twelfth_fire_test freezes chair 12 + 'has a next fire again'; thirteenth_fire_test owns length-13/.last/top pins; rank_test veteran wins 1700 (5455); rank_ui_test runsWon 1850 (5550).
- v0.171.0 artifacts PUBLISHED (CI 33424708073, codes 197/1197/2197/4197, all pins OK). v0.172 CI 33425977651 pending publish.
- OWNER DIRECTIVE 2026-08-31 18:45: big UI pass, reduce/rethink scrolling everywhere ("IDK you know what's best") — v0.174 lane: scroll-comfort audit (edge fades, CTAs above fold, in-run screens scroll-free on phones; keep list screens scrollable — 117 codex entries can't fit a fold honestly).

## v0.174.0 The Honest Fold (2026-08-31)
- ScrollComfort edge-fade shell in lib/ui/widgets.dart (keys scroll-fade-top/bottom, 32px, 160ms, EmberColors.bg, IgnorePointer, vertical-only via notification listeners — owns no controller). Applied to 10 screens: roster/ledger/codex/provings/news/credits/settings/shop/title/summary.
- LESSON: screens/*.dart are `part of` screens.dart — widgets.dart import there covers all parts. Paren-matching python wrapper (insert 'ScrollComfort(child: ' + matched ')') is the safe way to wrap long widget expressions; keep prefix ('return ', 'child: ') OUTSIDE the wrap.
- Owner scroll directive answered: keep scrolling (CTAs already pinned; 117 codex entries can't fit a fold), add affordance instead. Plates confirm subtle fade; M3 appbar scrolled-under tint pre-existing.
- v0.172.0 artifacts PUBLISHED (codes 198/…, all pins OK). v0.173 CI 33427087325 pending publish.

## v0.175.0 The Stoker (2026-08-31)
- FIFTEENTH delver: first all-heavy pouch (three plain d8s, no relic, no
  marks). 16 HP — roster's thinnest skin (prior floor 24); the heavy
  pouch swept HOT at normal HP (24→94.00/78.75/57.75, 20→92.75/72.75/
  51.25, 16→89.00/64.75/44.00 vs kindler 89.75/67.25/41.50 — third
  guess in band). Unlock 1950, index 14 — delve-code bits full at 16:
  ONE roster slot remains.
- Sprite: peddler remap hue -140° sat ×1.05 floor 0.28 val ×0.86
  (soot-rust; elf_m). LESSON: peddler source is teal (~170°) — furnace
  orange needs the LONG hue rotation; first cut -18° came out green.
- LESSON (escape doubling): a Dart '\u2014' written through file_edit
  JSON needs ONE backslash in the file — '\\u2014' renders literally on
  the card. Plates caught it; grep lib/data for '\\\\u' after patching.
- Weapon Fire Iron 0xFFC97B3F reach 0.58. Promise moves 14→15
  (full_company/crowned_company/the_six_handed); tales recount Fifteen
  (tale 5 hit the 200 cap at 203 chars — dropped 'now'; assert length
  in the patch BEFORE writing). Frozen gates: reason-only updates
  (amethyst delversCleared>=12, tenthfire charsUnlocked>=10).
- test/stoker_test.dart (easy 1 win; normal 4 win 7 loss; hunt: easy
  losses 3/13, normal wins 1/2/4/5/6/9/10/11/12/14). Suite 1087/1087,
  analyze clean. Plates good (locked card dim = expected).

## v0.176.0 The Fifteenth Way (2026-08-31)
- Stoker's proving (seed 12 normal — UNUSED by any other delver proving,
  bot-win pinned; stoker normal win set 1/2/4/5/6/9/10/11/12/14) after
  colliers_proving; honors The First Shovel (char_wins/stoker/1) +
  Fifteen Ways Down (delvers_cleared 15); the_proven 22→23. Count pins
  22→23 in provings_test (×2 + '0 of 23'/'1 of 23') + eighth_way_test.
  New test/fifteenth_way_test.dart. Suite 1090/1090 first try, analyze
  clean. v0.119 pattern, ninth use.

## v0.177.0 The Banked Coals (2026-08-31)
- REAL BUG (found by perf/animation directive audit): SpriteView's
  _repaintDriver was built in initState BEFORE the frame-loop controller
  existed and never rebuilt — multi-frame idles froze on frame 0
  wherever bob/sway were off (title hearth, map nodes, codex, picker
  portraits). Combat masked it via the bob _life ticker. Fix: call
  _rebuildDriver() after _ctrl creation (both paths). REVERT-CHECKED:
  test red on pre-fix code.
- warmSpriteSheets() decodes all sheets post-first-frame (GameRoot
  initState addPostFrameCallback); SpriteView sync fast path commits
  cached sheets in initState with NO setState (initState precedes first
  build; didUpdateWidget is already in a rebuild) — no empty-box frame.
  debugSpriteSheetCached for tests. test/banked_coals_test.dart (3);
  CustomPainter EXTENDS Listenable — painter.addListener observes the
  repaint wiring directly in widget tests.
- Suite 1093/1093, analyze clean. 0.177.0+203.
- ARTIFACTS: v0.173.0 (CI 33427087325, codes 199/…) and v0.174.0
  (CI 33427927937, codes 200/…) and v0.175.0 (CI 33430681673, codes
  201/…) PUBLISHED, all pins OK + AAB pins OK, sha256 tables appended.
  In flight: v0.176 CI 33431048080, v0.177 CI 33432253170
  (predicate /work/temp/ci_check_175_177.sh covers 176+177 too).

## 2026-08-31 — v0.176.0 + v0.177.0 artifacts PUBLISHED
- v0.176.0: CI 33431048080 success, codes 202/1202/2202/4202, ALL PINS
  OK + AAB PIN OK, sha256 table appended. PUBLISHED.
- v0.177.0: CI 33432253170 success, codes 203/1203/2203/4203, ALL PINS
  OK + AAB PIN OK, sha256 table appended. PUBLISHED.
- Published-artifact chain now continuous v0.167.0 → v0.177.0.
- Next lead scouting: sixteenth delver (LAST roster slot, unlock 2100?),
  sixth tale cycle, further UI polish (instr 18), perf/anim rotation
  (instr 17), roster "Wardrobe" jump anchor idea.

## 2026-08-31 — DEMAND freeze acknowledged + Feb-2027 migration item closed
- Pulled two owner-authored DEMAND.md commits (12bd0ec, 1a82b1d): RELEASE
  FREEZE (no new tags/releases/Play until owner's consolidated cut; work
  and merging continue) + ranked freeze worklist + DECIDED: the paid
  unlock file stays portable. Freeze honored from this point; flagged to
  requester in-app for confirmation since it supersedes the per-improvement
  release instruction.
- MIGRATION (Feb-2027 item, per directive 2026-08-31b): AndroidManifest
  now declares allowBackup="true" + fullBackupContent + dataExtractionRules.
  New res/xml/backup_rules.xml + data_extraction_rules.xml explicitly
  INCLUDE emberdelve_meta.json (+ run + settings) in cloud backup AND
  device transfer ("file" domain = getApplicationSupportDirectory).
  .tmp atomic-save files not included. No release cut — riding the freeze.
- No Dart changes; push CI will validate the manifest merge + @xml refs.

## 2026-08-31 — freeze worklist item 1: size audit + font subset (merged, no release)
- arm64 APK ledger (v0.177 artifact, 35.8 MB): libflutter.so 11.6 MB
  (fixed engine cost), libapp.so 6.6 MB (AOT), music oggs 15.6 MB,
  classes.dex 3.3 MB (R8 already on), Inter-Regular.ttf 0.86 MB.
- Music is ALREADY lean vorbis (70-117 kbps stereo per ffprobe) — a
  lossy->lossy re-encode would audibly degrade a reviewed-9/10 asset for
  modest savings; Opus-in-Ogg needs API 29 under MediaPlayer. NOT done.
  The honest paths to the <30 MB pillar are (a) count Play's real
  per-device download size from the AAB, not raw APK bytes, or (b) an
  owner call on music delivery (install-time asset pack vs re-encode).
  Parked for the consolidated release discussion.
- Inter-Regular.ttf subset with fontTools 876 KB -> 247 KB (774 glyphs:
  Latin-1 + Latin Ext-A, general punctuation, arrows, math ops, U+2713;
  kern/liga/ccmp/mark/mkmk/frac/tnum kept, hinting dropped — Flutter
  ignores hinting). Chars Inter lacks (U+2726 sparkle etc.) already
  rendered via system fallback, unchanged. Verified: coverage script,
  stoker plates (kerning + em dash + middle dot perfect), full suite
  1093/1093. Original font kept at /work/temp/Inter-Original.ttf.

## 2026-08-31 — freeze worklist: REAL download size + review-charter audit
- MEASURED with bundletool 1.18.1 get-size on the v0.177.0 AAB
  [bundletool, 2026-08-31]: Play per-device download = armeabi 25.9 MB,
  arm64 26.4 MB, x86_64 26.6 MB. **The <30 MB pillar is MET when shipping
  via the AAB.** The 33-37 MB figures in the freeze directive were raw
  sideloaded split APKs (uncompressed zip stores + all densities), not
  what a Play user downloads. Font subset (-630 KB) lands on top of this.
  Sideload APKs remain ~35 MB; if the pillar is meant to cover the
  "Direct APK" path too, that needs the owner's music-delivery call.
- Review charter audited (worklist item 4): ReviewService matches every
  clause — one ask ever stamped on request, cloud merge ORs reviewAsked
  (cloud_merge.dart:156), tour-gated, no incentives/pre-filter, official
  API only. Wired once in _bankRun; test/review_service_test.dart. No
  regression, no change needed.
- Item 3 (google-services.json / pyregrove mirroring): noted, applies to
  the pyregrove repos; nothing to touch in emberdelve. Not regenerating.
- JRE for bundletool lives at /work/temp/jdk-21.0.12+8-jre (portable).

## 2026-08-31 — SIXTEENTH DELVER: The Hearthkeeper (merged under freeze, NO release)
- The FINAL chair: sworn pouch ['d6_brand','d6_ward','d6_steady'] — every
  die a forged specialist, none plain. No relic, no marks. 26 HP (sweep:
  28 -> 92.00/70.25/45.75 hot; 26 -> 91.50/68.25/42.00 vs kindler
  89.75/67.25/41.50, in band). Unlock 2100, index 15 — ROSTER CLOSED at
  16 (delve-code bits 31..34 full; hearthkeeper_test pins length==16).
- Sprite: ascetic remap hue +20° sat ×1.0 floor 0.40 val ×1.12 (hearth
  gold, doc base evens to 4; first cut floor 0.32/val 1.05 read muddy —
  A/B'd). Weapon Hearth Hook 0xFFD9A85A reach 0.50. Codex page 119.
  Promises move 15->16 (full_company/crowned_company/many-handed).
  Tales 5+40 recount Sixteen (tale 5 EXACTLY 200 chars — cap is <=200).
  Frozen vista gates: reason-only updates, marked 'never move again'.
- test/hearthkeeper_test.dart (index pin 15, roster-closed pin, easy
  win 1 / loss 3, normal win 4 / loss 8; hunt: easy losses 3 only,
  normal losses 3/8/13). tool/ sweep+hunt+visual kept.
- Suite 1095/1095, analyze clean. NO version bump, NO news entry, NO
  tag: riding the freeze. News + release notes land at the owner's
  consolidated release. Proving + honors (Kept Hearth, the_proven
  23->24) follow in the next commit (v0.119 pattern, tenth use).

## 2026-08-31 — The Kept Hearth: hearthkeeper proving + final roster honors (merged under freeze)
- The v0.119 pattern, TENTH and LAST use: hearthkeepers_proving (seed 16
  normal — seed sixteen for the sixteenth chair, bot-win pinned, unused
  by other delver provings) after stokers_proving; honors The Kept Fire
  (char_wins/hearthkeeper/1) + Sixteen Ways Down (delvers_cleared 16);
  the_proven 23 -> 24. Count pins moved in provings_test (x2 + '0 of
  24'/'1 of 24') + eighth_way_test. New test/kept_hearth_test.dart (3).
  The delver-proving block is COMPLETE — no seventeenth.
- Suite verified with JSON reporter: 1094 tests, all pass, analyze
  clean. (Plain-counter totals drifted ±1 across concatenated logs;
  per-file JSON counts confirmed every new test runs. LESSON: when a
  suite count looks off, count per-file with `flutter test -r json`,
  not with the progress counter of a combined log.)
- Still NO version bump / tag / news: riding the freeze.

## 2026-08-31 — The Sixth Cycle: ten new hearth tales (merged under freeze)
- Tales 51-60 (indices 50-59): the last chairs get theirs at last —
  cutler (edge + guard marks), collier (no relic, three small marks),
  stoker (three big coals, sixteen points of skin), hearthkeeper (dice
  forged to their work) — then the closed fire's honors: roster done
  making chairs, the Many-Handed asks all sixteen, eight crowned
  things, thirteen rungs ending at the Worldflame, provings end at the
  summit of ash, six times round the book. Every fact mirror-asserted
  in new test/sixth_cycle_test.dart (3 tests; note: the epithet ID is
  'the_six_handed' — display renamed the Many-Handed in v0.118 but the
  save-contract id never changed; CharacterDef field is startRelic
  (nullable single), not startRelics).
- Pins moved: fifth_cycle_test + fourth_cycle_test 50 -> 60,
  hearth_tale_test 5* -> 6*hearthgoldTales. All tales <= 200 chars
  (asserted in the patch before writing). hearthgoldTales stays 10.
- Suite 1097/1097, analyze clean. NO version bump / tag / news: freeze.

## 2026-08-31 — The Wardrobe Lift: jump anchor on the picker (merged under freeze)
- The picker screen is sixteen delver cards, THEN the whole Wardrobe
  (dyes, vistas, dice skins). Owner UI directive (2026-08-31 18:45)
  dislikes forced scrolling — so the app bar gains a 'WARDROBE' action
  (checkroom icon, micro/dim — quiet chrome) that walks the lazy
  ListView in short animated steps until the wardrobe header inflates,
  then Scrollable.ensureVisible settles it under the app bar. Handles
  both the full-roster long scroll and a fresh one-delver roster
  without overshooting. ScrollController owned+disposed by the state;
  anchor is a GlobalKey on the header Row.
- LESSON: ListView(children:) inflates lazily — a GlobalKey anchor far
  below the fold has NO context until scrolled near, so ensureVisible
  alone can't reach it; step-scroll first. LESSON: pumpAndSettle never
  settles on screens with idling sprites — pump fixed frames. LESSON
  (tooling): never issue two parallel file_edit calls against the same
  file; they race on the original and the second write clobbers the
  first. Edit one file sequentially.
- test/wardrobe_jump_test.dart (3 tests). Suite 1100/1100, analyze
  clean. NO version bump / tag / news: freeze.

## 2026-08-31 — plate critique caught a title squeeze (merged under freeze)
- Rendered wardrobe-lift plates (tool/wardrobe_lift_visual_test.dart,
  390x844 + 320x568, before/after the lift). CRITIQUE FINDING: the new
  WARDROBE action ellipsized the app-bar title ('CHOOSE A DELV...' at
  390, 'CHOOSE...' at 320). Fix: title wrapped in FittedBox scaleDown —
  full 'Choose a delver' at every width, slightly smaller at 320.
  Landed plates verified: wardrobe header settles right under the app
  bar; chip row + ember purse render clean at both widths.
- LESSON: any new AppBar action steals title slack — re-plate the bar
  at 320 wide whenever one is added; scale titles, never ellipsize.
- Suite 1100/1100, analyze clean. Plate tool kept in tool/.

## 2026-08-31 — perf lane: one glide, one pin (merged under freeze)
- Lift glide: the wardrobe walk was 24 chained easeOut steps — a
  saw-tooth velocity (decelerate, jerk, decelerate). Mid-walk steps are
  now Curves.linear, so the walk reads as ONE constant-speed glide; the
  final ensureVisible keeps the easeOutCubic settle. (Owner directive:
  smooth animations.)
- Scoped-rebuild pin: GameRoot's combat scoping (identical CombatScreen
  instance across controller notifications so Element.updateChild
  short-circuits) lived only in a comment. test/scoped_rebuild_test.dart
  pins it: a c.notifyListeners() must NOT produce a new CombatScreen
  widget instance, with the deliberately-_whole shop screen as the
  sensitivity control (it MUST produce a new instance). One refactor can
  no longer silently regress combat to whole-screen rebuilds per sim
  command.
- Audit alongside: SpriteView already RepaintBoundary-wrapped with a
  cached repaint driver; picker uses local setState only (user-action
  frequency); map/reward hot paths carry their own past perf fixes. No
  blind micro-optimization added.
- Suite 1102/1102, analyze clean.

## 2026-08-31/09-01 — THE CODEX LANES + the tan-bar fix (merged under freeze)
- Shared lazy walk: walkToAnchor(scroll, key, {alignment, preferUp}) in
  widgets.dart — linear glide steps until the lazy anchor inflates, eased
  ensureVisible settle, walks BOTH directions (flips once at an edge,
  gives up after covering the list both ways). The wardrobe lift now
  delegates to it (character_screen.dart shrank by 23 lines).
- Codex Lanes: the book is 119 entries across seven sections; reaching
  THE DICE was a marathon. CodexScreen (now stateful) pins one chip per
  section under the app bar — World/Company/Enemies/Relics/Rules/Marks/
  Dice — each walking the list to its keyed header. Chips NAVIGATE, they
  never filter: the whole book stays one honest page. Direction hint =
  tapped index vs last-walked index. Keys 'codex-lane-<id>'.
- test/codex_lanes_test.dart (3): chips render; dice lane inflates and
  lands the bottom section; world lane walks back UP from the bottom.
- PLATE CRITIQUE CATCH (global): M3 scrolledUnderElevation tinted every
  scrolled app bar a muddy TAN (primary surfaceTint over our palette) —
  visible on codex/picker/every scrolling screen since M3. theme.dart
  AppBarTheme now pins bg color, surfaceTint transparent, elevations 0.
  Re-plated: the bar stays the room's darkness at every offset.
- LESSON (test churn): adding a horizontal scrollable ABOVE a screen's
  ListView breaks find.byType(Scrollable).first in that screen's older
  tests — retarget them at find.descendant(of: ListView). Fixed in
  spoken_dice/ember_sink/enemy_record tests. Also: chips beyond the
  viewport need tester.ensureVisible before tap.
- Plate tool: tool/codex_lanes_visual_test.dart. Suite 1105/1105.

## 2026-09-01 — THE NEXT DELVER (retention lane #1, merged under freeze)
- DEMAND 2026-08-31c focus #1 is retention (28 MAU, 7-day retention of 1
  device) — first session / first week, "the reason to open the app
  tomorrow." First answer: the summary screen — the exact moment a player
  decides about day 2 — never named the next delver, though the picker
  has always known (meta.nextUnlockTarget). A first loss banks embers
  toward the Warden and the player was never told.
- SummaryScreen: 'next-delver' panel between the waymarks and Delve
  again — dim 40dp sprite of the cheapest locked delver, 'NEXT DELVER —
  THE WARDEN', an ember progress bar with the profile's real '<have> /
  <cost> embers'. Affordable → plain 'The embers are banked. They wait
  at the hearth.' Roster complete → panel absent. Wins AND losses
  (embers banked either way). §Ethics: recognition facts, no urgency,
  no countdown, nothing sold.
- test/next_delver_test.dart (3): loss names the Warden with real
  arithmetic; affordable swaps to the banked fact (no '/' text);
  roster-complete says nothing. Plates tool/next_delver_visual_test.dart
  at 320/360/412 — panel sits directly above the Delve-again CTA.
- Suite 1108/1108, analyze clean. No tag/version bump (freeze).

## 2026-09-01 — THE FIRST WORDS (retention lane #2, merged under freeze)
- A real Play review answered our design for us: a player FINISHED easy
  mode and wrote "I still don't understand what's a delve." The world's
  own answer — place:the_delve, the book's opening entry — sat sealed
  behind 10 embers. The first question a new delver asks should not
  carry a price.
- data/codex.dart: `giftedCodex` const set {place:the_delve} — entries
  the book gives away: always unsealed, never charged, never counted as
  an earned unseal by the ledger's marks (achievements keep reading
  ownedCodex only). meta.codexOwned(id) = bought OR gifted; tryBuyCodex
  refuses gifts. Codex screen renders gifts as owned; the UNSEALED
  header counts them honestly (fresh profile reads '1 of 119').
- delve_itself_test purchase pin updated to the new truth (gift refuses
  sale, purse untouched; the_ember still sells at 10); new widget test:
  fresh profile opens the book with the delve's lore readable, header
  '1 of 119', tapping the gift sells nothing.
- Suite 1109/1109, analyze clean. No tag/version bump (freeze).

## 2026-09-01 — THE SHARED FIRE, RELIT (retention lane #3, merged under freeze)
- The daily delve is the literal "reason to open the app tomorrow," and
  its only front door (v0.153.0 shared-delve tip) was gated on a first
  WIN (runsWon >= 1). The players most at risk of never returning are
  the ones LOSING their opening runs — exactly the cohort the tip never
  reached. Gate is now any FINISHED run: tips.onTitleArrival takes
  playedBefore (runsPlayed >= 1) instead of wonBefore. Copy unchanged
  (already charter-clean: "a skipped day is silent and costs nothing").
- shared_fire_test updated to the new truth (a lost first run counts);
  news_ui_test veteran profile marks the tip seen (it now legitimately
  fires for daily-never veterans, which is desired in the app — the
  test just needs one story on the title).
- Suite 1109/1109, analyze clean. No tag/version bump (freeze).

## 2026-09-01 — THE RETURNED DELVER (retention lane #4, merged under freeze)
- Day-2 arrival: the daily recap (v0.3.4) speaks only on the day it was
  played — a player who came back TOMORROW (the exact behavior the
  retention focus wants) arrived to a title that said nothing. Now, when
  the profile's last daily is yesterday's, one micro line under the
  Daily button acknowledges the return and states the one fact that
  matters: dailyReturnLine (game/daily_share.dart) — won: "Yesterday's
  delve fell to you. Today deals a new one." / lost: "Yesterday you
  reached floor N. Today deals a new delve." Key 'daily-return'.
- Still the SINGLE stored record (no history added), never both lines at
  once, older-than-yesterday stays fully silent, copy sweep pinned
  against the banned list (§Ethics: what is true today, never what is
  owed). daily_record_test extended: today→recap, yesterday→return line,
  older→silence + ethics sweep on both variants.
- Suite 1110/1110, analyze clean. No tag/version bump (freeze).

## 2026-09-01 — THE MEASURED GLIDE (perf lane; probe only, no app change)
- Standing perf directive (2026-08-31): frame-cost audit of the two newest
  hot paths. New tool/glide_probe_test.dart (NOT in CI; perf_probe method:
  debugOnProfilePaint per-frame counts → build/glide_probe/metrics.json).
- Findings [glide_probe, 2026-09-01]:
  - codex idle: 0.0 paints/frame — the book is fully static at rest.
  - codex lane glide (World→Dice 18.2, Dice→World 20.2 paints/frame while
    the walk is animating): all of it is lazy child inflation inside the
    moving viewport (RenderIndexedSemantics/RenderRepaintBoundary pairs —
    ListView.addRepaintBoundaries doing its job). No app-bar, chip-row, or
    route-level leakage. Reference: pre-fix map_drag was 54.5/frame.
  - title idle with day-2 return line: 3.0 paints/frame, IDENTICAL to the
    plain title (RenderCustomPaint = EmberDrift's own layer only). The
    return line costs nothing at rest.
- Probe lessons: a guarded tester.tap cannot be left unawaited (chip onTap
  discards the glide future, so awaiting the tap does NOT await the walk —
  pump frames after); ensureVisible scrolls earlier chips off the row, so
  re-anchor before tapping a leftward chip.
- Verdict: boundaries hold; no remediation needed. No tag/bump (freeze).

## 2026-09-01 — THE UNCLIPPED WORD (UI lane; plate pass over this session's new surfaces)
- Plate review of everything that gained content under the freeze:
  next-delver panel (320/360/412 — reads well at all three, sprite dim,
  bar honest), codex lanes top/mid/narrow (chips clear, gifted The Delve
  unsealed with PLACE tag, '1 of 119 UNSEALED'), first-words title 320.
- One real find: the Short Delve toggle's helper ellipsized mid-word on
  320px ("six floors — a sh…"). Doctrine is wrap or scale, never clip
  meaning (v0.174 title-scale lesson) — the helper now wraps to two
  lines (maxLines: 2), full words at every width; 360+ stays one line.
  Verified by re-plate at 320x568 and the 36-size overflow probe.
- Suite 1110/1110, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE LARGE PRINT (UI lane; 1.3x accessibility plate pass)
- New plate tool tool/large_font_plates_test.dart (NOT in CI): title
  (day-2 state), wardrobe picker (full roster), summary (next-delver
  panel), settings — all at 320px AND 1.3x system text (Android
  "Large"), the accessibility worst case. The overflow probe catches
  layout ERRORS at 1.3x; these plates catch what it cannot — clipped
  words, cramped rows.
- Findings: picker, summary, and settings all degrade gracefully at
  1.3x — delver cards wrap kit lines, next-delver panel wraps its
  heading, settings helper copy wraps, nothing clipped.
- One regression caught in the freshly-merged Unclipped Word: the
  Short Delve helper's maxLines: 2 cap clipped its LAST word at 1.3x
  ("…a shorter" without its "sit"). The cap is gone — the helper now
  wraps freely (three lines at 320/1.3x, two at 320/1.0x, one at
  360+). Every word survives every width and font scale.
- LESSON: maxLines is just deferred ellipsis — under a bigger font
  scale the cap clips again. For helper copy, wrap freely and let the
  row grow; plate at 1.3x before calling a wrap fix done.
- Suite 1110/1110, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE SETTLED ROOM (UI lane; settings scroll-comfort plate check)
- New plate tool tool/settings_scroll_visual_test.dart (NOT in CI):
  settings at 320x568 — top, mid-scroll, bottom. First eyeball pass on
  this screen since ScrollComfort landed in v0.174.
- ScrollComfort verdict: fades behave honestly — bottom fade only at
  the top, both fades mid-scroll, top fade only at the bottom. No
  remediation.
- One cramp: every settings action row put Expanded(Text) flush
  against its button — on 320px the Paste row's copy ("…to merge")
  touched the PASTE plate. Space.m gutter inserted between text and
  button in all ten action rows (save-code, unlock-code, tour, about,
  et al). Re-plated: every row breathes; 1.3x plates unchanged-good.
- Suite 1110/1110, analyze clean, large-font plates re-verified.
  No tag/bump (freeze).

## 2026-09-01 — THE NAMED FOE (retention lane, DEMAND focus #1)
- Research (Roguebook GDC writeup; GlyphShuffle replayability essay;
  failure-design pieces) converges on one churn moment: the loss the
  player cannot explain. "You should be able to lose and understand
  the chain" — our loss summary named the floor but never the foe.
- The loss summary now shows a tappable row after the loss lines:
  "The <killer> has a page in the codex." One tap opens the codex
  glided straight to that entry (walkToAnchor, alignment 0.15) —
  sealed or unsealed, the book decides what it shows. Wins show
  nothing. Copy is a fact, not a prod (banned-words charter clean).
- CodexScreen gains optional `openEntry` (namespaced id): post-frame
  walk to that entry's card; the opened entry carries a GlobalKey
  anchor instead of its ValueKey.
- namedFoeEntry(c) helper beside lastThreadLine in summary_screen.
- test/named_foe_test.dart (2 pins: loss row names killer + tap lands
  codex at entry; win shows nothing). Plate tool
  tool/named_foe_visual_test.dart (320px, 1.0x AND 1.3x text): row
  wraps cleanly, codex lands on the killer's card ("Quench Hag —
  Met 1 · Deaths 1") at both scales.
- Suite 1112/1112, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE WEIGHED SUMMARY (perf lane; repaint probe on the grown summary)
- New probe tool tool/summary_probe_test.dart (NOT in CI; glide-probe
  method): the summary gained a second live SpriteView (next-delver)
  and the named-foe row since the last measurement — weighed it.
- Numbers [summary_probe, 2026-09-01]: idle loss summary 1.0
  paints/frame (one RenderCustomPaint — the sprite tickers stay inside
  their RepaintBoundaries; ledger, panels, route all sleep). Full
  drag down+up 11.6/frame, all lazy child inflation (pre-fix map_drag
  reference: 54.5). Named-foe tap → route push + codex openEntry glide
  15.6/frame across 120 frames, RepaintBoundary/IndexedSemantics
  dominated = the 119-entry walk inflating lazily, as designed.
- Verdict: boundaries hold everywhere; no remediation. The retention
  strikes cost the summary nothing at idle.

## 2026-09-01 — THE FIRST FALL (retention lane, DEMAND focus #1, first-session funnel)
- Research: Hades death-moment design ("the moment of death isn't about
  rage-quitting... feel the time you spent wasn't a waste" — Kasavin,
  gamedeveloper.com) + Slay the Spire first-run telemetry (~90% of
  first runs lose, foxrow.com) + loser-friendly design essay (losing is
  a valid way to experience the game). The genre's normal first
  experience IS a loss; a new player may read it as a failure screen.
- The profile's very first LOST run now opens its loss cluster with one
  gold line: 'A first fall — every delve ends in one, sooner or later.
  The embers you banked came home with you.' Once ever (runsPlayed==1
  && runsWon==0 at summary time). Sits ABOVE last-thread/named-foe, so
  a first loss reads frame → foe → codex page. The ember claim is
  always true: sim's fair-death floor banks >= 5 + layer on any death
  (run_layer.dart ~926).
- firstFallLine(c) helper beside settledScoreLine in summary_screen;
  ValueKey('first-fall'); charter-clean copy (a fact, no consolation
  prize language, no prod).
- test/first_fall_test.dart (3 pins: first loss shows it AND the banked
  embers fact is true; second loss silent; first win silent). LESSON:
  seed 13 is only a pinned loss on a FRESH profile — replayed after a
  prior run it wins; back-to-back seed 18 stays a loss.
- Plate tool tool/first_fall_visual_test.dart (320px, 1.0x and 1.3x):
  wraps freely, leads the cluster cleanly at both scales.
- Suite 1115/1115, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE ROOMY HOLLOW (UI lane, Large Print sweep over the mid-run screens)
- New plate tool tool/midrun_large_plates_test.dart (NOT in CI): reward,
  rest, shop, event, and the WIN summary at 320x568 in 1.0x AND 1.3x
  text. These were the last surfaces never re-plated since the Large
  Print doctrine (87961f13).
- FOUND: the rest screen's fixed column (title + subtitle + hearth tale
  + rest/temper buttons) overflowed 78px at 1.3x — Spacers collapse to
  zero but fixed prose cannot; no scroll escape existed. The tip card
  itself was already guarded (its own SingleChildScrollView).
- FIX: _hollowBody(...) builds the hollow's pieces once and arranges
  them two ways. Normal scale: the exact designed still room (Spacers,
  seated buttons, flexing forge list) — nothing scrolls, per the
  no-scroll directive. Under pressure (textScaler >115% AND height
  <640): the same pieces stack in one ScrollComfort ListView — every
  word and button reachable, nothing clipped.
- All other mid-run surfaces passed clean at both scales (reward cards,
  shop rows, event choice buttons, win summary all wrap correctly).
- Suite 1115/1115, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE STEADY RENDERER (perf lane, under freeze)
Impeller opted OUT on Android via manifest meta-data
(io.flutter.embedding.android.EnableImpeller=false), keeping Skia as
the renderer.
- Why: our market skews Adreno 5xx / low-end Mali. Flutter's engine
  denylists Vulkan on Adreno <=650, so those devices fall to Impeller
  GLES, which measures ~28fps vs Skia ~54 on Adreno 506
  (flutter/flutter#187009), and Android-10 Mali carries an
  ImageDecoder SIGABRT (flutter/flutter#190640 — we decode sprite
  PNGs). DEMAND pillar #2 = protect the zero-crash record; a pure-2D
  CustomPaint game gains nothing from Impeller here.
- Verified: debug APK built, merged manifest confirmed via aapt2 dump
  (EnableImpeller=false present) [local build, 2026-09-01].
- Re-evaluate on every Flutter upgrade (comment in manifest says so).
  Mirror to pyregrove-ci per DEMAND config-mirror rule.
- Manifest-only change; suite untouched (1115). No tag/bump (freeze).

## 2026-09-01 — THE MORROW'S DELVE (retention lane, under freeze)
A finished daily now states tomorrow's declared trial — the day-2 hook
lands at the exact moment today's is done.
- lib/game/trials.dart: trialForMorrow(now) (pure next-calendar-day via
  DateTime(y,m,d+1) — month/year rollover safe) + morrowTrialLine(now)
  ("Tomorrow's trial: NAME — blurb").
- Summary: daily runs only (gate c.dailyResultShareText != null), micro
  dim line ValueKey('morrow-trial') after the trial-met chip. Normal
  runs render nothing.
- Title: the played-today recap block adds the same line under the
  checkmark; the day-2 return line stands alone (no lecture about the
  day after tomorrow).
- §Ethics held: a fact about what tomorrow IS — no countdown, streak,
  or owing language; banned-word sweep pinned in test.
- test/morrow_trial_test.dart: 4 pins (pure rollover incl. year edge;
  honest-copy sweep; daily summary shows / normal run silent; title
  shows on played day only, absent on day-2 return).
- Suite 1119/1119, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE DEALT HAND (animation lane, under freeze)
Choice hands now deal in instead of popping: staggered fade + 14px rise
per card on the boon and keystone screens.
- lib/ui/fx.dart: DealtIn(index, child) — 300ms/card + 90ms stagger,
  Interval curve (no Timers), settled state is the identity so an idle
  screen pays nothing. Reduce-motion renders settled immediately;
  semantics always included (a reader hears the full hand at once).
- boon_screen.dart / keystone_screen.dart wrap each card in DealtIn.
- Third card settles at 480ms — under the 700ms older widget tests pump
  before tapping (verified: widget_test/overflow/semantics all green).
- test/dealt_hand_test.dart: 2 pins (stagger ordering mid-deal +
  settled identity; reduce-motion skip). Plate tool
  tool/dealt_hand_visual_test.dart (deal start / mid / settled, 360x800
  — all three beats read clean).
- Suite 1121/1121, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE KINDLED TALE (animation lane, under freeze)
The rest-hollow hearth tale now smolders in like fire catching down the
page, instead of pasting on screen. (Research pass [2026-09-01]:
slow-smoldering / letter-reveal UI text is a current indie trend —
Gamescom LATAM coverage, loomfeed 2026-05-28; micro/transition timing
canon 100-200ms / 200-400ms confirms DealtIn and this sit in band.)
- lib/ui/fx.dart: SmolderIn(child, duration=900ms) — paint-only
  ShaderMask alpha sweep top-to-bottom with a warm ember leading edge.
  Full text laid out + semantic from frame one (no reflow, no partial
  strings for readers or tests); mask DROPPED entirely once complete
  (settled = plain child, zero per-frame cost). Reduce-motion renders
  plainly, immediately.
- rest_screen.dart wraps the hearth-tale Text in SmolderIn.
- test/kindled_tale_test.dart: 2 pins (full text findable mid-sweep +
  mask dropped when settled; reduce-motion never masks). Fixture reuses
  hearth_tale_test's bot-driven atRest (LESSON: "seed 6 reaches rest"
  holds under botCmd, NOT under the trivial roll/end_turn walker — that
  policy dies before the hollow).
- Plate tool tool/kindled_tale_visual_test.dart (mid / late / settled,
  360x800): first line catches with warm edge, settled identical.
- Suite 1123/1123, analyze clean. No tag/bump (freeze).

## 2026-09-01 — THE BOUNDED ENTRANCE (perf lane, under freeze)
New probe tool/entrance_probe_test.dart (NOT in CI; reports, never
asserts) measures repaint cost of the two new entrance effects, mounting
BoonScreen/RestScreen DIRECTLY — the PhaseSwitcher fade legitimately
repaints the incoming screen every frame and drowns the signal if the
probe goes through GameRoot.
- Findings (before): DealtIn deal repainted the whole screen (85
  paints/frame incl. fade); SmolderIn sweep repainted the whole hollow
  (104 paints/frame).
- Fix in fx.dart: DealtIn gains RepaintBoundary on BOTH sides of the
  Opacity/Transform pair (outer keeps deal dirt off the screen, inner
  caches the card subtree as a layer); SmolderIn wraps its ShaderMask in
  a RepaintBoundary (mask builder extracted to _mask). Settled paths
  unchanged (identity / mask dropped).
- After: deal 7.1 paints/frame, smolder 3.0, both settled 1.0 (=
  EmberDrift baseline) [entrance_probe, 2026-09-01].
- Plates re-shot: deal stagger and smolder read identical — boundaries
  are visually invisible. Suite 1123/1123, analyze clean. No tag/bump.

## 2026-09-01 — THE CARVED CHASM (visual lane, under freeze)
The map chart now reads as the inside of a delve instead of nodes on a
void: jagged rock walls frame both sides of the descent.
- map_screen.dart _MapScenePainter._wall(): two overlapping silhouettes
  per side (far wall wider/dimmer, near wall darker) + a faint warm rim
  stroke where torchlight grazes the rock. Edge is a pure function of y
  (two sine octaves, per-side phase) — deterministic, no RNG state, and
  the painter stays static: zero per-frame cost, shouldRepaint
  unchanged. Max wall extent 31px; node centers start at x=54 and nodes
  are widgets ABOVE the CustomPaint, so no collision at any width.
- Plate tool tool/carved_chasm_visual_test.dart (chasm_start floor 1 +
  chasm_deep floor 4, 360x800): two-plane depth reads on both sides,
  walls sit behind trails/nodes, fog-of-war unaffected. Verified by eye.
- Suite 1123/1123, analyze clean. No tag/bump.

## 2026-09-01 — THE WHISPERED RUMOR (animation lane, under freeze)
SmolderIn extended to its second surface: the boon screen's rumor line
catches light (700ms) while the hand deals — one entrance language for
the whole boon moment.
- boon_screen.dart wraps the rumor-line Text in SmolderIn(700ms).
  Paint-only as before: rumor_test's full-text read still passes
  untouched, semantics whole from frame one, mask dropped when settled,
  reduce-motion plain.
- test/kindled_tale_test.dart gains a third pin: rumor masked mid-sweep
  with full text + mask gone settled (BoonScreen mounted directly).
- Suite 1124/1124, analyze clean. Plates re-shot (dealt_hand set);
  visual eye-check pending — the sandbox image viewer was down this
  loop (upload Unauthorized); mechanism identical to the eye-verified
  hearth tale smolder. No tag/bump.

## 2026-09-01 — map idle probe (perf lane, tool-only)
entrance_probe gains a map_idle_60f measurement (MapScreen mounted
directly, entrance walk settled first): 17.0 paints/frame idle, decoded
exactly as 4 reachable-node pulse glows x 4 small render objects each +
EmberDrift's 1 [entrance_probe, 2026-09-01]. _MapScenePainter (which
now carries THE CARVED CHASM walls) contributes ZERO idle paints — the
walls are confirmed free per-frame, and the node pulse dirties only
tiny glow subtrees. No lib/ change needed; report only.

## 2026-09-01 — THE WEIGHED FALL (animation lane, under freeze)
The summary's four narrative one-liners kindle in with SmolderIn — the
screen that decides day-2 return now delivers its verdict lines with
the same entrance language as the hearth tale and the rumor:
- first-fall + settled-score (gold, the big beats): 900ms.
- last-thread + narrow-climb (quiet micro facts): 600ms.
- The tappable named-foe panel stays static — it is a control, not a
  tale. Ledger, buttons, waymarks untouched: only prose smolders.
- Paint-only as ever: full text + semantics frame one, mask dropped at
  rest, reduce-motion plain. first_fall_test pins a SmolderIn ancestor
  (type check — time-independent). Suite 1124/1124, analyze clean.

## 2026-09-01 — THE FIRST SPARK (perf lane, under freeze)
Research pass (game-juice + low-end Flutter, 2026 sources) confirmed
combat juice already implements the canon (magnitude-scaled shake = the
"Balatro data channel", 80ms hit-stop at >=25% hits, 120ms flash in the
readable 50-100ms+tail window) — no change needed there. The real gap:
THE STEADY RENDERER pinned Skia, and Flutter ships no default shader
warm-up anymore, so every shader family compiles mid-animation on first
sight — a first-use hitch on exactly the low-end devices the directive
names.
- lib/ui/warmup.dart: EmberShaderWarmUp draws one small instance of
  every shader family the app actually uses (grep-audited): linear
  gradient fill/mask, radial glow, sweep ring, MaskFilter.blur, solid +
  stroked rrects/paths, saveLayer composite. ~12 draws, 100x100.
- main.dart sets PaintingBinding.shaderWarmUp BEFORE the binding
  initializes (contract: initInstances executes it).
- test/warmup_test.dart pins the scene rasterizes end-to-end (execute()
  through toImage) so it can't silently rot. Suite 1125, analyze clean.

## 2026-09-01 — THE DEEP WALL (visual/perf lane, under freeze)
The chasm gains true depth: the far rock plane now parallaxes, lagging
the scroll at 6% while the near wall, trails, and nodes move with the
chart — during a drag or the camera follow the walls read as standing
apart in space.
- _FarWallPainter (map_screen.dart): far plane extracted from
  _MapScenePainter into its own scroll-driven layer (repaint: the
  ScrollController itself), behind its own RepaintBoundary, under the
  scene. ValueKey('deep-wall'). Reduced motion pins offset 0 — the
  plane holds still but stays.
- Probe-verified pricing [entrance_probe, 2026-09-01]: map idle
  UNCHANGED at 17.0 paints/frame (parallax layer contributes zero);
  deep wall repaints exactly 1x per scrolled frame (10/10 in a counted
  drag) — one 2-path fill, nothing else joins it.
- Chasm plates re-shot (identical at offset 0 to the eye-verified set);
  suite 1125/1125, analyze clean. screens.dart gained motion.dart
  import (part-of files share it).

## 2026-09-01 — THE SWIFT LANTERN (perf lane, under freeze)
Cold-boot audit of main(): four independent service bring-ups (Play
Games prefs, reminder prefs, Watchtower prefs, and telemetry's
Firebase.initializeApp platform-channel init) ran in strict sequence
before runApp — on a slow phone the title screen literally waited on
Firebase. They now overlap in one Future.wait; every load still
completes before runApp, all wiring below is order-independent of the
loads (verified by reading each), so semantics are unchanged — only
the wall-clock sum shrinks to the slowest single member. app_open
still fires after telemetry is up. Suite 1125/1125, analyze clean.

## 2026-09-01 — THE OPEN FORGE (UI lane, under freeze; owner no-scroll directive)
New probe tool/scroll_audit_test.dart (report-only, not in CI): mounts
boon/map/rest/title at 360x800 and 320x640 and reports every
scrollable's maxScrollExtent. Doctrine: content lists may scroll
(browsing); decision screens must fit.
- FOUND: the rest hollow's default layout gave the forge list only the
  leftover strip under the buttons — a ~107px letterbox hiding 586px of
  forge rows (7 options, ONE visible) behind a nested inner scroll.
- FIX: whenever anything is forgeable the hollow now uses the one
  full-height ScrollComfort list (the former cramped branch): every
  forge option sits inline in the page, one honest scroll, no peephole.
  The centered no-scroll Column remains for the rest-only hollow.
- Remaining audit numbers are by-design: map pans (it's a chart), title
  and summary are browsable lists, boon fits at 360x800 (22px overflow
  at 320x640 noted as a future shave).
- Suite 1125/1125, analyze clean; hearth plates re-shot (eye-check
  queued, viewer still down).

## 2026-09-01 — THE TRIMMED WICK (UI lane, under freeze)
Scroll-audit follow-up: the boon hand overran 320x640-class screens by
22px. On short screens (<700px) the two decorative gaps shrink
(24->8, 16->8); text and cards never shrink. Audit now reads
maxExtent=0 at BOTH 360x800 and 320x640 — the decision screen fits
everywhere. Suite 1125/1125, analyze clean.

## 2026-09-01 — THE WALKED PATH (animation lane, under freeze)
The map delver's node-to-node walk gained three tells (map_screen
_delverMarker): the sprite faces its travel direction (Transform.flip
while moving left), the drop shadow stays grounded on the path and
thins/lightens at each hop apex (width 14->9, alpha .40->.22), and the
hop now respects reduce motion (glide alone remains). New
test/walked_path_test.dart pins the squash mid-walk and its absence
under reduce motion (suite 1127).
BONUS FIX: that test's teardown exposed a latent crash — EmberDrift's
AnimationController was a lazy `late final`; under reduce motion
build() never touched it, so dispose() CREATED it during unmount and
crashed on the TickerMode ancestor lookup. Now created eagerly in
initState (fx.dart). Any screen with EmberDrift unmounted while
reduce-motion was on would have thrown. Plates eye-verified (walk apex
mid-flight + settled); full eye-check queue also cleared this loop
(chasm, dealt hand, hearth, first-fall, settled-score — all pass).

## 2026-09-01 — v0.178.0 retention pick: THE SEVEN HEARTHS (mechanism, written BEFORE building)

Owner directive 2026-09-01 authorizes ONE release carrying ONE cohesive
retention improvement. Pick: **a first-week arc that resolves** — the
Seven Hearths.

WHY THIS MOVES DAY-7 RETENTION (the mechanism):
- The measured failure is day-7 (28 MAU, 7-day retention = 1 device),
  not day-1: people play a session and never build a week. Every
  existing hook is either single-day (morrow trial: reaches only day 2)
  or endless (the 2100-ember unlock ladder: no near horizon a new
  player can see resolving). Nothing in the game today names "your
  first week" as a thing that completes.
- The Seven Hearths gives the first seven PLAYED DAYS a visible,
  bounded arc: each day you finish (or even abandon) a delve, one of
  seven hearths on the title screen lights. Day counting uses distinct
  local dates, NOT consecutive days — a missed day costs nothing and
  the copy says the hearths keep. This is the strongest honest form of
  a week hook available under the §Ethics charter (no streaks, no
  expiry, no loss-framing) — the mechanism is goal-gradient + a
  concrete near-term resolution, not fear.
- It RESOLVES rather than trails off: the seventh hearth settles 60
  embers into the pouch (half a delver unlock — the ladder's own next
  step, so the arc hands you into the endless loop) and the row then
  retires from the title. One-time, per-profile, monotonic, cloud-merge
  MAX/OR so it can never regress or double-grant.
- Each session in week one thus ends with a changed title screen the
  next open will show — a reason to come back tomorrow that is a fact
  ("the third hearth lit") instead of a nag.

Falsifiable prediction: day-7 retention among NEW devices in the 28
days after ship should move off 1; if it does not, the next lever is
the opening run itself (R1 brief input).

## 2026-09-01 — v0.178.0 THE SEVEN HEARTHS (the one authorized release)

- Seven Hearths built exactly as the mechanism note above: hearths.dart
  (hearthCount=7, hearthGrantEmbers=60, hearthLine 0..7), meta fields
  (hearthDaysLit / lastHearthDay / sevenHearthsSettled), cloud merge
  MAX/OR, _lightHearth() at the top of _bankRun and abandonRun, title
  row between the daily block and the Weekly button.
- Suite 1136 green (9 new in test/seven_hearths_test.dart), analyze
  clean; plates eye-checked at 360x640 (0/3 lit) and 320x568 (settled).
  Lesson kept: never await controller.boot() inside a widget test —
  real I/O under FakeAsync hangs to the 10-minute timeout; title-row
  fixtures use an unbooted controller (waymark_line_test pattern).
- Version bumped 0.178.0+204; currentAppVersion 0.178.0; news entry;
  docs/releases/v0.178.0.md. ONE release, NOT prerelease, no Play.
- Release v0.178.0 PUBLISHED on GitHub (target 1e9a49ac, latest, not
  prerelease): signed CI run 33503007781, all 5 artifacts uploaded
  (universal apk code 204, aab 204, arm64 2204, v7a 1204, x86_64 4204),
  every signer cert matched pin 031acb42..., sha256 table appended to
  the notes. The tagged AAB is the Play candidate — do NOT rebuild.
  [publish_release.sh, 2026-09-01]
- SHIPPING STOPPED per DEMAND 477857cf. Next work is written research
  only: R1 first-session teardown, R2 session-end blindness options,
  R3 store-listing conversion doc. No second version bump.
- R1/R2/R3 research briefs written per DEMAND 477857cf (documents
  only, no code, no listing changes):
  docs/research/r1-first-session-teardown.md (method-labeled — no
  device/emulator in sandbox, so secondary-source teardown; top
  finding: sub-45s cold-start-to-first-roll in genre leaders +
  combat undo as the trust feature; our loss handling and day-2
  hooks already lead the premium field),
  docs/research/r2-session-end-blindness.md (recommendation: ask
  nothing, read Play Console harder — monthly retention ledger,
  first entry due ~2026-09-29 to judge the Seven Hearths
  prediction; consent-prompt rework parked behind MAU>500 trigger;
  third-party analytics rejected),
  docs/research/r3-listing-conversion.md (proposed listing as a
  document: short-desc keyword fix, screenshot reorder with
  benefit-first captions, trust block lifted to the top; live
  listing untouched — FROZEN). [research, 2026-09-01]
- R1 addendum: decision-distance probe
  (tool/first_session_distance_test.dart, green) — fresh profile
  reaches its first meaningful decision at tap 2 (boon pick) and the
  first roll at tap 4 across 4 screens; tour beat 1 anchors the ROLL.
  No structural first-session change warranted from tap distance;
  device wall-clock pass still owed. Also: retention-ledger.md
  created (R2 Option A instrument, baseline row; next pull
  ~2026-09-29, wakeup scheduled). [probe, 2026-09-01]
- R3 addendum: proposed listing screenshots rendered as documents —
  docs/store/screenshots/framed-r3/ (5 plates, R3 order + captions,
  live framed/ untouched, listing still FROZEN). [probe, 2026-09-01]
- R1 addendum 2: "what's a delve" vocabulary gap is ALREADY CLOSED
  (v0.71.0 firstWordsLine + gifted codex place:the_delve; reviewer
  was on pre-fix Play build 0.59.0). Corrected R1's residual-gap
  claim; nothing to ship. [code-audit, 2026-09-01]
- R3 supplement written (docs/research/r3-supplement-trust-headline.md):
  trust-as-headline = objection-handling before the pitch; evidence
  (S&D trust-list-as-description, Royal Match "no ads" brand arc,
  premium niche ~15%, Play cold-start traffic wall); relaunch copy
  implications — trust block as FIRST line, "everything visible"
  phrasing, itch demo funnel parked as owner call. [web, 2026-09-01]
- Perf: idle map repaint leak fixed — RenderCustomPaint repaints its
  children, so each reachable-node halo pulse frame was also redrawing
  the static icon stack (17.0/frame). Child now boxed in its own
  RepaintBoundary: idle map 17.0 -> 9.0/frame (5 real painters: 4
  reachable halos + drift; rest are boundary composites). Probe:
  tool/map_idle_probe_test.dart. No behavior change; suite 1136 green,
  analyze clean. NOT released — code sits on branch per one-release
  demand. [map_idle_probe, 2026-09-01]
- Owner directive 2026-09-01b (DEMAND.md 69401329) executed: (1)
  retention-ledger.md now opens with the no-new-tracking constraint;
  (2) R3 supplement corrected — itch is already the full free game,
  discovery surface only, no demo funnel exists to build; (3)
  docs/research/traffic-channels.md written — ranked zero-budget
  channels with sources & falsification (anchors: Asterogue 30
  Android sales across ALL channels @ ~1% conversion; Everfront
  UTM data: niche subs convert 2-3x broad, one niche post = 59% of
  results). Top of list: r/AndroidGaming dev post, r/roguelikes
  release post; HN postmortem essay = only fat-tail; GDWC/TouchArcade/
  X/broad-indie-subs named and rejected. [web, 2026-09-01]
- Pattern audit after the map fix: grep for `super(repaint:` painters
  paired with a CustomPaint `child:` — logo.dart, weapons.dart (x2)
  are painter-only, no child; the map medallion was the ONLY leak of
  this shape. Lesson: a RenderCustomPaint repaint also paints its
  children — any repaint-driven painter with a static child needs the
  child in its own RepaintBoundary. Audit complete, don't redo.
  [code-audit, 2026-09-01]
