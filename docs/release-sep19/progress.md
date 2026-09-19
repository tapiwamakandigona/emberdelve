# September 19 release progress — append only

## Iteration 1/8 — audit and plan

- VERIFIED canonical harness cloned/read at main/v3.0.1. Existing AGENTS.md
  already derives from it; scoped PROJECT/features/loop copied from the
  fresh canonical templates, not reconstructed from memory.
- VERIFIED primary source: shipping741b439, latest release0.183.0+210;
  PR104/105/106 already merged; PR102 remains an open historical critique.
- VERIFIED authenticated Play210 is Available on Google Play, full rollout,
 177/177 countries; internal/Alpha209. No unpublished changes initially.
- VERIFIED fresh primary merged-head CI35327651857 analyzer clean,
  1526 passed; signed job skipped. This is not a new signed build.
- VERIFIED Google login via user-supplied password/TOTP succeeded.
  itch Cloudflare verification blocks both normal and one proxy fallback
  before password input. No recovery, password test or store edit.
- Setup failure: password post-step wait used a broad selector and reported
  `strict mode violation: locator("input[type=password]") resolved to 2 elements`.
  Single corrected continuation used observed name=Passwd; login verified.
- Setup failure: incorrectly assumed official SDK index path returned
  `404 Not Found` and `NoSuchKey`; one identical-path retry stopped.
  Official Flutter archive documentation revealed the correct index.
  Download3.44.9/Dart3.12.2 matched official SHA256
  a9120fa4a01048bdef438ddc3a2d4b7389662ea98a95db86eeaf10382bc4efcb.
- Extraction failed `command timed out after 20000 milliseconds`; one
  adequately timed extraction of the checksum-verified archive succeeded.
- ASSUMED release choice: package integrated visuals as0.184.0+211, no
  speculative new art or simulation/billing changes. Open physical-device,
  purchase/restore and inherited keystone UI-tool gates remain false.

## Iteration 2/8 — local regression and current render verification

- VERIFIED pinned Flutter3.44.9 analyzer clean,1526/1526 original tests pass,
  art check22 models/40798 PNG bytes/675840 decoded bytes, SFX reachable
  cascades clear ceiling. Existing full-attack−0.90dBTP TIGHT unchanged.
- VERIFIED all582 protected baseline file hashes unchanged.
- Failure: full unchanged roster render command stopped with
  `command timed out after 600000 milliseconds`;34 phone cases completed
  without assertion failure. A single adequately timed retry is starting;
  do not call the partial sweep72/72 or modify the check.
- Tooling route failure: ordinary package installation reported
  `E: Could not open lock file /var/lib/dpkg/lock-frontend - open (13: Permission denied)`.
  Non-root distro download reported `E: Unable to locate package libaapt0`
  and `E: Unable to locate package libunwind0`; no package installed.
  Descoped the distro route instead of attempting root/elevation.
- VERIFIED official portable Android build-tools36, Temurin JDK17 and
  Google bundletool1.18.3 downloaded against published archive digests.
  apksigner/aapt2/jarsigner/bundletool execute without root. Verified the
  published210 AAB digest and permanent certificate as a tool smoke test,
  not as evidence for the still-unbuilt211 candidate.
- VERIFIED original renderer source, source-provenance records and
  runtime-observation structure reviewed. Direct aesthetic inspection,
  owner approval, physical touch/FPS and real purchases are not inferred
  from headless PNG generation or numeric assertions.
- VERIFIED single retry completed18:00 with72/72 passing cases:66 phone
  combinations,12540 observations,4608 PNGs. Independent PNG decoding/hash
  inventory and132 outgoing contact-sequence checks passed. Maximum
  shared-grip error2.842170943040401e-14 logical px across six tool families.
  All582 protected hashes and original root feature objects unchanged.
  evidence/render-review.json states the remaining visual/device limits.
- VERIFIED brand lint has0 errors and1 advisory (no primary alias). No
  generated colours or new brand values were introduced; existing palette,
  actual screenshots and existing fonts are retained.

## Iteration 3/8 — version and release documentation

- Plan: package0.184.0+211 and matching four-line in-game news, correct
  source-backed README roster/download facts, keep IARC history honest,
  then rerun all original analyzer/tests/art/SFX and integrity gates.
- VERIFIED news tests inspected before edits: newest-first/version-match,
  2–4lines, banned-word charter, show-once and archive semantics preserved.
- Version/news and documentation edits only. No test/sim/purchase/dependency
  or signing/workflow changes. Candidate is not yet signed or submitted.
- VERIFIED post-version original analyzer,1526/1526tests, art reproduction
  and reachable SFX all exited0. Evidence: `candidate-*`.
