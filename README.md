# Emberdelve

A dark, turn-based **dice-builder roguelite** for Android. Roll, assign,
and forge dice as you delve toward the ember at the bottom of the world.

**No ads. No energy timers. No tracking unless you opt in.** Runs are
seeded and fully deterministic — share a seed, share the exact delve.

<p align="center">
  <img src="docs/release-sep19/evidence/kindler-360-natural-ready.png" width="30%" alt="Kindler at the start of combat in the current Flutter game">
  <img src="docs/release-sep19/evidence/warden-360-natural-ready.png" width="30%" alt="Warden at the start of combat in the current Flutter game">
  <img src="docs/release-sep19/evidence/hedger-360-natural-ready.png" width="30%" alt="Hedger at the start of combat in the current Flutter game">
</p>

Actual headless Flutter encounter-entry captures at 360×640 logical pixels,
not painted mockups or physical-device performance evidence.
[Capture method and limits](docs/release-sep19/evidence/README.md).

## Download

**[⬇ Latest release](https://github.com/tapiwamakandigona/emberdelve/releases/latest)** —
grab `app-arm64-v8a-release.apk` for a 64-bit Android phone.
Every release ships SHA-256 checksums and is signed in CI with the
permanent Tsoro Studios key; notes explain exactly what changed and why.
Current builds require Android 7.0 or later.

| Your device | File |
| --- | --- |
| 64-bit ARM Android phones | `app-arm64-v8a-release.apk` |
| 32-bit ARM Android phones | `app-armeabi-v7a-release.apk` |
| x86-64 Android emulators / compatible Chromebooks | `app-x86_64-release.apk` |
| Not sure | `app-release.apk` (larger, all three supported ABIs) |

Also on [Google Play](https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve) (out now, 177 countries) ·
[download page](https://tapiwa.me/emberdelve/)

## The game

- **Roll → assign → forge.** Every turn you roll your pool and split it
  between attack and block. Between fights you forge dice into stronger,
  stranger shapes and temper runes onto faces.
- **Fair by construction.** The enemy's intent is always visible; the sim
  is a sealed, deterministic core with no hidden modifiers. When you die,
  it was the build — and the seed lets you prove it.
- **Twenty-two playable delvers**, each with a distinct kit and working
  silhouette; enemies, bosses, events, relics, daily trials and ascension
  ladders. All 22 have articulated combat bodies and hand-held tools.
- **Respects you**: play offline, no account, TalkBack-friendly
  (v0.19.0), reduce-motion mode, colorblind-safe UI, saves stay on your
  device. The one paid unlock (Hard + Ascension) is a single purchase —
  never consumables, never a second currency.
- **Your comfort, your choice:** a saved Blood effects switch hides blood,
  ichor and wound marks while preserving damage, guard and fatigue cues.

## For developers (human or AI)

1. `PROJECT.md` — goal, standing decisions, session-start ritual
2. `features.json` — machine-readable definition of done
3. `progress.md` — history; `checkpoints/` — phase gates
4. `flutter pub get && flutter test` — environment up + test suite

### Layout
- `lib/sim/` — sealed pure-Dart simulation core (commands in, events out; deterministic, seeded; no Flutter/dart:io imports)
- `lib/ui/` — Flutter presentation layer (custom-painted, no stock Material look)
- `lib/data/` — content as data modules (dice, foes, relics, boons, events)
- `lib/game/` — controller gluing sim to UI (autosave, choreography)
- `bin/autoplay.dart` — headless balance harness (`dart run bin/autoplay.dart 200`)
- `test/` — sim + widget suite, incl. overflow, semantics, and balance gates
- `docs/` — spec + architecture + sim contract (`docs/spec.md` §Ethics is binding)
- `.github/workflows/ci.yml` — analyze/test gate → signed Android APK+AAB

### Release signing
Release builds are signed in CI from repository secrets (see `docs/release.md`).
Without a local `android/key.properties` the build falls back to debug signing,
so contributors can build and run without any secrets.
