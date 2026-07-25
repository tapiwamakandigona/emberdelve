# Checkpoint 06 — v1.0.0-alpha.1 shipped + v2.1 roadmap (2026-07-25)

## Gate result: M6 PASSED
- CI (run 30128435151, main@951ad53): analyze clean, 143/143 tests, signed APK+AAB built,
  upload-key cert verified unchanged.
- GitHub prerelease v1.0.0-alpha.1 published with APK + AAB and honest release notes.
- The pivot (M0–M6) is now fully on GitHub: nothing exists only locally.

## State of the game
World 1 (5 levels + Grove Golem), 5 enemy types, 3-hit combo + apple throw, full meta shop
(weapons/skins/abilities), medals, tutorial signs, atomic saves, in-app credits. All
headless-tested; scripted runner bot proves completability of every regular level.

## Known gaps (feed M7–M10)
1. Performance targets are engineered-for but never measured on hardware → **M7**.
2. Results screen is functional but flat; nothing pulls players back daily (fairly) → **M8**.
3. One world only; boss/new-enemy art is tinted composites → **M9** (+ bespoke art later).
4. Play testers are still on the dice-builder build; pivot must reach the track → **M10**.

## Resume ritual
Read PROJECT.md → features.json (P-M7 next) → tail of progress.md → ./init.sh.
