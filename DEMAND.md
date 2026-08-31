# DEMAND — Emberdelve Classic (`legacy/dice-builder`)


## Owner directive 2026-08-31c — size pillar RETRACTED, priorities re-ranked

### Correction first: the download-size pillar was my error. Stand down on it.

Directive 2026-08-31 ranked "per-device download <30 MB" as focus item #1 and cited
emberdelve splits at 33-37 MB. **That was wrong and I am retracting it.**

Authoritative source, Play Console -> Android vitals -> App size, read 2026-08-31:

- App download size: **20.6 MB** for the reference device, **20-20.7 MB** across all
  device configurations.
- Peer group median: **52.7 MB**. Emberdelve is **32.1 MB below** the peer median.
- ABI, screen-density and language configuration APKs: all three already
  **Implemented**.

Your bundletool `get-size` measurement (25.9-26.6 MB, commit 4009f01) was right and
reached me correctly. The 33-37 MB figures I quoted were raw sideload split APKs
with uncompressed stores — not what a Play user downloads. I fed you a bad number
and ranked it first; that is on me, and you caught it. Good.

**Consequence: stop all work aimed at the <30 MB pillar. It is met with a 9 MB
margin and beats peers by a wide gap.** The Inter subset in 7136a97 was a real win
and stays, but do not chase further byte-shaving. It is not a bottleneck, and the
"Extract large files" tip in the console shows no quantified saving.

The sideloaded direct-APK path is still ~35 MB. That is a real number but it affects
only the minority who download from GitHub, it is not a Play compliance matter, and
it does not justify a music-delivery redesign. **Do not open that work.** If it ever
becomes worth doing, it will be an owner call, not a freeze-worklist item.

### Feb-2027 migration: CLOSED on both products. Verified.

`emberdelve@legacy/dice-builder` now declares `allowBackup="true"`,
`dataExtractionRules`, `fullBackupContent`, with both rules files present and the
paid unlock explicitly included in cloud-backup and device-transfer. Read back from
the GitHub API and confirmed. Combined with R8 already being on, **emberdelve and
pyregrove are both Feb-2027 clean.** Nothing further needed unless Google moves the
goalposts. Do not re-open it.

### Re-ranked focus list — replaces the previous one

1. **Retention, not content breadth.** This is now the weakest real number in the
   business. Last 28 days: 28 monthly active devices, and **7-day retention of 1
   device**. Meanwhile the roster just reached sixteen delvers and a sixth cycle of
   hearth tales. More content for players who are not coming back on day 7 does not
   move anything. Favour work that strengthens the first session and the first week:
   the opening run's clarity, the first meaningful decision, the reason to open the
   app tomorrow. If you are choosing between a seventeenth delver and making day-2
   return compelling, choose day 2 every time.
   Caveat, stated honestly: n is tiny (28 devices, retention of 1). Treat this as a
   direction, not a precise target, and do not build anything that depends on the
   exact figures.
2. **Stability is already excellent — protect it.** Play vitals shows zero
   user-perceived crashes and zero ANRs over the full 28 days. That is a genuine
   asset. Any change that risks it is a bad trade.
3. **Keep the suite green and `flutter analyze` clean.** Suite is at 1093/1093.
4. **Do not regress the in-app review charter.** Your audit found it clean; keep it
   that way. It is the single highest-value unshipped change in the repo.
5. Mirror Android config to `pyregrove-ci`; still do not regenerate
   `android/app/google-services.json`.

### The freeze still stands, unchanged.

No tags, no GitHub releases, no Play submissions, no store-listing edits. The freeze
is on publishing, not on work. The next release is ONE consolidated GitHub + Play
release cut by the owner and the ops agent, carrying the review-ask fix, the
migration attributes, and the captioned screenshots. Urgent items go at the top of
`progress.md` with a stop, not a self-cut release.


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

1. **Fair dice roguelite.** No ads, no timers, no gacha, no loss-framed nags.
   Free tier is a complete game (Easy + Normal + Hard); Ember Forge ($4.99,
   one-time) buys the Ascension ladder and future depth — never expressive
   core mechanics.
2. **The sim is sacred.** `lib/sim/` stays pure Dart — no Flutter, no
   `dart:io`, no unseeded randomness. `resolveAssignment` is the single
   arithmetic source of truth. Golden hashes only move with a documented
   re-anchor table in the commit.
3. **Performance before spectacle.** Per-device download < 30 MB, < 180 MB
   peak memory on a 3 GB device, no perf-proxy regression > 5% without a
   logged justification.
4. **Honest presentation.** Recaps, share text, and store copy state facts.
   A stranger looking at any screen for 3 seconds should never call it fake,
   empty, or confusing.

## Release standards (current mode: FROZEN - see owner directive above)

- Owner directive 2026-08-16: **do NOT submit to Play Store** until told
  otherwise. Ship every improvement as a **GitHub release** instead: tag at
  the release sha, signed APK+AAB from CI (workflow_dispatch on this branch),
  sha256s in the notes, and release notes that explain the improvement in
  plain player-facing language plus a short technical section.
- (SUSPENDED by the 2026-08-31 release freeze above) One improvement per
  release where practical; version bump per release
  (patch for fixes/polish, minor for features). Signer cert must match pin
  `031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`.

## Quality gates (all VERIFIED, evidence in progress.md)

- `flutter analyze` clean; full test suite green; no skipped tests.
- New behavior has tests; a bug fix has a regression test that fails on the
  old code.
- UI changes: overflow sweep 320×568 → 412×915 at 1.3× text; screenshot
  critique actually performed (look at the plates, write down what's wrong).
- Sim changes: seeded sweep win rates stay in band (easy 80–90%, normal
  55–70%, hard 30–45%), fuzz harness clean, golden re-anchor table recorded.

## Definition of failure

- Shipping a claim without an evidence artifact.
- A release whose notes don't match what the code does.
- Weakening a check to make it pass.
- Waiting idle for anything — build waits are research/content/test time.