- Audit-wrapper failure (not an original game check):
  `AssertionError: ['lib/data/news.dart', 'pubspec.yaml']`.
  The broad pre-release hash inventory includes the two files this
  iteration explicitly must change. Do not alter that wrapper assertion or
  claim all582 hashes still match. Review the exact version/news diff and
  record the580 unchanged protected files plus the two declared exceptions.
- VERIFIED managed Git exact diff shows only the planned version line and
  additive four-line release news in the two baseline exceptions. All
  original tests/checks, integration tests, tool scripts, CI, Android, sim
  and lockfile have empty diffs against741b439. The wrapper remains
  unmodified; evidence/candidate-review.json records the actual outcome.
- VERIFIED release notes366characters (en-GB, maximum500); no runtime/art
  change since the72-case render checkpoint. Next: commit/push and release
  PR, then existing signed CI dispatch against the exact candidate ref.
- Documentation patch rejected before application:
  `Update hunk does not contain any lines`. Single corrected patch removed
  the empty root-progress hunk; no acceptance check changed.

## Iteration 4/8 — exact-head signed CI and binary verification

- VERIFIED release branch pushed at84f973f3a28b043effefb6d0b0a9b6ea9a13e4b9.
  PR107 opened against legacy/dice-builder; no PR merged.
- Managed existing CI dispatch failed exactly:
  `could not create workflow dispatch event: HTTP 403: Resource not accessible by integration (https://api.github.com/repos/tapiwamakandigona/emberdelve/actions/workflows/318731966/dispatches)`.
  One authorized fallback read the provisioned token from protected storage
  and dispatched the same unchanged workflow/ref through Actions REST,
  HTTP204. Token values were not printed or committed.
- VERIFIED run35447309873 is workflow_dispatch on exact84f973f. Waiting
  for both headless checks and signed Android job, not inferring signed
  artifacts from PR checks. Native artifact verification tools ready.
- Read-only publishing preflight selector failure:
  `Locator.wait_for: Timeout 60000ms exceeded.`
  `waiting for get_by_text("Managed publishing").first to be visible`
  `locator resolved to hidden <span ...>`.
  Page was already rendered; single read-only inspection confirmed
  `Managed publishing off` and no pending changes. Corrected future wait
  to the exact observed text, not another navigation/retry.
- VERIFIED signed CI35447309873 completed successfully on84f973f; all
  five APK/AAB files downloaded. AAB structure/manifest/JAR signature and
  universal APK signature verified independently.
- Local binary-adapter failure: `assert "sdkVersion:'24'" in manifest`
  raised `AssertionError`. Actual official aapt2 output is
  `minSdkVersion:'24'`; target remains36 and package/version match.
  One corrected adapter retry uses the observed field name, still requires
  exactly24. No expected SDK value, repository test/check or binary changed.
- VERIFIED corrected binary adapter passes all5 files: permanent cert,
  package/version,SDK24/36,not-debuggable,APK cryptographic verification,
  AAB JAR signature/structure. AAB self-signed/no-timestamp/ZIP-order warnings
  recorded, not hidden. All22 sheets/fonts/meta match current source inside
  every binary; permission set identical to published210.
- Evidence-extraction assertion initially expected local expanded-reporter
  text; CI actually emits `1526 tests passed.`. Single corrected primary-log
  read verified that line and all other checks. This shell invocation did
  not stop before the following publication command; the release was still
  gated by its own already-passing signed-CI/binary assertions. Subsequent
  command batches use `set -e`; do not rely on last-command exit status.
- VERIFIED GitHub release v0.184.0 published from exact84f973f at
  2026-09-19T14:15:43Z. All5 public asset digests/sizes match independently
  verified local files; SHA256SUMS published. This is not Play availability.

## Iteration 5/8 — authorized Play production submission

- Plan: create211 only in the existing Emberdelve production track, upload
  independently verified AAB after browser-side size/SHA256 match, enter
  the366-character en-GB notes, inspect processed bundle/device-support
  preview and every pending change before saving/submitting.
- Preserve existing targeting/content ratings/privacy/purchases. If preview
  loses device support or exposes unrelated pending changes, stop and resolve
  without dropping legacy coverage. Distinguish staged, in review and live.
- Create click succeeded; post-click broad file selector failed:
  `strict mode violation: locator("input[type=file]") resolved to 2 elements`.
  Read-only inspection confirms production draft release8, not a failed
  creation. Continue using observed `input[type=file][accept=".aab"]`;
  never click create again or upload to the expansion-file input.
- VERIFIED browser-received AAB size/SHA256 matched the independently
  signed binary before assignment to the ordinary .aab file input.
  Processed row211/0.184.0,min24,target36 and366-character notes matched.
  Preview showed100% rollout/all targeted countries and zero device loss
  across every form factor. Saved once, then inspected Publishing overview.
