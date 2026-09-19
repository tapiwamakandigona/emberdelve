# VERIFIED release evidence — September 19, 2026

Source `84f973f3a28b043effefb6d0b0a9b6ea9a13e4b9`, version `0.184.0+211`,
package `com.tsorostudios.emberdelve`. Packages merged visual PRs #104–#106.
Release PR [#107](https://github.com/tapiwamakandigona/emberdelve/pull/107)
remains open; no PR merged by this release pass.

## Source checks

- Pinned Flutter 3.44.9 analyzer clean, **1,526 tests passed** locally and in
  exact-head [signed CI 35447309873](https://github.com/tapiwamakandigona/emberdelve/actions/runs/35447309873).
- Art reproduction and reachable SFX gates pass; existing full-attack
  **−0.90 dBTP TIGHT** remains explicit.
- Actual headless render check **72/72**, 66 phone combinations, 12,540
  observations, 4,608 PNGs decoded and hashed. All source/runtime/fixture
  limits: `docs/release-sep19/evidence/README.md`.
- No original test/check, sealed simulation, purchase logic, dependency,
  Android configuration or signing-key change. 580 of 582 baseline hashes
  match; two declared exceptions are the version and additive release news.

## Signed binary verification

Official Android build-tools 36, Temurin JDK 17 and Google bundletool 1.18.3
were downloaded against published archive digests. Every APK passes
`apksigner verify`; the AAB passes JAR signature and bundle structure
verification. Each binary's own manifest confirms the package/version,
min SDK **24**, target SDK **36**, and **not debuggable**.

Permanent upload-certificate SHA-256:
`031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`.

| File | Bytes | versionCode | SHA-256 |
|---|---:|---:|---|
| app-release.aab | 73,728,918 | 211 | `ae60d8c8507c843fa830d21f9daf071f2f6420601f2a104ef12988e95bbfebad` |
| app-release.apk | 75,707,508 | 211 | `a882b12c4a1e127fef78ec0b12ca0d64005653f20807a329b1bf5bf906c2766f` |
| app-arm64-v8a-release.apk | 38,138,738 | 2211 | `7a21f1de6a36aeb75884c2b5236e58dda47c84f56aca898e907c69602934a330` |
| app-armeabi-v7a-release.apk | 35,715,206 | 1211 | `e72925bbff333324c2b00d1807586f89ad0491722cbd37253918746bd2ecffa0` |
| app-x86_64-release.apk | 39,662,094 | 4211 | `d7615bcf29d65ca49ac5012f9103a12b784053adde11fc95419d189ffc6406a3` |

All 22 character sheets, both game fonts and sprite metadata match current
source bytes inside every binary. Permissions are identical to production
210; advertising-ID/AdServices-attribution permissions remain absent.

AAB verifier advisories are recorded: Android's pinned self-signed upload
certificate, no signing timestamp (certificate expires 2066), and ZIP-order
differences for sequential `JarInputStream`. `JarFile` entries verify; the
same advisories occur in the published 210 baseline. They were not suppressed
or misreported as an all-warning-free verification.

## GitHub publication

[v0.184.0 — The Whole Company](https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.184.0)
published **2026-09-19 14:15:43 UTC** from the exact source above. Five
binaries plus SHA256SUMS; public GitHub asset digests and sizes match.

## Google Play checkpoint

Before this submission, authenticated production showed **210 (0.183.0) —
Available on Google Play**, full rollout in 177 countries. Managed publishing
was off and no changes were pending. **211 is not yet submitted at this
checkpoint**. Subsequent submission/review/live readback will be appended.

### VERIFIED submission — September 19, 14:24–14:27 UTC

The independently verified AAB was uploaded to the existing production
track and processed as **211 (0.184.0)**. Browser-received bytes and SHA-256
matched before upload. The preview retained support for every device
previously supported: zero losses and zero additions across all form factors.
New-install estimate **26.6 MB**, update **2.34 MB**.

Saved **100% rollout, all 177 existing targeted countries**; Publishing
overview contained exactly one intended change:
**Production → 211 (0.184.0) → Start full rollout**.
Final send was accepted at **14:24:21 UTC**.

Authenticated readback:
- Publishing overview: **Changes in review**, with quick checks still
  running and review queued after successful checks.
- Production and release8: **211 (0.184.0) — In review**.
- Live predecessor: **210 (0.183.0) — Available on Google Play**.
- Managed publishing remains **off**: approval publishes automatically.

**211 is not verified live.** No listing, privacy, rating, monetisation or
unrelated pending change was submitted. Play's non-blocking recommendations
about edge-to-edge display and R8 optimisation remain documented follow-ups,
not reasons to mutate an already-signed release.

Evidence: `docs/release-sep19/evidence/play-submission.json`,
`play-upload.json`, `play-device-preview.json`. Public transcripts omit
private install counts. Exact-source PR headless CI and unsigned iOS build
also passed; `candidate-pr-checks.json` records them separately from the
signed Android dispatch.

## itch.io and remaining limits

Authentication stops at Cloudflare before password entry, including the one
permitted proxy fallback. No password reset or page edit was made.

Physical-phone FPS/touch, direct aesthetic inspection/owner approval, full
natural UI playthrough and real Play purchase/restore remain unverified.
Original root false gates stay false. A headless render pass is not evidence
of “best visuals,” and GitHub publication is not Google Play availability.
