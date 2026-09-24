# Exact-Kill "Clean Cut" — evidence (2026-09-24)

Presentation-only feel pass. Requested by the owner (Viktor app, Tapiwa):
"improve the models and animations to be more enjoyable" + a test APK.

## Change

An **exact kill** (a die spent for exactly-lethal damage — the game's signature
tactic) now gets a distinct contact read: a crisp ember-white ring + a four-point
glint over the foe (`CleanCutFlash`, 440 ms), on top of the existing `EXACT!`
call-out. Ordinary kills and overkills are unchanged.

| File | Change |
|---|---|
| `lib/ui/weapons.dart` | new public `CleanCutFlash` widget + `_CleanCutPainter` |
| `lib/ui/screens/combat/fx.dart` | `_FxKind` gains `cleanCut` |
| `lib/ui/screens/combat/stage.dart` | render `cleanCut` → `CleanCutFlash` |
| `lib/ui/screens/combat_screen.dart` | spawn `cleanCut` on the `exact_kill` event (non-blocking) |
| `test/exact_kill_clean_cut_test.dart` | new — 3 cases |

## Verification (all VERIFIED 2026-09-24, local, Flutter 3.44.9 / Dart 3.12.2)

- `flutter analyze` → **No issues found!**
- `flutter test test/exact_kill_clean_cut_test.dart` → **3/3**
  - exact kill shows the clean-cut flourish
  - overkill does **not** (negative control)
  - `CleanCutFlash` renders, reports done, stops painting
- `flutter test` (full) → **1529/1529** (1526 inherited + 3 additive; no
  inherited test weakened)
- `python3 tool/art/build_delvers.py --check` → **pass**
- `python3 tool/sfx_headroom.py` → every reachable cascade clears the ceiling
- `git diff --stat` → four `lib/ui/` files, **zero `lib/sim/` edits** — the
  sealed simulation, its hashes and the contact-timeline contract are unchanged.

## Boundaries (unchanged / not claimed)

Source PR only — no merge, release, version bump, signed store dispatch or Play
action. **Owner aesthetic approval is pending**: install the test APK and land an
exact kill (spend a die for exactly-lethal damage) to see it. Physical-device FPS
and Play purchase/restore gates remain out of scope and open. A 25 fps headless
capture is not device FPS.
