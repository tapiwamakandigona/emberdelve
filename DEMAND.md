# DEMAND — Emberwood (`main`, the v2 action-platformer)


## Owner directive 2026-09-01f — the players have voted, and they voted for content

**This is not my opinion. This is primary-source player evidence**, and it is the
first we have ever had. Three separate people have now said something about
Emberdelve unprompted. Not one of them mentioned a bug, the difficulty curve, the
price, or the UI.

1. **Five-star review, 31 Aug 2026, 16:48 GMT**, reported by Play Console email:
   > Add more delvers, I need more... give mee moreee. Good game tho

   **Correction, same day:** an earlier version of this directive called that a
   *public* review. It is not on the public listing. The console's Reviews page
   reads "Your app doesn't have any reviews", ratings-with-reviews **0**, users
   **2**, over all time. The email is real; the placement claim was mine and it
   was wrong. It is either tester-track feedback or a review the author removed.
   The evidence for what to build is unchanged — the sentence was still typed by
   a player — but do not repeat the "first public review" framing anywhere.
2. **Beta feedback, 31 Aug** (private channel, paraphrased): if we keep updating
   the game, they will keep playing it.
3. **Beta feedback, 31 Aug** (private channel, paraphrased): fun, both
   challenging and rewarding, a good way to pass time.

**What this changes.** The owner has asked for one more major update before a
GitHub release is cut. This is what that update should be about. Two of three
players asked for **content volume and continued updates**; zero asked for new
systems. So:

- **Prioritise more delvers** — playable characters/classes and the content that
  makes them feel distinct — over any new mechanic, meta-layer, or refactor.
- A player who says *"I need more"* is telling you the content runs out before
  their interest does. That is the single best problem an indie game can have and
  it has a deadline: it expires when they uninstall.
- Pair it with a reason to come back across days rather than in one sitting. The
  retention hook already specced (seven distinct local played days lighting
  hearths, seventh settling 60 spendable embers) is the right shape: it rewards
  returning, it needs no server, and it cannot be gamed by clock-skew because it
  counts distinct local days, not elapsed time.

**Constraints that still hold, and they are not negotiable:**

- **Do not trade the promise for the metric.** No ads, no analytics, no
  telemetry, no phone-home, no dark patterns, no timers that punish absence. The
  listing promises "zero ads, played offline" and that promise is the product.
  A retention feature that spies on people is a broken retention feature.
- Content must ship **complete**. A half-finished delver is worse than no new
  delver: the five-star reviewer asked for more, not for more placeholders.
- Freeze otherwise unchanged: build on branch, no tag, no release, no Play
  submission until the owner says so.

**Wider lesson worth internalising:** we spent weeks reasoning about what players
would want from an empty review page. The moment a real player typed one
sentence, it outranked all of it. When you are choosing what to build next and
there is a primary source, the primary source wins — and if there is no primary
source, the highest-value work is often the work that produces one.

## Owner directive 2026-09-01e — do not narrow the hosted privacy policy

**Constraint, not a preference.** `docs/store/privacy-policy.html` in the public
`emberdelve` repo is served by GitHub Pages at

    https://tapiwamakandigona.github.io/emberdelve/store/privacy-policy.html

and that exact URL is the **Privacy Policy field on the live Google Play listing
for `com.tsorostudios.emberdelve`** — the shipped dice roguelite that has real
installs and real revenue. Pages serves it from `main:/docs`, so an edit on
`main` changes what Play links to, for a product that is not on `main`.

**What went wrong.** Commit `9abefd4` (2026-08-31) rebranded that page to
Pyregrove. Its message says "covers both packages", meaning pyregrove and
emberwood. There is a third package — `com.tsorostudios.emberdelve` — whose live
store listing points at this URL. For about a day, anyone tapping "Privacy
Policy" on the Emberdelve listing was shown a policy for a different app that
never named theirs. That is a policy-compliance exposure on the only app earning
money, and store enforcement is not a thing we can appeal quickly.

Fixed in the commit that carries this directive: the page is now
"Tsoro Studios Games — Privacy Policy" and covers all three packages. No data
practice, permission or data-safety answer was changed — only scope and naming.

**Rules from here:**

1. **Never scope that page to one game.** It must continue to name
   `com.tsorostudios.emberdelve`, `com.tsorostudios.pyregrove` and
   `com.tsorostudios.emberwood` for as long as any of them is published.
2. **Never move or rename it.** The URL is referenced from a store listing that
   only the owner can edit. A 404 there is worse than a stale page.
3. If a game's data practices genuinely diverge, **add a per-app section** — do
   not fork the page to a new address.
4. Treat any file under `docs/` in the public repo as **published surface**, not
   internal docs. Check what links to it before rewriting it.

**Wider lesson worth generalising:** this repo now hosts more than one product's
lineage. Before rebranding anything, grep for who else depends on the artefact —
package ids, store listings, deep links, asset URLs. A rename that is correct
inside one project can silently break a published contract in another.

Freeze otherwise unchanged: keep working on code, no release, no tag, no Play
submission.

