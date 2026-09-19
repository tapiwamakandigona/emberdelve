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
- VERIFIED Play initially served 0.183.0 (210), full production rollout,
  177/177 countries. No unpublished changes at initial authenticated read.
  Final September19 14:34UTC readback still shows210 available and211 In review.
- Code211 was verified unused, then consumed by this release; do not reuse it.
  Retain the permanent package/upload key,
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

Release — iterations1–6 complete as tasks, with itch publication blocked.
Original analyzer/full suite/art/SFX passed;
unchanged whole-roster render retry passed72/72 in18minutes. All4608 PNGs
decoded/hashed,12540 observations and source identities reviewed. This is
mechanical/source verification, not direct aesthetic or physical-device QA.
Portable official Android signature/manifest tools are installed and their
archive hashes verified; no system/root changes. Iteration3 version/news/docs
complete:0.184.0+211 passes the original analyzer,1526tests,art and SFX again.
The broad582-file baseline now has exactly two reviewed planned exceptions
(version and news); all580 other files matched at that pre-log checkpoint.
The final required append-only root progress update makes579/582 match;
the third difference is history appended without altering its original prefix.
Iteration4 complete: exact
source84f973f signed by CI35447309873, all5 artifacts independently verified,
GitHub v0.184.0 published with matching hashes. PR107 remains open; no merge.
Iteration5 complete: exact211 AAB uploaded,100% rollout across all177 existing
targeted countries,zero supported-device loss. Final send accepted one
Production211/Start full rollout change at14:24UTC. Primary production
readback14:26UTC marks211 In review;210 remains Available on Google Play.
Publishing overview still shows quick checks before review. Managed
publishing remains off; do not call211 live. Iteration6 complete but blocked:
itch page/devlog/correct disclosure,3 source-matched captures and verified APK
package prepared;8 links verified. Public itch still0.179.0. No further
challenge retry or authenticated itch write. REL-ITCH remains false;
authorised editor access needed,Butler key can unblock binary upload only.
Iteration7: final readback14:34UTC confirms211 In review,210 still live;
the quick-check banner is no longer present. Source/tag remains84f973f.
Final integrity and documentation-only push/handoff preserve all false root
gates and REL-ITCH. Seven of eight planned task iterations used; no reserve
iteration needed unless final verification exposes an issue. This is partial
completion, not an all-passing project or proof of live production211.
