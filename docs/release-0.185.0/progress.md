# progress.md — 0.185.0 release (append-only)

## 2026-09-27 — iteration 1: audit + packaging

- Owner instruction (Viktor app, 2026-09-27 06:12 UTC): "go ahead and make a
  release". Read as: promote the experimental polish-loop work to a stable
  release. docs/experimental/PROJECT.md kept that line pre-release-only
  "until I order otherwise". ASSUMED interpretation, recorded here.
- VERIFIED GitHub state before acting (releases API, 06:14 UTC): latest stable
  = v0.184.0 (Sep 19, source 84f973f, AAB attached). Experimental
  pre-releases v0.184.101-exp.1 … v0.184.106-exp.6 (Sep 24–25), highest code
  217. Open PRs: #102 critique, #107 release 0.184.0, #108 living foes, #109
  experimental loop. PR #109 head = experimental/polish-loop = 7d61e26.
- VERIFIED last CI on 7d61e26: workflow_dispatch run 36131395943 success
  (both jobs); pull_request run 36131390015 success.
- VERIFIED scope audit, `git diff 84f973f 7d61e26` excluding docs/ and
  progress.md: 41 files. lib/sim, purchase/entitlement code, android/,
  .github/ and pubspec dependencies are untouched (pubspec diff = version
  line only). test/: 11 files added, 3 files with additions only (numstat
  deletions = 0). tool/: 3 harnesses added, 2 corrected (DieChip taps,
  keystone phase).
- Packaging (this commit): pubspec 0.184.106+217 → 0.185.0+218;
  currentAppVersion 0.185.0; one 0.185.0 "Living Foes" news entry replaces
  the six experimental entries; docs/releases/v0.185.0.md;
  play-notes-en-GB.txt (407 chars). Local emulation of test/news_test.dart
  rules (2–4 lines, §Ethics banned words, newest-first, version pin): pass.
  ASSUMED until CI runs the real suite.
- Canonical harness files: loop.sh copied from subagent-toolkit v3.0.1
  templates; PROJECT.md and features.json adapted from the templates.

## 2026-09-27 — iteration 2: checks, signed build, GitHub publication

- VERIFIED CI: workflow_dispatch run 36300015985 on `release/0.185.0`, head
  `c08a0d5ff4701ea33197da5bed7d2f4abc9a79c6`, conclusion success
  (06:24:49–06:42:20 UTC).
  - Job "Analyze + test (headless)" (108565820514) success: analyzer
    "No issues found!"; full suite "🎉 1598 tests passed."; sfx_headroom
    "Every reachable cascade clears the ceiling." (full_attack_turn stays
    TIGHT at −0.90 dBTP, as in 0.184.0).
  - Job "Build signed Android release (APK + AAB)" (108566825316) success,
    including the in-CI cert-pin step (all four APKs print
    031acb42…4b7a0d, DN "O=Tsoro Studios, CN=Emberdelve Upload Key").
- VERIFIED no check was edited to pass: `git diff --name-only 7d61e26
  c08a0d5 -- test tool .github lib/sim android` is empty.
- VERIFIED independent artifact check (downloaded run artifacts;
  apksigner 35 / aapt2 / bundletool 1.18.1 / keytool + jarsigner, Temurin 17):

  | file | package | versionName | versionCode | min/target SDK | debuggable | signer SHA-256 |
  |---|---|---|---|---|---|---|
  | app-release.apk | com.tsorostudios.emberdelve | 0.185.0 | 218 | 24/36 | no | 031acb42…4b7a0d (v2) |
  | app-armeabi-v7a-release.apk | com.tsorostudios.emberdelve | 0.185.0 | 1218 | 24/36 | no | 031acb42…4b7a0d (v2) |
  | app-arm64-v8a-release.apk | com.tsorostudios.emberdelve | 0.185.0 | 2218 | 24/36 | no | 031acb42…4b7a0d (v2) |
  | app-x86_64-release.apk | com.tsorostudios.emberdelve | 0.185.0 | 4218 | 24/36 | no | 031acb42…4b7a0d (v2) |
  | app-release.aab | com.tsorostudios.emberdelve | 0.185.0 | 218 | 24/36 | no | 031acb42…4b7a0d (jar verified) |

  SHA-256:
  ```text
  6651fd41b9dbf7a650e6d6afe2693caa9a1e543d6f75bfc6084f04a80f132f0f  app-release.aab
  06ae6a89e00238c4e379ba55cfb81f7d680aa36ec7aa3bf3f6c843d6e31b33eb  app-release.apk
  1819f4650a267092530ff17fedeef17d3518180edaab6720fc87e1e8e04b3d4e  app-arm64-v8a-release.apk
  6225e5944d4aae9079d2ade171ff3d5d6c7674e178a5c1a94c59eba277e46eaa  app-armeabi-v7a-release.apk
  87cbe33caa72e99d257d9a8bd9ff20f68a7ef458e9d406a6ce6233282ab78176  app-x86_64-release.apk
  ```
- VERIFIED audit re-run before publishing: parent of c08a0d5 = 7d61e26;
  `git diff --name-only 84f973f c08a0d5 -- lib/sim lib/meta lib/main.dart
  android .github assets` empty; controller.dart hunks = song-credit and
  tour gates only (no purchase/entitlement line); test numstat 14 files
  +2253 −0; no release among 223 mentions 0.185 or code 218; latest before
  publish = v0.184.0.
- SHIPPED GitHub release id 397540423, published 2026-09-27T06:47:38Z:
  https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.185.0
  (prerelease=false). VERIFIED readback: `/releases/latest` = v0.185.0; tag
  ref v0.185.0 → c08a0d5; all 6 assets (5 binaries + emberdelve-SHA256SUMS)
  re-downloaded, SHA-256 match.
- Open: REL185-PLAY (Play production upload of AAB 218) and REL185-ITCH
  need an authenticated browser session; not attempted this iteration.
