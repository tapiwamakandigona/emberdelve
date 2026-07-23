# Release & signing — Emberdelve (Flutter)

**For any AI/human building or releasing this app.** No secret values live in
this repo — this file only tells you where they are.

## Android signing (permanent upload key — NEVER regenerate)

Every build (debug and release) is signed with the **same permanent keystore**
so installed apps always update in place (owner requirement, 2026-07-23).
Package id: `com.tsorostudios.emberdelve`.

| What | Where |
|---|---|
| Keystore (PKCS12, alias `emberdelve`, RSA-4096, valid to 2066) | Viktor sandbox: `/work/secrets/emberdelve-upload.keystore`; signing notes + password: `/work/secrets/emberdelve_signing.md` |
| CI copies | GitHub Actions secrets on `tapiwamakandigona/emberdelve`: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (set 2026-07-23) |

Rules:
1. **Never commit** the keystore or passwords. `.gitignore` blocks `*.keystore`,
   `*.jks`, `*.p12`, `key.properties` — keep it that way.
2. **Never generate a new keystore** "to fix a build". If signing breaks, fix
   the plumbing; a new key = users must uninstall/reinstall = owner-level
   decision only.
3. CI decodes `ANDROID_KEYSTORE_BASE64` to a temp file and signs via Gradle
   `signingConfigs` (see `.github/workflows/` + `android/app/build.gradle*`).
   Local builds without the keystore fall back to a debug key — fine for
   development, but any APK **delivered to the owner** must be CI-signed.
4. When publishing to Google Play: this keystore is the **upload key**; enroll
   in Play App Signing at first upload.

## History

- Defold-era CI (≤ M1) signed with throwaway debug certs — that's why updates
  used to require uninstall/reinstall. Fixed with the permanent key above.
- The first Flutter APK cannot install over a Defold-era APK (different
  signature); one final uninstall/reinstall was expected and communicated.
