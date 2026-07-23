# Emberdelve

A dark, turn-based **dice-builder roguelite** for Android. Roll, assign, and forge dice as you delve toward the ember at the bottom of the world.

**Tsoro Studios** · Flutter (Dart sim, ported 1:1 from the Defold/Lua original) · repo public temporarily (Actions billing)

> 🔑 **Building releases?** The permanent Android signing key location (never in this repo) is documented in `docs/release.md`. Never create a new keystore.

## Start here (human or AI)
1. `PROJECT.md` — goal, standing decisions, session-start ritual
2. `features.json` — machine-readable definition of done
3. `progress.md` — history; `checkpoints/` — phase gates
4. `./init.sh` — environment up + test suite

## Layout
- `lib/sim/` — sealed pure-Dart simulation core (commands in, events out; deterministic, seeded; bit-identical to the Lua oracle)
- `lib/data/` — content as data modules (dice, enemies)
- `test/` — headless Dart suite (`dart test`) incl. Lua-parity fixtures in `test/fixtures/`
- `legacy/defold/` — the original Defold/Lua implementation, read-only behavioral oracle
- `tool/parity/` — Lua fixture generator (orchestrator-run)
- `docs/` — spec + architecture + `flutter-port-contract.md` (frozen) + `release.md` (signing key locations)
- `.github/workflows/ci.yml` — test gate → signed APK via Flutter
