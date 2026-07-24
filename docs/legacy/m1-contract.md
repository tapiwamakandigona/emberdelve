# Emberdelve — M1 Interface Contract (FROZEN 2026-07-23)

Extends `docs/architecture.md` §2 for milestone M1. Workers implement against this
verbatim. Changing anything here = orchestrator decision + SIM_VERSION bump.
SIM_VERSION becomes **2** in M1 (snapshot shape changes).

## 1. Layer seam inside sim/

```
sim/init.lua    dispatch + hashing + persistence      (owner: run-worker)
sim/run.lua     run layer: map position, node entry,  (owner: run-worker)
                rewards, rest, run win/loss ledger
sim/combat.lua  encounter layer ONLY                  (owner: content-worker)
sim/map.lua     pure map generation                   (owner: map-worker)
sim/rng.lua     FROZEN — do not edit
data/*.lua      content as data, zero logic           (owner: content-worker)
```

**Seam rule:** `sim/combat.lua` never requires `sim/run.lua` or `sim/map.lua`,
never generates rewards/loot, never sets run-level phases. When an encounter
ends it pushes its event and sets `sim.combat_over = "won"|"lost"` (nil while
fighting). After every dispatched command, `sim/init.lua` calls
`run.post(sim, events)` which reads `sim.combat_over`, clears it, and performs
run-level transitions (rewards, defeat ledger, next node, run victory).

## 2. Command set (v2, complete)

