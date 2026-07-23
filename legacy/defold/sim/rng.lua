-- sim/rng.lua — Deterministic per-domain RNG streams.
-- SEALED SIM MODULE: pure Lua, no engine APIs, no os/math.random.
--
-- Design (see docs/architecture.md §RNG):
--   * One run seed spawns independent named streams (map/combat/loot/shuffle)
--     so consuming one stream never shifts another (prevents "opening a menu
--     changed the next card" desyncs).
--   * Park–Miller minstd LCG using plain arithmetic only: every intermediate
--     value stays below 2^53, so results are bit-identical on LuaJIT (doubles,
--     Defold runtime) and Lua 5.4 (integers, CI test runtime).
--   * M3+ may swap in a native PCG extension behind this same interface.

local RNG = {}
RNG.__index = RNG

local MOD = 2147483647 -- 2^31 - 1 (Mersenne prime)
local MUL = 48271      -- Park–Miller minstd multiplier

-- djb2-style string hash, arithmetic only, result in [0, MOD)
local function hash_string(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + string.byte(s, i)) % MOD
  end
  return h
end

--- Create a stream for `domain` derived from `run_seed`.
function RNG.new(run_seed, domain)
  assert(type(run_seed) == "number", "run_seed must be a number")
  assert(type(domain) == "string", "domain must be a string")
  local seed = (math.floor(run_seed) + hash_string(domain)) % MOD
  if seed == 0 then seed = 1 end -- 0 is a fixed point of the LCG
  return setmetatable({ seed = seed, domain = domain, calls = 0 }, RNG)
end

function RNG:next_raw()
  self.seed = (self.seed * MUL) % MOD
  self.calls = self.calls + 1
  return self.seed
end

--- Integer uniform in [lo, hi] inclusive.
function RNG:range(lo, hi)
  assert(hi >= lo, "range: hi < lo")
  return lo + self:next_raw() % (hi - lo + 1)
end

--- Roll one die with `sides` faces (1..sides).
function RNG:die(sides)
  return self:range(1, sides)
end

--- Plain-table snapshot (for save/restore; must stay JSON-safe).
function RNG:snapshot()
  return { seed = self.seed, domain = self.domain, calls = self.calls }
end

function RNG.restore(snap)
  return setmetatable(
    { seed = snap.seed, domain = snap.domain, calls = snap.calls }, RNG)
end

return RNG
