# Emberdelve

A dark, turn-based **dice-builder roguelite** for Android. Roll, assign, and forge dice as you delve toward the ember at the bottom of the world.

[<img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="60">](https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve)

**Free on [Google Play](https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve) (public early access)** · no ads, no energy timers, no tracking unless you opt in · [download page](https://tapiwa.me/emberdelve/)

**Tsoro Studios** · Flutter 3.32 / Dart (sealed pure-Dart sim) · public repo

## Start here (human or AI)
1. `PROJECT.md` — goal, standing decisions, session-start ritual
2. `features.json` — machine-readable definition of done
3. `progress.md` — history; `checkpoints/` — phase gates
4. `flutter pub get && flutter test` — environment up + test suite

## Layout
- `lib/sim/` — sealed pure-Dart simulation core (commands in, events out; deterministic, seeded; no Flutter/dart:io imports)
- `lib/ui/` — Flutter presentation layer (custom-painted, no stock Material look)
- `lib/data/` — content as data modules (dice, foes, relics, boons, events)
- `lib/game/` — controller gluing sim to UI (autosave, choreography)
- `bin/autoplay.dart` — headless balance harness (`dart run bin/autoplay.dart 200`)
- `test/` — sim + widget suite
- `docs/` — spec + architecture + sim contract (`docs/spec.md` §Ethics is binding)
- `.github/workflows/ci.yml` — analyze/test gate → signed Android APK+AAB on main

## Release signing
Release builds are signed in CI from repository secrets (see `docs/release.md`).
Without a local `android/key.properties` the build falls back to debug signing,
so contributors can build and run without any secrets.