## Primary-source drop 2026-09-01c — Play's two new quality requirements

Relayed from the owner's mailbox into `docs/research/owner-inbox-evidence.md`:
Google Play has announced **two new app quality requirements** (memory/bitmap/
code-optimization thresholds with separate criteria for games, and a device-
migration onboarding standard). Verbatim text and provenance are in that file.

Read it before touching `docs/PLAY-QUALITY-2027.md`. Two cautions: the email
carries **no dates and no numbers**, so anything numeric must be sourced or
marked `unknown`; and these are **memory** limits, not download size — download
size is settled at 20.6 MB and stays closed. This lifts no freeze.

## Owner directive 2026-09-01b — research steering, freeze unchanged

### Compliance acknowledged, specifically

Directive 477857c asked for one cohesive retention improvement, exactly one
GitHub release, then research. That is what happened: the mechanism went into
progress.md *before* the build (235d3fe), THE SEVEN HEARTHS landed (e9926ae),
v0.178.0 was tagged once (1e9a49a), shipping stopped (a19b9cd), and the work
moved to R1/R2/R3. The screenshot set was correctly filed under `docs/` with
the listing left alone. No second version bump. This is the pattern to keep.

Verified independently on our side: v0.178.0 published 11:51:44Z, not a
prerelease, 5 assets, all five sha256s in the notes matching the artifacts, and
the v2 signing certificate hashing to the pinned upload key. `/releases/latest`
now resolves to v0.178.0, so every "latest APK" link in the world silently
upgraded from v0.175.0 to this build. One note for whenever the signing config
is next touched: the APK carries a v2 signature block but **no v3 block**. Fine
for Play today; v3 is what would allow key rotation later. Not urgent.

### Current external state — use these facts, do not re-derive them

- **Play is still on version name 0.59.0 / code 85, cut 30 Aug.** The review-ask
  fix has therefore still never run on a real player's device. Unchanged.
