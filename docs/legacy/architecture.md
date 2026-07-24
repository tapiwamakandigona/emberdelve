# Emberdelve — Architecture (v1, frozen 2026-07-23)

Stack: **Defold 1.13.0** (pinned by sha1 in CI) + pure-Lua simulation core. Rationale: smallest APKs in class (~2–5MB baseline), stable 60fps on 1–3GB devices, first-class Android + CI story, Lua everywhere.

## 1. The seam that must never leak
```
┌────────────────────────────────────────────┐
│ presentation (Defold: main/, gui/, fx)     │  renders events, sends commands
├────────────────────────────────────────────┤
│            commands ↓      events ↑        │  THE ONLY INTERFACE
├────────────────────────────────────────────┤
│ sim/ (pure Lua, sealed)                    │  zero engine APIs, zero io/os
└────────────────────────────────────────────┘
```
- `sim/` must run identically headless (Lua 5.4, CI) and in-engine (LuaJIT). No `math.random`, no `os.*` (except nothing), no Defold calls, no globals.
- Presentation may *read* `sim:state()` for rendering but must never mutate sim internals. All mutation via `sim:apply(cmd)`.
- Benefits this buys (don't trade away): ms-fast headless full-run tests, deterministic replays/daily seeds, free autosave (snapshot = plain table), free undo, AI-agent-friendly iteration.

## 2. Frozen interface contract (change = architecture revision + SIM_VERSION bump)
```lua
local Sim = require "sim.init"
local sim  = Sim.new(run_seed)        -- number
local evs  = sim:apply(cmd)           -- {type=..., ...} -> array of events
local view = sim:state()              -- read-only view
local snap = sim:snapshot()           -- plain serializable table
local sim2 = Sim.restore(snap)        -- continues bit-identically
local h    = sim:state_hash()         -- deterministic number
sim.event_hash                        -- running hash over all emitted events
```
- **Commands**: flat tables, string `type`, scalar fields. v1 set: `start_encounter`, `roll`, `assign{die,action}`, `end_turn`. M1 adds map/shop/forge commands.
- **Events**: flat tables, string `type`, scalar fields only (hashable, serializable, replayable). Invalid input ⇒ `invalid_command` event, state untouched.
- **Autosave protocol**: presentation serializes `sim:snapshot()` (via defold-saver, M1) after every applied command.

## 3. RNG discipline
`sim/rng.lua`: per-domain streams (`map`, `combat`, `loot`, `shuffle`) derived from the run seed. Park–Miller minstd with arithmetic <2^53 ⇒ bit-identical on LuaJIT doubles and Lua 5.4 integers (proven by CI golden-hash test). Never share streams across domains; add new domains rather than reusing. A native PCG extension may replace the implementation behind the same interface in M3+ if statistical quality demands it.

## 4. Module map & ownership
| Path | Role | Owner discipline |
|---|---|---|
| `sim/init.lua` | dispatch, hashing, persistence | interface frozen |
| `sim/rng.lua` | RNG streams | interface frozen |
| `sim/combat.lua` | combat rules | grows in M1 |
| `sim/map.lua` (M1) | StS-style layered node map | pure function of map stream |
| `data/` (M1) | content as plain Lua data modules + effect primitives | schema-validated in CI; no logic |
| `main/` | boot + screens (monarch, M1) | presentation only |
| `gui/` (M1) | druid-based UI | presentation only |
| `tests/` | headless suite | workers may not weaken assertions |
| `.github/workflows/ci.yml` | test gate → bob.jar bundle | pinned Defold sha1; JDK 25 |

## 5. Planned dependencies (verified active 2026-07)
monarch (screens), druid (GUI), defold-saver (saves + schema migrations), defold-input (touch/gesture), deftest (in-engine tests, M1). Added via `game.project` dependencies + `bob.jar resolve` in CI — never vendored.

## 6. Testing strategy
1. **Pure-Lua suite** (`tests/run_tests.lua`, CI gate): determinism, stream independence, snapshot round-trip, rules invariants, golden-hash anchor.
2. **Seeded autoplayer** (M1): policy bot plays full runs headless; asserts run completability, event-log hash stability, and balance stats (turn counts, damage distributions).
3. **In-engine smoke** (M2, deftest headless): boot, one fight, resume-from-snapshot.
4. **Device QA** (M2+): manual on low-end Android; frame timing via Defold profiler.

## 7. CI/CD
GitHub Actions (`ci.yml`): `test` job (Lua 5.4 headless suite) gates `build-android` (temurin JDK 25 → pinned bob.jar → resolve → build → bundle debug APK → artifact). M2 adds release-AAB job with keystore from repo secrets (never committed). M4 adds Play upload (fastlane supply or gradle-play-publisher equivalent) — still manual-approval gated.

## 8. Asset licensing constraint (affects repo topology)
Paid packs (Penusbmic art, Leohpaz audio, etc.) forbid raw-file redistribution ⇒ they live only in this **private** repo (or a private submodule later). Anything public (build repo, releases page) may contain compiled bundles but never raw licensed assets. CC0 assets (Kenney, Foozle, Abstraction music) are unrestricted.
