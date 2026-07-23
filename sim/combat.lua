-- sim/combat.lua — Encounter layer (M1, v2).
-- SEALED SIM MODULE: pure Lua, no engine APIs, no os/io/math.random.
--
-- Seam rules (docs/m1-contract.md §1 — LAW):
--   * encounter layer ONLY: never requires sim/run.lua or sim/map.lua,
--     never generates rewards/loot, never sets run-level phases.
--   * on encounter end it pushes encounter_won/encounter_lost (plus
--     boss_defeated for the boss), sets sim.combat_over = "won"|"lost",
--     and does NOT touch sim.phase — run.post performs phase transitions.
--   * public command handlers keep M0 signatures (sim, cmd, events):
--     roll, assign, end_turn. start_encounter is REMOVED from the public
--     set; the run layer starts fights via the internal seam combat.begin.
--
-- Fair-play pillars (docs/spec.md §Ethics):
--   * enemy intent is ALWAYS visible before the player commits
--   * the shown intent resolves EXACTLY as shown — never rerolled
--   * randomness decides what you roll, never how a stated action resolves

local dice_data = require "data.dice"
local enemies_data = require "data.enemies"

local combat = {}

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

-- Deep copy of plain data tables (data/*.lua entries are scalar-only trees).
local function deep_copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = deep_copy(val) end
  return out
end

local function die_def(id)
  local def = dice_data[id]
  assert(def ~= nil, "unknown die id: " .. tostring(id))
  return def
end

-- Event for the currently shown intent. For attack_block the block amount
-- rides along as an additional scalar field (contract §4).
local function intent_event(enemy)
  local intent = enemy.intent
  local ev = {
    type = "intent_shown",
    enemy = enemy.id,
    kind = intent.kind,
    amount = intent.amount,
  }
  if intent.kind == "attack_block" then
    ev.block = intent.block
  end
  return ev
end

-- ---------------------------------------------------------------------------
-- internal seam — called by the run layer (sim/run.lua), NOT a public command
-- ---------------------------------------------------------------------------

--- Begin an encounter against `enemy_id` (key into data/enemies.lua).
--- `elite` is a boolean carried onto the encounter_started event.
function combat.begin(sim, enemy_id, elite, events)
  local def = enemies_data[enemy_id]
  assert(def ~= nil, "unknown enemy id: " .. tostring(enemy_id))
  local enemy = deep_copy(def)
  enemy.max_hp = enemy.hp
  enemy.block = 0
  enemy.pattern_index = 1
  enemy.intent = deep_copy(enemy.pattern[1])
  sim.enemy = enemy
  sim.combat_over = nil
  sim.phase = "player_turn"
  sim.turn = 1
  sim.player.block = 0
  sim.player.rolled = nil
  sim.player.rolled_max = nil
  sim.player.assigned = {}
  push(events, {
    type = "encounter_started",
    enemy = enemy.id,
    enemy_hp = enemy.hp,
    turn = sim.turn,
    elite = elite and true or false,
  })
  push(events, intent_event(enemy))
  return events
end

-- ---------------------------------------------------------------------------
-- shared end-of-encounter protocol (seam rule: flag + events, never phase)
-- ---------------------------------------------------------------------------

local function encounter_won(sim, events)
  sim.combat_over = "won"
  push(events, { type = "encounter_won", turns = sim.turn })
  if sim.enemy.boss then
    push(events, { type = "boss_defeated", turns = sim.turn })
  end
end

local function encounter_lost(sim, events)
  sim.combat_over = "lost"
  push(events, { type = "encounter_lost", turns = sim.turn })
end

-- ---------------------------------------------------------------------------
-- public command handlers (M0 signatures preserved)
-- ---------------------------------------------------------------------------

function combat.roll(sim, cmd, events)
  if sim.phase ~= "player_turn" or not sim.enemy then
    return invalid(events, "not_player_turn")
  end
  if sim.combat_over then
    return invalid(events, "encounter_over")
  end
  if sim.player.rolled then
    return invalid(events, "already_rolled_this_turn")
  end
  local values, maxed = {}, {}
  for i = 1, #sim.player.dice do
    local def = die_def(sim.player.dice[i])
    local raw = sim.rng.combat:die(def.size)
    maxed[i] = (raw == def.size)
    local min_value = def.mods.min_value
    if min_value and raw < min_value then raw = min_value end
    values[i] = raw
  end
  sim.player.rolled = values
  -- Additive internal field: which dice showed their max face this turn
  -- (plain array of booleans — snapshot/serialization safe).
  sim.player.rolled_max = maxed
  sim.player.assigned = {}
  local ev = { type = "dice_rolled", count = #values }
  for i = 1, #values do ev["d" .. i] = values[i] end
  push(events, ev)
  return events
end

-- cmd: { type="assign", die=<index>, action="attack"|"block" }
function combat.assign(sim, cmd, events)
  if sim.phase ~= "player_turn" or not sim.enemy then
    return invalid(events, "not_player_turn")
  end
  if sim.combat_over then
    return invalid(events, "encounter_over")
  end
  local rolled = sim.player.rolled
  if not rolled then
    return invalid(events, "roll_first")
  end
  local i = cmd.die
  if type(i) ~= "number" or not rolled[i] then
    return invalid(events, "no_such_die")
  end
  if sim.player.assigned[i] then
    return invalid(events, "die_already_assigned")
  end
  local def = die_def(sim.player.dice[i])
  local mods = def.mods
  local bonus = (sim.player.rolled_max and sim.player.rolled_max[i])
    and (mods.on_max_bonus or 0) or 0

  if cmd.action == "attack" then
    if mods.block_only then
      return invalid(events, "die_is_block_only")
    end
    local value = rolled[i] + (mods.attack_bonus or 0) + bonus
    sim.player.assigned[i] = "attack"
    -- Enemy block (gained from its last block/attack_block intent) absorbs
    -- player damage this turn; it resets at enemy turn start.
    local absorbed = value
    if absorbed > sim.enemy.block then absorbed = sim.enemy.block end
    sim.enemy.block = sim.enemy.block - absorbed
    sim.enemy.hp = sim.enemy.hp - (value - absorbed)
    push(events, { type = "die_assigned", die = i, action = "attack", value = value })
    push(events, { type = "damage_dealt", target = sim.enemy.id,
                   amount = value, blocked = absorbed, enemy_hp = sim.enemy.hp })
    if sim.enemy.hp <= 0 then
      encounter_won(sim, events)
    end
  elseif cmd.action == "block" then
    if mods.attack_only then
      return invalid(events, "die_is_attack_only")
    end
    local value = rolled[i] + (mods.block_bonus or 0) + bonus
    sim.player.assigned[i] = "block"
    sim.player.block = sim.player.block + value
    push(events, { type = "die_assigned", die = i, action = "block", value = value })
    push(events, { type = "block_gained", amount = value, total_block = sim.player.block })
  else
    return invalid(events, "unknown_action")
  end
  return events
end

function combat.end_turn(sim, cmd, events)
  if sim.phase ~= "player_turn" or not sim.enemy then
    return invalid(events, "not_player_turn")
  end
  if sim.combat_over then
    return invalid(events, "encounter_over")
  end
  local enemy = sim.enemy
  -- Enemy turn start: leftover enemy block from last turn expires.
  enemy.block = 0
  -- Enemy resolves its VISIBLE intent — exactly as it was shown. Never rerolled.
  local intent = enemy.intent
  if intent.kind == "attack" or intent.kind == "attack_block" then
    local incoming = intent.amount
    local blocked = incoming
    if blocked > sim.player.block then blocked = sim.player.block end
    local dmg = incoming - blocked
    sim.player.hp = sim.player.hp - dmg
    local ev = { type = "enemy_attacked", amount = incoming,
                 blocked = blocked, damage = dmg, player_hp = sim.player.hp }
    if intent.kind == "attack_block" then
      enemy.block = enemy.block + intent.block
      ev.block = intent.block
    end
    push(events, ev)
  elseif intent.kind == "block" then
    enemy.block = enemy.block + intent.amount
    push(events, { type = "enemy_blocked", enemy = enemy.id,
                   amount = intent.amount, enemy_block = enemy.block })
  end
  if sim.player.hp <= 0 then
    encounter_lost(sim, events)
    return events
  end
  -- Next turn: advance the pattern cycle deterministically (no RNG).
  sim.turn = sim.turn + 1
  sim.player.block = 0
  sim.player.rolled = nil
  sim.player.rolled_max = nil
  sim.player.assigned = {}
  enemy.pattern_index = (enemy.pattern_index % #enemy.pattern) + 1
  enemy.intent = deep_copy(enemy.pattern[enemy.pattern_index])
  push(events, { type = "turn_started", turn = sim.turn })
  push(events, intent_event(enemy))
  return events
end

return combat
