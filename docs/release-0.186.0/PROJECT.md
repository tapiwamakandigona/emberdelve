# PROJECT.md — 0.186.0 "Clear Choices" release

Adapted from the canonical subagent-toolkit v3.2.0 template (`templates/PROJECT.md`).

## Goal

Ship the October 2026 quality pass as the stable release **0.186.0+219**.
The source is the `legacy/dice-builder` lane: v0.185.0 (`c08a0d5`), plus
PRs #112–#125, plus one packaging commit. Version and in-game news move
together. CI's analyzer, full test suite and SFX headroom check pass on the
exact release commit. The signed APKs and AAB come from CI
`workflow_dispatch`, and their signer matches the pinned upload certificate.
GitHub `v0.186.0` is published as the latest (non-pre) release. Its asset
hashes are checked after an unauthenticated download.

The Play release is a separate feature. It uses the Play Developer API
through the publishing service account (see `PLAN.md` §5). It ships AAB 219
to internal, closed (alpha) and production at 100 % in one edit, with en-GB
and de-DE notes.

## Session-start ritual

1. Read `PLAN.md`, `DEMAND.md`, this file, `features.json`, and the tail of
   `progress.md`.
2. Baseline = CI on the lane head (`flutter analyze`, `flutter test`,
   `python3 tool/sfx_headroom.py`, iOS build) on pinned Flutter 3.44.9.
3. Pick the single most important unfinished feature and work only on that.

## Standing decisions

- The owner authorised merging reviewed PRs and cutting GitHub releases
  (2026-10-03 01:38 UTC). He authorised Play production at 100 % rollout
  (2026-10-03 02:12 UTC). There are no store-listing, pricing or in-app
  product edits in this pass. (2026-10-03)
- Version **0.186.0+219**. It is above v0.185.0's code 218, the highest code
  on any track (`PLAN.md` §5). Future builds use a name above 0.186.0 and a
  code above 219. (2026-10-03)
- The release commit is the lane head after the packaging PR merges. The tag
  `v0.186.0` points at exactly the commit CI built. (2026-10-03)
- Signed binaries come only from CI `workflow_dispatch` with the permanent
  upload key. The certificate's SHA-256 is
  `031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`. Never
  regenerate the key and never touch `EXPECTED_CERT_SHA256`. (2026-10-03)
- German is store-listing data only (`store-de-DE.json`). The game is not
  translated into German, and no note claims it is. (2026-10-03)

## Constraints

- One writer, plus one read-only reviewer. No spending and no force-push.
- Never weaken or edit tests or checks. On failure, retry once with the
  failure quoted, then descope or escalate. Two iterations without a diff
  halt the loop.
- The Play upload needs the publishing service-account key, which lives
  outside every repo. Never commit, log or quote it.
- Headless evidence does not close physical-phone FPS, touch feel, audio as
  heard, or a real Play purchase or restore. Those stay unverified.

## Current phase

release — packaging, then the signed build, the GitHub publication and the
Play edit.
