# Emberdelve

A dark, turn-based **dice-builder roguelite** for Android. Roll, assign, and forge dice as you delve toward the ember at the bottom of the world.

**Tsoro Studios** · Defold 1.13.0 · private repo (asset licensing — see `docs/architecture.md` §8)

## Start here (human or AI)
1. `PROJECT.md` — goal, standing decisions, session-start ritual
2. `features.json` — machine-readable definition of done
3. `progress.md` — history; `checkpoints/` — phase gates
4. `./init.sh` — environment up + test suite

## Layout
- `sim/` — sealed pure-Lua simulation core (commands in, events out; deterministic, seeded)
- `main/` — Defold presentation layer
- `data/` — (M1) content as data modules
- `tests/` — headless suite, runs on plain Lua 5.4 (`lua5.4 tests/run_tests.lua`)
- `docs/` — spec + architecture (interfaces frozen)
- `.github/workflows/ci.yml` — test gate → Android bundle via pinned bob.jar
