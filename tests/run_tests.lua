-- tests/run_tests.lua — Emberdelve sim test suite (M1, sim v2).
-- Runs on plain Lua 5.4 (CI) and LuaJIT — no external deps.
-- Usage: lua5.4 tests/run_tests.lua   (from repo root)

package.path = "./?.lua;./?/init.lua;" .. package.path

local Sim = require "sim.init"
local RNG = require "sim.rng"
local dice_data = require "data.dice"

-- ---------------------------------------------------------------------------
-- Micro test runner
-- ---------------------------------------------------------------------------
local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("PASS  " .. name)
  else
    failed = failed + 1
    print("FAIL  " .. name .. "\n      " .. tostring(err))
  end
end

local function eq(a, b, msg)
  if a ~= b then
    error((msg or "values differ") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
  end
end

local function neq(a, b, msg)
  if a == b then
    error((msg or "values should differ") .. ": both " .. tostring(a), 2)
  end
end

-- ---------------------------------------------------------------------------
-- Deterministic greedy driver (public v2 command set only).
-- A pure function of sim:state() -> next command, so the same seed always
-- produces the same command sequence; `drive` records every applied command
-- so a twin sim can replay them verbatim.
-- ---------------------------------------------------------------------------
local function next_cmd(sim)
  local st = sim:state()
  local phase = st.phase
  if phase == "idle" then
    return { type = "start_run" }
  elseif phase == "map" then
    local edges = st.map.edges[st.map.position]
    local want_rest = st.player.hp * 2 < st.player.max_hp
    local pick
    for i = 1, #edges do
      local kind = st.map.nodes[edges[i]].kind
      if want_rest and kind == "rest" then pick = edges[i]; break end
      if not want_rest and kind ~= "rest" and not pick then pick = edges[i] end
    end
    return { type = "choose_node", node = pick or edges[1] }
  elseif phase == "player_turn" then
    if not st.player.rolled then return { type = "roll" } end
    for i = 1, #st.player.rolled do
      if not st.player.assigned[i] then
        local mods = dice_data[st.player.dice[i]].mods
        local intent = st.enemy.intent
        local incoming = 0
        if intent.kind == "attack" or intent.kind == "attack_block" then
          incoming = intent.amount
        end
        local action
        if incoming > st.player.block and not mods.attack_only then
          action = "block"
        elseif not mods.block_only then
          action = "attack"
        else
          action = "block"
        end
        return { type = "assign", die = i, action = action }
      end
    end
    return { type = "end_turn" }
  elseif phase == "reward" then
    return { type = "choose_reward", index = 1 }
  elseif phase == "rest" then
    return { type = "rest" }
  end
  return nil -- terminal
end

--- Drive `sim` for up to `max_cmds` commands (default: to terminal).
--- Returns (all_events, applied_commands).
local function drive(sim, max_cmds)
  max_cmds = max_cmds or 3000
  local all, cmds = {}, {}
  for _ = 1, max_cmds do
    local cmd = next_cmd(sim)
    if not cmd then break end
    cmds[#cmds + 1] = cmd
    local evs = sim:apply(cmd)
    for _, e in ipairs(evs) do all[#all + 1] = e end
  end
  return all, cmds
end

local function replay(sim, cmds)
  local all = {}
  for _, cmd in ipairs(cmds) do
    local evs = sim:apply(cmd)
    for _, e in ipairs(evs) do all[#all + 1] = e end
  end
  return all
end

--- Deterministic seed search (style: tests/content_tests.lua).
local function find_seed(pred)
  for seed = 1, 20000 do
    if pred(seed) then return seed end
  end
  error("no seed found in [1,20000]")
end

--- Fresh sim advanced into its first fight node. Returns sim plus the
--- events of the node entry (encounter_started, intent_shown...).
local function enter_first_fight(seed)
  local sim = Sim.new(seed)
  sim:apply({ type = "start_run" })
  local edges = sim.map.edges[sim.map.position]
  for i = 1, #edges do
    if sim.map.nodes[edges[i]].kind == "fight" then
      return sim, sim:apply({ type = "choose_node", node = edges[i] })
    end
  end
  return nil -- first layer had no plain fight edge for this seed
end

local function find_event(evs, etype)
  for i = 1, #evs do
    if evs[i].type == etype then return evs[i] end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Tests: RNG (unchanged from M0)
-- ---------------------------------------------------------------------------

test("rng: die rolls stay in bounds and hit all faces", function()
  local r = RNG.new(42, "combat")
  local seen = {}
  for _ = 1, 1000 do
    local v = r:die(6)
    assert(v >= 1 and v <= 6, "die out of bounds: " .. v)
    seen[v] = true
  end
  for face = 1, 6 do
    assert(seen[face], "face never rolled: " .. face)
  end
end)

test("rng: streams are independent", function()
  -- Draining the combat stream must not shift the loot stream.
  local a_loot = RNG.new(7, "loot")
  local b_combat, b_loot = RNG.new(7, "combat"), RNG.new(7, "loot")
  for _ = 1, 100 do b_combat:next_raw() end
  for i = 1, 20 do
    eq(a_loot:next_raw(), b_loot:next_raw(), "loot stream shifted at draw " .. i)
  end
end)

test("rng: snapshot/restore continues identically", function()
  local r = RNG.new(99, "map")
  for _ = 1, 10 do r:next_raw() end
  local twin = RNG.restore(r:snapshot())
  for i = 1, 50 do
    eq(r:next_raw(), twin:next_raw(), "diverged at draw " .. i)
  end
end)

-- ---------------------------------------------------------------------------
-- Tests: sim v2 determinism + persistence
-- ---------------------------------------------------------------------------

test("sim: same seed + same commands => identical event and state hashes", function()
  local a = Sim.new(123456)
  local _, cmds = drive(a)
  local b = Sim.new(123456)
  replay(b, cmds)
  eq(a.event_hash, b.event_hash, "event hashes differ")
  eq(a.event_count, b.event_count, "event counts differ")
  eq(a:state_hash(), b:state_hash(), "state hashes differ")
end)

test("sim: different seeds => different runs", function()
  local a, b = Sim.new(1), Sim.new(2)
  drive(a)
  drive(b)
  neq(a.event_hash, b.event_hash, "event hashes should differ across seeds")
end)

test("sim: snapshot mid-run, restore, continue => identical", function()
  local a = Sim.new(777)
  drive(a, 30) -- into the run: map + combat state live
  local b = Sim.restore(a:snapshot())
  local _, tail = drive(a) -- finish a with the policy, recording commands
  replay(b, tail)          -- twin replays the exact same commands
  eq(a.event_hash, b.event_hash, "event hashes diverged after restore")
  eq(a:state_hash(), b:state_hash(), "state hashes diverged after restore")
  eq(a.phase, b.phase, "phases diverged after restore")
end)

test("sim: restore rejects non-v2 snapshots", function()
  local sim = Sim.new(5)
  local snap = sim:snapshot()
  snap.version = 1
  local ok, err = pcall(Sim.restore, snap)
  assert(not ok, "restore accepted a v1 snapshot")
  assert(tostring(err):find("SIM_VERSION"), "error message unclear: " .. tostring(err))
end)

-- ---------------------------------------------------------------------------
-- Tests: run layer
-- ---------------------------------------------------------------------------

test("sim: start_run builds the map, run ledger, and map phase", function()
  local sim = Sim.new(2026)
  local evs = sim:apply({ type = "start_run" })
  local started = find_event(evs, "run_started")
  assert(started, "no run_started event")
  eq(started.seed, 2026, "run_started.seed wrong")
  assert(started.nodes > 0 and started.layers == 9, "run_started shape wrong")
  local st = sim:state()
  eq(st.phase, "map", "phase should be map")
  eq(st.map.position, st.map.start, "position not at start")
  eq(#st.map.visited, 1, "visited should hold only the start node")
  eq(st.map.visited[1], st.map.start, "visited[1] must be start")
  eq(st.run.embers, 0, "embers not zeroed")
  eq(st.run.fights_won, 0, "fights_won not zeroed")
  -- second start_run is invalid and mutates nothing
  local before = sim:state_hash()
  local evs2 = sim:apply({ type = "start_run" })
  eq(evs2[1].type, "invalid_command", "second start_run should be invalid")
  eq(sim:state_hash(), before, "state changed by invalid start_run")
end)

test("sim: choose_node accepts only edges of the current position", function()
  local sim = Sim.new(4242)
  sim:apply({ type = "start_run" })
  local before = sim:state_hash()
  -- non-adjacent: the boss node is never one hop from start (9 layers)
  local evs = sim:apply({ type = "choose_node", node = sim.map.boss })
  eq(evs[1].type, "invalid_command", "boss node should not be adjacent")
  eq(evs[1].reason, "not_adjacent", "wrong reason")
  eq(sim:state_hash(), before, "state changed by invalid choose_node")
  -- adjacent node enters and emits node_entered with kind + layer
  local target = sim.map.edges[sim.map.position][1]
  local evs2 = sim:apply({ type = "choose_node", node = target })
  local entered = find_event(evs2, "node_entered")
  assert(entered, "no node_entered event")
  eq(entered.node, target, "wrong node entered")
  eq(entered.layer, 2, "first hop must reach layer 2")
  eq(sim.map.position, target, "position not updated")
  eq(sim.map.visited[2], target, "visited not updated")
end)

test("sim: entering a fight node auto-starts the encounter with visible intent", function()
  local seed = find_seed(function(s) return enter_first_fight(s) ~= nil end)
  local sim, evs = enter_first_fight(seed)
  local started = find_event(evs, "encounter_started")
  assert(started, "no encounter_started event")
  eq(started.elite, false, "regular fight flagged elite")
  assert(find_event(evs, "intent_shown"), "intent not shown at encounter start")
  eq(sim.phase, "player_turn", "phase should be player_turn")
  eq(sim.turn, 1, "turn should be 1")
end)

test("sim: intent resolves exactly as shown (deterministic resolution)", function()
  local seed = find_seed(function(s)
    local sim, evs = enter_first_fight(s)
    if not sim then return false end
    local intent = find_event(evs, "intent_shown")
    return intent and intent.kind == "attack"
  end)
  local sim, evs = enter_first_fight(seed)
  local shown = find_event(evs, "intent_shown")
  sim:apply({ type = "roll" })
  local hit = find_event(sim:apply({ type = "end_turn" }), "enemy_attacked")
  assert(hit, "no enemy_attacked event")
  eq(hit.amount, shown.amount, "enemy attack differs from shown intent")
end)

test("sim: block reduces incoming damage", function()
  local seed = find_seed(function(s)
    local sim, evs = enter_first_fight(s)
    if not sim then return false end
    local intent = find_event(evs, "intent_shown")
    return intent and intent.kind == "attack"
  end)
  local sim, evs = enter_first_fight(seed)
  local intent = find_event(evs, "intent_shown").amount
  sim:apply({ type = "roll" })
  sim:apply({ type = "assign", die = 1, action = "block" })
  sim:apply({ type = "assign", die = 2, action = "block" })
  sim:apply({ type = "assign", die = 3, action = "block" })
  local block = sim.player.block
  assert(block >= 3, "expected at least 3 block")
  local hit = find_event(sim:apply({ type = "end_turn" }), "enemy_attacked")
  assert(hit, "no enemy_attacked event")
  eq(hit.blocked, math.min(intent, block), "blocked amount wrong")
  eq(hit.damage, intent - math.min(intent, block), "damage after block wrong")
end)

test("sim: won fight pays embers and offers 2-3 rewards; choosing grows the pool", function()
  local sim = Sim.new(31337)
  local all = drive(sim) -- full run
  local offered = find_event(all, "reward_offered")
  assert(offered, "no reward_offered event in a full run")
  assert(offered.o1 and offered.o2, "offer needs at least o1 and o2")
  assert(dice_data[offered.o1] and dice_data[offered.o2], "offers must be die ids")
  -- replay the same run and stop AT the first reward phase to inspect it
  local sim2 = Sim.new(31337)
  for _ = 1, 3000 do
    if sim2.phase == "reward" then break end
    sim2:apply(next_cmd(sim2))
  end
  eq(sim2.phase, "reward", "never reached reward phase")
  local st = sim2:state()
  assert(#st.offers >= 2 and #st.offers <= 3, "offers must be 2-3, got " .. #st.offers)
  assert(st.run.embers >= 8, "won fight must pay >= 8 embers")
  eq(st.run.fights_won, 1, "fights_won must be 1 after first win")
  local pool_before = #st.player.dice
  local evs = sim2:apply({ type = "choose_reward", index = 1 })
  local chosen = find_event(evs, "reward_chosen")
  assert(chosen, "no reward_chosen event")
  eq(#sim2.player.dice, pool_before + 1, "die pool did not grow")
  eq(sim2.player.dice[#sim2.player.dice], chosen.die, "wrong die added")
  eq(sim2.phase, "map", "phase should return to map")
  eq(sim2:state().offers, nil, "offers must clear after choosing")
end)

test("sim: choose_reward index 0 skips without growing the pool", function()
  local sim = Sim.new(31337)
  for _ = 1, 3000 do
    if sim.phase == "reward" then break end
    sim:apply(next_cmd(sim))
  end
  eq(sim.phase, "reward", "never reached reward phase")
  local pool_before = #sim.player.dice
  local evs = sim:apply({ type = "choose_reward", index = 0 })
  assert(find_event(evs, "reward_skipped"), "no reward_skipped event")
  eq(#sim.player.dice, pool_before, "skip must not grow the pool")
  eq(sim.phase, "map", "phase should return to map")
end)

test("sim: rest heals 30% of max hp, floored and capped", function()
  -- Drive a wounded run until the policy takes a rest node.
  local seed = find_seed(function(s)
    local sim = Sim.new(s)
    for _ = 1, 3000 do
      if sim.phase == "rest" then return true end
      local cmd = next_cmd(sim)
      if not cmd then return false end
      sim:apply(cmd)
    end
    return false
  end)
  local sim = Sim.new(seed)
  for _ = 1, 3000 do
    if sim.phase == "rest" then break end
    sim:apply(next_cmd(sim))
  end
  eq(sim.phase, "rest", "never reached rest phase")
  local hp, max_hp = sim.player.hp, sim.player.max_hp
  local expect = math.min(math.floor(max_hp * 3 / 10), max_hp - hp)
  local rested = find_event(sim:apply({ type = "rest" }), "rested")
  assert(rested, "no rested event")
  eq(rested.healed, expect, "healed amount wrong")
  eq(rested.hp, hp + expect, "hp after rest wrong")
  eq(sim.player.hp, math.min(hp + expect, max_hp), "hp overshot max")
  eq(sim.phase, "map", "phase should return to map")
end)

test("sim: full run reaches a terminal phase with a consistent ledger", function()
  local sim = Sim.new(20260723)
  local all = drive(sim)
  assert(sim.phase == "run_won" or sim.phase == "run_lost",
    "expected terminal phase, got " .. sim.phase)
  local terminal = find_event(all, sim.phase) -- run_won / run_lost event
  assert(terminal, "no " .. sim.phase .. " event")
  eq(terminal.embers, sim.run.embers, "event embers != ledger embers")
  eq(terminal.fights_won, sim.run.fights_won, "event fights_won != ledger")
  if sim.phase == "run_won" then
    assert(find_event(all, "boss_defeated"), "run_won without boss_defeated")
    assert(terminal.turns_total > 0, "turns_total must be positive")
    assert(sim.run.embers >= 40, "boss bonus missing from embers")
  else
    assert(terminal.layer >= 2, "run_lost.layer must be a middle+ layer")
  end
  -- terminal phases are dead: every further command is invalid, state frozen
  local before = sim:state_hash()
  for _, cmd in ipairs({ { type = "start_run" }, { type = "roll" },
                         { type = "choose_node", node = sim.map.start } }) do
    local evs = sim:apply(cmd)
    eq(evs[1].type, "invalid_command", "terminal phase accepted " .. cmd.type)
  end
  eq(sim:state_hash(), before, "terminal state mutated")
end)

test("sim: invalid commands emit events but never mutate state", function()
  local sim = Sim.new(42)
  sim:apply({ type = "start_run" })
  local before = sim:state_hash()
  local cases = {
    { type = "roll" },                        -- not in combat
    { type = "assign", die = 1, action = "attack" },
    { type = "end_turn" },
    { type = "choose_reward", index = 1 },    -- no offers
    { type = "rest" },                        -- not at a rest node
    { type = "start_run" },                   -- already running
    { type = "choose_node", node = -1 },      -- no such edge
    { type = "nonsense" },                    -- unknown
  }
  for _, cmd in ipairs(cases) do
    local evs = sim:apply(cmd)
    eq(evs[1].type, "invalid_command", "expected invalid_command for " .. cmd.type)
    eq(#evs, 1, "invalid command must emit exactly one event")
  end
  eq(sim:state_hash(), before, "state changed by invalid commands")
end)

test("sim: golden determinism anchor (cross-VM regression guard)", function()
  -- If this hash ever changes, sim behavior changed for existing seeds:
  -- bump SIM_VERSION and document in progress.md.
  -- GOLDEN = nil -- re-anchored by orchestrator (via EMBERDELVE_GOLDEN env)
  local sim = Sim.new(20260723)
  drive(sim)
  -- self-consistency: the same seed + same commands must reproduce the hash
  local twin = Sim.new(20260723)
  drive(twin)
  eq(sim.event_hash, twin.event_hash, "golden run is not self-consistent")
  local golden = tonumber(os.getenv("EMBERDELVE_GOLDEN") or "0")
  if golden ~= 0 then
    eq(sim.event_hash, golden, "event hash drifted from golden value")
  else
    print("      golden event_hash = " .. string.format("%.0f", sim.event_hash))
  end
end)

-- ---------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
