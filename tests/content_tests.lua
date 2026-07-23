-- tests/content_tests.lua — M1 content + encounter-layer tests.
-- Standalone: does NOT require sim/init.lua (rewritten in parallel).
-- Usage: /work/tools/lua5.4 tests/content_tests.lua   (from repo root)

package.path = "./?.lua;./?/init.lua;" .. package.path

local RNG = require "sim.rng"
local combat = require "sim.combat"
local dice = require "data.dice"
local enemies = require "data.enemies"

-- ---------------------------------------------------------------------------
-- Micro test runner (style copied from tests/run_tests.lua)
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

local function ok(cond, msg)
  if not cond then error(msg or "condition false", 2) end
end

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- Fake sim per orchestrator brief — no sim/init.lua.
local function fake_sim(seed, pool)
  return {
    rng = { combat = RNG.new(seed or 42, "combat") },
    player = { hp = 30, max_hp = 30, block = 0,
               dice = pool or { "d6", "d6", "d6" },
               rolled = nil, assigned = {} },
    phase = "idle", turn = 0,
  }
end

local function begin_fight(seed, enemy_id, pool, elite)
  local sim = fake_sim(seed, pool)
  local evs = combat.begin(sim, enemy_id, elite or false, {})
  return sim, evs
end

-- Deterministic seed search: first seed in [1,20000] whose fresh combat
-- stream satisfies pred. Pure arithmetic — stable across VMs.
local function find_seed(pred)
  for seed = 1, 20000 do
    if pred(RNG.new(seed, "combat")) then return seed end
  end
  error("no seed found in [1,20000]")
end

local function find_event(evs, etype)
  for i = 1, #evs do
    if evs[i].type == etype then return evs[i], i end
  end
  return nil
end

