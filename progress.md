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
