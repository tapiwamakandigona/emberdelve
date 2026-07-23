# PROJECT.md — Emberdelve

**Goal:** A turn-based **dice-builder roguelite** for Android (Google Play), built with Defold. Mobile-first: portrait, one-thumb, 3–7 minute play units inside 15–30 minute runs. Free download + one-time full-unlock IAP ($3.99–4.99), no forced ads. Quality bar: "fair-addictive" — addictive through quality, never through dark patterns.

**Owner:** memorymadie (Tsoro Studios, Play developer ID 6318480192689304537, GitHub `tapiwamakandigona`). Built and orchestrated by Viktor (AI). This repo is designed so **any AI agent can resume the project from these files alone** — read this file, `features.json`, the tail of `progress.md`, then run `init.sh`.

## Canonical artifacts
| What | Where |
|---|---|
| Product spec (approved) | `docs/spec.md` |
| Architecture (interfaces frozen) | `docs/architecture.md` |
| Definition of done | `features.json` (machine-readable; workers only flip `passes` + `evidence`) |
| History / decisions | `progress.md` (append-only), `checkpoints/` |
| Dev environment | `init.sh` |

## Standing decisions (do not relitigate without owner)
1. **Engine:** Defold **1.13.0**, pinned by sha1 in `.github/workflows/ci.yml`. bob.jar requires OpenJDK 25.
2. **Repo:** private (paid art/audio licenses forbid public raw-file redistribution). Releases may be public. CI runs on private-repo free minutes (2,000/mo); if exhausted, split a public build repo containing **no licensed assets**.
3. **Architecture:** sealed pure-Lua simulation core (`sim/`) — commands in, events out, zero engine APIs inside. Presentation (Defold) renders events only. Never violate this seam.
4. **Determinism:** all randomness via per-domain seeded streams (`sim/rng.lua`). Same seed + same commands ⇒ identical event/state hashes on every Lua VM. CI enforces it.
5. **Mechanic:** dice-builder combat (roll dice pool → assign dice to actions; grow/upgrade dice across the run). Enemy intent always visible; randomness in *offerings*, never in *resolution*.
6. **Monetization:** free + one-time unlock IAP. **Banned:** energy timers, decaying streaks, rigged near-misses, FOMO-expiring content, loss-framed notifications (see `docs/spec.md` §Ethics).
7. **Art direction (M2+):** dark high-contrast cartoony pixel-painterly, 48–64px sprites, portrait. No AI-generated animated sprites. Paid packs need owner budget approval BEFORE purchase.
8. **Audio (M2+):** real recorded SFX only (Sonniss GDC bundles / Leohpaz / Kenney CC0). No AI audio. Licensed (non-CC0) assets must never enter a public repo.
9. **Milestones:** M0 skeleton → M1 prototype (full seeded run) → M2 vertical slice → M3 content → M4 release. One milestone per work session; gate via `features.json` + checkpoint.

## Session-start ritual (for any AI/human resuming)
1. Read this file, `features.json`, tail of `progress.md`, latest `checkpoints/*.md`.
2. `git log --oneline -20` for recent history.
3. `./init.sh` to bring the environment up and run the test suite.
4. Work the next unfinished feature; update `features.json` (evidence required) and append to `progress.md`.

## Research provenance
Decisions above come from a 5-track research run (market, core-build, art, audio, psychology), 2026-07-23, synthesized in the owner's records. Key conclusions are embedded in `docs/spec.md` and `docs/architecture.md`; trust these files over memory.
