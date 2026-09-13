# Blood preference — implementation and verification

**13 September 2026 · Base `b8b24a7` · Version unchanged: 0.183.0+210**

This PR is for an **open next-agent handoff**, not another release.
The [art/animation/depth critique](combat-art-depth-critique-2026-09-13.md)
is deliberately separate from implementation correctness.

## Behaviour

- **Settings → COMBAT VISUALS → Blood effects**, default **on** for
  backwards-compatible presentation. Off is saved through the existing
  queued/atomic, best-effort SettingsStore.
- Persisted choice is applied **before the first frame** in `main()`,
  including a resumed injured run. Missing/invalid new values default on
  without discarding other valid preferences.
- Off suppresses future blood/ichor bursts, removes active bursts and
  existing floor stains, and hides wound marks on **hero and foe**.
  Delayed stain callbacks cannot add stains while disabled; re-enabling
  does not revive cancelled effects or old stains. Future hits can bleed.
- Damage, block, hit flashes, non-bloody contact effects, numbers,
  posture/pallor/breathing/fatigue remain. Reduced motion still follows its
  separate setting. No simulation, seed, balance or entitlement change.
- Native switch with labelled/toggled semantics and a ≥48px touch target.
  English/French/Spanish/Brazilian Portuguese label, helper and section.
  Complete new panel checked at 320px / 1.3× text with real fonts.
- **Not age-rating relief.** Blood remains available. The existing Play
  content declaration/submission is unchanged. Declare accessible content
  accurately; see [Google's content-rating policy](https://support.google.com/googleplay/android-developer/answer/9898843?hl=en).

## Verified local checks

Flutter 3.44.9 / Dart 3.12.2. Full output excerpts and failure records:
[verification.txt](blood-toggle-2026-09-13/verification.txt).

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | **PASS**, no issues |
| `flutter test --no-pub --reporter expanded` | **PASS, 1,387 tests**: 1,369 baseline + 18 new |
| `test/blood_effects_test.dart` after restoring negative controls | **PASS, 18/18** |
| `tool/l10n/build_catalog.py --check` | **PASS**, 95 source messages × 3 translations, key/placeholder parity |
| `tool/sfx_headroom.py` | **PASS**, every reachable cascade below ceiling; full-attack scenario still **TIGHT at −0.90 dBTP**, not new audio work |
| Unchanged `tool/combat_idle_probe_test.dart` | **120 paints / 120 frames = 1.0/frame**; a limited headless census, not device FPS |
| New `tool/art_depth_review_test.dart` | **PASS, 9/9**, four encounters + roster + four locales, actual rendered evidence |
| New `tool/depth_review_probe.dart` | **600/600 terminal runs**, zero invalid commands; per-seed hashes retained |
| Original-file preservation | Existing tests, simulation, shipped assets, dependencies, workflows and version unchanged |

### New regression coverage

The 18 tests cover migration and round-trip values; actual temporary-file
save/load; notifier behaviour; four locale/semantics/touch layouts;
blood-off attacks in full/reduced motion; live burst cancellation;
stain clearing/re-enable; both bodies' retained condition and unchanged
simulation state; raw-RGBA wound suppression/restoration for all four
ichor palettes; and bloodless incoming damage.

**Negative controls (expected failures):**

1. Temporarily remove only `_spawnBlood()`'s disabled-preference guard.
   The unchanged new combat regression fails:
   `Expected: no matching candidates` / `Found 1 widget with type "BloodBurst"`.
2. Temporarily paint `cond.wounds` regardless of `showWounds`.
   The unchanged raw-RGBA regression fails its clean-pixel equality assertion.
3. Restore exact production bytes, verified by SHA-256, then rerun:
   **all 18 green**. Tests were never altered for these controls.

## Known failures — not hidden by the green main suite

Two **existing supplemental tools** fail against the unchanged base and
are outside the normal `flutter test` directory. They remain unchanged:

| Tool | Reproduced result | Confirmed cause / boundary |
|---|---|---|
| `python3 tool/art/build_delvers.py --check` | `AssertionError: metadata differs` | Image-pixel comparisons precede the failure. Generated metadata omits each of the 22 new hand sockets. Do not “fix” by deleting socket data or the assertion. |
| `flutter test tool/play_session_test.dart` | Illegal `player_turn → keystone`, then stuck at keystone; same result on retry | Tool's transition graph and tap dispatcher omit the intentional keystone phase. Zero complete UI runs verified; not proof of a product softlock. |

The next-agent tasks and acceptance checks are in the critique.
**Do not describe all project checks or all features as passing.**
The existing device-playthrough and Play purchase/restore gates remain open.

## Failure trail during this PR

Failures were investigated, not erased:

- First new fixture leaked a `SemanticsHandle` until the framework's
  end-of-test validation. Corrected disposal with `try/finally`; no
  semantic assertions removed.
- Initial insertion in COMFORT displaced the existing UPDATES block
  beyond a lazy list's built region. Original update-service test failed
  (`Found 0 widgets with text "UPDATES"`); it passed on clean base.
  A compact-row retry did not solve it. Moved the new control after UPDATES
  into COMBAT VISUALS, preserving the established blocks and original test.
- Semantic label merging was corrected with a separate semantic container;
  no label/toggled/touch requirement weakened.
- Initial new capture probe assumed one WeaponView during hit-flash.
  `Bad state: Too many elements` exposed AnimatedSwitcher's outgoing and
  incoming children. Probe now records the list and requires it nonempty.
- The new research scripts initially had analyzer warnings (test-only
  reset and relative imports). Switched to public Motion update and
  package imports; analyzer then passed.
- Initial Settings captures aligned the centre switch at the viewport
  edge, cropping the panel label. Reframed the **whole panel** with
  additional containment assertions, without changing app layout to fake
  a screenshot. Final real-font plates pass.
- The original baseline frame tool first hit a short process timeout;
  one retry with adequate execution time passed four captures.
- Supplemental art-generator and old UI-playthrough failures above remain
  open, explicitly reproduced on base. No original check was weakened.

## Release boundary

No version bump, signed build dispatch, GitHub release/tag, merge,
Play submission or content-rating change belongs to this PR.
The separately submitted 0.183.0 production release was last verified
**in review**, not live; that status is not rechecked by this toggle task.
Do not infer store availability from the open PR or passing unit tests.