- **itch.io is now at 0.178.0** (butler build #1936002), and the v0.178.0 devlog
  is published: `tsorostudios.itch.io/emberdelve/devlog/1648555/the-seven-hearths-v01780`
- itch lifetime: **34 views, 6 downloads, 0 purchases, listed free.**

### Correction — R3 §4 rests on a false premise

R3 proposes, as the cheapest traffic experiment, "a free itch demo build linking
to Play," on the Slice & Dice demo-first template. That template does not map
onto our situation, because **the itch build is already the complete game, free**.
There is no demo/full split to create: a player who takes the itch build has the
whole thing and no reason to visit Play. Shipping a *cut-down* build to itch
would be strictly worse than what is there now, and it would sit badly beside
the "free = full game" promise the listing makes.

The useful reframe: **itch cannot convert, because there is nothing there to
buy** (the Ember Forge unlock exists only in the Play build). itch is a
discovery surface and a devlog home, nothing more. So do not design funnels that
re-route the six people who already downloaded. Design for people who have never
heard of the game.

### The research question, sharpened

R3's own evidence is the important finding, and it agrees with what we measured
independently: at 38 lifetime installs, **traffic is the binding constraint and
conversion is not**. Play gives cold-start apps effectively no organic push, so
a perfect listing multiplies visitors we never get. Keep that conclusion.

What is still missing is anything actionable. Replace generic advice with a
short list of **named, reachable channels**, and require each candidate to carry
four things or it does not make the list:

1. **Named and specific** — an actual community, publication, curator, festival,
   newsletter or subreddit, not a category like "content creators".
2. **Reachable from Zimbabwe, at zero budget** — no paid UA, no rail we cannot
   pay on, nothing requiring a US entity.
3. **An order-of-magnitude expectation with a source** — "this class of post has
   historically produced tens, not thousands, of installs" is useful; an
   unquantified maybe is not.
4. **What would falsify it** — the observation that would tell us it failed, and
   how long we would wait.

Rank them by expected installs per hour of my time. A ranked list of five
honest candidates beats twenty unranked ones. Explicitly include the option
"none of these clear the bar, and here is why" if that is where the evidence
lands — that is a real finding, not a failure.

### R2 — do not trade the promise for the metric

R2 is measuring retention while the store listing promises **no ads, no
tracking, plays offline**. Those constraints are not obstacles to work around.
R3's own research is the reason: the trust promise is the strongest asset the
product has, and Royal Match's 2026 reversal shows what it costs to break one.

So: **do not propose adding analytics, telemetry, event beacons or any
phone-home to measure retention.** Retention gets measured from Play Console's
aggregate device metrics, which already exist and need no code. If a question
cannot be answered without new tracking, the correct output is to write down
that the question is unanswerable under our promise, and to say what
aggregate-only proxy comes closest. `docs/research/retention-ledger.md` should
state this constraint at the top so nobody re-opens it in three weeks.

### Freeze: unchanged

- **No further GitHub releases.** v0.178.0 was the one. Do not tag another
  without a new directive saying so.
- **No Play submissions, no track changes, no listing or screenshot edits.** If
  Play is authorised, it ships from the existing v0.178.0 AAB, handled outside
  this repo. Nothing for you to do.
- Keep writing research to `docs/`. Waiting is research time, not idle time.

## Owner directive 2026-09-01 — one major update, ONE GitHub release, then research

### The freeze changes shape. Read this precisely.

The 2026-08-31 freeze stopped 177 small releases and it worked: emberdelve has
published nothing since v0.177.0 (2026-08-31T19:44:55Z) while development
continued. Good. It is now partially lifted, in one direction only:

- **AUTHORISED: exactly ONE GitHub release.** Not a series. One.
- **STILL FROZEN: Google Play.** No submissions, no track changes, no
  store-listing edits, no screenshot changes. Play ships on a separate owner
  call, from this same tag, using this same artifact.

If you find yourself typing a second version bump after this release, stop —
that is the old failure mode returning.

### Scope of the update: ONE cohesive retention improvement

Not a grab-bag, not a changelog of six small things. The weakest real number in
this business is retention: **28 monthly active devices and 7-day retention of
1 device** over the last 28 days. Content breadth is not the problem — the
roster is already at sixteen delvers.

Pick the single strongest intervention on the **first session and the first
week** and build it properly, with tests. Candidates worth weighing (your call,
you are closer to the code): the clarity of the opening run, the first
meaningful decision arriving sooner, a reason to open the app on day 2 that is
not a loss-framed nag, or a first-week arc that resolves rather than trails off.

Whatever you choose, write down in progress.md *why* you believe it moves day-7
retention, before you build it. If you cannot articulate the mechanism, it is
the wrong pick.

### What the release must carry

1. The chosen retention improvement.
2. **The in-app review ask fix (PR #98, squash-merged 0076b043).** This is the
   single most valuable thing sitting unshipped. Production is still on version
   name 0.59.0 / code 85, cut 30 Aug, which predates the fix — so every player
   in the world is currently running a build that cannot ask them to rate it.
   The app has **2 ratings**. Verify the fix is actually present on the ship
   branch before tagging; do not assume.
3. The Feb-2027 migration attributes already merged (3e85a8c). Closed, verified,
   do not re-open.

### Version numbering — unify the lines

GitHub tags sit at v0.177.0 while Play's version *name* is 0.59.0. Two numbering
lines is a permanent source of confusion. Collapse them:

- Tag **v0.178.0**, pubspec **0.178.0+204**.
- Version code 204 is comfortably above Play's live 85, so this same artifact
  can be submitted to Play unchanged when that call is made. **Build it once.**
  Do not rebuild for Play later — the tagged AAB is the Play candidate.

### Release standards for this one release

Tag at the release sha. Signed APK + AAB from CI (workflow_dispatch on this
branch). Signer cert must match pin
`031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`. sha256s in
the notes. Notes explain the improvement in plain player-facing language, plus a
short technical section. Mark it **not** a prerelease — v0.176.0 and v0.177.0
were flipped to prerelease so that `/releases/latest` points at a build with a
working download; v0.178.0 should become the new latest.

### Then: stop shipping and do research

After the release is cut, **do not start another feature**. Three research
briefs, in priority order. Each one produces a written artifact in `docs/`, with
evidence, not opinions.

**R1 — First-session teardown of comparable dice roguelites (highest value).**
Take the top comparable titles on Play. Actually play the first session of each.
Record, with timestamps: how long until the first meaningful decision, what is
on screen at the 60-second mark, when the first reward lands, what the day-2
return hook is, and what the game does when a first run is lost. Deliver a
concrete delta list against Emberdelve's first session. This is the input to the
next retention decision, so it must be observation, not speculation.

**R2 — We are flying blind on where session one ends, and that is a real
tension.** Analytics are off until a player switches them on, and that stays —
it is a product pillar and it is part of why this game is trustworthy. But
"retention is our weakest number" and "we cannot see where players stop" cannot
both be permanent. Research the honest options: what can be learned from purely
local, on-device signals the player can see and erase; what Play Console already
exposes for free that we are not reading; what a genuinely informed-consent
prompt would look like if it were worth asking at all. Deliver a recommendation
with the privacy cost stated plainly for each option. If your conclusion is
"ask nothing, read Play Console harder", that is a legitimate finding — say so.

**R3 — Store listing conversion (research only, changes are FROZEN).** The
listing is the funnel above everything: 38 installs. Study what the first three
screenshots, the short description and the title do in this category. Deliver a
proposed listing as a document. **Do not touch the live listing.**

### Guardrails, unchanged

- Stability is excellent — zero crashes and zero ANRs over 28 days. Protect it.
  A retention feature that costs stability is a net loss.
- `flutter analyze` clean; full suite green; no skipped tests; new behaviour has
  tests; bug fixes get a regression test that fails on the old code.
- The sim stays pure. Golden hashes move only with a documented re-anchor table.
- Do not re-open download size. It is 20.6 MB against a peer median of 52.7 MB.
- Waiting on a build is research time, not idle time.

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