| type | fields | valid phase | effect |
|---|---|---|---|
| `start_run` | — | `idle` | generate map (map stream), position at start node, phase→`map` |
| `choose_node` | `node` (id) | `map` | must be an edge from current node; enters node by kind |
| `roll` | — | `player_turn` | roll all dice (combat stream), once per turn |
| `assign` | `die` (index), `action` (string) | `player_turn` | apply die per its data spec |
| `end_turn` | — | `player_turn` | enemy resolves SHOWN intent exactly; next turn or combat over |
| `choose_reward` | `index` (1..#offers or 0=skip) | `reward` | add offered die to pool (0 skips), phase→`map` |
| `rest` | — | `rest` | heal 30% max_hp (floor), phase→`map` |

Invalid command in any phase ⇒ single `{type="invalid_command", reason=...}`
event, state untouched (M0 behavior preserved).

## 3. Phases (sim.phase)

`idle → map → (player_turn | reward | rest) → ... → run_won | run_lost`

- Entering a `fight`/`elite`/`boss` node auto-starts the encounter (no
  `start_encounter` command anymore — it is removed from the public set).
- `reward` phase only after won `fight`/`elite` encounters. Boss victory goes
  straight to `run_won`.
- `run_won` / `run_lost` are terminal; only a fresh `Sim.new` starts over.

## 4. Events (all flat tables, scalar fields only)

Existing (keep shapes): `intent_shown`, `dice_rolled` (`count`,`d1..dN`),
`die_assigned` (`die`,`action`,`value`), `damage_dealt`, `block_gained`,
`enemy_attacked`, `turn_started`, `encounter_won` (`turns`), `encounter_lost`
(`turns`), `invalid_command` (`reason`).

New in M1:
- `run_started {seed, nodes, layers}`
- `node_entered {node, kind, layer}`
- `encounter_started {enemy, enemy_hp, turn, elite(boolean)}`
- `reward_offered {o1, o2, o3}` — die ids (strings); o3 may be absent for 2 offers
- `reward_chosen {die}` / `reward_skipped {}`
- `rested {healed, hp}`
- `boss_defeated {turns}`
- `run_won {embers, fights_won, turns_total}`
- `run_lost {embers, fights_won, layer}` — death ledger (fair-death pillar)

Embers: total per run computed in run layer from the `loot` stream
(range 8–20 per won fight, half for a lost run's ledger, +40 boss bonus).

## 5. State view (sim:state()) — additive

```lua
{
  turn=..., phase=..., player=..., enemy=...,        -- as M0
  map = {           -- present after start_run
    layers=N, start=id, boss=id,
    nodes = { [id]={id=,layer=,kind=,x=} },          -- kind: start|fight|elite|rest|boss
    edges = { [id]={id1,id2,...} },                  -- forward edges only
    position = id, visited = {id1,id2,...},
  },
  offers = {id1,id2[,id3]} | nil,                    -- when phase=="reward"
  run = { embers=N, fights_won=N },
}
```

`player.dice` becomes an array of die ids (strings) resolving into
`data/dice.lua`; `player.hp/max_hp/block/rolled/assigned` unchanged in shape.
`rolled` stays an array of numbers (face values after die mods).

## 6. sim/map.lua signature (map-worker)

```lua
local Map = require "sim.map"
local map = Map.generate(rng, cfg)   -- rng = the sim's map stream; cfg optional
```

- Pure function: same rng state + cfg ⇒ identical map. No globals, no other
  streams, no os/io/math.random. Numeric node ids, deterministic ordering
  (never rely on pairs() order for anything that consumes randomness).
- Default cfg: 9 layers. Layer 1 = single `start` node; layer 9 = single
  `boss` node; layers 2–8 have 2–4 nodes. Kinds on middle layers:
  fight-dominant with sprinkled `elite` (≥1, from layer 4+) and `rest`
  (≥1, layer 6+ guaranteed before boss); never two `rest` adjacent in a path.
- Every node has ≥1 forward edge; every node reachable from start; boss
  reachable from every node (no dead ends). Edges never cross more than one
  layer.

## 7. data/ schema (content-worker; no logic in data files)

`data/dice.lua` → `{ [id] = {id, name, size, mods={...}} }` — exactly the
mod vocabulary below; combat resolves it:
- `attack_bonus=N` (+N when assigned to attack)
- `block_bonus=N` (+N when assigned to block)
- `min_value=N` (rolls below N become N)
- `attack_only=true` / `block_only=true`
- `on_max_bonus=N` (+N to the action when the die rolled its max face)

≥10 dice ids required; starting pool = `{"d6","d6","d6"}` (plain d6 must exist).

`data/enemies.lua` → `{ [id] = {id, name, hp, boss(bool), elite(bool),
pattern={ {kind="attack"|"block"|"attack_block", amount=N [, block=N]} , ...}} }`
- Intent = pattern entries cycled **in order** (index advances each turn;
  deterministic, no RNG for intent selection). `attack_block` shows and does both.
- Enemy `block` absorbs player damage that turn, resets at enemy turn start.
- ≥3 regular enemies + exactly 1 boss required. Elite = existing enemy with
  `elite` variant entry (more hp/amounts), or dedicated elite entries.
- Which enemy spawns at a fight/elite node: run layer picks uniformly from the
  eligible pool via the **combat** stream at node entry.

## 8. RNG stream discipline (unchanged + M1 assignments)

`map` = map generation only. `combat` = dice rolls + enemy spawn pick.
`loot` = ember amounts + reward offer picks. `shuffle` = reserved (unused M1).

## 9. Autosave protocol (ui-worker)

- After **every** `sim:apply(cmd)` that returns ≥1 event, presentation saves
  `sim:snapshot()` via defold-saver under key `run`.
- On boot: if a saved snapshot exists and its `phase` is not terminal,
  `Sim.restore(snap)` and route directly to the screen for that phase
  (`map`→map screen, `player_turn`→combat screen with current state,
  `reward`→reward overlay, `rest`→rest screen). Terminal/absent ⇒ title screen.
- Screens render only from `sim:state()` and the events returned by apply;
  never poke sim internals.

## 10. Testing floor (all workers)

Headless suite must keep passing on Lua 5.4 AND stay bit-identical across VMs.
Never weaken existing assertions. New golden hash will be re-anchored by the
orchestrator at integration — workers must not hardcode new golden values into
CI themselves; they assert structural invariants instead.
