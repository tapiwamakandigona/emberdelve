# Gauntlet self-prompt — Emberdelve v7 Face Forge

Written in the style of Anthropic's *Prompting Claude Opus 5*: whole
specification up front, no re-check instructions, explicit scope, capped
delegation, evidence artifacts instead of assurances.

## Standing frame (applies to every iteration)

You are the sole executor on `feat/face-forge-v1` in the Emberdelve Classic
repo. Work continuously; do not stop for staged permission. Deliver what the
iteration specifies, at the scope intended. Make routine judgment calls
yourself and only surface a choice when two readings produce materially
different games. If a better approach exists, say so in one sentence and
continue as specified.

Delegate only for large, genuinely independent tracks (wide multi-file
investigation, independent research). One helper if one suffices. Never
delegate a check of your own work.

Communication: one sentence before the first tool call; brief updates only on
important findings or direction changes; final message leads with the outcome.
Documents you write to disk cover the substance without filler.

Hard constraints, unchanged:

- `lib/sim/` stays pure Dart: no Flutter, no `dart:io`, no `dart:math.Random`.
- All randomness flows through the seeded streams in `simStreams`.
- Enemy intent stays visible and resolves exactly as shown.
- One arithmetic source of truth: `resolveAssignment` powers both combat
  resolution and the UI preview. A second copy of the formula is a defect.
- Goldens and tests are not editable to reach green. Re-anchoring a golden is
  its own deliberate task with recorded old → new evidence.

## Iteration 05 — Surge and Echo runes

Ship the two remaining v7 runes end to end in the sealed sim, per
`docs/v7-face-forge-contract.md`.

**Surge** — when a tempered die's natural face comes up on a roll, the player
gains `+1 rerolls_left`. Once per die per turn: a charge reroll or a risky
reroll that lands the face again in the same turn does not pay a second time.
Emit `reroll_gained {die, amount, source:"surge_rune"}`.

**Echo** — when a tempered die's natural face is assigned, the *next*
assignment to the opposite verb gains `+1`. Arm with
`echo_armed {die, other_action}`; spend with `echo_spent {die, action, amount}`.
It never stacks past one pending charge, never survives the turn, and the
arming assignment cannot spend its own charge.

Requirements:

- The Echo bonus lands in `resolveAssignment` so the on-screen preview and the
  emitted `die_assigned.value` are the same number, at the contract's
  arithmetic position (after rune, before nothing else exists yet).
- All new per-turn state resets at `combatBegin` and at turn rollover, and
  rides the existing snapshot untouched by special-casing.
- Every new event is a flat map of scalars.

Evidence to produce, in the final message:

- `flutter analyze` result.
- `flutter test` counts for `test/face_forge_sim_test.dart`,
  `test/sim_test.dart`, `test/feel_pregate_test.dart`.
- The `goldenV6` value after the change.
- The commit SHA pushed to `origin/feat/face-forge-v1`.

Out of scope this iteration: keystones, rest-node UI, combat rune visuals,
balance re-anchoring, any Play upload.
