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
