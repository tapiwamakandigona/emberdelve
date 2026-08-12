# Emberdelve next mechanics — face forge + keystones (working design)

## Competitive gap

- Die in the Dungeon lets players set individual faces and reallocate face-value
  points; its spatial board and 142 relics create build expression.
- Slice & Dice scales variety through face-changing items, 128 classes and 473+
  items while keeping every turn inspectable and undoable.
- Astrea gets run identity from typed dice plus 170+ run-long Blessings,
  including stronger drawback-bearing variants.

Emberdelve should not copy their spatial board, party model or purification
system. Its advantage is a faster portrait arithmetic duel: forge one die in
seconds, then see that choice become a weapon and exact impact.

## Face forge v1

Represent custom faces only when a die has been forged:

```dart
CustomDie {
  baseId: String,
  faces: List<Face>, // length == base die sides, authoring order is stable
}
Face { value: int, rune: FaceRune? }
enum FaceRune { blade, aegis, surge, echo }
```

- Existing string IDs remain legal and decode to their current 1..N faces.
- A rest forge offers **Temper a face**: choose one die, choose one face, add a
  rune. No freeform value redistribution in v1; it is too much phone UI and too
  broad a balance surface.
- Pool entries cannot become map objects without touching almost every existing
  cast to `String`. Keep `player['dice']` as stable IDs: the first tempered die
  becomes a run-local ID (`custom_1`, `custom_2`, ...), with its base/rune data
  in `run['custom_dice']`. One resolver maps either catalog or run-local IDs to
  the same combat descriptor. Rewards, shops and events continue yielding
  catalog IDs; only `temper_face` creates a run-local ID.
- Each die may hold one rune total in v1. This makes the choice readable in the
  tray and limits snapshot growth.
- A rolled face carries `{value, rune}`; assignment resolves the rune through
  the same command/event stream. Preview must call the same pure resolver.

Runes:

1. Blade — when assigned to Attack, +2 damage.
2. Aegis — when assigned to Block, +2 block.
3. Surge — on this face's natural maximum, +1 reroll next turn.
4. Echo — after assignment, the next die assigned to the other verb gets +1.

## Ten transformative keystones

Each run may equip at most three. All triggers emit named events and all
counters are in the snapshot.

1. **Ashen Edge** (Blade): first Attack assignment each turn gains the number
   of unassigned dice. Rewards attacking early; visible preview.
2. **Executioner's Measure** (Blade): exact kills permanently add +1 to one
   random Blade-rune face (RNG stream + event names target); caps at +3/run.
3. **Last Coal** (Blade/Heart): when one unassigned die remains, it rolls at
   least half its sides but cannot Block. Converts end-turn texture.
4. **Living Bastion** (Aegis): unused Block carries at 50% (floor, cap 8);
   carried block cannot trigger thorns. Makes defence a plan, not waste.
5. **Counterbrand** (Aegis/Blade): after fully blocking an attack, the first
   Attack die next turn gains the absorbed amount, capped at its sides.
6. **Shelter the Spark** (Aegis/Heart): assigning a natural 1 to Block heals 1
   after combat, maximum 3 per fight. Turns low defensive rolls into recovery.
7. **Crown of Twelve** (Heart): each distinct die size assigned in a turn adds
   +1 to the final assignment; at 4 sizes, also gain 2 embers after victory.
8. **Loaded Furnace** (Heart): the first max roll each turn is locked from
   rerolls but its rune triggers twice. Strong consistency with opportunity cost.
9. **Twin Bellows** (Ember): alternating Attack/Block assignments build a
   +1/+2/+3 combo; repeating a verb resets it. Gives mixed pools real identity.
10. **Debt to the Deep** (risk): start each fight with one temporary d12 Hex
    (faces 8/9/10/11/12 and one self-damage 4); removing it from the pool after
    assignment grants 5 gold. Power with an explicit drawback, Astrea lesson
    without copying its system.

## Determinism/versioning

- Bump SIM_VERSION once, for face runes + initial keystone set together.
- Add an explicit `keystone` RNG stream only if a shipped keystone needs random
  targets; append it to `simStreams` so snapshots are complete. Do not borrow
  `loot` or `combat`, which would perturb map rewards or rolls.
- Snapshot `custom_dice` and `keystones` conditionally; unmodified normal runs
  remain compact. Never key by object identity; custom dice get stable run IDs.
- Dedicated RNG stream/tag for any random target (`keystone_target`) so adding
  visual RNG or unrelated rewards cannot perturb it.
- Migration maps old die strings directly; no mutation of v6 snapshots until a
  v7 command changes them. v6 replay fixtures stay executable under v6 rules.
- Re-anchor golden only after: migration twins, command replay, autoplay balance,
  every trigger event, preview==resolution drift guard, and snapshot JSON roundtrip.

## Smallest coherent first sim release

Ship four face runes + four keystones (Ashen Edge, Living Bastion, Crown of
Twelve, Twin Bellows), one Temper action at rest, one custom die per run.
That gives four genuine build axes and validates UI/save/balance before the
remaining six keystones multiply interactions. Do not gate these mechanics
behind Forge; Forge owners receive HARD/Ascension, while Easy/Normal need the
same expressive core to build audience and conversion ethically.
