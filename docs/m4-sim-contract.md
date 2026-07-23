# Emberdelve — M4 Sim Contract (gameplay depth, SIM_VERSION 4)

Extends `docs/m3-contract.md` for the v0.3.0 "gameplay depth" milestone
(backlog: `docs/improvements/gameplay-depth.md` items #1, #2, #4, #5, #8-sim,
#9-sim). Everything unchanged from M3 stays law: sealed pure-Dart sim under
`lib/sim/`, commands in / flat scalar events out, all randomness via seeded
per-domain streams, enemy intent always visible, randomness in offerings never
in resolution.

**SIM_VERSION: 3 → 4.** Old saves are rejected by `Sim.restore` (start a new
run), same policy as the 2→3 bump.

**Golden re-anchor (deliberate):** `playRun(20260723).sim.eventHash`
old (v3) `513683311` → new (v4) `1117081416`. Anchored in `test/sim_test.dart`
(`goldenV4`). Verified self-consistent by `dart run bin/autoplay.dart 200`.

**RNG streams:** `simStreams` is now
`['map', 'combat', 'loot', 'shuffle', 'offer', 'boon']`.
- `offer` — reward telegraphs: per-node die offers pre-resolved at `start_run`.
- `boon` — the starting-boon 1-of-3 offering.
Existing streams keep their M3 roles; reward-die picks MOVED from `loot` to
`offer` (they are precomputed at run start now — see §5).

---

## 1. Commands — NEW / CHANGED

| type | fields | valid phase | effect |
|---|---|---|---|
| `start_run` *(changed)* | `[ascension]`, `[character]`, `[boons:bool]` | idle | as before, **plus**: pre-resolves reward telegraphs onto map nodes (§5). If `boons==true`, phase→`boon` with a 1-of-3 offering (§6) instead of →`map`. Default (no flag) is unchanged →`map`. |
| `choose_boon` *(new)* | `index` (0 = skip, 1..3 = pick) | boon | applies the chosen boon's effects, phase→`map`. Invalid: `not_boon_phase`, `no_such_boon`. |
| `reroll_risky` *(new)* | `dice` (list of 1-based die indices) | player_turn | rerolls that subset of **unassigned** dice, **max once per turn**. Cost: each rerolled die lands at its new face **−1 pip** (floor 1) — waived if this turn holds a free reroll earned by a straight (§3). One `combat`-stream draw per die, consumed in ascending index order (replay-deterministic). Combos are re-detected afterwards (§3). Invalid reasons: `not_player_turn`, `encounter_over`, `roll_first`, `risky_reroll_used`, `no_dice_chosen`, `no_such_die`, `duplicate_die`, `die_already_assigned`. |

**Cost decision (−1 pip, not 1 damage):** chosen because (a) a reroll must
never be lethal — a "fun button" that can kill the player poisons the
fair-death pillar; (b) the cost is visible arithmetic on the dice themselves
(ghost-preview friendly); (c) it self-balances — rerolling a low die is +EV,
rerolling a decent die usually isn't, which is exactly the push-your-luck
tension the backlog asked for.

The M3 `reroll {die}` (relic-charge, single die, no penalty) is unchanged and
coexists.

## 2. Phases

`idle → [boon] → map → (player_turn | reward | rest | shop | event) → … → run_won | run_lost`

New phase `boon` occurs only when `start_run` was sent with `boons:true`.
New state field: `sim.boons` (`List<String>?` of 3 boon ids while phase ==
`boon`, else null). Present in `state()`, `snapshot()`, and the state hash.

## 3. Combos (backlog #1) — pure function of the rolled pool

Detection lives in `lib/sim/combos.dart` (`detectCombos(List<int>) →
ComboResult`), consumes **zero RNG**, and runs after every `roll` and after
every `reroll_risky` (over the final effective values, i.e. after min_value
floors and the −1 pip penalty).

- **Pair** — exactly two dice share a value: each of the two dice carries a
  **+1 combo bonus** (+2 across the pair) added to whatever action it is
  assigned to (attack or block). Multiple distinct pairs stack per die.
- **Triple** — three or more dice share a value: **ignite** — the enemy gains
  `+3` burn stacks (`igniteBurnStacks`). Ignite fires **at most once per
  turn** (re-detection after a risky reroll can't double-apply). Burn ticks at
  the end of the enemy's action in `end_turn`: damage = current stacks, then
  stacks −1. Burn can kill (triggers `encounter_won`); burn kills grant no
  exact-kill/overkill bonus.
- **Straight** — 3+ consecutive distinct values anywhere in the pool: earns a
  **free risky reroll next turn** (the −1 pip cost is waived for that turn's
  one `reroll_risky`). Earned at most once per turn; does not stack across
  turns (it's a flag, not a counter).

Player-state fields (all inside `sim.player`, snapshot-safe):
`combo_bonus` (List\<int\>|null, per-die), `risky_used` (bool), `ignited`
(bool), `free_reroll` (bool, this turn), `free_reroll_next` (bool). Enemy
gains `burn` (int stacks). All reset appropriately at `combatBegin` /
turn start.

Why small dice are now competitive: two d4s pair at 25% per roll vs 16.7% for
two d6s and 12.5% for two d8s; a +2 pair is 80% of a d4's mean face (2.5) but
only 44% of a d8's (4.5), and d4 values sit in the dense 1–4 band where
straights live.

## 4. Exact-kill / overkill (backlog #4)

On a lethal **attack assignment** (not burn, not thorns):
- enemy hp exactly 0 → `+5` embers (`exactKillEmbers`), event `exact_kill`.
- enemy hp < 0 → surplus damage, **capped at 5** (`overkillSplashCap`), is
  banked on `sim.run['pending_splash']` and dealt to the **next encounter's
  enemy** at `combatBegin` (encounters are single-enemy, so "next living
  enemy" is the next one you meet). Splash softens but never pre-kills: it is
  clamped so the new enemy keeps ≥1 hp. Pure arithmetic, no RNG.

New run-ledger field: `run.pending_splash` (int, init 0).

## 5. Reward telegraphs (backlog #5)

At `start_run`, after map generation, `_resolveRewardTelegraphs` walks nodes
in ascending id order and, for every `fight`/`elite` node, pre-resolves the
reward die offers from the **`offer` stream**:
- 2–3 distinct dice from the layer-tier-gated pool (same `_tierCeiling` rule
  as M3);
- **elites additionally guarantee one tier-3 (rare) die** as the first offer.

Node fields added (inside `map.nodes[id]`, snapshot/hash-safe):
- `offers`: `List<String>` — the exact die ids that will be offered on win;
- `reward_preview`: `String` — the single best die on offer (highest tier,
  then size). **Honest by construction:** `runPost` serves these stored
  offers verbatim, so the preview can never lie. UI shows `reward_preview`
  on the map (e.g. "⚔️ elite — Molten Blade on offer").

Non-combat nodes carry neither field. Reward payout amounts (gold/embers)
still come from `loot` at win time, unchanged.

## 6. Starting boons (backlog #8, sim part)

Vocabulary: `lib/data/boons.dart` — `BoonDef { id, name, text, effects }`,
8 boons in `boonsOrder`. Effect vocabulary (strict subset of event effects):
`gold`, `max_hp`, `gain_die`, `embers`. Schema-tested in
`test/content_test.dart`.

`start_run {boons:true}` → 3 distinct boons drawn from the `boon` stream
without replacement over `boonsOrder`, phase `boon`, event `boon_offered`.
`choose_boon {index}` applies effects (order: gold, max_hp, gain_die, embers)
or skips with `index:0`. No timer, no decay, skip always allowed — ethics
clean.

## 7. Daily seed (backlog #9, sim part)

`lib/sim/daily.dart`: `int dailySeed(int year, int month, int day)` — pure
(no `DateTime.now()`, caller supplies the UTC date), returns a valid LCG seed
in `[1, 2^31−2]` via `hashDomainString('emberdelve-daily:YYYY-MM-DD')`. The
controller starts "today's run" with `Sim(dailySeed(...))` (+ `boons:true` if
desired) and every player gets the identical run.

## 8. Events — NEW (all flat scalar maps)

| type | fields | emitted when |
|---|---|---|
| `combo_pair` | `value`, `d1`, `d2` (die indices), `bonus` (=2, total) | detection finds a pair (per pair) |
| `combo_triple` | `value`, `count` | detection finds a triple (per value) |
| `burn_applied` | `stacks` (+3), `total_burn`, `target` (enemy id) | triple ignite fires (≤1/turn) |
| `burn_tick` | `amount`, `stacks_left`, `enemy_hp` | end_turn, after enemy action, while burn > 0 |
| `combo_straight` | `low`, `high`, `length` | detection finds a straight |
| `free_reroll_earned` | — | straight grants next-turn free reroll (≤1/turn) |
| `free_reroll_granted` | — | at `turn_started` of a turn holding a free reroll |
| `risky_reroll` | `count`, `free` (bool), `penalty` (0\|1), `r1..rN` (die index), `v1..vN` (new value) | successful `reroll_risky` |
| `exact_kill` | `embers` (=5), `total` | attack kill at exactly 0 hp |
| `overkill` | `surplus` (1..5) | attack kill below 0 hp |
| `splash_damage` | `amount`, `enemy_hp` | `combatBegin` of the next encounter, when pending splash > 0 |
| `boon_offered` | `b1`, `b2`, `b3` (boon ids) | `start_run {boons:true}` |
| `boon_chosen` | `boon` | `choose_boon` pick (preceded by its effect events: `gold_gained`, `max_hp_changed`, `die_gained`, `embers_gained`) |
| `boon_skipped` | — | `choose_boon {index:0}` |

Changed event context: `dice_rolled` is now followed in the same batch by any
combo events; `die_assigned.value` / `block_gained.amount` include the pair
combo bonus.

## 9. Balance (measured)

Player power rose sharply (combos + reroll + boon die + splash + smarter
bot): the 200-seed autoplay win rate hit **100%** on the v0.2.0 roster.
Rebalance in `lib/data/enemies.dart`: **hp ×2.4, attack +7, block +5** across
the roster (elite/boss included; ascension schedule unchanged).

| measurement (`dart run bin/autoplay.dart 200`) | win rate |
|---|---|
| v0.2.0 baseline (old sim, old roster) | 53.5% |
| v4 features, old roster | 100.0% |
| v4 features, rebalanced roster | **53.5%** (band 20–80% ✓, invalids 0, twinFails 0) |

## 10. Notes for the UI wiring agent

- `start_run` from the restart flow / "Delve again" button should pass
  `boons:true`; the plain title-screen start may keep the old flow. Handle the
  new `boon` phase: render `sim.state()['boons']` (3 ids → `data/boons.dart`
  for name/text), send `choose_boon`. A skip affordance is required.
- Map screen: render `reward_preview` on fight/elite nodes (die name/icon via
  `data/dice.dart`). It is guaranteed to be among the actual offers.
- Combat: celebrate `combo_pair` / `combo_triple` / `combo_straight` /
  `free_reroll_earned`; show enemy `burn` stacks (state field) and animate
  `burn_tick`; `exact_kill` and `overkill` deserve juice. The risky-reroll UI
  needs a die multi-select + confirm that sends
  `{'type':'reroll_risky','dice':[...]}`, disabled once
  `player.risky_used == true`; show "FREE" when `player.free_reroll == true`.
- Daily run: `dailySeed(y,m,d)` with the device's **UTC** date.
- Saves: v3 snapshots are rejected (version 4); clear stale autosaves on
  upgrade like the 2→3 bump did.
- Ghost-preview (#12) inputs: `player.combo_bonus[die-1]` + die mods + relic
  sums fully determine projected values.
