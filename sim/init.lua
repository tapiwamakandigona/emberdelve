-- sim/init.lua — Emberdelve simulation core: the sealed black box.
--
-- CONTRACT (frozen in docs/architecture.md — do not change without an
-- architecture revision):
--   Sim.new(run_seed)          -> sim
--   sim:apply(cmd)             -> events (array of flat event tables)
--   sim:state()                -> read-only view of current state
--   sim:snapshot()             -> plain serializable table
--   Sim.restore(snap)          -> sim (continues identically)
--   sim:state_hash()           -> deterministic number
--   sim.event_hash             -- running hash over every emitted event
--
-- RULES:
--   * Pure Lua. Zero Defold/engine APIs. Zero os/io/math.random.
--   * All randomness through sim.rng.<domain> streams (sim/rng.lua).
--   * Same seed + same command sequence => identical events, hashes, state,
--     on every Lua VM. CI enforces this (tests/run_tests.lua).
--   * Events are flat tables: string `type` + scalar fields only.

local RNG = require "sim.rng"
local combat = require "sim.combat"

local Sim = {}
Sim.__index = Sim

local SIM_VERSION = 1
local MOD = 2147483647

local STREAMS = { "map", "combat", "loot", "shuffle" }

local HANDLERS = {
  start_encounter = combat.start_encounter,
  roll = combat.roll,
  assign = combat.assign,
  end_turn = combat.end_turn,
}

-- ---------------------------------------------------------------------------
-- Deterministic hashing (order-independent over keys, exact over values)
-- ---------------------------------------------------------------------------

local function hash_value(h, v)
  local t = type(v)
  if t == "number" then
    h = (h * 31 + (math.floor(v * 8192) % MOD)) % MOD
  elseif t == "string" then
    for i = 1, #v do h = (h * 33 + string.byte(v, i)) % MOD end
  elseif t == "boolean" then
    h = (h * 31 + (v and 2 or 1)) % MOD
  elseif t == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      h = hash_value(h, k)
      local vv = v[k]
      if vv == nil then vv = v[tonumber(k)] end
      h = hash_value(h, vv)
    end
  end
  return h
end

local function deep_copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = deep_copy(val) end
  return out
end

-- ---------------------------------------------------------------------------
-- Construction / persistence
-- ---------------------------------------------------------------------------

function Sim.new(run_seed)
  assert(type(run_seed) == "number", "run_seed must be a number")
  local self = setmetatable({}, Sim)
  self.version = SIM_VERSION
  self.run_seed = run_seed
  self.rng = {}
  for _, name in ipairs(STREAMS) do
    self.rng[name] = RNG.new(run_seed, name)
  end
  self.turn = 0
  self.phase = "idle" -- idle | player_turn | victory | defeat
  self.player = {
    hp = 30, max_hp = 30, block = 0,
    dice = { 6, 6, 6 }, -- die sizes; the "dice-builder" axis grows here
    rolled = nil, assigned = {},
  }
  self.enemy = nil
  self.event_hash = 0
  self.event_count = 0
  return self
end

function Sim:snapshot()
  local snap = {
    version = self.version,
    run_seed = self.run_seed,
    turn = self.turn,
    phase = self.phase,
    player = deep_copy(self.player),
    enemy = deep_copy(self.enemy),
    event_hash = self.event_hash,
    event_count = self.event_count,
    rng = {},
  }
  for _, name in ipairs(STREAMS) do
    snap.rng[name] = self.rng[name]:snapshot()
  end
  return snap
end

function Sim.restore(snap)
  assert(snap.version == SIM_VERSION,
    "snapshot version " .. tostring(snap.version) .. " != " .. SIM_VERSION)
  local self = setmetatable(deep_copy(snap), Sim)
  self.rng = {}
  for _, name in ipairs(STREAMS) do
    self.rng[name] = RNG.restore(snap.rng[name])
  end
  return self
end

-- ---------------------------------------------------------------------------
-- Command dispatch
-- ---------------------------------------------------------------------------

--- Apply one command; returns the ordered list of resulting events.
function Sim:apply(cmd)
  assert(type(cmd) == "table" and type(cmd.type) == "string",
    "command must be a table with a string 'type'")
  local events = {}
  local handler = HANDLERS[cmd.type]
  if not handler then
    events[#events + 1] = { type = "invalid_command", reason = "unknown_command" }
  else
    handler(self, cmd, events)
  end
  for _, ev in ipairs(events) do
    self.event_hash = hash_value(self.event_hash, ev)
    self.event_count = self.event_count + 1
  end
  return events
end

function Sim:state()
  return {
    turn = self.turn,
    phase = self.phase,
    player = self.player,
    enemy = self.enemy,
  }
end

function Sim:state_hash()
  local h = 17
  h = hash_value(h, self.turn)
  h = hash_value(h, self.phase)
  h = hash_value(h, self.player)
  h = hash_value(h, self.enemy or "none")
  for _, name in ipairs(STREAMS) do
    h = hash_value(h, self.rng[name]:snapshot())
  end
  return h
end

return Sim
