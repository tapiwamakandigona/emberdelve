# Emberwood

A crisp **pixel action-platformer** for Android. Fight through the cursed forest of Emberwood — slash beasts, loot chests, hunt secret rooms, and gear up in the shop. Apple-Knight-style loop, tighter feel, no ad spam.

**Tsoro Studios** · Flutter 3.32 + Flame · public repo

> **v2 pivot (2026-07-24):** this game began as a v2 rewrite of Emberdelve, reborn as an action platformer.
> **Renamed (2026-08-11, owner-directed):** the platformer is now **Emberwood** (`com.tsorostudios.emberwood`) —
> a separate app, so it can never collide with Emberdelve Classic on Google Play. The original
> dice-builder roguelite is preserved on branch [`legacy/dice-builder`](../../tree/legacy/dice-builder),
> tag `v0.3.10-legacy`, and the ["Emberdelve Classic" release](../../releases/tag/v0.3.10-legacy).

## Start here (human or AI)
1. `PROJECT.md` — goal, standing decisions, session-start ritual
2. `features.json` — machine-readable definition of done
3. `progress.md` — history; `checkpoints/` — phase gates
4. `flutter pub get && flutter test` — environment up + test suite

## Layout
- `lib/game/` — Flame gameplay: player, enemies, levels, physics, HUD (`docs/architecture.md`)
- `lib/meta/` — economy, shop catalog, progression (pure Dart, headless-tested)
- `lib/ui/` — Flutter meta screens (title, level select, shop, settings)
- `lib/core/` — seeded RNG, atomic save system
- `lib/audio/` — music/SFX service
- `assets/levels/` — ASCII level grids (unit-tested)
- `docs/` — spec + architecture (`docs/spec.md` §7 Ethics is binding); `docs/legacy/` — dice-era docs

## Build
```
flutter pub get
flutter test        # full headless gate (levels, physics, economy, UI smoke)
flutter build apk --release
```
CI builds signed APK/AAB on `main` (see `.github/workflows/ci.yml` — signing config is immutable).

## Licensing
Code: see `LICENSE`. Art/audio: CC0/CC-BY only, cataloged in `PROVENANCE.md`, attribution shipped in-app (`CREDITS.md`).
