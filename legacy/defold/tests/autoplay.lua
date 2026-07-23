-- tests/autoplay.lua — Seeded full-run autoplayer (M1 gate).
-- Runs on plain Lua 5.4 (CI) and LuaJIT — no external deps.
-- Usage: /work/tools/lua5.4 tests/autoplay.lua   (from repo root)
--
-- A deterministic greedy policy bot drives ONLY the public v2 command set
-- (docs/m1-contract.md §2) on the real Sim, for seeds 1..100. Exit 0 iff:
--   * every run reaches run_won or run_lost within MAX_CMDS applied commands
--   * the bot's legal-move logic never triggers an invalid_command event
--   * win rate lands in the 20%–80% band (exact wins/losses printed)
--   * for seeds 1..10, a mid-run snapshot→restore→continue produces an
--     identical terminal event_hash vs the uninterrupted twin run.

package.path = "./?.lua;./?/init.lua;" .. package.path

local Sim = require "sim.init"
local dice_data = require "data.dice" -- read-only: die mods for legal assigns

local SEEDS = 100
local MAX_CMDS = 3000
local BAND_LO, BAND_HI = 20, 80 -- percent
local SNAP_SEEDS = 10           -- seeds 1..N get the snapshot/restore twin check
local SNAP_AT = 25              -- snapshot after this many applied commands

-- ---------------------------------------------------------------------------
-- Greedy policy: a pure function of sim:state() -> next command (or nil at a
-- terminal phase). Deterministic, so twin sims produce identical runs.
-- ---------------------------------------------------------------------------
local function bot_cmd(sim)
  local st = sim:state()
  local phase = st.phase
  if phase == "idle" then
    return { type = "start_run" }
  elseif phase == "map" then
    -- First reachable node; prefer rest when hp < 50%, else prefer non-rest.
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
        -- Attack unless block is still needed vs the SHOWN intent.
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
    return { type = "choose_reward", index = 1 } -- always take the first offer
  elseif phase == "rest" then
    return { type = "rest" }
  end
  return nil -- run_won / run_lost: terminal
end

-- Play one seed to terminal. Returns final sim, applied-command count, and
-- the count of invalid_command events the bot triggered (must be 0).
-- If `snap_at` is given, snapshot/restore there and continue on the restored
-- twin — proving mid-run persistence is lossless.
local function play(seed, snap_at)
  local sim = Sim.new(seed)
  local applied, invalids = 0, 0
  while applied < MAX_CMDS do
    local cmd = bot_cmd(sim)
    if not cmd then break end
    local evs = sim:apply(cmd)
    applied = applied + 1
    for i = 1, #evs do
      if evs[i].type == "invalid_command" then invalids = invalids + 1 end
    end
    if snap_at and applied == snap_at then
      sim = Sim.restore(sim:snapshot())
    end
  end
  return sim, applied, invalids
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
local wins, losses, failures = 0, 0, 0

for seed = 1, SEEDS do
  local sim, applied, invalids = play(seed, nil)
  if sim.phase == "run_won" then
    wins = wins + 1
  elseif sim.phase == "run_lost" then
    losses = losses + 1
  else
    failures = failures + 1
    print(string.format("FAIL  seed %d not terminal after %d commands (phase=%s)",
      seed, applied, sim.phase))
  end
  if invalids > 0 then
    failures = failures + 1
    print(string.format("FAIL  seed %d: bot triggered %d invalid_command events",
      seed, invalids))
  end
end

-- Snapshot/restore twin check: interrupted run must end with the identical
-- event_hash (and state_hash) as the uninterrupted run of the same seed.
for seed = 1, SNAP_SEEDS do
  local plain = play(seed, nil)
  local resumed = play(seed, SNAP_AT)
  if plain.event_hash ~= resumed.event_hash
     or plain:state_hash() ~= resumed:state_hash() then
    failures = failures + 1
    print(string.format(
      "FAIL  seed %d: snapshot/restore diverged (event_hash %s vs %s)",
      seed, tostring(plain.event_hash), tostring(resumed.event_hash)))
  end
end
print(string.format("snapshot/restore twin check: seeds 1..%d", SNAP_SEEDS))

print(string.format("wins=%d losses=%d (band %d%%-%d%%)",
  wins, losses, BAND_LO, BAND_HI))
if wins < BAND_LO or wins > BAND_HI then
  failures = failures + 1
  print(string.format(
    "FAIL  win rate %d%% outside %d%%-%d%% balance band", wins, BAND_LO, BAND_HI))
end

if failures > 0 then
  print(string.format("AUTOPLAY FAILED (%d failures) wins=%d losses=%d",
    failures, wins, losses))
  os.exit(1)
end
print(string.format("AUTOPLAY OK wins=%d losses=%d", wins, losses))
