# Play compliance check on the v0.179.0 artefacts — 2026-09-02

Purpose: the directive holds v0.179.0 as the build the owner may one day apply to Play. Before
that call is made, every Play platform requirement with a 2026–2027 deadline is checked here
**against the released artefacts themselves** (downloaded from the v0.179.0 release page, sha256
matched to the release body), not against source or memory. Nothing in this note is a
recommendation to release; it records that the build as it exists clears the bars below.

## Results

| Requirement (primary source) | Deadline | v0.179.0 artefact says | Status |
| --- | --- | --- | --- |
| Target API level — "New apps and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play" ([Play Console Help 11926878](https://support.google.com/googleplay/android-developer/answer/11926878)) | 2026-08-31 (extension to 2026-11-01) | `aapt2 dump badging emberdelve-v0.179.0-arm64-v8a.apk` → `targetSdkVersion:'36'`, `compileSdkVersion='36'`, `platformBuildVersionName='16'` | **Clear** |
| Play Billing Library — "By Aug 31, 2026, all new apps and updates to existing apps must use Billing Library version 8 or later" ([deprecation FAQ](https://developer.android.com/google/play/billing/deprecation-faq); table: v7 deadline 2026-08-31, v8 deadline 2027-08-31) | 2026-08-31 for ≥ 8; ≥ 9 by 2027-08-31 | Manifest meta-data `com.google.android.play.billingclient.version = "8.0.0"` (aapt2 xmltree on the universal APK); AAB dex carries the same `8.0.0`; comes from `in_app_purchase_android 0.5.2` (pubspec.lock, identical at v0.59.0 and v0.179.0) | **Clear until 2027-08-31**; then Billing 9 is needed — that is an `in_app_purchase` bump, not app code |
| 16 KB page sizes — "all apps targeting Android 15 (API level 35) and higher must support 16 KB memory page sizes on 64-bit devices … Starting February 1, 2027, if your app updates don't support 16 KB memory page sizes, you won't be able to release these updates" ([page-sizes guide](https://developer.android.com/guide/practices/page-sizes)) | 2027-02-01 hard stop | `readelf -lW` on every arm64 `.so` in the split APK: `libapp.so` 0x10000, `libflutter.so` 0x10000, `libdartjni.so` 0x4000, `libdatastore_shared_counter.so` 0x4000 — all LOAD segments ≥ 16 KB aligned; `zipalign -c -P 16 -v 4` → "Verification successful" | **Clear** |
| Backup / data-extraction rules (owner-verified, DEMAND.md "Feb-2027 migration: CLOSED") | — | not re-checked; owner closed it | Closed, do not re-open |
| Privacy policy URL unchanged (`docs/store/privacy-policy.html` on main) | — | not part of the build | Standing rule |

Note: split-APK `versionCode='2205'` is the ABI-offset code (arm64 = 2000 + 205); the AAB
carries 205, which is what Play uses.

## What this does and does not mean

- The build that exists **clears every Play deadline through 2027-01-31 with nothing to do.**
  The next platform-forced change is Billing Library 9 by 2027-08-31 (or 2027-11-01 with
  extension), which arrives as an `in_app_purchase` dependency bump when the plugin ships it.
- This is **not** a reason to cut anything. It only removes "is the build even acceptable to
  Play?" from the list of open questions for the day the owner decides to apply it.
- The Play production build (`0.59.0`, 2026-08-25) uses the same plugin version and
  targetSdk; it is also compliant. There is no compliance pressure forcing an apply.

## How to re-run (five minutes, no device)

```
aapt2 dump badging <split-apk> | grep -E "targetSdk|compileSdk"
aapt2 dump xmltree <universal-apk> --file AndroidManifest.xml | grep -A1 billingclient.version
unzip -o <arm64-apk> 'lib/arm64-v8a/*.so' -d /tmp/so && readelf -lW /tmp/so/lib/arm64-v8a/*.so | grep LOAD
zipalign -c -P 16 -v 4 <arm64-apk> | tail -1
```

Re-run on every artefact set before any apply; re-read the two Google pages above each
January and August, since Google moves the table once a year.
