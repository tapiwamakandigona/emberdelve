-- sim/map.lua — StS-style layered node-map generator (M1 contract §6).
-- SEALED SIM MODULE: pure Lua, no engine APIs, no os/io/math.random, no globals.
--
-- Guarantees (enforced by construction, property-tested in tests/map_tests.lua):
--   * Pure: same rng state + cfg ⇒ identical map. All randomness comes from
--     the single `rng` stream passed in; iteration everywhere follows
--     deterministic numeric index order, never pairs().
--   * Shape: `layers` layers; layer 1 = single `start`, layer N = single
--     `boss`; middle layers have min_nodes..max_nodes nodes each.
--   * Edges span exactly one layer, are built as a random monotone
--     "staircase walk" per adjacent layer pair, which makes every node have
--     ≥1 forward edge AND ≥1 incoming edge — so every node is reachable
--     from start and the boss is reachable from every node (no dead ends),
--     with no crossing edges (planar, render-friendly).
--   * Kinds: fight-dominant; ≥1 elite (layer elite_from+ only); ≥1 rest with
--     one guaranteed on layer rest_guarantee_from+ (before the boss); no two
--     rest nodes ever adjacent on any path (no rest→rest edge exists).
--   * All arithmetic is integer-valued (or exact small-ratio division for
--     the render-only `x`), below 2^53 ⇒ bit-identical Lua 5.4 / LuaJIT.

local Map = {}

-- Tuning constants (percent rolls out of 100; one roll per middle node so
-- rng consumption is a fixed, deterministic function of the node layout).
local ELITE_PCT = 16 -- r in [1..16]  → elite (on eligible layers)
local REST_LO   = 17 -- r in [17..30] → rest (if no rest parent)
local REST_HI   = 30

local DEFAULTS = {
  layers = 9,
  min_nodes = 2,               -- middle-layer node count bounds
  max_nodes = 4,
  elite_from_layer = 4,        -- elites only on this layer or deeper
  rest_guarantee_layer = 6,    -- ≥1 rest guaranteed on this layer or deeper
}

