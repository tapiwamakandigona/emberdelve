# PROJECT.md — September 19 production release

Adapted from the freshly cloned canonical subagent-toolkit v3.0.1 template.

## Goal

Package the already-merged September 18 visual improvements as
0.184.0+211, verify source/render/regression and signed artifacts, submit the
authorized Google Play production update, and refresh the Emberdelve itch.io
page/download if access permits. Distinguish submission, review, and live
availability. Do not claim "best visuals" or close physical-device/purchase
gates from headless evidence.

## Session-start ritual

1. Read this file, `features.json`, and the tail of `progress.md`.
2. Run `flutter analyze && flutter test` on pinned Flutter 3.44.9.
3. Pick the single most important unfinished feature; work only on that.

## Standing decisions

- VERIFIED user mandate explicitly authorizes this production release and
  itch.io update. Do not publish unrelated audience/social/email messages.
- VERIFIED shipping source: legacy/dice-builder at 741b439; main is frozen.
  PR104/105/106 are already merged, not work to implement again.
  PR102 is an open historical critique; leave it open.
- VERIFIED Play currently serves 0.183.0 (210), full production rollout,
  177/177 countries. No unpublished changes at initial authenticated read.
- The next unused code is 211; retain the permanent package/upload key,
  entitlements, saves, all sealed simulation, dependencies and existing tests.
- Use existing integrated visuals, not unreviewed replacement art.
  Existing brand values and actual-render evidence govern store copy/assets.
- User-supplied credentials remain outside every repository, dir0700/file0600.
  Managed Git is mandatory. No secret values in evidence or public output.
- Original root feature objects and full progress prefix must be preserved.
  Physical-phone touch/FPS and real Play purchase/restore remain open.
  The inherited keystone-unaware supplemental UI harness is not green and
  must not be weakened or described as a product softlock.

## Constraints

- Single executor, no subagents. Eight substantive task iterations maximum:
  1 audit/plan; 2 local regression+visual review; 3 version/docs package;
  4 signed CI build/artifact verification; 5 Play submission; 6 itch package
  and authorized update if possible; 7 final evidence/handoff; 8 one reserve.
- One corrected retry after quoting each failure, then descope/escalate.
  Two consecutive no-diff iterations halt. Do not spend money or buy assets.
- Browser sessions are named six-hour sessions. Respect platform challenges.
- itch login currently stops at Cloudflare verification after the one
  permitted proxy fallback. No password tested; no reset or bypass authorized.

## Current phase

Release — iterations1–2 complete. Original analyzer/full suite/art/SFX passed;
unchanged whole-roster render retry passed72/72 in18minutes. All4608 PNGs
decoded/hashed,12540 observations and source identities reviewed. This is
mechanical/source verification, not direct aesthetic or physical-device QA.
Portable official Android signature/manifest tools are installed and their
archive hashes verified; no system/root changes. Iteration3 version/news/docs
complete:0.184.0+211 passes the original analyzer,1526tests,art and SFX again.
The broad582-file baseline now has exactly two reviewed planned exceptions
(version and news); all580 other files match. Iteration4 signed CI and
independent binary verification next; no store edit yet.
