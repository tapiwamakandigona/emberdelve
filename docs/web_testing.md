# Web test harness (browser-based control testing)

The Android app can't run in a sandbox without KVM, but the whole game runs
in a browser via Flutter web — which is how the alpha.3 touch-input bugs were
found and verified. The harness lives in `lib/main_webtest.dart` and is NOT
part of the Android app (nothing in `lib/main.dart` imports it).

## Why a separate entrypoint

The production save/settings layer (`lib/core/save.dart`,
`lib/audio/settings.dart`) uses `dart:io` + `path_provider`, which throw at
runtime on web — `main()` crashes before `runApp`. The harness boots with an
in-memory save, no audio, and jumps straight into a level.

## Build & run

```sh
flutter build web --release -t lib/main_webtest.dart
cd build/web && python3 -m http.server 8123
# open http://localhost:8123/?level=w1_l1&seed=42
```

Query params: `level` (default `w1_l1`), `seed` (default 42, deterministic).

## Telemetry for automated tests

Every 50 ms the harness publishes real simulation state to JS:

```js
window.__emberdelve = {
  loaded,           // bool: level session ready
  x, y,             // player body centre (world px)
  hearts, coins,    // run state
  touchLeft, touchRight, // HUD hold-button state (movement input)
  paused,
  rawPointerDowns,  // pointer events that reached the Flutter tree at all
}
```

Assert on telemetry, not pixels. Example (Playwright): hold a touch on the
right arrow (canvas coords: game view 480x270 scales to the canvas; right
arrow centre is view (92, 236)), then check `touchRight === true` and `x`
increasing.

## Gotchas learned the hard way (alpha.3)

- **Gesture recognizers must exist before the GameWidget's first build.**
  Flame's TapCallbacks/DragCallbacks register their dispatchers when the
  first such component mounts — too late in release builds; the recognizers
  never attach and the whole touch HUD is deaf while keyboard input works.
  `EmberGame` now registers dispatchers + recognizers in its constructor and
  forwards game-level tap/drag events into them. Regression tests:
  `test/hud_routing_test.dart`.
- **Never "hide" a tappable component with `scale = Vector2.zero()`.**
  The singular transform collapses every canvas point to local (0,0), so the
  invisible component swallows every tap that reaches its hit-test slot.
  Gate `containsLocalPoint` on visibility instead (see `HudThrowButton`).
- Keyboard input goes through `onKeyEvent` (a different pipeline than
  pointers) — keyboard working proves nothing about touch.
- The tutorial thornling patrols near spawn in `w1_l1`: long uninterrupted
  holds walk the player into it and the death freeze makes later assertions
  fail. Reload between test sections or keep holds short.

## Ready-made verification script

`tool/webtest/verify_controls.py` is the exact Playwright/CDP driver used to verify the
alpha.3 input fixes. With the harness built and served on port 8123:

```bash
pip install playwright && playwright install chromium
WEBTEST_OUT=/tmp python tool/webtest/verify_controls.py
```

It tests touch hold right/left, thumb-drift-while-holding, keyboard arrows, and the jump
button from fresh page loads, printing PASS/FAIL per scenario and an overall verdict.
