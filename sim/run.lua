-- sim/run.lua — Run layer (M1, v2): map position, node entry, rewards,
-- rest, and the run win/loss ledger.
-- SEALED SIM MODULE: pure Lua, no engine APIs, no os/io/math.random.
--
-- Seam rules (docs/m1-contract.md §1 — LAW):
--   * combat.lua never touches run state; when an encounter ends it sets
--     sim.combat_over = "won"|"lost" and pushes its events. After EVERY
--     dispatched command sim/init.lua calls run.post(sim, events), which
--     reads sim.combat_over, clears it, and performs ALL run-level phase
--     transitions (rewards, defeat ledger, run victory).
--   * Encounters are started via the internal seam combat.begin — the
--     public start_encounter command no longer exists.
--
-- RNG discipline (contract §8):
--   * map stream    → map generation only (inside Map.generate)
--   * combat stream → dice rolls (combat.lua) + enemy spawn pick (here)
--   * loot stream   → ember amounts + reward offer picks (here)
--   * shuffle       → reserved, unused in M1
--   All pool iteration goes through data _order arrays — never pairs().

local Map = require "sim.map"
local combat = require "sim.combat"
local dice_data = require "data.dice"
local enemies_data = require "data.enemies"

local run = {}

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

local function push(events, ev)
  events[#events + 1] = ev
end

local function invalid(events, reason)
  push(events, { type = "invalid_command", reason = reason })
  return events
end

-- Enemy pools, built once from _order (deterministic authoring order).
local REGULARS, ELITES, BOSS = {}, {}, nil
for i = 1, #enemies_data._order do
  local id = enemies_data._order[i]
  local def = enemies_data[id]
  if def.boss then
    BOSS = id
  elseif def.elite then
    ELITES[#ELITES + 1] = id
  else
    REGULARS[#REGULARS + 1] = id
  end
end
assert(BOSS ~= nil, "run: data/enemies.lua has no boss")
assert(#REGULARS > 0 and #ELITES > 0, "run: enemy pools incomplete")

-- Ember payout for one won fight (contract §4: loot stream, range 8–20).
local function roll_embers(sim)
  return sim.rng.loot:range(8, 20)
end

-- ---------------------------------------------------------------------------
-- command handlers (signature: (sim, cmd, events) — same as combat's)
-- ---------------------------------------------------------------------------

function run.start_run(sim, cmd, events)
  if sim.phase ~= "idle" then
    return invalid(events, "not_idle")
  end
  local map = Map.generate(sim.rng.map)
  map.position = map.start
  map.visited = { map.start }
  sim.map = map
  sim.run = { embers = 0, fights_won = 0 }
  sim.turns_total = 0
  sim.phase = "map"
  local node_count = 0
  while map.nodes[node_count + 1] do node_count = node_count + 1 end
  push(events, {
    type = "run_started",
    seed = sim.run_seed,
    nodes = node_count,
    layers = map.layers,
  })
  return events
end

function run.choose_node(sim, cmd, events)
  if sim.phase ~= "map" then
    return invalid(events, "not_map_phase")
  end
  local target = cmd.node
  local out = sim.map.edges[sim.map.position]
  local adjacent = false
  for i = 1, #out do
    if out[i] == target then adjacent = true break end
  end
  if not adjacent then
    return invalid(events, "not_adjacent")
  end
  sim.map.position = target
  sim.map.visited[#sim.map.visited + 1] = target
  local node = sim.map.nodes[target]
  push(events, {
    type = "node_entered", node = target, kind = node.kind, layer = node.layer,
  })
  if node.kind == "fight" then
    local pick = REGULARS[sim.rng.combat:range(1, #REGULARS)]
    combat.begin(sim, pick, false, events)
  elseif node.kind == "elite" then
    local pick = ELITES[sim.rng.combat:range(1, #ELITES)]
    combat.begin(sim, pick, true, events)
  elseif node.kind == "boss" then
    combat.begin(sim, BOSS, false, events)
  elseif node.kind == "rest" then
    sim.phase = "rest"
  end
  return events
end

-- cmd: { type="choose_reward", index = 1..#offers | 0 to skip }
function run.choose_reward(sim, cmd, events)
  if sim.phase ~= "reward" or not sim.offers then
    return invalid(events, "not_reward_phase")
  end
  local i = cmd.index
  if type(i) ~= "number" or i ~= math.floor(i) or i < 0 or i > #sim.offers then
    return invalid(events, "no_such_offer")
  end
  if i == 0 then
    push(events, { type = "reward_skipped" })
  else
    local die = sim.offers[i]
    sim.player.dice[#sim.player.dice + 1] = die
    push(events, { type = "reward_chosen", die = die })
  end
  sim.offers = nil
  sim.phase = "map"
  return events
end

function run.rest(sim, cmd, events)
  if sim.phase ~= "rest" then
    return invalid(events, "not_rest_phase")
  end
  local p = sim.player
  -- 30% of max hp, floored; integer-exact arithmetic (never x*0.3).
  local healed = math.floor(p.max_hp * 3 / 10)
  if p.hp + healed > p.max_hp then healed = p.max_hp - p.hp end
  p.hp = p.hp + healed
  push(events, { type = "rested", healed = healed, hp = p.hp })
  sim.phase = "map"
  return events
end

-- ---------------------------------------------------------------------------
-- post hook — called by sim/init.lua after EVERY dispatched command
-- ---------------------------------------------------------------------------

--- Reads sim.combat_over, clears it, performs all run-level transitions.
function run.post(sim, events)
  local outcome = sim.combat_over
  if outcome == nil then return end
  sim.combat_over = nil
  sim.turns_total = (sim.turns_total or 0) + sim.turn
  local node = sim.map.nodes[sim.map.position]
  if outcome == "won" then
    sim.run.fights_won = sim.run.fights_won + 1
    if node.kind == "boss" then
      sim.run.embers = sim.run.embers + roll_embers(sim) + 40
      sim.phase = "run_won"
      push(events, {
        type = "run_won",
        embers = sim.run.embers,
        fights_won = sim.run.fights_won,
        turns_total = sim.turns_total,
      })
    else
      sim.run.embers = sim.run.embers + roll_embers(sim)
      -- Reward offers: 2–3 distinct die ids picked via the loot stream
      -- from data/dice._order (uniform, without replacement).
      local count = sim.rng.loot:range(2, 3)
      local pool = {}
      for i = 1, #dice_data._order do pool[i] = dice_data._order[i] end
      local offers = {}
      for k = 1, count do
        local idx = sim.rng.loot:range(1, #pool)
        offers[k] = pool[idx]
        table.remove(pool, idx)
      end
      sim.offers = offers
      sim.phase = "reward"
      local ev = { type = "reward_offered", o1 = offers[1], o2 = offers[2] }
      if offers[3] then ev.o3 = offers[3] end
      push(events, ev)
    end
  else -- "lost": the death ledger keeps half the embers (contract §4)
    sim.run.embers = math.floor(sim.run.embers / 2)
    sim.phase = "run_lost"
    push(events, {
      type = "run_lost",
      embers = sim.run.embers,
      fights_won = sim.run.fights_won,
      layer = node.layer,
    })
  end
end

return run
