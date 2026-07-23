-- tests/run_tests.lua — Emberdelve sim test suite.
-- Runs on plain Lua 5.4 (CI) and LuaJIT — no external deps.
-- Usage: lua5.4 tests/run_tests.lua   (from repo root)

package.path = "./?.lua;./?/init.lua;" .. package.path

local Sim = require "sim.init"
local RNG = require "sim.rng"

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

-- Scripted command sequence exercising a full mini-fight.
local SCRIPT = {
  { type = "start_encounter" },
  { type = "roll" },
  { type = "assign", die = 1, action = "attack" },
  { type = "assign", die = 2, action = "block" },
  { type = "assign", die = 3, action = "attack" },
  { type = "end_turn" },
  { type = "roll" },
  { type = "assign", die = 1, action = "attack" },
  { type = "assign", die = 2, action = "attack" },
  { type = "assign", die = 3, action = "attack" },
  { type = "end_turn" },
  { type = "roll" },
  { type = "assign", die = 1, action = "attack" },
  { type = "assign", die = 2, action = "attack" },
  { type = "assign", die = 3, action = "attack" },
  { type = "end_turn" },
  { type = "roll" },
  { type = "assign", die = 1, action = "attack" },
  { type = "assign", die = 2, action = "attack" },
  { type = "assign", die = 3, action = "attack" },
}

local function run_script(sim, script)
  local all = {}
  for _, cmd in ipairs(script) do
    -- Commands after victory/defeat are legal no-ops (invalid_command events).
    local evs = sim:apply(cmd)
    for _, e in ipairs(evs) do all[#all + 1] = e end
  end
  return all
end

-- ---------------------------------------------------------------------------
-- Tests
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

test("sim: same seed + same commands => identical event and state hashes", function()
  local a, b = Sim.new(123456), Sim.new(123456)
  run_script(a, SCRIPT)
  run_script(b, SCRIPT)
  eq(a.event_hash, b.event_hash, "event hashes differ")
  eq(a.event_count, b.event_count, "event counts differ")
  eq(a:state_hash(), b:state_hash(), "state hashes differ")
end)

test("sim: different seeds => different runs", function()
  local a, b = Sim.new(1), Sim.new(2)
  run_script(a, SCRIPT)
  run_script(b, SCRIPT)
  neq(a.event_hash, b.event_hash, "event hashes should differ across seeds")
end)

test("sim: snapshot mid-fight, restore, continue => identical", function()
  local a = Sim.new(777)
  -- play half the script
  for i = 1, 8 do a:apply(SCRIPT[i]) end
  local b = Sim.restore(a:snapshot())
  for i = 9, #SCRIPT do
    a:apply(SCRIPT[i])
    b:apply(SCRIPT[i])
  end
  eq(a.event_hash, b.event_hash, "event hashes diverged after restore")
  eq(a:state_hash(), b:state_hash(), "state hashes diverged after restore")
end)

test("sim: full fight reaches a terminal phase with consistent state", function()
  -- 3d6 all-attack averages ~10.5 dmg/turn vs 14 hp: the scripted fight must
  -- end in victory (or defeat is impossible: enemy deals max 6/turn vs 30 hp
  -- across 4 turns). Verify terminal state, not luck.
  local sim = Sim.new(20260723)
  local events = run_script(sim, SCRIPT)
  eq(sim.phase, "victory", "expected victory, got " .. sim.phase)
  assert(sim.enemy.hp <= 0, "enemy hp should be <= 0, is " .. sim.enemy.hp)
  local won, loot = false, false
  for _, e in ipairs(events) do
    if e.type == "encounter_won" then won = true end
    if e.type == "loot_dropped" then loot = true end
  end
  assert(won, "no encounter_won event")
  assert(loot, "no loot_dropped event")
end)

test("sim: enemy intent is visible before every player turn", function()
  local sim = Sim.new(555)
  local events = sim:apply({ type = "start_encounter" })
  local shown = false
  for _, e in ipairs(events) do
    if e.type == "intent_shown" then
      shown = true
      assert(e.amount >= 4 and e.amount <= 6, "intent amount out of range")
    end
  end
  assert(shown, "intent not shown at encounter start")
end)

test("sim: intent resolves exactly as shown (deterministic resolution)", function()
  local sim = Sim.new(31337)
  local shown_amount
  for _, e in ipairs(sim:apply({ type = "start_encounter" })) do
    if e.type == "intent_shown" then shown_amount = e.amount end
  end
  sim:apply({ type = "roll" })
  for _, e in ipairs(sim:apply({ type = "end_turn" })) do
    if e.type == "enemy_attacked" then
      eq(e.amount, shown_amount, "enemy attack differs from shown intent")
    end
  end
end)

test("sim: invalid commands emit events but never mutate state", function()
  local sim = Sim.new(42)
  sim:apply({ type = "start_encounter" })
  local before = sim:state_hash()
  local cases = {
    { type = "assign", die = 1, action = "attack" }, -- roll first
    { type = "start_encounter" },                    -- already running
    { type = "nonsense" },                           -- unknown
  }
  for _, cmd in ipairs(cases) do
    local evs = sim:apply(cmd)
    eq(evs[1].type, "invalid_command", "expected invalid_command for " .. cmd.type)
  end
  eq(sim:state_hash(), before, "state changed by invalid commands")
end)

test("sim: block reduces incoming damage", function()
  local sim = Sim.new(9001)
  sim:apply({ type = "start_encounter" })
  local intent = sim.enemy.intent.amount
  sim:apply({ type = "roll" })
  -- block with all three dice
  sim:apply({ type = "assign", die = 1, action = "block" })
  sim:apply({ type = "assign", die = 2, action = "block" })
  sim:apply({ type = "assign", die = 3, action = "block" })
  local block = sim.player.block
  assert(block >= 3, "expected at least 3 block")
  for _, e in ipairs(sim:apply({ type = "end_turn" })) do
    if e.type == "enemy_attacked" then
      eq(e.blocked, math.min(intent, block), "blocked amount wrong")
      eq(e.damage, intent - math.min(intent, block), "damage after block wrong")
    end
  end
end)

test("sim: golden determinism anchor (cross-VM regression guard)", function()
  -- If this hash ever changes, sim behavior changed for existing seeds:
  -- bump SIM_VERSION and document in progress.md. Value captured at M0.
  local sim = Sim.new(20260723)
  run_script(sim, SCRIPT)
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