- Pre-submit guard failure: `AssertionError` at
  `get_by_role('button',name='Save for later',exact=True).count()==1`.
  DOM showed the visible button's inner span has `aria-label="button"`;
  the role/name locator is not its visible text. Read actual change rows
  instead; exactly Production211/Start full rollout, no unrelated changes.
  This failed before a submit click. No original product check changed.
- VERIFIED single final `Send changes for review` click at
  2026-09-19T14:24:21Z returned `1 change sent for review`.
  Publishing overview then showed Changes in review with quick checks
  still running; it says review follows successful checks. Do not treat
  the heading alone as completed pre-review checks or live availability.
- Post-submit readback selector failure:
  `Locator.wait_for: Timeout 60000ms exceeded.`
  `waiting for get_by_text("211 (0.184.0)", exact=True).first to be visible`.
  Production landed on Release dashboard with the version inside a longer
  summary. Single corrected continuation selected the observed Releases
  tab. No repeated submission. A transient overview notification read
  `An unexpected error has occurred. Please try again. (73C9342D)`;
  independent production and release-details reads succeeded.
- VERIFIED primary production readback14:26UTC:211 In review,177countries;
  210 remains Available on Google Play. Release8 details confirms exact
  notes,bundle211,min24,target36. Managed publishing off. Existing
  edge-to-edge/R8 suggestions are documented, not hidden or patched by
  changing release code after signing.
- VERIFIED exact-source PR CI35447297307 and unsigned iOS35447297322
  succeeded. Signed binary proof remains the separate dispatch35447309873.
  Binary source/tag stays84f973f; later evidence commits are docs-only.

## Iteration 6/8 — itch.io publication package, access blocked

- Plan: refresh the public-page readback, prepare current page/devlog copy,
  unchanged actual-render screenshots, exact-release download and checksum.
  Do not retry authentication or treat a public read as editor access.
  Keep REL-ITCH false unless an authenticated save and public readback occur.
- Packaging-path failure:
  `FileNotFoundError: [Errno 2] No such file or directory: '/work/temp/emberdelve-0.184.0-artifacts/app-release.apk'`.
  Artifact inspection found the existing APK in its named CI artifact
  subdirectory. One path-only correction; size/hash/signature gates unchanged.
- VERIFIED public itch page still0.179.0/69MB with AI-assisted Code/Text
  disclosure only. It already links GitHub latest; that link now reaches
  0.184.0, but no itch edit is implied. No further login attempt.
- VERIFIED prepared description,one catch-up devlog,generated-graphics
  disclosure,3 unchanged source-matched720×1280 PNGs,exact-release APK link
  and checksums. Eight content links responded successfully; remote image
  bytes match source PNG hashes. No new theme,art or visual claim.
- VERIFIED private ZIP contains11 files,including exact75,707,508-byte
  signed universal APK renamed for itch; extracted hash matches signed
  release and ZIP CRC check passes. Git contains copy/manifest/screenshots,
  not the binary. REL-ITCH remains false: prepared is not published.
- ASSUMED editorial choice: one substantive catch-up devlog is preferable
  to recreating every intervening release post. No schedules created.

## Iteration 7/8 — final evidence and private handoff

- Plan: read Play status again without mutation, verify exact release/tag
  and source integrity, update handoff checkpoints, push documentation only,
  and deliver the prepared itch package privately. Do not merge PR107,
  advance the release tag, infer Play availability or mark itch complete.
- Final all-file inventory adapter failed:
  `AssertionError` at `assert baseline_changed == sorted(declared)`.
  It reused the pre-log version/news-only exception list after the required
  root progress append. Actual final inventory is579/582 unchanged:
  version,news,and append-only progress differ. Original progress prefix
  is byte-identical; signed-source progress is also an exact current prefix.
  Retain this failed adapter,do not weaken its assertion. Report actual
  inventory separately and verify the immutable production-source diff.
- A supplementary `git show` hash initially hashed the SDK's
  `Output too long` pointer rather than its saved full output. Reading the
  full432542-byte signed-source progress output verified exact prefix
  preservation;the initial431492-byte progress prefix also matches.
  No actual source/history rewrite. Previous580/582 statements describe
  the pre-progress-append checkpoint,not the final docs handoff.
- VERIFIED independent final inventory records actual579/582 unchanged;
  exact signed-source production diff is empty. Both original/signed
  progress prefixes and all original root/scoped criteria are preserved.
  Complete69-file delta scan has no provisioned credential-value matches.
  Latest release asset digests and remote tag still match84f973f.
- VERIFIED final Play14:34UTC:211 In review,quick-check banner absent,
  210 remains available. Scope4/5 passing;REL-ITCH and three inherited root
  gates remain false. No overall completion claim. Next: documentation-only
  commit/push and remote PR readback,then private package delivery.
