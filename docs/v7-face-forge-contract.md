# v7 simulation contract — face tempering + first keystones

Status: **design gate; implementation must not begin until this contract's
invariants and tests are explicit.**

## Scope

One coherent mechanics release:

1. At a rest node, **Temper a face** adds one rune to one die.
2. Four run-defining keystones: Ashen Edge, Living Bastion, Crown of Twelve,
   Twin Bellows.
3. All outcomes remain shown before assignment and replay deterministically.

No full face-value editor, second combat board, runtime physics, consumables,
ads, or Forge-only gameplay mechanics.

## Data model

`player['dice']` remains `List<String>` so all existing pool/UI/content seams
stay typed the same. Catalog IDs keep existing behavior. Tempering replaces
the selected catalog ID with a stable run-local ID:

```text
run.custom_dice = {
  "custom_1": {
    "base": "d8_blade",
    "face": 8,
    "rune": "blade"
  }
}
run.next_custom_die = 2
```

If a custom die is later size-forged, the new custom entry preserves its rune
only when `face <= new sides`; its base changes to the selected catalog target.
Run-local IDs never enter content catalogs, rewards, shops, events or meta
state. A single pure resolver returns base `DieDef` + optional tempered face.

### Rune vocabulary

| Rune | Trigger | Exact effect |
|---|---|---|
| Blade | its natural tempered face assigned to Attack | +2 assignment value |
| Aegis | its natural tempered face assigned to Block | +2 assignment value |
| Surge | its natural tempered face rolled | +1 `rerolls_left`, once per die per turn |
| Echo | its natural tempered face assigned | next assignment to the other verb gets +1 |

“Natural face” means the pre-floor RNG result. `min_value`, relic floors and a
risky-reroll penalty do not fake a rune match. `rolled_face` is stored beside
the resolved `rolled` value so previews and restores know the trigger.

One die may have one tempered face/rune. One run may temper at most one die in
v7; the cap is explicit in `run['tempers_used']`.

## Commands/events

### `temper_face`

```text
{ type:"temper_face", die:1, face:6, rune:"blade" }
```

Valid only in `rest`; one use per run; selected entry resolves to a catalog or
custom die; face is `1..sides`; rune is in the four-value vocabulary.

Events:

```text
{ type:"face_tempered", die:1, custom:"custom_1",
  base:"d6", face:6, rune:"blade" }
```

Invalid commands emit existing `invalid_command` with one of:
`not_rest_phase`, `no_such_die`, `temper_used`, `no_such_face`,
`unknown_rune`.

### Combat events

- `rune_triggered { die, rune, face }` — emitted on the roll for Surge, on the
  assignment for Blade/Aegis/Echo.
- `rune_bonus { die, action, amount }`
- `echo_armed { die, other_action }`
- `echo_spent { die, on_die, action, amount }` — `die` armed the charge,
  `on_die` is the assignment it paid. Shipped with both so the UI never has to
  guess which die the +1 belongs to.
- `reroll_gained { die, amount, source:"surge_rune" }`

`die_assigned.value` remains the final exact contribution shown by preview.

## First four keystones

Keystones are string IDs in `run['keystones']`, maximum three. v7 acquisition
is deliberately simple: a deterministic 1-of-3 pick after boss-layer rewards
is deferred; the first implementation exposes a start command seam and test
fixtures, then one production acquisition point must be chosen before ship.
No dead feature may be called complete.

1. `ashen_edge`: first Attack assignment each turn gains the count of
   unassigned dice immediately before assignment.
2. `living_bastion`: after enemy resolution, half unused Block carries to the
   next turn, floored and capped at 8. Carried block never re-triggers thorns.
3. `crown_of_twelve`: assignment N gains the count of distinct die sizes among
   assignments 1..N this turn minus 1 (0/1/2/3...); this is visible in preview.
4. `twin_bellows`: alternating Attack/Block assignments gain +1, +2, then +3
   (cap); repeating a verb resets the next bonus to 0.

Named events: `keystone_triggered {keystone, amount, die?}`. Counters live in
player turn state and reset explicitly at encounter/turn boundaries.

## Versioning and migration

- `simVersion` becomes 7.
- `Sim.restore` accepts v7 only, preserving the current clean stale-save rule.
  **Controller behavior for a v6 autosave must be tested:** archive/discard with
  an honest restart notice; never crash-loop.
- Add no RNG stream for these four deterministic keystones. If a later
  keystone needs random targeting, add a dedicated `keystone` stream in that
  later sim version.
- `state()` must expose enough custom-die data for UI rendering without UI
  reading mutable sim internals directly.
- `stateHash()` and snapshot include all custom data and turn counters.
- Normal runs necessarily get a new event/state golden because the versioned
  player/run shape changes. Re-anchoring requires recorded old/new evidence,
  not editing the expected integer until green.

## Required tests before UI

1. Each rune: match/non-match, wrong verb, natural-vs-resolved face, risky and
   charged rerolls, preview equals `die_assigned`.
2. Temper validation, cap, custom-ID monotonicity, size-forge preservation.
3. Snapshot → JSON → restore twin after temper and after every armed/counter
   state; identical future events/hash/state.
4. Each keystone trigger, reset, cap, combined ordering with runes/combos/relics.
5. Two controllers, same seed + commands = identical custom IDs/events/hashes.
6. v6 autosave controller migration behavior.
7. Autoplay termination and win-rate bands for Easy/Normal/Hard over at least
   500 seeds each, with and without each keystone.
8. Existing boss-per-seed fixtures, mutators and progression tests.

## Implementation order (small commits)

1. **Shared assignment resolver first.** Move the current formula out of both
   `combatAssign` and UI `assignPreview` into a pure sim-side descriptor/result
   API that accepts public maps. Pin it against all existing v6 seeded
   assignments before adding one modifier. This removes the current
   presentation twin rather than tripling drift risk.
2. Add run-local die resolver + temper command + snapshot/hash tests, with no
   combat effect yet.
3. Add and test one rune at a time in Blade → Aegis → Surge → Echo order.
4. Add one keystone at a time behind explicit start/test seams.
5. Build rest/combat/reward UI only after the command/event core and restore
   twins are green.
6. Re-anchor and balance once, at the end, with a recorded old-v6/new-v7 hash
   table and command corpus.

## Arithmetic order

Assignment final value:

```text
resolved roll
+ catalog die modifier
+ on-max modifier
+ combo bonus
+ relic flat / elite bonus
+ matching face-rune bonus
+ keystone bonus
+ pending Echo bonus
```

The shared pure resolver must power both UI preview and combat resolution.
Duplicating this formula is forbidden.