-- Shallow-ish state fingerprint for "state untouched" assertions.
local function fingerprint(sim)
  local rolled = "nil"
  if sim.player.rolled then rolled = table.concat(sim.player.rolled, ",") end
  local assigned = {}
  for k, v in pairs(sim.player.assigned) do
    assigned[#assigned + 1] = k .. "=" .. v
  end
  table.sort(assigned)
  return table.concat({
    sim.phase, sim.turn, tostring(sim.combat_over),
    sim.player.hp, sim.player.block, rolled, table.concat(assigned, ","),
    sim.enemy and sim.enemy.hp or -1,
    sim.enemy and sim.enemy.block or -1,
    sim.enemy and sim.enemy.pattern_index or -1,
    sim.rng.combat.calls,
  }, "|")
end

local DIE_MODS = { attack_bonus = "number", block_bonus = "number",
                   min_value = "number", on_max_bonus = "number",
                   attack_only = "boolean", block_only = "boolean" }

-- ---------------------------------------------------------------------------
-- 1–4: data schema validation
-- ---------------------------------------------------------------------------

test("data: dice schema valid, >=10 ids, plain d6 present", function()
  local n = 0
  for id, def in pairs(dice) do
    if id ~= "_order" then
      n = n + 1
      eq(def.id, id, "dice id mismatch for " .. id)
      eq(type(def.name), "string", id .. ".name")
      ok(type(def.size) == "number" and def.size >= 2
         and def.size == math.floor(def.size), id .. ".size invalid")
      eq(type(def.mods), "table", id .. ".mods")
      for mk, mv in pairs(def.mods) do
        ok(DIE_MODS[mk], id .. ": illegal mod key " .. tostring(mk))
        eq(type(mv), DIE_MODS[mk], id .. ": mod " .. mk .. " wrong type")
      end
      ok(not (def.mods.attack_only and def.mods.block_only),
         id .. ": attack_only and block_only both set")
    end
  end
  ok(n >= 10, "need >=10 die ids, got " .. n)
  ok(dice.d6 and dice.d6.size == 6, "plain d6 missing or wrong size")
  eq(next(dice.d6.mods), nil, "plain d6 must have no mods")
end)

test("data: dice._order complete, deterministic, no duplicates", function()
  eq(type(dice._order), "table", "_order missing")
  local seen = {}
  for _, id in ipairs(dice._order) do
    ok(dice[id], "_order lists unknown id " .. tostring(id))
    ok(not seen[id], "_order duplicates " .. id)
    seen[id] = true
  end
  for id in pairs(dice) do
    if id ~= "_order" then
      ok(seen[id], "id missing from _order: " .. id)
    end
  end
end)

test("data: enemies schema valid; >=3 regular, >=2 elite, exactly 1 boss", function()
  local regular, elite, boss = 0, 0, 0
  for id, def in pairs(enemies) do
    if id ~= "_order" then
      eq(def.id, id, "enemy id mismatch for " .. id)
      eq(type(def.name), "string", id .. ".name")
      ok(type(def.hp) == "number" and def.hp > 0, id .. ".hp")
      eq(type(def.boss), "boolean", id .. ".boss")
      eq(type(def.elite), "boolean", id .. ".elite")
      ok(type(def.pattern) == "table" and #def.pattern >= 1, id .. ".pattern")
      for pi, entry in ipairs(def.pattern) do
        local kind = entry.kind
        ok(kind == "attack" or kind == "block" or kind == "attack_block",
           id .. ".pattern[" .. pi .. "].kind invalid")
        ok(type(entry.amount) == "number" and entry.amount > 0,
           id .. ".pattern[" .. pi .. "].amount")
        if kind == "attack_block" then
          ok(type(entry.block) == "number" and entry.block > 0,
             id .. ".pattern[" .. pi .. "].block")
        else
          eq(entry.block, nil, id .. ".pattern[" .. pi .. "]: stray block field")
        end
      end
      if def.boss then boss = boss + 1
      elseif def.elite then elite = elite + 1
      else regular = regular + 1 end
    end
  end
  ok(regular >= 3, "need >=3 regular enemies, got " .. regular)
  ok(elite >= 2, "need >=2 elites, got " .. elite)
  eq(boss, 1, "need exactly 1 boss")
end)

test("data: enemies._order complete, deterministic, no duplicates", function()
  eq(type(enemies._order), "table", "_order missing")
  local seen = {}
  for _, id in ipairs(enemies._order) do
    ok(enemies[id], "_order lists unknown id " .. tostring(id))
    ok(not seen[id], "_order duplicates " .. id)
    seen[id] = true
  end
  for id in pairs(enemies) do
    if id ~= "_order" then
      ok(seen[id], "id missing from _order: " .. id)
    end
  end
end)

-- ---------------------------------------------------------------------------
-- 5–7: combat.begin + pattern cycling
-- ---------------------------------------------------------------------------

test("combat.begin: state set, deep-copied enemy, correct events", function()
  local sim, evs = begin_fight(7, "cinder_wisp", nil, false)
  eq(sim.phase, "player_turn")
  eq(sim.turn, 1)
  eq(sim.player.block, 0)
  eq(sim.player.rolled, nil)
  eq(sim.enemy.hp, enemies.cinder_wisp.hp)
  eq(sim.enemy.pattern_index, 1)
  eq(evs[1].type, "encounter_started")
  eq(evs[1].enemy, "cinder_wisp")
  eq(evs[1].enemy_hp, enemies.cinder_wisp.hp)
  eq(evs[1].turn, 1)
  eq(evs[1].elite, false)
  eq(evs[2].type, "intent_shown")
  eq(evs[2].kind, "attack")
  eq(evs[2].amount, enemies.cinder_wisp.pattern[1].amount)
  -- deep copy: mutating the live enemy must not corrupt the data module
  local orig_amount = enemies.cinder_wisp.pattern[1].amount
  local orig_hp = enemies.cinder_wisp.hp
  sim.enemy.pattern[1].amount = 999
  sim.enemy.hp = 1
  eq(enemies.cinder_wisp.pattern[1].amount, orig_amount, "data module mutated!")
  eq(enemies.cinder_wisp.hp, orig_hp, "data module mutated!")
end)

test("combat.begin: elite flag carried onto encounter_started", function()
  local _, evs = begin_fight(7, "pyre_howler", nil, true)
  eq(evs[1].elite, true)
end)

test("pattern cycling: intents follow authored order, wrap, no RNG", function()
  local sim = begin_fight(11, "cinder_wisp")
  sim.player.hp = 999 -- survival is not under test; intent order is
  local p = enemies.cinder_wisp.pattern
  local expect = { p[2].amount, p[3].amount, p[1].amount, p[2].amount } -- turns 2..5 after wrap
  local rng_calls_used = 0
  for t = 1, 4 do
    local before = sim.rng.combat.calls
    local evs = combat.end_turn(sim, { type = "end_turn" }, {})
    rng_calls_used = rng_calls_used + (sim.rng.combat.calls - before)
    local intent = find_event(evs, "intent_shown")
    eq(intent.amount, expect[t], "turn " .. (t + 1) .. " intent")
    eq(intent.kind, "attack")
  end
  eq(rng_calls_used, 0, "intent selection must consume no RNG")
end)

-- ---------------------------------------------------------------------------
-- 8–11: dice v2 — rolls, mods
-- ---------------------------------------------------------------------------

test("roll: values from combat stream, in range, dice_rolled shape", function()
  local sim = begin_fight(101, "cinder_wisp")
  local evs = combat.roll(sim, { type = "roll" }, {})
  eq(#evs, 1)
  eq(evs[1].type, "dice_rolled")
  eq(evs[1].count, 3)
  for i = 1, 3 do
    local v = sim.player.rolled[i]
    ok(v >= 1 and v <= 6, "d" .. i .. " out of range: " .. tostring(v))
    eq(evs[1]["d" .. i], v, "event d" .. i .. " mismatch")
  end
  eq(sim.rng.combat.calls, 3, "one rng call per die")
  -- determinism: identical seed => identical roll
  local sim2 = begin_fight(101, "cinder_wisp")
  combat.roll(sim2, { type = "roll" }, {})
  for i = 1, 3 do eq(sim2.player.rolled[i], sim.player.rolled[i], "not deterministic") end
end)

test("mod min_value: low raw rolls are raised to the floor", function()
  -- seed whose first d6 roll is below 3 (raw), so the floor must trigger
  local seed = find_seed(function(r) return r:die(6) < 3 end)
  local sim = begin_fight(seed, "cinder_wisp", { "d6_steady", "d6_steady", "d6_steady" })
  combat.roll(sim, { type = "roll" }, {})
  for i = 1, 3 do
    ok(sim.player.rolled[i] >= 3, "min_value 3 violated: " .. sim.player.rolled[i])
  end
  -- same seed, plain dice: first raw roll really was < 3 (floor did something)
  local plain = begin_fight(seed, "cinder_wisp")
  combat.roll(plain, { type = "roll" }, {})
  ok(plain.player.rolled[1] < 3, "seed search broken")
end)

test("mods attack_bonus / block_bonus: applied on assign", function()
  local sim = begin_fight(5, "cinder_wisp", { "d6_keen", "d6_stout", "d6" })
  combat.roll(sim, { type = "roll" }, {})
  local r1, r2 = sim.player.rolled[1], sim.player.rolled[2]
  local hp0 = sim.enemy.hp
  local evs = combat.assign(sim, { type = "assign", die = 1, action = "attack" }, {})
  eq(evs[1].type, "die_assigned")
  eq(evs[1].value, r1 + 1, "attack_bonus not applied")
  eq(sim.enemy.hp, hp0 - (r1 + 1))
  eq(evs[2].type, "damage_dealt")
  eq(evs[2].amount, r1 + 1)
  evs = combat.assign(sim, { type = "assign", die = 2, action = "block" }, {})
  eq(evs[1].value, r2 + 1, "block_bonus not applied")
  eq(sim.player.block, r2 + 1)
  eq(evs[2].type, "block_gained")
  eq(evs[2].total_block, r2 + 1)
end)

test("mod on_max_bonus: fires only on the max face", function()
  local max_seed = find_seed(function(r) return r:die(10) == 10 end)
  local sim = begin_fight(max_seed, "ember_tyrant", { "d10_surge", "d6", "d6" })
  combat.roll(sim, { type = "roll" }, {})
  eq(sim.player.rolled[1], 10, "seed search broken")
  local hp0 = sim.enemy.hp
  local evs = combat.assign(sim, { type = "assign", die = 1, action = "attack" }, {})
  eq(evs[1].value, 14, "on_max_bonus 4 not applied to nat 10")
  eq(sim.enemy.hp, hp0 - 14)
  -- non-max face: no bonus
  local low_seed = find_seed(function(r) return r:die(10) < 10 end)
  local sim2 = begin_fight(low_seed, "ember_tyrant", { "d10_surge", "d6", "d6" })
  combat.roll(sim2, { type = "roll" }, {})
  local raw = sim2.player.rolled[1]
  local evs2 = combat.assign(sim2, { type = "assign", die = 1, action = "attack" }, {})
  eq(evs2[1].value, raw, "bonus applied without max face")
end)

-- ---------------------------------------------------------------------------
-- 12–13: attack_only / block_only rejection (invalid-command safety)
-- ---------------------------------------------------------------------------

test("attack_only die: block rejected, single event, state untouched", function()
  local sim = begin_fight(9, "cinder_wisp", { "d8_blade", "d6", "d6" })
  combat.roll(sim, { type = "roll" }, {})
  local fp = fingerprint(sim)
  local evs = combat.assign(sim, { type = "assign", die = 1, action = "block" }, {})
  eq(#evs, 1)
  eq(evs[1].type, "invalid_command")
  eq(evs[1].reason, "die_is_attack_only")
  eq(fingerprint(sim), fp, "state changed on invalid command")
  -- die is still usable for its legal action (with its attack_bonus 2)
  local raw = sim.player.rolled[1]
  local evs2 = combat.assign(sim, { type = "assign", die = 1, action = "attack" }, {})
  eq(evs2[1].type, "die_assigned")
  eq(evs2[1].value, raw + 2)
end)

test("block_only die: attack rejected, single event, state untouched", function()
  local sim = begin_fight(9, "cinder_wisp", { "d8_aegis", "d6", "d6" })
  combat.roll(sim, { type = "roll" }, {})
  local fp = fingerprint(sim)
  local evs = combat.assign(sim, { type = "assign", die = 1, action = "attack" }, {})
  eq(#evs, 1)
  eq(evs[1].type, "invalid_command")
  eq(evs[1].reason, "die_is_block_only")
  eq(fingerprint(sim), fp, "state changed on invalid command")
  local raw = sim.player.rolled[1]
  local evs2 = combat.assign(sim, { type = "assign", die = 1, action = "block" }, {})
  eq(evs2[1].type, "die_assigned")
  eq(evs2[1].value, raw + 2)
end)

-- ---------------------------------------------------------------------------
-- 14–15: attack_block resolution + enemy block absorb/reset
-- ---------------------------------------------------------------------------

test("attack_block: intent + resolution carry block field, both effects land", function()
  -- soot_shade turn 1 intent: attack_block (amounts from data module)
  local sim, evs = begin_fight(3, "soot_shade")
  local p1 = enemies.soot_shade.pattern[1]
  local hp_start = sim.player.hp
  eq(p1.kind, "attack_block", "test premise: soot_shade opens attack_block")
  eq(evs[2].kind, "attack_block")
  eq(evs[2].amount, p1.amount)
  eq(evs[2].block, p1.block, "intent_shown missing block field")
  local evs2 = combat.end_turn(sim, { type = "end_turn" }, {})
  local atk = find_event(evs2, "enemy_attacked")
  eq(atk.amount, p1.amount)
  eq(atk.block, p1.block, "enemy_attacked missing block field")
  eq(atk.damage, p1.amount)
  eq(sim.player.hp, hp_start - p1.amount, "attack part not resolved as shown")
  eq(sim.enemy.block, p1.block, "block part not resolved")
end)

test("enemy block: absorbs player damage that turn, resets at enemy turn start", function()
  local sim = begin_fight(3, "soot_shade")
  local p = enemies.soot_shade.pattern
  local b1 = p[1].block
  combat.end_turn(sim, { type = "end_turn" }, {}) -- enemy now has block from turn-1 intent, turn 2
  eq(sim.enemy.block, b1)
  combat.roll(sim, { type = "roll" }, {})
  local v = sim.player.rolled[1]
  local hp0 = sim.enemy.hp
  local evs = combat.assign(sim, { type = "assign", die = 1, action = "attack" }, {})
  local absorbed = math.min(v, b1)
  eq(evs[2].blocked, absorbed, "damage_dealt.blocked wrong")
  eq(sim.enemy.hp, hp0 - (v - absorbed), "enemy block did not absorb")
  eq(sim.enemy.block, b1 - absorbed, "enemy block not consumed")
  -- enemy turn start (turn-2 intent is pure attack) resets leftover block
  local evs2 = combat.end_turn(sim, { type = "end_turn" }, {})
  eq(sim.enemy.block, 0, "enemy block not reset at enemy turn start")
  eq(find_event(evs2, "enemy_attacked").amount, p[2].amount)
end)

test("block intent: enemy_blocked event, no damage to player", function()
  -- ember_beetle turn 1 intent: pure block (amount from data module)
  local sim, evs = begin_fight(13, "ember_beetle")
  local b = enemies.ember_beetle.pattern[1].amount
  eq(evs[2].kind, "block")
  local hp0 = sim.player.hp
  local evs2 = combat.end_turn(sim, { type = "end_turn" }, {})
  local blk = find_event(evs2, "enemy_blocked")
  ok(blk, "no enemy_blocked event")
  eq(blk.amount, b)
  eq(blk.enemy_block, b)
  eq(sim.enemy.block, b)
  eq(sim.player.hp, hp0, "block intent damaged player")
  ok(not find_event(evs2, "enemy_attacked"), "spurious enemy_attacked")
end)

-- ---------------------------------------------------------------------------
-- 16–18: combat_over protocol
-- ---------------------------------------------------------------------------

test("combat_over won: flag set, phase untouched, no loot, guard on further cmds", function()
  local sim = begin_fight(21, "cinder_wisp")
  combat.roll(sim, { type = "roll" }, {})
  sim.enemy.hp = 1 -- force lethal
  local evs = combat.assign(sim, { type = "assign", die = 1, action = "attack" }, {})
  local won = find_event(evs, "encounter_won")
  ok(won, "no encounter_won")
  eq(won.turns, 1)
  eq(sim.combat_over, "won")
  eq(sim.phase, "player_turn", "combat must NOT touch sim.phase")
  ok(not find_event(evs, "boss_defeated"), "boss_defeated for non-boss")
  ok(not find_event(evs, "loot_dropped"), "combat generated loot (run-layer job)")
  -- further combat commands are rejected without state damage
  local fp = fingerprint(sim)
  local evs2 = combat.end_turn(sim, { type = "end_turn" }, {})
  eq(evs2[1].type, "invalid_command")
  eq(fingerprint(sim), fp)
end)

test("combat_over won vs boss: boss_defeated pushed too", function()
  local sim = begin_fight(21, "ember_tyrant")
  combat.roll(sim, { type = "roll" }, {})
  sim.enemy.hp = 1
  local evs = combat.assign(sim, { type = "assign", die = 1, action = "attack" }, {})
  local won, wi = find_event(evs, "encounter_won")
  local bd, bi = find_event(evs, "boss_defeated")
  ok(won and bd, "missing encounter_won/boss_defeated")
  ok(wi < bi, "encounter_won must precede boss_defeated")
  eq(bd.turns, 1)
  eq(sim.combat_over, "won")
  eq(sim.phase, "player_turn")
end)

test("combat_over lost: flag set, phase untouched, correct event", function()
  local sim = begin_fight(31, "pyre_howler")
  sim.player.hp = 2 -- turn-1 intent: attack 6 → lethal
  local evs = combat.end_turn(sim, { type = "end_turn" }, {})
  local lost = find_event(evs, "encounter_lost")
  ok(lost, "no encounter_lost")
  eq(lost.turns, 1)
  eq(sim.combat_over, "lost")
  eq(sim.phase, "player_turn", "combat must NOT touch sim.phase")
  ok(not find_event(evs, "turn_started"), "turn advanced after death")
end)

-- ---------------------------------------------------------------------------
-- 19: general invalid-command state safety (M0 behavior preserved)
-- ---------------------------------------------------------------------------

test("invalid commands: single event, state bit-untouched", function()
  local sim = begin_fight(55, "ash_rat")
  local cases = {
    { fn = combat.assign,   cmd = { type = "assign", die = 1, action = "attack" },
      reason = "roll_first" },
    { fn = combat.roll,     cmd = { type = "roll" }, pre = function(s)
        combat.roll(s, { type = "roll" }, {}) end,
      reason = "already_rolled_this_turn" },
    { fn = combat.assign,   cmd = { type = "assign", die = 99, action = "attack" },
      reason = "no_such_die" },
    { fn = combat.assign,   cmd = { type = "assign", die = 1, action = "dance" },
      reason = "unknown_action" },
  }
  for _, c in ipairs(cases) do
    if c.pre then c.pre(sim) end
    local fp = fingerprint(sim)
    local evs = c.fn(sim, c.cmd, {})
    eq(#evs, 1, c.reason .. ": expected single event")
    eq(evs[1].type, "invalid_command", c.reason)
    eq(evs[1].reason, c.reason)
    eq(fingerprint(sim), fp, c.reason .. ": state changed")
  end
  -- wrong phase: all three handlers reject when not player_turn
  sim.phase = "map"
  local fp = fingerprint(sim)
  for _, fn in ipairs({ combat.roll, combat.assign, combat.end_turn }) do
    local evs = fn(sim, { type = "x", die = 1, action = "attack" }, {})
    eq(evs[1].type, "invalid_command")
    eq(evs[1].reason, "not_player_turn")
    eq(fingerprint(sim), fp)
  end
end)

-- ---------------------------------------------------------------------------
-- 20: balance smoke — greedy bot beats every regular with the starting pool
-- ---------------------------------------------------------------------------

test("balance: starting pool {d6,d6,d6} beats each regular enemy (seed sweep)", function()
  local regulars = {}
  for _, id in ipairs(enemies._order) do
    local e = enemies[id]
    if not e.boss and not e.elite then regulars[#regulars + 1] = id end
  end
  ok(#regulars >= 3)
  -- simple policy: block with the smallest die if intent hurts, attack rest
  for _, id in ipairs(regulars) do
    local wins = 0
    for seed = 1, 20 do
      local sim = begin_fight(seed * 1000 + 7, id)
      for _ = 1, 30 do
        if sim.combat_over then break end
        combat.roll(sim, { type = "roll" }, {})
        local smallest, sv = 1, sim.player.rolled[1]
        for i = 2, 3 do
          if sim.player.rolled[i] < sv then smallest, sv = i, sim.player.rolled[i] end
        end
        local hurts = sim.enemy.intent.kind ~= "block"
        for i = 1, 3 do
          if sim.combat_over then break end
          local action = (hurts and i == smallest) and "block" or "attack"
          combat.assign(sim, { type = "assign", die = i, action = action }, {})
        end
        if not sim.combat_over then
          combat.end_turn(sim, { type = "end_turn" }, {})
        end
      end
      if sim.combat_over == "won" then wins = wins + 1 end
    end
    ok(wins >= 15, id .. ": too hard for starter pool (won " .. wins .. "/20)")
    ok(wins <= 20, id) -- sanity
  end
end)

-- ---------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
