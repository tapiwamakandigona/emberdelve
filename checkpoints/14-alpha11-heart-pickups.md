# v1.0.0-alpha.11+23 — Mended Hearts (heart pickups)

## For testers

- New pickup: **hearts**. Touching one heals +1 heart. If you're already at
  full health it stays where it is — come back after taking a hit.
- Placed where the difficulty data said runs were dying with no way to
  recover: two in World 1-5 (the thornling/totem colonnade) and two in
  World 2-4 (the soot-creeper + fire-pit gauntlet).

## Why

- Wipe probe (upgraded casual bot, 4 seeds, 300 s cap, per-hit attribution):
  w2_l4 wiped at 73% on every seed — checkpoints at cols 18/62/108 but the
  cols 62-108 stretch stacks a totem, two fire pits, and two soot creepers
  against 3 hearts with zero mid-run healing, so every life replays the same
  death. w1_l5 wiped at 30-41% for the same structural reason (thornling@36
  + totem@44 duel).
- The game had NO heal item at all — only the heal spell and respawn.

## Implementation

- level_data.dart: SpawnKind.heart (appended after feather — enum order for
  existing kinds unchanged, no serialization risk), legend char 'h'.
- session.dart: SessionEventKind.heartPickup; pickup heals +1 only when
  below max hearts, otherwise the entity is NOT consumed (stays put).
- ember_game.dart: heartPickup -> 'heal' sfx (0.8) + red SparkleFx.
- items_component.dart: _drawHeartPickup — procedural 8x8 heart (same
  bitmask as the HUD hearts), 1.5x scale, bob on _coinClock*2.4, shadow.
- Placements: w1_l5 (37,15) + (50,15); w2_l4 (45,15) + (90,15). All on '.'
  with '#' below; reachability suite covers 'h' targets now.
- New test/heart_pickup_test.dart: 7 tests — parse, heal, stays-put at full
  health, no overheal, event emission, and a design pin that w1_l5 & w2_l4
  each keep >= 1 heart.

## Results

- Probe rerun: **w2_l4 flips from 73% wipe to COMPLETED** (97% progress,
  ~28 s, all 4 seeds). w1_l5 still wipes ~30% — hearts don't fix it because
  the caged thornling@36 duel + totem@44 body-block the ground route flush
  against the 46-48 pillar; that's a level-design fix (widen the cage /
  move the totem) and is the next release's target.
- Suite 385/385 (+7). Analyze clean. Look pass phone+desktop at all four
  heart sites: reads as health instantly (HUD-matching sprite), distinct
  from apples, bob+shadow clean, no tile clipping.

## Probe method (temp tool, deleted)

- test/_wipe_probe_test.dart drove GameSession headless with the alpha.10
  casual bot + hit attribution (which enemy/hazard at which column); rebuild
  it from checkpoints/13 method notes if needed.
