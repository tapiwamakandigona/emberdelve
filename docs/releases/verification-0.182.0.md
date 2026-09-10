# VERIFIED release-candidate evidence — 2026-09-08

Source `8a9def489a748a65d343a5998ed1375d3ceb86ca`, quality PR #101 to
`legacy/dice-builder`. Version `0.182.0+209`, package
`com.tsorostudios.emberdelve`. No original test, CI workflow, signing pin,
simulation, entitlement or telemetry check weakened.

## Build and integrity

[Existing signed CI](https://github.com/tapiwamakandigona/emberdelve/actions/runs/34243188072)
completed successfully after the owner explicitly authorized their supplied
PAT. Analyzer, 1,348 tests and existing SFX gate green. Local read-only
character-asset reproducibility gate green.

GitHub artifact ZIP digests matched after download. Each APK passed Android
`apksigner verify --verbose --print-certs`; manifests/certificate bytes
independently parsed. AAB passed JDK `jarsigner -verify`, PKCS7 certificate
pin and `bundletool validate`/manifest readback. Correct package,
non-debuggable, minSdk 24/targetSdk 36.

Permanent upload certificate SHA256:
`031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`.

| File | Bytes | versionCode | SHA256 |
|---|---:|---:|---|
| app-release.aab | 73443860 | 209 | `88c36e957a25c8c0809e21273f8f78f18d98c857f1c60ff6454e9cbdbcc6279d` |
| app-release.apk | 75312216 | 209 | `21fe112a18ad3089af10fb68ccbf6843d37681b8a7a6b7926a9c5650d4c550c0` |
| app-arm64-v8a-release.apk | 38005594 | 2209 | `6b01aa861336d19964ff4462f70f00c6a34937a1cf13fb241d6b5940decc7a86` |
| app-armeabi-v7a-release.apk | 35582058 | 1209 | `304ecb7a203a7a0f89394cf09159c6f8fced2c5337035d83805ab9fa99020a5f` |
| app-x86_64-release.apk | 39528950 | 4209 | `fba20f19bd4b035b866f5eef4d43781df31c715276d4b4f4f60cc7221afd0c42` |

## Google Play

VERIFIED after publishing and reopening the internal track:
**209 (0.182.0) — Available to internal testers — 2 version codes**.
This is a testing update, not a production rollout.

The internal track previously had code 12/minSdk 21. New code 209 uses the
already-shipping minSdk 24. First preview flagged 1,921 device models losing
support. Rather than override that error, the old code 12 was retained as
the legacy-device fallback. Second preview: **Ready to release**, zero
newly unsupported phone/tablet/TV/other device rows. Thus Android 5–6 keeps
the old game; it does not get the new Android 7+ candidate's features.

No tester roster or production change was submitted. Do not confuse a
console estimate (26.5 MB new install on its example device) with the
universal APK size or a measured download on a low-end phone.

## Still open

Physical low-end FPS, installed visual/touch review and Play purchase/
restore have not been verified. M1-3 and M4-2 stay false. The unchanged
emulator frame-trace run
[34245082297](https://github.com/tapiwamakandigona/emberdelve/actions/runs/34245082297)
completed successfully; downloaded timeline summaries report:

| Scenario | Avg build ms | Avg raster ms | Worst build ms | Missed build/raster frames |
|---|---:|---:|---:|---:|
| Title tap storm | 1.095 | 70.037 | 28.394 | 1 / 75 |
| Combat button storm | 2.646 | 101.506 | 83.929 | 2 / 86 |
| Map drag | 0.746 | 115.129 | 9.013 | 0 / 60 |

These are profile-mode Android emulator/SwiftShader measurements. They
verify the three flows executed and expose jank in this environment; they
do **not** establish 60 FPS or predict low-end physical GPU performance.
No before/after device comparison or physical acceptance is claimed.

## Published download readback

[v0.182.0 prerelease](https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.182.0)
targets the exact built SHA, `prerelease=true`, `latest=false`. All five
published binary files and `emberdelve-SHA256SUMS` were downloaded again
from the release and matched byte lengths/SHA256 above.
