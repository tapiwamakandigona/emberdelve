# PROJECT.md — 0.185.0 "Living Foes" release

Adapted from the canonical subagent-toolkit v3.0.1 template (`templates/PROJECT.md`).

## Goal

Ship the experimental polish-loop work as the stable release **0.185.0+218**.
Source is experimental builds 1–6 (PR #109 head `7d61e26`). That head already
includes #107's 0.184.0 packaging and #108's living foes. Version and in-game
news move together. CI's analyzer, full test suite and SFX headroom check pass
on the exact release commit. The signed APKs and AAB are verified
independently after download. GitHub `v0.185.0` is published as the latest
(non-pre) release, and its asset hashes are checked after download. Store
steps (Play production, itch.io) are separate features. Each one needs an
authenticated browser session.

## Session-start ritual

1. Read this file, `features.json`, and the tail of `progress.md`.
2. Baseline = CI run on the release commit (`flutter analyze`, `flutter test`,
   `python3 tool/sfx_headroom.py`) on pinned Flutter 3.44.9.
3. Pick the single most important unfinished feature; work only on that.

## Standing decisions

- The owner authorised a release on 2026-09-27 ("go ahead and make a
  release"). That is the "order otherwise" that ends the experimental-only
  status in `docs/experimental/PROJECT.md`. (2026-09-27)
- Release source = `experimental/polish-loop` @ `7d61e26` plus one packaging
  commit that changes only the version, in-game news and docs. This pass
  changes no gameplay, art, audio, simulation, purchase, dependency, workflow
  or signing code. (2026-09-27)
- Version **0.185.0+218**. It sits above every experimental versionCode
  (212–217) and above Play production 211. One 0.185.0 entry replaces the
  experimental news entries 0.184.101–0.184.106, as
  `docs/experimental/PROJECT.md` decision 2 asks. **Any future experimental
  build must use a version name above 0.185.0 and a code above 218.**
  (2026-09-27)
- Branch `release/0.185.0`. Its PR into `legacy/dice-builder` stays open
  (repo rule: never merge PRs). #102, #107, #108 and #109 stay open and
  untouched. (2026-09-27)
- Signed binaries come only from CI `workflow_dispatch` with the permanent
  upload key. After download, cert SHA-256 `031acb42…4b7a0d` is checked with
  official `apksigner`/`bundletool`. (2026-09-27)

## Constraints

- Single executor. No spending, no force-push, no merge.
- Never weaken or edit tests/checks. One retry per failure with the failure
  quoted, then descope or escalate. Two no-diff iterations halt.
- Six iterations: 1 audit + packaging; 2 CI checks + signed build;
  3 artifact verification; 4 GitHub publish + readback; 5 Play production
  submission (login-gated); 6 itch update (login-gated).
- Headless evidence does not close physical-phone FPS/touch/audio, owner
  aesthetic approval or real Play purchase/restore. Those stay unverified.

## Current phase

release — iteration 1 (audit + packaging).
