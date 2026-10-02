# Clear Choices candidate — verification, 2026-10-02

## Status: BLOCKED, not released

Runtime source: `f3ce6d7a728cb3debff22653a7a9ed5fc5618048`.
Branch: `release/0.186.0`, based on shipping `legacy/dice-builder` at
`535029bcfc24bcd6bf75a33379dd9f1365485ca9`.
[Draft PR111](https://github.com/tapiwamakandigona/emberdelve/pull/111).

The planned version is0.186.0+219. Version/news have **not** been changed;
no new tag, release binary or Play production release has been created.
Live production remains218/0.185.0. No PR has been merged.

## Actual checks

| Check | Evidence |
|---|---|
| Red baseline | [CI37017234889](https://github.com/tapiwamakandigona/emberdelve/actions/runs/37017234889),16dd061: analyzer clean;1596passed/9failed. All seven added regressions fail on original production code. |
| Candidate analyzer | [CI37018504673](https://github.com/tapiwamakandigona/emberdelve/actions/runs/37018504673),f3ce6d7: “No issues found!” |
| Candidate full tests |1604passed/1failed. All seven new clarity tests pass, as do all three original title-layout tests. The sole remaining failure is the inherited weekly-history test below. |
| Check integrity | All281 original test files are byte-identical to the shipping archive. The added regression file is byte-identical to its red-baseline commit. |
| Catalog generation | Unchanged generator and `--check`:95messages ×3locales, matching keys/placeholders. Source JSON changed; generated Dart was not hand-patched. |
| SFX | Original local `sfx_headroom.py`: every reachable cascade clears0dBTP. `full_attack_turn` remains TIGHT at−0.90dBTP; no audio edits. CI's SFX step was skipped after the test failure. |
| Art | Original local `build_delvers.py --check`: pass,22models. No art edits or aesthetic/device approval. |
| Protected source | Simulation, meta/billing/entitlements, Android build files, CI, assets and dependencies unchanged. |
| Signed build | Correctly skipped by unchanged CI after the failing test. No unsigned/debug substitute delivered. |

## Remaining gate: contradictory original weekly test

`test/marked_week_test.dart` compares saved `mutators` with all of
`rule.mutators`, then immediately requires `short_road` not to occur in the
same list. On2026-10-02 the current rule is Short Road, so those assertions
cannot both hold. Exact failure:

```text
Expected: equals ['short_road'] unordered
  Actual: <null>
```

Production deliberately represents this format as `short: true`, not as a
non-encodable modifier. `GameController._moddedMutators` excludes
`short_road`; `_runRecord` omits the `mutators` key when that filtered list
is empty. This matches the test's own header and separate `short` assertion.

No clock, weekly rotation, simulation, save format or test has been changed
to evade the failure. Under the owner's no-test-edits rule, a narrow
correction needs explicit authorization. The intended correction is to
compare the exact non-`short_road` modifier set, explicitly require an absent
key when that set is empty, retain the separate short-format assertion, and
exercise fixed Short Road and composed-short weeks rather than rely only
on the wall clock. This is a proposal, not an applied patch.

## Independent read-only review

The authorized ultra-tier evaluator returned **source PASS / release NO**.
It independently read the candidate CI log and source and confirmed the
weekly-test contradiction is not a game bug. `evaluation.json` preserves
the result and non-blocking caveats. Its minimal correction keeps the
existing clock/rotation and separate short assertion; a fixed-date sweep
of all eight rotation weeks is optional additional coverage.

## German storefront

The actual `de-DE` fields match `store-de-DE.json` after reload:
name28/30, short73/80, full2283/4000. It plainly says the game is not in
German. English text and all inherited default-language visuals are
preserved; there were no new image/video uploads.

The sole `German–de-DE / Add language` change was sent for review.
Reloaded Publishing overview says **Changes in review**; managed publishing
is off. This is a store-metadata submission, **not** production version219
or proof the German listing is already public.

## Limits

The new regression rendering is headless. Actual phone/system-bar appearance,
device FPS, Play license-tester purchase/restore and human aesthetic approval
remain unverified. Existing root gates M1-3, M4-2 and
NEXT-UI-PLAYTHROUGH-20260913 remain untouched. R8 and background downsampling
were already present; no claim that they were newly added or that Play's
recommendation cards have disappeared.
