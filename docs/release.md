# Release & signing — Emberdelve (Flutter)

**For any AI/human building or releasing this app.** No secret values live in
this repo — this file only tells you where they are.

## Android signing (permanent upload key — NEVER regenerate)

Every delivered build is signed with the **same permanent keystore** so
installed apps always update in place (owner requirement, 2026-07-23).
Package id: `com.tsorostudios.emberdelve`.

| What | Where |
|---|---|
| Keystore (PKCS12, alias `emberdelve`, RSA-4096, valid to 2066) | Build machine: `/work/secrets/emberdelve-upload.keystore`; passwords + alias + cert fingerprint: `/work/secrets/emberdelve_signing.md` |
| CI copies | GitHub Actions secrets on `tapiwamakandigona/emberdelve`: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (set 2026-07-23) |
| Cert SHA-256 fingerprint | `03:1A:CB:42:56:6A:51:D5:B5:9F:FD:5D:EB:17:3F:1B:0E:81:7A:9E:DF:F1:BB:69:79:F6:85:64:D4:4B:7A:0D` (public info — pinned in CI's verification step) |

Rules:
1. **Never commit** the keystore or passwords. `android/.gitignore` blocks
   `key.properties`, `**/*.keystore`, `**/*.jks` — keep it that way.
2. **Never generate a new keystore** "to fix a build". If signing breaks, fix
   the plumbing; a new key = users must uninstall/reinstall = owner-level
   decision only.
3. CI decodes `ANDROID_KEYSTORE_BASE64` to a temp file, writes
   `android/key.properties`, and signs via the Gradle `signingConfigs` in
   `android/app/build.gradle.kts` (see `.github/workflows/ci.yml`,
   job `build-android-release`). CI then verifies the APK cert SHA-256 with
   `apksigner` and **fails the build** if it isn't the permanent key.
4. Local builds without `android/key.properties` fall back to a debug key —
   fine for development, but any APK **delivered to the owner** must come from
   the CI-signed artifacts (`emberdelve-release-apk` / `emberdelve-release-aab`).
5. When publishing to Google Play: this keystore is the **upload key**; enroll
   in Play App Signing at first upload.

## Local release builds (optional)

Create `android/key.properties` (never committed):

```properties
storePassword=<see /work/secrets/emberdelve_signing.md>
keyPassword=<same>
keyAlias=emberdelve
storeFile=/work/secrets/emberdelve-upload.keystore
```

Then `flutter build apk --release`. Verify the signature before delivering:

```sh
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
# SHA256 must match the fingerprint pinned above.
```

## Version discipline

`pubspec.yaml` `version: x.y.z+N` — `N` is the Android `versionCode` and
**must strictly increase for every build delivered to anyone**, or Android
refuses the in-place update. Bump `x.y.z` per normal semver judgment; bump `+N`
always.

## History

- The Flutter-stack pivot regenerated `android/` (54f2e85) and wiped the
  original signing scaffold (cd35828); v0.2.0 "release" APKs were therefore
  debug-signed. Fixed by restoring permanent-key signing (branch
  `release-signing`, 2026-07-23) — the keystore itself never changed.
- **One-time caveat:** the first permanent-signed APK cannot install over a
  debug-signed v0.2.0 install (different signature). One final
  uninstall/reinstall is required; every update after that is in place.

## Google Play closed testing (status 2026-07-24)

- **Live:** release 12 (v0.3.9+12) on the "Closed testing - Alpha" track,
  177 countries. Passed Google Play review 2026-07-24.
- Testers join via the Google Group `emberdelve@googlegroups.com`, then the
  opt-in link https://play.google.com/apps/testing/com.tsorostudios.emberdelve,
  then install from the Play Store.
- **Production gate (personal dev account):** 12+ opted-in testers for 14
  continuous days → "Apply for production" unlocks → Google questionnaire →
  application review (~days) → production release passes one more standard
  review. Criterion met 2026-07-24 → earliest apply ~2026-08-07.

### Verified mechanics (plan releases around these)

1. Pushing app updates to the track and editing the store listing do **NOT**
   reset the 14-day clock — it tracks opted-in testers, not versions. Only a
   dip below 12 opted-in testers resets it.
2. Testers receive **no explicit update notification**; Play auto-updates
   installed apps (typically ≤24h). Shipping updates mid-window is safe and
   expected — closed testing exists for exactly this.
3. Submitting changes while a review is in progress pops a "Do you want to
   restart your review?" dialog — confirm it. Bundle the new build + refreshed
   screenshots/listing in **one** submission.
4. Once the tester criterion is met the exact opted-in count is hidden;
   proxies = group member count + testing-track install stats.

### Open commitments for the next update

- **In-game tutorial** — publicly promised to testers ("in the next update").
  `lib/ui/screens/tutorial_overlay.dart` exists; wire and verify before
  release. Blocker.
- Owner is considering a core-gameplay-simplification pass — pair with the
  tutorial + new screenshots in a single submission.
