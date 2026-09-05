# Campfire reduced motion — scoped source fix

## Scope

The title's decorative campfire now follows the existing shared `Motion`
setting. Reduced motion keeps the hearth visible at a fixed phase and stops
its ticker; toggling the setting resumes/stops animation without rebuilding
the route. Painter invalidation also includes the animation and cosmetic
colours. No simulation, economy, dependency, release version or store change.

## VERIFIED evidence

- Base: shipping `legacy/dice-builder`,
  `82a3defadb2a158b33cc905b0ddb956f298657e2`. Intervening changes since the
  reviewed `6716509` base did not alter `fx.dart` or `motion.dart`.
  [managed Git diff, 2026-09-05]
- Flutter **3.44.9**, Dart **3.12.2**; official archive digest and toolchain
  version were verified. [download digest and version command, 2026-09-05]
- Both additive tests failed against unmodified production code:
  `Expected: <0>` / `Actual: <20>` for reduced-motion paints, and
  `Expected: true` / `Actual: <false>` for colour invalidation.
  [baseline flutter test output, 2026-09-05]
- The same assertions pass after the production fix: **2/2** focused tests.
  Subsequent test edits were formatter-only; no condition or assertion changed.
  [focused test output and formatter diff, 2026-09-05]
- `flutter analyze --no-pub`: **No issues found!**
  [analyzer output, 2026-09-05]
- `flutter test --no-pub --reporter expanded`: **1,308 passed**, exit **0**,
  including the formatted regression file. [full suite output, 2026-09-05]
- Existing `tool/sfx_headroom.py`: exit **0**, every reachable cascade clears
  the ceiling. Existing full-attack-turn warning remains **TIGHT, -0.90 dBTP**;
  this patch does not change audio. [headroom output, 2026-09-05]

## Build and acceptance limitations

The attempted web build failed verbatim:

```text
This project is not configured for the web.
To configure this project for the web, run flutter create . --platforms web
```

No web target was added to make the check pass. This environment has no Java
or Android SDK, so an Android package was not built. No paid runner, signing
material, workflow gate or deployment was changed.

**Not complete:** build/device/holistic visual acceptance. Repaint counts are
widget-test evidence, not measured phone frame times or battery savings.
Root `features.json` remains unchanged, including the false device-run and
real billing/restore criteria. No Play release, merge to the shipping branch
or version bump is part of this checkpoint.
