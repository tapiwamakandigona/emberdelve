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
