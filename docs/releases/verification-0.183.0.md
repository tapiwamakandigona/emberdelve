# VERIFIED release evidence — 2026-09-13

Source `c611e16b3ccdde571734077979dcde7847f82d04` (merge of PR #103 into
`legacy/dice-builder`). Version `0.183.0+210`, package
`com.tsorostudios.emberdelve`. No original test, CI workflow, signing pin,
simulation, entitlement or telemetry check weakened.

## Build and integrity

[Signed CI run 34743081440](https://github.com/tapiwamakandigona/emberdelve/actions/runs/34743081440)
(`workflow_dispatch` on `legacy/dice-builder`) completed successfully:
analyzer, 1,369 tests, SFX headroom gate, signed AAB/APK build, in-CI
certificate pin check. Artifacts downloaded and re-hashed locally; manifests
read back from each binary (package, versionCode, versionName, minSdk 24,
targetSdk 36, not debuggable). AAB signer certificate SHA-256 equals the
permanent upload certificate:
`031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`.

| File | Bytes | versionCode | SHA256 |
|---|---:|---:|---|
| app-release.aab | 73573718 | 210 | `2c07a8e8a452b2348f103626f6d916da58cdbc75b6378ffed9ea2ad285162fdd` |
| app-release.apk | 75443448 | 210 | `1ddda9947d7edf2f7becf2ef5bdd8a7154a0f1414e1a06542ba8226afaf9a03c` |
| app-arm64-v8a-release.apk | 38071282 | 2210 | `d451f92d9aae6180f0bdb91312f3710663464661ba9bda511c82d1437e13c60d` |
| app-armeabi-v7a-release.apk | 35647750 | 1210 | `862c7e70ea1d642db45128e91eb1367e5123385ce3bc72ea7735821d44054488` |
| app-x86_64-release.apk | 39529106 | 4210 | `ce1651c856ff5a717cbb5096a48ad20a62ec3b1d21a325e67aa61676520e288c` |

GitHub release: <https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.183.0>
(the five binaries above plus `emberdelve-SHA256SUMS`, marked Latest).

## Google Play — content rating

The build draws blood, so a new IARC questionnaire was completed and saved
before the production release (console shows a submission dated
13 September 2026, 00:11 console time, alongside the 24 July 2026
certificate). Declared: violence against humans and non-humans, fantastical
setting, pixelated style, unrealistic reactions, often distant perspective,
**mild/limited blood and gore**, fierce sounds/dark overtones; rare scary
elements; digital purchases without random items or trading; no sexuality,
gambling, language, substances, crude humour, user interaction, location
sharing, or restricted symbols/content.

Ratings shown by the IARC summary (may be adjusted by rating authorities):

| Authority | Previous (Jul 24) | New (Sep 13) |
|---|---|---|
| ESRB | Everyone 10+ (Fantasy violence) | Everyone 10+ (Fantasy violence, Mild blood) |
| PEGI | 7 (Mild violence) | 7 (Mild violence, Fear) |
| USK | 6+ | 12+ (Fantasy violence, Dark atmosphere) |
| ClassInd (Brazil) | All ages | 14+ (Violence) |
| ACB (Australia) | PG (Scary scenes) | PG (Mild violence, Scary scenes) |
| GRAC (Korea) | Violence/Fear | 12+ (Violence) |
| Taiwan DGSC | PG12 | PG15 (Violence, Horror) |
| Gmedia (Saudi) | 12 | 12 |
| IARC generic | 7+ | 7+ (Mild violence, Fear) |

## Google Play — production

VERIFIED in the console: `app-release.aab` uploaded to the **production**
track as **210 (0.183.0)**, API 24+, target SDK 36; the preview reported
**0 devices no longer supported** in every form factor versus 208 (0.181.0)
(12,476 phones, 6,690 tablets, 7 TVs, 25 cars, 72 Chromebooks, 1 XR), new
install size 26.6 MB, update 2.99 MB. Release notes (en-GB, under the
500-character cap) describe the new combat bodies. Roll-out 100%, all
targeted countries. Publishing overview: **"Changes in review"** for both
items (Production 210 — Start full rollout; App content — Content Rating —
Submit new questionnaire), sent after Google's quick checks. Managed
publishing is off, so the build goes live automatically when Google's review
completes (typically within seven days).

Production shown to users remained **208 (0.181.0)** at the time of writing;
do not report 210 as live until the track page shows it.

## Still open

Physical low-end FPS with the finished art, installed visual/touch review
and Play purchase/restore have not been verified on a device. Art quality
was judged from headless 360×640 renders (`tool/combat_bodies_frames_test.dart`).
