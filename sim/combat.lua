-- sim/combat.lua — Dice-builder combat command handlers.
-- SEALED SIM MODULE: pure Lua, no engine APIs.
--
-- M0 scope: one minimal but complete encounter loop proving the
-- command->events architecture. Content (enemy roster, dice faces, relics)
-- scales in M1+ as data modules; rules of fairness are already enforced here:
--   * enemy intent is ALWAYS visible before the player acts (psychology P0-1)
--   * randomness decides what you ROLL, never whether an action resolves
--     as stated (variable offerings, deterministic resolution — P0-4)

local combat = {}

-- M0 stub enemy. M1 moves this into data/enemies/*.lua.
local function make_enemy(rng)
  return {
    id = "cinder_wisp",
    name = "Cinder Wisp",
    hp = 14,
    max_hp = 14,
    intent = { kind = "attack", amount = rng:range(4, 6) },
  }
end

local function new_intent(rng)
  return { kind = "attack", amount = rng:range(4, 6) }
end

local function push(events, ev)
  events[#events + 1] = ev
end

local function intent_event(enemy)
  return {
    type = "intent_shown",
    enemy = enemy.id,
    kind = enemy.intent.kind,
    amount = enemy.intent.amount,
  }
end

local function invalid(events, reason)
  push(events, { type = "invalid_command", reason = reason })
  return events
end

function combat.start_encounter(sim, cmd, events)
  if sim.phase ~= "idle" then
    return invalid(events, "encounter_already_running")
  end
  sim.enemy = make_enemy(sim.rng.combat)
  sim.phase = "player_turn"
  sim.turn = 1
  sim.player.block = 0
  sim.player.rolled = nil
  push(events, { type = "encounter_started", enemy = sim.enemy.id,
                 enemy_hp = sim.enemy.hp, turn = sim.turn })
  push(events, intent_event(sim.enemy))
  return events
end

function combat.roll(sim, cmd, events)
  if sim.phase ~= "player_turn" then
    return invalid(events, "not_player_turn")
  end
  if sim.player.rolled then
    return invalid(events, "already_rolled_this_turn")
  end
  local values = {}
  for i = 1, #sim.player.dice do
    values[i] = sim.rng.combat:die(sim.player.dice[i])
  end
  sim.player.rolled = values
  sim.player.assigned = {}
  local ev = { type = "dice_rolled", count = #values }
  for i = 1, #values do ev["d" .. i] = values[i] end
  push(events, ev)
  return events
end

-- cmd: { type="assign", die=<index>, action="attack"|"block" }
function combat.assign(sim, cmd, events)
  if sim.phase ~= "player_turn" then
    return invalid(events, "not_player_turn")
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
  local value = rolled[i]
  if cmd.action == "attack" then
    sim.player.assigned[i] = "attack"
    sim.enemy.hp = sim.enemy.hp - value
    push(events, { type = "die_assigned", die = i, action = "attack", value = value })
    push(events, { type = "damage_dealt", target = sim.enemy.id,
                   amount = value, enemy_hp = sim.enemy.hp })
    if sim.enemy.hp <= 0 then
      sim.phase = "victory"
      push(events, { type = "encounter_won", turns = sim.turn })
      local loot = sim.rng.loot:range(8, 20)
      push(events, { type = "loot_dropped", embers = loot })
    end
  elseif cmd.action == "block" then
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
  if sim.phase ~= "player_turn" then
    return invalid(events, "not_player_turn")
  end
  -- Enemy resolves its VISIBLE intent — exactly as it was shown. Never rerolled.
  local incoming = sim.enemy.intent.amount
  local blocked = math.min(incoming, sim.player.block)
  local dmg = incoming - blocked
  sim.player.hp = sim.player.hp - dmg
  push(events, { type = "enemy_attacked", amount = incoming,
                 blocked = blocked, damage = dmg, player_hp = sim.player.hp })
  if sim.player.hp <= 0 then
    sim.phase = "defeat"
    push(events, { type = "encounter_lost", turns = sim.turn })
    return events
  end
  -- Next turn.
  sim.turn = sim.turn + 1
  sim.player.block = 0
  sim.player.rolled = nil
  sim.player.assigned = {}
  sim.enemy.intent = new_intent(sim.rng.combat)
  push(events, { type = "turn_started", turn = sim.turn })
  push(events, intent_event(sim.enemy))
  return events
end

return combat
