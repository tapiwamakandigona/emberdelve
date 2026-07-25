# Checkpoint 08 — v1.0.0-alpha.3: touch input root-caused + browser test harness (2026-07-25)

## Where things stand
- **Release:** v1.0.0-alpha.3 prerelease live (tag on 99d0131, CI run 30144670090,
  cert Signature OK). Version 1.0.0-alpha.3+15. 174/174 tests, analyze clean.
- **The device movement bug is (finally) root-caused and fixed** — two bugs, both in
  input plumbing, both invisible to callback-level unit tests:
  1. Flame gesture dispatchers were never registered in release builds (registration
     depends on a post-first-build GameWidget refresh that never lands). Fixed: EmberGame
     pre-registers MultiTapDispatcher/MultiDragDispatcher at construction.
  2. Hidden HudThrowButton (scale=0) collapsed all points to local (0,0) and swallowed
     every tap before the arrows in hit-test order. Fixed: skip hit-test while hidden.
  Regression coverage: test/hud_routing_test.dart (end-to-end through the gesture API;
  headless boot pattern — pumpWidget cannot mount Flame children in flutter_test).

## Web test harness (committed, for any AI/dev)
- `lib/main_webtest.dart` + `web/` + `docs/web_testing.md`.
- Build: `flutter build web --release -t lib/main_webtest.dart`; serve build/web.
- `?level=w1_l1&seed=42` boots straight into a level; telemetry at `window.__emberdelve`
  (loaded, x, y, hearts, coins, touchLeft/Right, paused, rawPointerDowns) every 50ms.
- Drive with headless Chromium: CDP Input.dispatchTouchEvent for touch, page.keyboard
  for keys. 1280×720 viewport → game coords ×2.667. Gotchas in docs/web_testing.md
  (grey headless screenshots = WebGL artifact; reload between sections — spawn thornling
  kills the player during long holds).
- Verified there: touch hold L/R, thumb-drift hold, keyboard, jump — all PASS on the
  compiled release build.

## Open next
- Owner to confirm fix on the real device (alpha.3 APK).
- P-M9 World 2 (Cinder Depths); P-M10 beta.1 → Play track update.
- Device hardware metrics (frame budget, cold start) — needs a physical device.
- Consider deleting/unlisting the broken alpha.1 prerelease.
- Parallel feel agent merged #33/#34/#40/#41 (asym gravity, turn assist, layout, roll verb)
  — release notes for beta.1 should mention these.
