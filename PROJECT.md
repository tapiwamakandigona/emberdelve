# PROJECT.md — Emberdelve (v2: action platformer)

**Goal:** A 2D **pixel action-platformer** for Android (Google Play), built with Flutter + Flame. Inspired by *Apple Knight*'s loop — run/jump/double-jump, melee combat, coins, treasure chests, secret rooms, level-based worlds, and a meta shop (weapons · skins · abilities) — but tighter, fairer, and better optimised. Landscape, touch-first, 2–5 minute levels. Free download, no forced ads.

**Owner:** memorymadie (Tsoro Studios, GitHub `tapiwamakandigona`). Built by Tsoro Studios. This repo is designed so **anyone can resume the project from these files alone** — read this file, `features.json`, the tail of `progress.md`, then run `init.sh`.

> **Pivot note (2026-07-24, owner-directed):** The original turn-based dice-builder
> is archived intact on branch `legacy/dice-builder`, tag `v0.3.10-legacy`, and the
> GitHub release "Emberdelve Classic". Everything below describes the new game.
> The legacy spec lives at `docs/legacy/`; do not build against it.

## Canonical artifacts
| What | Where |
|---|---|
| Product spec v2 (platformer) | `docs/spec.md` |
| Architecture v2 | `docs/architecture.md` |
| Definition of done | `features.json` (machine-readable; workers only flip `passes` + `evidence`) |
| History / decisions | `progress.md` (append-only), `checkpoints/` |
| Dev environment | `init.sh` |
| Asset licensing | `PROVENANCE.md`, `CREDITS.md` (shipped in-app) |

## Standing decisions (do not relitigate without owner)
1. **Engine:** Flutter (stable 3.32.x, Dart ≥3.8.1) + **Flame** (pinned in pubspec). Owner mandate: Flutter for consistency with their other apps.
2. **Repo:** public. Only CC0 / CC-BY assets with attribution shipped in-app (`PROVENANCE.md`). No license may forbid redistribution.
3. **Package id / signing:** `com.tsorostudios.emberdelve` and the permanent upload keystore are **immutable** — the Play closed-testing track depends on them. Never regenerate keys; never change `EXPECTED_CERT_SHA256` in CI.
4. **Architecture seam:** game logic (`lib/game/`) is engine-code but *headless-testable*: level parsing, physics resolution, economy, and save data have zero rendering dependencies and are covered by `flutter test`. Determinism where it matters (drops, daily seeds) via seeded RNG (`lib/core/rng.dart`).
5. **Gameplay loop:** level-based worlds → collect coins/apples/chests/secrets → spend in shop (weapons with stats+specials, skins with levels, abilities) → replay for 3-medal completion. Fair-addictive: mastery and collection, never dark patterns.
6. **Monetization:** free; optional one-time supporter IAP later. **Banned:** energy timers, decaying streaks, FOMO-expiring content, loss-framed notifications, pay-to-win.
7. **Performance targets:** 60 fps on 2GB-RAM Android (see spec §Performance): sprite batching / atlases, object pooling for projectiles+particles, no per-frame allocations in hot paths, `--release` profiling before each release.
8. **Tutorial promise:** an in-game tutorial was promised to Play testers — the first level must teach movement/jump/attack via signs & guided layout. Blocker for the first pivot release.
9. **Milestones (v2):** M1 scaffold (boots, CI green) → M2 engine core (player+physics+camera+touch) → M3 combat & pickups → M4 meta (shop/save/level-select) → M5 content (World 1 “Emberwood”: 5 levels + boss) → M6 release `v1.0.0-alpha.1` — **all shipped 2026-07-25** ([release](../../releases/tag/v1.0.0-alpha.1)). **Push to GitHub at every milestone — never hold work locally.**
10. **Milestones (v2.1 — current):** M7 performance/device-proof pass (measured 60fps, APK diet, cold-start budget) → M8 game-feel & retention polish (medal economy, results juice, seeded Daily Delve — still zero dark patterns) → M9 World 2 “Cinder Depths” (5 levels + boss, 2 new enemies, cave tileset) → M10 release `v1.0.0-beta.1` to the existing Play closed-testing track. Acceptance criteria live in `features.json` (P-M7…P-M10).

## Play publishing status (updated 2026-07-24)
- Closed testing (Alpha) LIVE, release 12 (v0.3.9+12), 177 countries. Production gate: 12+ opted-in testers for 14 days → earliest apply ~2026-08-07. A dip below 12 resets the clock; app updates do NOT.
- The pivot ships on the **same package + track** as a normal app update.

## Session-start ritual (for any AI/human resuming)
1. Read this file, `features.json`, tail of `progress.md`, latest `checkpoints/*.md`.
2. `git log --oneline -20` for recent history.
3. `./init.sh` to bring the environment up and run the test suite.
4. Work the next unfinished feature; update `features.json` (evidence required) and append to `progress.md`. Commit + push.
