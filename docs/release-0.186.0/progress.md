# progress.md — 0.186.0 release (append-only)

## 2026-10-03 — iteration 1: audit + packaging

- Authority: the October pass plan (`PLAN.md` §1 and §5) and my decisions
  of 2026-10-03. Merging reviewed PRs and cutting GitHub releases is a go
  (01:38 UTC). Play production is authorised at 100 % (02:12 UTC). At
  05:56 UTC: "go ahead with everything".
- VERIFIED GitHub state before packaging (API, 2026-10-03 09:37 UTC):
  - Latest stable is v0.185.0 "Living Foes": tag → `c08a0d5`, prerelease
    false, published 2026-09-27.
  - None of the 224 releases mentions 0.186 or versionCode 219 in its tag,
    name or body.
  - No `v0.186*` tag exists on origin.
- VERIFIED lane head `c90c520` (merge of #125). CI 37113171978 (analyze +
  test) and ios 37113171986 both succeeded on that push.
  - Every PR head from #112 to #125 had analyze+test green before it merged.
  - Every code PR also had iOS green. #120 is docs only and ran
    analyze+test.
  - Checked via the check-runs API per head SHA.
- VERIFIED scope audit with `git diff c08a0d5 c90c520`:
  - `c08a0d5` is an ancestor of the lane.
  - These paths are unchanged: lib/sim, lib/meta (store and entitlement
    code), lib/game, android, ios, .github, assets, pubspec.yaml and
    pubspec.lock.
  - lib changes are 14 files in lib/ui, plus lib/l10n/catalog.dart (one
    tutorial card) and lib/main.dart (edge-to-edge).
  - test/ numstat is 15 files, +2578 −15:
    - 12 new files.
    - test/victory_beat_test.dart gains lines only.
    - test/readout_lanes_test.dart is +149 −13. It moved to the new lane
      API, and review 0187 found no weakened assertion.
    - test/marked_week_test.dart is +8 −2. This corrects its Short Road
      self-contradiction, as authorised at 2026-10-03 01:38 UTC.
  - tool/ has 2 new review harnesses and the l10n source for the tutorial
    card.
- Packaging (this commit):
  - pubspec `0.185.0+218` → `0.186.0+219`.
  - `currentAppVersion` set to 0.186.0.
  - One 0.186.0 "Clear Choices" news entry (4 lines, ending in thanks).
  - New `docs/releases/v0.186.0.md`.
  - New play notes: en-GB at 476 characters and de-DE at 464 characters,
    both under Play's 500.
  - Release state files: this file, `PROJECT.md` and `features.json`.
  - `loop.sh` copied verbatim from the subagent-toolkit v3.2.0 templates.
