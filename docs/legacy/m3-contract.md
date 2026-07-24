# Emberdelve — M3 Interface Contract (Flutter/Dart, SIM_VERSION 3)

Extends `docs/architecture.md` §2 and supersedes `docs/m1-contract.md` for the
Flutter build. Sim is a **sealed pure-Dart library** under `lib/sim/`: no
Flutter imports, no `dart:io`, no `dart:math` Random. Presentation (Flutter)
renders events and reads `sim.state()`; all mutation via `sim.apply(cmd)`.

SIM_VERSION becomes **3** (new phases + state fields + commands). The M1 golden
(`311044885`, sim v2) is retained only as the port-parity anchor in
`bin/parity.dart`; the v3 suite re-anchors its own golden.

## 1. Layer seam (unchanged law)
`combat.dart` = encounter only; sets `sim.combatOver`, never touches phase.
`run_layer.dart` owns all run-level transitions via `runPost` after every
command. New sub-systems (shop, event, forge) live in the run layer.

## 2. Command set (v3, complete)
| type | fields | valid phase | effect |
|---|---|---|---|
| `start_run` | `[ascension]`,`[character]` | idle | build map, apply character + ascension, phase→map |
| `choose_node` | `node` | map | enter node by kind (fight/elite/boss→combat, rest→rest, shop→shop, event→event) |
| `roll` | — | player_turn | roll dice once per turn |
| `assign` | `die`,`action` | player_turn | apply die (with relic hooks) |
| `reroll` | `die` | player_turn | re-roll one die; costs a charge (relic `rerolls`); invalid if none left or die unassigned-missing |
| `end_turn` | — | player_turn | enemy resolves shown intent; thorns/turn_block applied |
| `choose_reward` | `index` (0 skip) | reward | add offered die |
| `rest` | — | rest | heal 30%+rest_bonus |
| `forge` | `die` (pool index), `into` (die id) | rest | at a rest, forge one owned die into one of its `forgeTo` (alternative to healing; one action per rest) |
| `buy` | `slot` | shop | buy shop slot (die/relic/heal); pay gold | 
| `leave_shop` | — | shop | phase→map |
| `event_choose` | `option` (1-based) | event | apply option effects; phase→map |

Invalid command in any phase ⇒ single `invalid_command {reason}`, state
untouched.

## 3. Phases
`idle → map → (player_turn | reward | rest | shop | event) → ... → run_won | run_lost`
Rest nodes offer BOTH rest and forge (player picks one action, then →map).

## 4. Economy & new state
`sim.player` adds nothing structural; gold + relics live on `sim.run`:
```
run = { embers, fights_won, gold, relics:[id...], insight:<string|null>,
        seen_events:[id...], rerolls_used, ascension, character }
```
- **Gold**: won fight → `range(12,22)` (loot stream) + relic `gold_bonus`;
  boss +30. Spent in shops/events. Embers unchanged (meta currency).
- **Relics**: hooks resolved wherever the vocabulary in `data/relics.dart`
  says; all additive, order = relicsOrder.
- **insight**: on run_lost, a deterministic one-line lesson chosen from a
  fixed table by the death context (loot stream) — the fair-death payout.

## 5. Node kinds added
`shop` (layer 3+), `event` (layer 2+). Map generator gains `shopPct`,
`eventPct` and one guaranteed shop on layer ≥ shop_guarantee. Fight-dominant
still holds. Rest/elite guarantees unchanged.

## 6. Shop
On entry, stock is generated from the loot stream: 3 dice (tier ≤ layer-scaled),
2 relics (unowned), 1 heal (25% max hp). Prices from fixed base × tier, minus
relic `shop_discount`. `buy` validates gold; sold-out slots reject.

## 7. New events
`shop_stocked {slots...}`, `event_shown {event, o1..o3}`,
`event_resolved {event, option}`, `forged {from, into}`, `bought {slot, kind, id}`,
`gold_gained {amount, total}`, `gold_spent {amount, total}`,
`relic_gained {relic}`, `reroll_used {die, value, left}`,
`insight_earned {text}` (rides run_lost).

## 8. Meta layer (OUTSIDE the sim)
`lib/meta/` — NOT part of the deterministic core. Persists embers + unlocks +
ascension + stats via `path_provider`. Unlocks add starting dice/characters/
relics and are injected into `start_run` as `character`. Ascension raises enemy
amounts by a fixed integer schedule (applied in run_layer at combatBegin as an
additive `ascAmount`, deterministic — no RNG), so the sim stays pure.

## 9. Determinism floor
Same seed + same commands (+ same ascension/character) ⇒ identical event/state
hashes. `dart test` enforces it; `test/autoplay_test.dart` re-anchors the v3
golden and holds the 20–80% win band. Meta layer never feeds the sim except via
the two scalar start_run params.
