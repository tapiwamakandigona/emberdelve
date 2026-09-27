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
  Android configuration or signing-key change. Before the required root
  progress append,580 of582 baseline hashes matched (version and news were
  the two reviewed exceptions). Final documentation handoff matches579/582:
  the third difference is append-only progress,whose entire original prefix
  remains byte-identical. No additional production-code difference.

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

### VERIFIED final store readback — September 19, 14:34 UTC

Publishing overview and Production Releases both still show **211 (0.184.0)
In review**. The quick-check banner is no longer present; no separate
successful-checks banner was captured. The one change remains
**Production → 211 (0.184.0) → Start full rollout**. Managed publishing is
off, country coverage177, and **210 (0.183.0) remains available**.
`play-final-readback.json` and its accompanying redacted text excerpt record
the readback. **No live211 claim or further submission.**

## itch.io and remaining limits

The initial pass stopped at Cloudflare before the password form. On the
owner's explicit instruction, a password reset was then completed: the reset
link was retrieved from the registered Gmail, and the new password was set.

VERIFIED itch update — September 19, 15:37 UTC. Signed in as `tsorostudios`,
the Emberdelve page now offers **`emberdelve-0.184.0-android-arm64.apk`
(36 MB)** and **`emberdelve-0.184.0-android-arm32.apk` (34 MB)**; the old
`0.179.0` file was deleted; the AI Disclosure now includes **Graphics** (Code,
Graphics, Text). A major-update devlog is public at
`/emberdelve/devlog/1669707/the-whole-company-emberdelve-01840`.

The 75 MB universal APK exceeded the 50 MB browser-transfer cap, and itch's
butler/upload hosts (`*.itch.ovh`, `*.itch.zone`) do not resolve from the
sandbox, so butler could not be used. The two ARM split APKs (identical
signed 0.184.0 build) cover all real phones; the linked GitHub release
carries the universal APK, the x86_64 split and SHA-256 checksums. The APK
uploads are itch's own re-signed distribution copies; the canonical signed
artifacts and digests remain the GitHub release. Evidence:
`docs/release-sep19/evidence/itch-published.json`. `REL-ITCH` now passes.

Physical-phone FPS/touch, direct aesthetic inspection/owner approval, full
natural UI playthrough and real Play purchase/restore remain unverified.
Original root false gates stay false. A headless render pass is not evidence
of “best visuals,” and GitHub publication is not Google Play availability.

## VERIFIED final source and acceptance inventory

`docs/release-sep19/evidence/final-inventory.json` records the complete
release delta and a credential-value scan with no matches. Exact remote tag
and latest-release assets still match source84f973f and the verified bytes.
All production code, assets, checks, Android/signing and dependencies are
unchanged from that signed source.

Final broad inventory is **579/582 unchanged**, not580/582: the two reviewed
version/news edits plus the required append-only root progress entry.
Both the original431,492-byte progress prefix and signed432,542-byte prefix
are preserved exactly. The fixed pre-log audit assertion remains failed and
unmodified; the final report records the real differences instead of
relabeling that failure as a pass.

Scoped release criteria: **4 of5 passing**. `REL-ITCH` remains false.
Original root objects are unchanged, including open
`NEXT-UI-PLAYTHROUGH-20260913`, `M1-3` and `M4-2`.
This is a verified GitHub release and Play submission with a blocked itch
publication, **not overall project completion**.