- VERIFIED locally (Flutter 3.47.6; CI's 3.44.9 is the gate):
  - test/news_test.dart passes 7/7. It covers the version pin, a note for the
    shipping release, newest-first order, 2–4 lines and the §Ethics word
    list.
  - test/news_ui_test.dart passes 3/3. The title-screen panel shows the new
    entry's first line, and the archive lists every entry.
  - `dart format` reports no change to news.dart.
- ASSUMED until CI runs on the release commit: the full suite and the
  analyzer stay green with the packaging diff. It touches no test, check or
  runtime code besides the news data and the version line.
- Next: the packaging PR goes through CI, then the read-only review of #125
  finishes, then the merge. After that comes the signed `workflow_dispatch`
  build on the lane, artifact checks, tag `v0.186.0`, the GitHub release
  and an unauthenticated hash check. The Play edit waits for the publishing
  service-account key (REL186-PLAY).

## 2026-10-03 — iteration 2: review verdict, binaries, GitHub release

- Logged at 2026-10-03 15:05 UTC.
- VERIFIED the independent read-only review of `fa60db2..2a553ad` (#125 C4-01
  and #126 packaging; fresh context, writes only evaluation.json): **PASS**,
  no blocking findings. The two merge trees equal their PR heads
  (73ad583 → c90c520, 41b8695 → 2a553ad). Tests in the range only gain lines,
  and the packaging commit touches no test, tool or workflow file. Minor
  findings, deferred to the next pass (none blocks):
  1. `test/victory_moment_test.dart:253` skips the banner-vs-delver check
     silently when the hero keys are missing. A renamed key would make it
     pass without checking; the lookup should fail loudly.
  2. `lib/ui/victory_beat.dart:138`: `heroEnvelope` was measured on the
     kindler only. Other delvers are not checked on the 320x568 stage.
  3. `docs/releases/v0.186.0.md` points here for the signed-run evidence and
     the per-PR reviews. Both are now recorded (this entry).
  4. `docs/release-0.186.0/loop.sh` is the toolkit template verbatim. It is a
     dev doc and stays out of release bodies and assets.
- VERIFIED REL186-AUDIT and REL186-CHECKS; the command outputs are in
  `features.json`. CI on 2a553ad: analyzer `No issues found!`,
  `1672 tests passed.`, every reachable SFX cascade clears the ceiling
  (full-attack −0.90 dBTP stays TIGHT), iOS green.
- VERIFIED REL186-BINARY. Signed run 37114318037 (`workflow_dispatch` on
  2a553ad, finished 10:05:14 UTC): every step succeeded, and the signer step
  prints the pinned certificate for all four APKs. I downloaded the artifacts
  and checked them independently with Android build-tools 37.0.0
  (`apksigner verify --print-certs`, `aapt2 dump badging`), JDK 21
  `jarsigner -verify` and bundletool 1.18.3 (`dump manifest`):

  | File | versionCode | Bytes | SHA-256 |
  |---|---|---|---|
  | `app-release.apk` | 219 | 75,969,652 | `bc9eb54e838266d43df7c06ab9c39a841c3e1532e0572d44a3560405ae267ec2` |
  | `app-arm64-v8a-release.apk` | 2219 | 38,204,274 | `68569264ad5b0536ed8dffd2ce0f62e51a36fecba6c90b169bbbca900a6f8c4b` |
  | `app-armeabi-v7a-release.apk` | 1219 | 35,846,278 | `826ba3d313505ebaa92c40c663b12a36f4378dc151a5b8a5bb17ef0528190fb0` |
  | `app-x86_64-release.apk` | 4219 | 39,727,630 | `d66887a4e0fb3a542d03aa5c0e68cfa0320beb7bf2f41d68076b1cef5e7dbe16` |
  | `app-release.aab` | 219 | 74,019,333 | `84decb4ed9b14fd66f2a3a87f8c24397df0208526620bf647144d603ec516ebb` |

  Every file is `com.tsorostudios.emberdelve` 0.186.0, minSdk 24,
  targetSdk 36, not debuggable, signed by
  `031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`. The
  APKs verify with signature scheme v2, and the AAB reports `jar verified.`
  jarsigner adds notes on the AAB: the self-signed upload certificate has no
  PKIX chain, which is expected, and there are four "signed in JarFile but is
  not signed in JarInputStream" entry-order notes. The Play-accepted v0.185.0
  AAB shows the same kind of notes (three) under the same JDK, so `-strict`
  is not a usable gate for these bundles.
- VERIFIED REL186-GITHUB. v0.186.0 "Clear Choices" was published at
  14:47:52 UTC as the latest release (not a prerelease), with tag
  `v0.186.0` → `2a553ad7c0cf8c84d59fdad31f8b8482a40c3f9b`. It has six assets:
  the five files above plus `emberdelve-SHA256SUMS`. An unauthenticated
  download of `app-arm64-v8a-release.apk` matched its published SHA-256, and
  the downloaded `emberdelve-SHA256SUMS` is byte-identical to the local copy.
- REL186-PLAY is not done. At 14:33 UTC I put Play work on hold for now. The
  verified AAB 219 is attached to the release for when it resumes. No Play
  call was made.
- Not established: physical-phone FPS and touch, audio as heard, a full
  natural UI playthrough, a real Play purchase or restore.
