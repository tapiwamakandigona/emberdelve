# DEMAND — Emberwood (`main`, the v2 action-platformer)

What "good" means for every Gauntlet session on this branch. Edited only when
standards genuinely change. Never contains diagnosis of the current build —
that lives in progress.md.

## Owner directive 2026-08-31 — RELEASE FREEZE (read this first)

**Stop cutting public releases.** No new git tags, no GitHub releases, no Play
Store submissions, no store-listing edits. This supersedes the earlier
"one improvement per release, version bump per release" rule, which is what
produced the churn described below.

The freeze is on **publishing**, not on work. Keep building, keep merging, keep
the suite green. Accumulate changes.

Why: this repo cut 177 releases, several within minutes of each other, and
release notes were being published before binaries were attached. The "Direct
APK" button on tapiwa.me/emberdelve points at `/releases/latest`, so during
those gaps visitors landed on a release with nothing to download. Verified
2026-08-31: `v0.176.0` (19:31:39Z) and `v0.177.0` (19:44:55Z) were both
published with **zero assets**, and v0.176.0 was superseded 13 minutes later.

The next public release will be a **single consolidated release**, cut by the
owner together with his operations agent, published to GitHub and Google Play
together. When that happens the existing standards still apply: tag at the
release sha, signed APK+AAB from CI (`workflow_dispatch` on the ship branch),
sha256s in the notes, plain player-facing notes plus a short technical section,
and the signer cert must match the pin already recorded in this file.

If you believe something genuinely must ship immediately — a crash, data loss,
or a security issue — **do not cut the release yourself.** Write it at the top
of `progress.md`, state the severity and the evidence, and stop.

## Where to spend effort during the freeze (owner-set, 2026-08-31)

Ranked. Do these instead of releasing.

1. **Per-device download size.** Product pillar 3 requires < 30 MB. The current
   split APKs measure 33-37 MB, so the branch is out of compliance with its own
   standard. Measure per-ABI, find what is actually large, and reduce it.
2. **Google Play quality requirements, enforced February 2027.** Google now
   requires DEX optimization of at least 25% coverage across optimization,
   shrinking and obfuscation via R8, plus thresholds on memory (anonymous RSS
   + swap) and bitmap memory, plus a secure device-migration standard.
   - Emberdelve already sets `isMinifyEnabled` and `isShrinkResources` (commit
     `8f756dd8`).
   - **Pyregrove sets neither, so R8 is off and it fails the DEX item.** Fix it,
     but do not flip the flag blind: reflection-heavy plugins break *only* in
     minified release builds. Copy the keep rules from emberdelve's
     `android/app/proguard-rules.pro`, then build a release APK and launch it.
   - Neither app declares `allowBackup`, `dataExtractionRules` or
     `fullBackupContent`. Full detail and exact patches:
     `docs/PLAY-QUALITY-2027.md` in the pyregrove repo.
   - **Do not change what is included in backup for paid-entitlement state
     without the owner's sign-off** — it decides whether a purchase survives a
     phone upgrade, so it is a monetization decision, not a technical one.
3. **Do not regenerate `android/app/google-services.json`.** It was corrected on
   2026-08-31; before that, both client blocks carried the wrong app id and
   analytics were attributed to the wrong app. Any Android config change must
   land in **both** `pyregrove` and the public CI mirror `pyregrove-ci` — a fix
   in one alone does nothing.
4. **Do not regress the in-app review charter.** One ask ever, stamped on
   request, sticky across cloud merge, never during the tour, no incentives, no
   pre-filtering by sentiment, official API only.
5. Keep the full test suite green and `flutter analyze` clean. No skipped tests.

## Owner directive 2026-08-31b — device migration + the paid unlock (DECIDED)

Status check, verified against the repos on 2026-08-31 21:15Z:

- `pyregrove@main` now sets `isMinifyEnabled`/`isShrinkResources`, has real keep
  rules in `android/app/proguard-rules.pro`, and declares all three of
  `allowBackup`, `dataExtractionRules`, `fullBackupContent`. Good — that closes
  its Feb-2027 items.
- **`emberdelve@legacy/dice-builder` declares none of the three.** R8 is already
  on here, so migration is the only outstanding Feb-2027 item — and this is the
  branch that ships the paid product. Close it.

### The entitlement question is now decided: KEEP THE UNLOCK PORTABLE

The first directive said not to change paid-entitlement backup behaviour without
owner sign-off. Here is the sign-off, with the reasoning, so it is not
re-litigated later.

`forgeUnlocked` and the redeemed unlock nonces live in `MetaState` ->
`emberdelve_meta.json` (`lib/meta/meta.dart`, `_fileName = 'emberdelve_meta.json'`).

**Include that file in both backup and device transfer. Do not exclude it.**

Why: buyers who redeemed an offline unlock code — sideload users, who cannot buy
the Forge through Play billing at all — have **no Play receipt to restore from**.
For them `emberdelve_meta.json` is the only record that they paid. Excluding it
would silently destroy a purchase when they change phones, and they would have no
way to prove it and no way to re-buy. Play-billing buyers can restore via their
Google account, so they lose nothing either way. The asymmetry is one-sided.

The piracy angle does not change this: a copyable meta file is a theoretical loss
on a 4.25 USD game, whereas a paying customer losing the thing they bought is a
real loss, a refund, and a one-star review.

So: add the three attributes, and write `backup_rules.xml` /
`data_extraction_rules.xml` so `emberdelve_meta.json` is explicitly **included**
for both cloud backup and device-to-device transfer. Note in code review that on
some devices `allowBackup="false"` does not disable D2D transfer, so rely on the
explicit rules rather than on the flag alone.

Do not cut a release for this. The freeze still holds — merge it and let it ride
until the consolidated release.

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