--- Generate a map. `rng` = the sim's map stream (sim/rng.lua instance);
--- `cfg` optional, see DEFAULTS. Returns the contract §5 map view minus
--- position/visited (those belong to the run layer).
function Map.generate(rng, cfg)
  cfg = cfg or {}
  local layers    = cfg.layers or DEFAULTS.layers
  local min_nodes = cfg.min_nodes or DEFAULTS.min_nodes
  local max_nodes = cfg.max_nodes or DEFAULTS.max_nodes
  local elite_from = cfg.elite_from_layer or DEFAULTS.elite_from_layer
  local rest_from  = cfg.rest_guarantee_layer or DEFAULTS.rest_guarantee_layer
  assert(layers >= 3, "map: need at least 3 layers")
  assert(min_nodes >= 1 and max_nodes >= min_nodes, "map: bad node bounds")
  -- Placement rules below assume the guarantee layers exist and leave room
  -- for the adjacency argument that makes repair always possible.
  assert(elite_from >= 2 and elite_from < layers, "map: elite_from_layer out of range")
  assert(rest_from >= 2 and rest_from <= layers - 1, "map: rest_guarantee_layer out of range")

  -- ---- 1. Node layout (consumes rng: one range() per middle layer) -------
  -- layer_nodes[l] = array of node ids in that layer, in x order.
  -- Ids are assigned layer-major (1 = start, last = boss): deterministic.
  local layer_nodes = {}
  local nodes = {}
  local next_id = 1
  for l = 1, layers do
    local count
    if l == 1 or l == layers then
      count = 1
    else
      count = rng:range(min_nodes, max_nodes)
    end
    local row = {}
    for i = 1, count do
      local id = next_id
      next_id = next_id + 1
      -- x: evenly spread 0..1 (exact ratios of small ints: deterministic).
      local x
      if count == 1 then x = 0.5 else x = (i - 1) / (count - 1) end
      nodes[id] = { id = id, layer = l, kind = "fight", x = x }
      row[i] = id
    end
    layer_nodes[l] = row
  end
  nodes[layer_nodes[1][1]].kind = "start"
  nodes[layer_nodes[layers][1]].kind = "boss"

  -- ---- 2. Edges: random monotone staircase per adjacent layer pair -------
  -- Walk (i,j) from (1,1) to (#A,#B), connecting A[i]→B[j] at every step.
  -- Monotone ⇒ non-crossing; endpoint coverage ⇒ every A node gets a forward
  -- edge and every B node an incoming edge. rng is consumed only when both
  -- indices can still advance (a fixed function of the two layer sizes plus
  -- the choices themselves — fully determined by the stream).
  local edges = {}
  for id = 1, next_id - 1 do edges[id] = {} end
  for l = 1, layers - 1 do
    local A, B = layer_nodes[l], layer_nodes[l + 1]
    local i, j = 1, 1
    local function connect()
      local out = edges[A[i]]
      -- The walk revisits a node only with a strictly larger j, so targets
      -- stay unique and ascending; no dedupe needed.
      out[#out + 1] = B[j]
    end
    connect()
    while i < #A or j < #B do
      if i < #A and j < #B then
        local m = rng:range(1, 3)
        if m == 1 then i = i + 1
        elseif m == 2 then j = j + 1
        else i = i + 1; j = j + 1 end
      elseif i < #A then
        i = i + 1
      else
        j = j + 1
      end
      connect()
    end
  end

  -- Reverse adjacency (parents), needed for the rest-adjacency rule.
  -- Built by deterministic id order; consumes no rng.
  local parents = {}
  for id = 1, next_id - 1 do parents[id] = {} end
  for id = 1, next_id - 1 do
    local out = edges[id]
    for k = 1, #out do
      local p = parents[out[k]]
      p[#p + 1] = id
    end
  end

  local function has_rest_parent(id)
    local p = parents[id]
    for k = 1, #p do
      if nodes[p[k]].kind == "rest" then return true end
    end
    return false
  end
  local function has_rest_child(id)
    local out = edges[id]
    for k = 1, #out do
      if nodes[out[k]].kind == "rest" then return true end
    end
    return false
  end

  -- ---- 3. Kinds: sprinkle in id order (exactly one roll per middle node) --
  -- Processing in id order = layer order, so when a node considers becoming
  -- a rest, all its parents already have final-ish kinds (later repairs only
  -- ever place rests where both neighbours are checked). A node becomes rest
  -- only if no parent is a rest ⇒ no rest→rest edge can ever be created.
  for id = 2, next_id - 2 do -- skip start (1) and boss (last)
    local n = nodes[id]
    local r = rng:range(1, 100)
    if n.layer >= elite_from and r <= ELITE_PCT then
      n.kind = "elite"
    elseif r >= REST_LO and r <= REST_HI and not has_rest_parent(id) then
      n.kind = "rest"
    end
  end

  -- ---- 4. Guarantee: ≥1 rest on layer rest_from+ (before the boss) -------
  -- If the sprinkle produced none, convert a safe node. Candidates must not
  -- touch a rest on either side to preserve the no-adjacent-rests invariant.
  -- Note: when this triggers there is NO rest anywhere on layers ≥ rest_from,
  -- so nodes on layers rest_from+1 .. layers-1 have no rest neighbours at
  -- all — the fallback candidate list below is provably non-empty.
  local have_late_rest = false
  for id = 2, next_id - 2 do
    local n = nodes[id]
    if n.kind == "rest" and n.layer >= rest_from then have_late_rest = true end
  end
  if not have_late_rest then
    local fights, nonrest = {}, {}
    for id = 2, next_id - 2 do
      local n = nodes[id]
      if n.layer >= rest_from and not has_rest_parent(id) and not has_rest_child(id) then
        if n.kind == "fight" then fights[#fights + 1] = id end
        if n.kind ~= "rest" then nonrest[#nonrest + 1] = id end
      end
    end
    local pool = (#fights > 0) and fights or nonrest
    assert(#pool > 0, "map: no candidate for guaranteed rest") -- see note above
    nodes[pool[rng:range(1, #pool)]].kind = "rest"
  end

  -- ---- 5. Guarantee: ≥1 elite (layer elite_from+ only) -------------------
  -- Runs after the rest repair so a rest conversion can never erase the last
  -- elite unnoticed. Converting fight→elite has no adjacency constraint.
  local have_elite = false
  for id = 2, next_id - 2 do
    if nodes[id].kind == "elite" then have_elite = true end
  end
  if not have_elite then
    local cands = {}
    for id = 2, next_id - 2 do
      local n = nodes[id]
      if n.layer >= elite_from and n.kind == "fight" then cands[#cands + 1] = id end
    end
    -- Non-empty: rests are never adjacent, so layers elite_from..layers-1
    -- cannot be all-rest; with no elites the non-rest nodes are all fights.
    assert(#cands > 0, "map: no candidate for guaranteed elite")
    nodes[cands[rng:range(1, #cands)]].kind = "elite"
  end

  return {
    layers = layers,
    start = layer_nodes[1][1],
    boss = layer_nodes[layers][1],
    nodes = nodes,
    edges = edges, -- forward edges only; boss id maps to an empty array
  }
end

return Map
