# Build identity v1 — visible power without a sim change (2026-08-12)

## Goal

Make the pool the player assembled visibly feel like *their build*, first in
combat and then in the terminal recap. This is the presentation half of the
competitor-depth plan; face-forging/keystones remain a later, separately
versioned sim change.

## Contract

Derive one stable `RunBuildIdentity` from the current ordered die IDs:

- **Blade** — attack-only / attack-bonus dice dominate.
- **Aegis** — block-only / block-bonus dice dominate.
- **Heart** — on-max/min-value consistency dice dominate.
- **Ember** — balanced or plain pool.

The score is explicit and deterministic. A die contributes:

- attack-only: 3 Blade; `attack_bonus`: its value as Blade;
- block-only: 3 Aegis; `block_bonus`: its value as Aegis;
- `on_max_bonus`: its value as Heart; `min_value`: 1 Heart;
- no modifiers: 1 Ember;
- ties resolve Ember → Blade → Aegis → Heart, so the same ordered pool always
  produces the same identity with no RNG or persisted state.

Names are a dominant-trait recap, not an exhaustive build classifier: for
example, `Emberbound` means no specialist axis outscored the mixed/plain pool.

Also expose:

- dominant die size and tier;
- counts by d4/d6/d8/d10/d12;
- special-die count;
- compact label and one honest build description.

## Presentation

1. `WeaponView` receives the identity and evolves its existing procedural
   weapon: build-coloured edge/smear, one extra silhouette element per path,
   and intensity from dominant tier. It still uses one painter and the existing
   animation clock.
2. Summary shows **POOL FORGED THIS RUN** with identity, exact die-count chips
   and special count. This is a recap, not a reward or monetization prompt.
3. The summary panel appears on both wins and losses: the build existed even
   when it failed, and surfacing it makes a death more learnable.

## DoD

- pure identity tests cover all paths, tie stability, unknown IDs, counts and
  order independence;
- every weapon path renders through idle/raise/swing without exceptions;
- terminal summary shows the identity and exact pool counts;
- short-phone overflow suite, screenshot harness, perf probe and full suite
  remain green;
- no `lib/sim/`, save schema, golden, dependency or binary-asset change.
