# Checkpoint 04 — v0.3.0: gameplay depth + visual overhaul + permanent signing

State as of branch `v030-integration` (version `0.3.0+3`). Read alongside progress.md §v0.3.0.

## What shipped
- **Sim v4** (SIM_VERSION 4, golden `1117081416`): combos (pair/triple-ignite/straight), `reroll_risky`, exact-kill +5 embers + capped overkill splash, honest offer-stream reward telegraphs (elite ⇒ tier-3 die), 1-of-3 starting boons (`start_run {boons:true}`, `choose_boon` 0=skip, `lib/data/boons.dart`), `dailySeed(y,m,d)` (`lib/sim/daily.dart`). Enemies rescaled hp ×2.4 / atk +7 / blk +5. Contract: `docs/m4-sim-contract.md`.
- **Visual system**: de-Flutter pass, 100% programmatic (no new binary assets). `lib/ui/fx.dart` (hit-stop, shake, damage/Text pops, ember dissolve, flame wipe), `lib/ui/logo.dart` (drawn logotype + camp-fire title). Painted buttons, pip die faces + tumble, segmented HP bars, map medallions/fog/trails, transitions, victory/defeat moments.
- **UI wiring**: all v4 mechanics playable — combo/burn call-outs, gated risky-reroll tray control, exact/overkill moments, telegraph badges (verbatim from sim preview — never invent), boon screen, "Daily Delve" title entry (device-LOCAL date; contract doc said UTC, owner objective won), fast "Delve again", stale v3/corrupt autosave cleanup on boot.
- **Release signing (permanent)**: Gradle `key.properties` signingConfig (debug fallback when absent); CI `build-android-release` (main pushes + dispatch, never PRs) builds signed APK+AAB, gated on apksigner cert fingerprint. Cert SHA-256 `03:1A:CB:42:56:6A:51:D5:B5:9F:FD:5D:EB:17:3F:1B:0E:81:7A:9E:DF:F1:BB:69:79:F6:85:64:D4:4B:7A:0D` (valid 2066). Keystore lives OUTSIDE the repo (owner-side, private). See `docs/release.md`.

## Verification (all reproduced by the integrator, not just workers)
- `flutter analyze`: clean. `flutter test`: 54/54.
- Autoplay 200 seeds: win 53.5% (band 20–80%), 0 invalid commands.
- Signed-build CI run 30018705918 green; fingerprint gate passed.

## Gotchas for the next agent
- Fine-grained-PAT pushes do NOT trigger push workflows — dispatch with `gh workflow run CI --ref main`.
- Ambient animation loops hang `pumpAndSettle`; use the bounded `pumpFor` helper (see test/widget_test.dart header).
- v3 autosaves are rejected by v4 `restore`; `GameController.boot()` deletes them and lands on title.
- `MapScreen._walkFrom` is a static guard — revisit if map screens ever coexist.
- Debug-signed v0.2.0 installs cannot upgrade in place to release-signed builds (different cert): one-time uninstall, then never again.

## Descoped (deliberate, still open)
- gameplay-depth backlog: A3 chaining faces, B6 relic combo synergies, B7 adaptive telegraphs.
- visuals backlog: #4 reward card flip, #8 launcher icon retint.
- On-device eyeball of motion timings + the taller combat action zone (tuned blind; widget-test viewport only).
