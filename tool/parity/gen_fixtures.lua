-- tool/parity/gen_fixtures.lua — Generate Lua-side parity fixtures for the Dart port.
-- Run from repo root: /work/tools/lua5.4 tool/parity/gen_fixtures.lua
-- Writes JSON fixtures to test/fixtures/ (consumed by the Dart test suite).
--
-- JSON conventions (contract, docs/flutter-port-contract.md §Fixtures):
--   * Lua sequential arrays -> JSON arrays
--   * other tables -> JSON objects with stringified keys
--   * events/commands are flat objects (scalars only)

package.path = "legacy/defold/?.lua;legacy/defold/?/init.lua;" .. package.path
local Sim = require "sim"
local RNG = require "sim.rng"
local dice_data = require "data.dice"

-- ---------------------------------------------------------------- JSON out
local function is_array(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then return false end
    n = n + 1
  end
  return n == #t
end

local function enc(v)
  local t = type(v)
  if t == "number" then
    if v % 1 == 0 then return string.format("%.0f", v) end
    return string.format("%.17g", v)
  elseif t == "string" then
    return string.format("%q", v):gsub("\\\n", "\\n")
  elseif t == "boolean" then
    return v and "true" or "false"
  elseif t == "nil" then
    return "null"
  elseif t == "table" then
    if is_array(v) then
      local parts = {}
      for i = 1, #v do parts[i] = enc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
      parts[#parts + 1] = string.format("%q", tostring(k)) .. ":" .. enc(v[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("cannot encode " .. t)
end

local function write(path, tbl)
  local f = assert(io.open(path, "w"))
  f:write(enc(tbl))
  f:close()
  print("wrote " .. path)
end

os.execute("mkdir -p test/fixtures")

-- ------------------------------------------------------------- RNG vectors
local rng_cases = {}
for _, case in ipairs({
  { seed = 1, domain = "map" }, { seed = 1, domain = "combat" },
  { seed = 20260723, domain = "map" }, { seed = 20260723, domain = "combat" },
  { seed = 20260723, domain = "loot" }, { seed = 20260723, domain = "shuffle" },
  { seed = 2147483646, domain = "map" }, { seed = 0, domain = "combat" },
  { seed = 999983, domain = "loot" },
}) do
  local r = RNG.new(case.seed, case.domain)
  local raws = {}
  for i = 1, 20 do raws[i] = r:next_raw() end
  local ranges = {}
  for _, lohi in ipairs({ {1,6}, {1,20}, {8,20}, {0,3}, {5,5}, {1,2} }) do
    ranges[#ranges + 1] = { lo = lohi[1], hi = lohi[2], value = r:range(lohi[1], lohi[2]) }
  end
  local snap = r:snapshot()
  rng_cases[#rng_cases + 1] = {
    seed = case.seed, domain = case.domain,
    raws = raws, ranges = ranges, final = snap,
  }
end
write("test/fixtures/rng_vectors.json", { cases = rng_cases })

-- ---------------------------------------------- Golden trace (seed 20260723)
-- Scripted policy copied verbatim from legacy/defold/tests/run_tests.lua drive().
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
  return nil -- run_won / run_lost
end

local sim = Sim.new(20260723)
local steps = {}
for _ = 1, 3000 do
  local cmd = next_cmd(sim)
  if not cmd then break end
  local evs = sim:apply(cmd)
  steps[#steps + 1] = {
    cmd = cmd, events = evs,
    event_hash = sim.event_hash, event_count = sim.event_count,
  }
end
assert(sim.event_hash == 311044885,
  "golden drift! got " .. tostring(sim.event_hash))
write("test/fixtures/golden_trace.json", {
  seed = 20260723,
  final_event_hash = sim.event_hash,
  final_event_count = sim.event_count,
  final_state_hash = sim:state_hash(),
  final_phase = sim.phase,
  final_snapshot = sim:snapshot(),
  steps = steps,
})

-- ------------------------------------------- Mid-run snapshot parity anchor
local sim2 = Sim.new(4242)
local mid_steps = {}
for i = 1, 25 do
  local cmd = next_cmd(sim2)
  if not cmd then break end
  local evs = sim2:apply(cmd)
  mid_steps[#mid_steps + 1] = { cmd = cmd, events = evs, event_hash = sim2.event_hash }
end
write("test/fixtures/midrun_snapshot.json", {
  seed = 4242,
  steps = mid_steps,
  snapshot = sim2:snapshot(),
  state_hash = sim2:state_hash(),
})
print("OK")

-- ------------------------------------------------ 100-seed outcome anchors
local outcomes = {}
for seed = 1, 100 do
  local s = Sim.new(seed)
  for _ = 1, 3000 do
    local cmd = next_cmd(s)
    if not cmd then break end
    s:apply(cmd)
  end
  outcomes[#outcomes + 1] = {
    seed = seed, phase = s.phase,
    event_hash = s.event_hash, event_count = s.event_count,
  }
end
write("test/fixtures/seed_outcomes.json", { policy = "run_tests_drive", outcomes = outcomes })
print("OK2")
