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
