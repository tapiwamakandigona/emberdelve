# Gauntlet iteration 19 — v1.0.0-alpha.16: overflow sweep gate

alpha.15 SHIPPED (CI 33418320882 ✓, APK verified 1.0.0-alpha.15/27 pin MATCH ✓, prerelease 379929799 + assets ✓, skill bumped+compressed ✓).

Improvement: DEMAND quality gate "Overflow sweep for Flutter UI screens at
small phone + 1.3× text" has NO automation and no recent manual sweep. Build
test/overflow_sweep_test.dart pumping every UI screen at small-phone sizes
(portrait 320×640 + landscape 640×320 where relevant) with TextScaler 1.3;
overflow errors fail widget tests natively. Fix whatever it flags.

- [ ] Read ui_smoke_test/meta_screens_test pump patterns (app_state deps)
- [ ] Write sweep test: title, level select, shop, settings, credits, game results/pause
- [ ] Run → log flagged overflows (VERIFIED red before fix)
- [ ] Fix overflows (minimal layout edits)
- [ ] Gates: analyze clean + full suite green
- [ ] Look-pass phone+desktop at changed screens
- [ ] progress.md + checkpoint 19 + pubspec 1.0.0-alpha.16+28
- [ ] Commit -F, tag, push, CI, verify artifacts (pin!), prerelease, skill bump
