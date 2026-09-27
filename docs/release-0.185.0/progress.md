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
