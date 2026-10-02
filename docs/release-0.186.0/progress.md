# 0.186.0 progress (append-only)

## Iteration 1 — regression-first baseline, 2026-10-02
- VERIFIED canonical source535029b and latest published0.185.0/code218.
- VERIFIED original CI36307712574 successful on shipping branch.
- Added scoped criteria and new regression tests; existing test files untouched.
- Local Flutter installation blocked: official manifest and pinned archive404.
  Remote CI will supply actual red/green evidence, not a guessed result.
- Current Play has no unpublished changes before this task.

## Iteration 1 result — actual red baseline
- VERIFIED CI37017234889 on16dd061: analyzer passed; 1596 tests passed,
  9 failed; signed build correctly skipped. The seven new regressions all
  failed on the unchanged production source.
- Exact layout failures include "A RenderFlex overflowed by 120 pixels on
  the right." and "A RenderFlex overflowed by 676 pixels on the bottom."
  at320px/1.0x. Larger text also failed. New copy and edge-to-edge checks
  failed because the requested behavior is not present yet.
- Two ORIGINAL tests also failed, before implementation:
  `shorter_title_test.dart`412x915 expected0 scroll, actual8.0;
  `marked_week_test.dart` expected equals['short_road'] unordered, actualnull.
- The weekly test's next assertion forbids short_road in the same list,
  contradicting its first assertion for this week's Short Road rule.
  No test, clock, weekly rotation, save format or simulation is changed to
  evade this. Release remains blocked unless the original check can be
  corrected explicitly without weakening its intended invariant.

## German listing preparation
- VERIFIED only en-GB existed. Added de-DE text: name28/30, short73/80,
  full2283/4000. Full description explicitly says gameplay is not German.
- Saved, reloaded and compared all three fields exactly. Default English
  copy and inherited real graphics remain unchanged. Play review identifies
  the graphics as fallback-to-default. No new visual asset was uploaded.
- AI declaration dialogue offered only the twelve existing visual assets;
  all were unlabelled on entry and their labels were left unchanged.
- VERIFIED publishing overview contains exactly one unsent item:
  German–de-DE / Add language. Managed publishing is off.
- Browser confirmation wait failed on nonexistent toast/header wording,
  not the writes: primary-source readback showed "Changes ready to send
  for review" and "Change saved. Send for review in Publishing overview."
  No duplicate save or submission was attempted.

## Iteration 2 — presentation fixes, verification pending
- Forge uses safe insets, a wrapping header, scrolling content and an
  explicit not-now control. Free play, permanent purchase and localized
  Play pricing remain separate; billing/entitlement code is unchanged.
- Manual/context spending copy now teaches the existing preview and end
  turn. Updated the canonical translation JSON, regenerated its Dart output,
  and passed the unchanged95-message/three-locale parity check.
- Explicit edge-to-edge startup joins the existing prerequisite futures.
  The manual now respects SafeArea. Existing R8/downsampling is untouched.
- Reduced title outer vertical padding from16px to12px, recovering8px
  without shrinking text or touch targets. The original no-scroll test
  is the acceptance check; its assertion is unchanged.
- VERIFIED archive comparison: all281 original test files byte-identical,
  new regression file byte-identical to the red baseline; no changes in
  simulation, meta/billing, Android build files, CI or assets.
- Flutter analyzer/full-suite verification is pending the next unchanged CI
  run. The contradictory weekly-history assertion remains a release blocker.
