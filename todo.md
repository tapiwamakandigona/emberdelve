# Gauntlet iteration 18 — v1.0.0-alpha.15: boss design-intent review

alpha.14 SHIPPED (CI ✓, APK verified 1.0.0-alpha.14/26 pin MATCH ✓, prerelease 379915652 ✓, assets ✓, skill bumped ✓).

Sweep state: all 10 regular levels COMPLETED by casual probe; w1_boss WIPED pct46, w2_boss WIPED pct42.
Rule: design-intent review FIRST — bosses are telegraph fights, maybe meant to beat a masher. No automatic nerf.

- [x] Boss code + levels read (BossCore state machine, pens, moats)
- [x] Fresh masher probes: both wipe trading at melee range — 2 hits/life
- [x] Verdict: (a) intended skill gate (fairness_test pins it) + one real defect: w2 sign coaches unreachable ground play
- [x] Fix: w2_boss sign rewrite (crown-strike coaching) + permanent gate test/boss_intent_test.dart (coached bot must win, 8/8 green)
- [x] Gates: analyze clean + 411 passed + 1 skipped
- [x] Look-pass phone+desktop at sign site PASS (a15 shots)
- [x] progress.md + checkpoint 18 + pubspec 1.0.0-alpha.15+27
- [ ] Commit -F, tag, push, CI, verify artifacts (pin!), prerelease, skill bump + compress (<4000)
