# DEMAND — Emberwood (`main`, the v2 action-platformer)

What "good" means for every Gauntlet session on this branch. Edited only when
standards genuinely change. Never contains diagnosis of the current build —
that lives in progress.md.

## Product pillars

1. **Tighter, fairer Apple Knight.** Run / double-jump / dash, 3-hit melee,
   apple throw, coins/feathers/chests/secrets, 3-medal mastery loop, meta
   shop. Better game-feel than AK (coyote time, buffers, hit-pause), none of
   its dark patterns. Banned forever: energy timers, decaying streaks,
   FOMO-expiring content, loss-framed notifications, pay-to-win,
   interstitial ads.
2. **Headless-testable engine.** `lib/game/` logic (level parsing, physics
   resolution, economy, saves) has zero rendering dependencies and is covered
   by `flutter test`. Determinism where it matters via seeded RNG. Tuning
   constants live in `lib/game/tuning.dart`, never inlined.
3. **Performance before spectacle.** 60 fps in `--release` on a 2 GB Android;
   zero allocations in `update()` hot paths; pooled projectiles/particles;
   APK ≤ 60 MB. Perf claims are measured (bench harness / traces), not felt.
4. **Honest presentation.** A stranger looking at any screen for 3 seconds
   should never call it fake, empty, or confusing. Store copy, HUD counters,
   and results screens state facts.
5. **Original assets only.** CC0/CC-BY with in-app attribution
   (PROVENANCE.md + CREDITS.md); nothing that forbids redistribution; no
   traced/ripped art.

## Release standards

- Ship improvements as GitHub prereleases cut from `main`: version bump per
  release (`1.0.0-alpha.N+code`, patch cadence one improvement at a time),
  tag at the release sha, signed APK+AAB from CI (workflow_dispatch), sha256s
  in the notes, player-facing notes + short technical section.
- Package id `com.tsorostudios.emberwood`. NOT on any Play track yet; going
  to Play is an owner call (P-M10). Never submit to Play without an explicit
  owner instruction.
- Signer: the shared immutable upload keystore; CI pin `EXPECTED_CERT_SHA256`
  (031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d) never
  changes. Never regenerate keys.
- If GitHub auth is down, keep the train moving locally: gates green, version
  bumped, notes written, progress.md entry appended, commit made — tag/CI/
  release published as soon as auth returns.

## Quality gates (all VERIFIED, evidence in progress.md)

- `flutter analyze` clean; full test suite green; no skipped tests.
- New behavior has tests; a bug fix has a regression test that fails on the
  old code.
- Gameplay/UI changes: web-harness look pass (build `lib/main_webtest.dart`,
  landscape-phone ~915×412 AND desktop viewports, spawn + mid-level shots,
  close and wide) — actually LOOK at the shots and log what a stranger would
  flag. Overflow sweep for Flutter UI screens at small phone + 1.3× text.
- Physics/feel changes: telemetry-driven browser verification (assert on
  `window.__emberdelve`, not pixels); reachability/jump-height contracts in
  tests stay green.
- progress.md is append-only and written as you go; open issues carry
  forward verbatim until actually fixed.
