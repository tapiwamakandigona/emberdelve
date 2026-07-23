-- tests/map_tests.lua — property tests for sim/map.lua (M1 contract §6).
-- Runs on plain Lua 5.4 (CI) and LuaJIT — no external deps.
-- Usage: /work/tools/lua5.4 tests/map_tests.lua   (from repo root)
--
-- Each property is checked over SEEDS random run seeds. Failure messages
-- always include the offending seed so a break is reproducible.

package.path = "./?.lua;./?/init.lua;" .. package.path

local Map = require "sim.map"
local RNG = require "sim.rng"

local SEEDS = 200
-- Mix of small, large and "awkward" seeds; deterministic list.
local function seed_list()
  local s = {}
  for i = 1, SEEDS do s[i] = i * 7919 + 13 end -- spread across the LCG state
  s[1] = 0; s[2] = 1; s[3] = 2147483646        -- edge seeds: 0, 1, MOD-1
  return s
end

-- ---------------------------------------------------------------------------
-- Micro test runner (same pattern as tests/run_tests.lua)
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

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function gen(seed, cfg)
  return Map.generate(RNG.new(seed, "map"), cfg)
end

-- Canonical serialization: fixed field order, ids ascending. Never uses
-- pairs() output order, so it is stable across VMs and table layouts.
local function serialize(m)
  local out = { "L", m.layers, "S", m.start, "B", m.boss }
  local ids = {}
  for id in pairs(m.nodes) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local n = m.nodes[id]
    out[#out + 1] = string.format("n%d:%d:%s:%.6f", n.id, n.layer, n.kind, n.x)
    local e = m.edges[id] or {}
    local es = {}
    for k = 1, #e do es[k] = e[k] end
    table.sort(es)
    out[#out + 1] = "e" .. table.concat(es, ",")
  end
  return table.concat(out, "|")
end

local function node_ids(m)
  local ids = {}
  for id in pairs(m.nodes) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

local function for_seeds(fn)
  for _, seed in ipairs(seed_list()) do fn(seed, gen(seed)) end
end

local function fail(seed, msg) error("seed " .. seed .. ": " .. msg, 0) end

-- ---------------------------------------------------------------------------
-- Property tests
-- ---------------------------------------------------------------------------

test("map: determinism — same seed ⇒ identical serialized map", function()
  for _, seed in ipairs(seed_list()) do
    local a, b = serialize(gen(seed)), serialize(gen(seed))
    if a ~= b then fail(seed, "two generates from fresh streams differ") end
  end
end)

test("map: purity — fresh same-seeded stream reproduces map; no globals; input cfg untouched", function()
  -- Snapshot the global environment; generate must not create globals.
  local before = {}
  for k in pairs(_G) do before[k] = true end
  for _, seed in ipairs(seed_list()) do
    local r1 = RNG.new(seed, "map")
    local m1 = Map.generate(r1)
    local r2 = RNG.new(seed, "map")
    local m2 = Map.generate(r2)
    if serialize(m1) ~= serialize(m2) then fail(seed, "second generate differs") end
    if r1.calls ~= r2.calls or r1.seed ~= r2.seed then
      fail(seed, "rng consumption differs between identical generates")
    end
    -- cfg table must not be mutated (pure function of its inputs).
    local cfg = { layers = 9 }
    Map.generate(RNG.new(seed, "map"), cfg)
    local nkeys = 0
    for _ in pairs(cfg) do nkeys = nkeys + 1 end
    if nkeys ~= 1 or cfg.layers ~= 9 then fail(seed, "cfg table was mutated") end
  end
  for k in pairs(_G) do
    if not before[k] then error("generate leaked global: " .. tostring(k), 0) end
  end
end)

test("map: layer/node-count bounds, start and boss placement, x in [0,1]", function()
  for_seeds(function(seed, m)
    if m.layers ~= 9 then fail(seed, "layers ~= 9") end
    local per_layer = {}
    for _, id in ipairs(node_ids(m)) do
      local n = m.nodes[id]
      if type(n.id) ~= "number" or n.id ~= id then fail(seed, "id mismatch at " .. id) end
      if n.layer < 1 or n.layer > 9 then fail(seed, "layer out of range") end
      if n.x < 0 or n.x > 1 then fail(seed, "x out of [0,1] at node " .. id) end
      per_layer[n.layer] = (per_layer[n.layer] or 0) + 1
    end
    if per_layer[1] ~= 1 then fail(seed, "layer 1 not a single node") end
    if per_layer[9] ~= 1 then fail(seed, "layer 9 not a single node") end
    for l = 2, 8 do
      local c = per_layer[l] or 0
      if c < 2 or c > 4 then fail(seed, "layer " .. l .. " has " .. c .. " nodes") end
    end
    if m.nodes[m.start].kind ~= "start" or m.nodes[m.start].layer ~= 1 then
      fail(seed, "bad start node")
    end
    if m.nodes[m.boss].kind ~= "boss" or m.nodes[m.boss].layer ~= 9 then
      fail(seed, "bad boss node")
    end
  end)
end)

test("map: every edge spans exactly one layer forward, targets exist, no duplicates", function()
  for_seeds(function(seed, m)
    for _, id in ipairs(node_ids(m)) do
      local n, seen = m.nodes[id], {}
      for _, to in ipairs(m.edges[id] or {}) do
        local t = m.nodes[to]
        if not t then fail(seed, "edge to missing node " .. tostring(to)) end
        if t.layer ~= n.layer + 1 then
          fail(seed, "edge " .. id .. "→" .. to .. " spans " .. (t.layer - n.layer) .. " layers")
        end
        if seen[to] then fail(seed, "duplicate edge " .. id .. "→" .. to) end
        seen[to] = true
      end
    end
  end)
end)

test("map: every node reachable from start (forward BFS covers all nodes)", function()
  for_seeds(function(seed, m)
    local ids = node_ids(m)
    local reached, queue = { [m.start] = true }, { m.start }
    local head = 1
    while head <= #queue do
      local id = queue[head]; head = head + 1
      for _, to in ipairs(m.edges[id] or {}) do
        if not reached[to] then reached[to] = true; queue[#queue + 1] = to end
      end
    end
    for _, id in ipairs(ids) do
      if not reached[id] then fail(seed, "node " .. id .. " unreachable from start") end
    end
  end)
end)

test("map: boss reachable from every node — no dead ends (reverse BFS covers all)", function()
  for_seeds(function(seed, m)
    local ids = node_ids(m)
    local parents = {}
    for _, id in ipairs(ids) do
      for _, to in ipairs(m.edges[id] or {}) do
        parents[to] = parents[to] or {}
        parents[to][#parents[to] + 1] = id
      end
    end
    local reaches, queue = { [m.boss] = true }, { m.boss }
    local head = 1
    while head <= #queue do
      local id = queue[head]; head = head + 1
      for _, p in ipairs(parents[id] or {}) do
        if not reaches[p] then reaches[p] = true; queue[#queue + 1] = p end
      end
    end
    for _, id in ipairs(ids) do
      if not reaches[id] then fail(seed, "boss not reachable from node " .. id) end
    end
    -- Directly: every non-boss node must have ≥1 forward edge.
    for _, id in ipairs(ids) do
      if id ~= m.boss and #(m.edges[id] or {}) == 0 then
        fail(seed, "node " .. id .. " has no forward edge")
      end
    end
  end)
end)

test("map: all forward paths end at the boss (walk any greedy path)", function()
  -- Complements the BFS tests: exhaustively walk every path via DFS with a
  -- per-seed cap; since edges only go forward, path count is finite.
  for_seeds(function(seed, m)
    local walked = 0
    local function dfs(id)
      walked = walked + 1
      if walked > 20000 then return end -- safety cap; maps are tiny
      local out = m.edges[id] or {}
      if #out == 0 then
        if id ~= m.boss then fail(seed, "path dead-ends at node " .. id) end
        return
      end
      for _, to in ipairs(out) do dfs(to) end
    end
    dfs(m.start)
  end)
end)

test("map: kinds valid; elites ≥1 and only on layer 4+ (never layer 9)", function()
  local valid = { start = true, fight = true, elite = true, rest = true, boss = true }
  for_seeds(function(seed, m)
    local elites = 0
    for _, id in ipairs(node_ids(m)) do
      local n = m.nodes[id]
      if not valid[n.kind] then fail(seed, "bad kind " .. tostring(n.kind)) end
      if (n.kind == "start") ~= (id == m.start) then fail(seed, "stray start kind") end
      if (n.kind == "boss") ~= (id == m.boss) then fail(seed, "stray boss kind") end
      if n.kind == "elite" then
        elites = elites + 1
        if n.layer < 4 or n.layer > 8 then
          fail(seed, "elite on layer " .. n.layer)
        end
      end
    end
    if elites < 1 then fail(seed, "no elite node") end
  end)
end)

test("map: rests ≥1 with one on layer 6+ before the boss", function()
  for_seeds(function(seed, m)
    local rests, late = 0, 0
    for _, id in ipairs(node_ids(m)) do
      local n = m.nodes[id]
      if n.kind == "rest" then
        rests = rests + 1
        if n.layer >= 6 and n.layer <= 8 then late = late + 1 end
        if n.layer < 2 or n.layer > 8 then fail(seed, "rest on layer " .. n.layer) end
      end
    end
    if rests < 1 then fail(seed, "no rest node") end
    -- All nodes are reachable from start (proven above), so ≥1 rest on
    -- layer 6..8 ⇒ a rest is guaranteed reachable before the boss.
    if late < 1 then fail(seed, "no rest on layers 6-8") end
  end)
end)

test("map: no two rests adjacent on any path (no rest→rest edge)", function()
  -- Edge-level check is equivalent to the path property: two rests can only
  -- be consecutive on a path if a rest→rest edge exists.
  for_seeds(function(seed, m)
    for _, id in ipairs(node_ids(m)) do
      if m.nodes[id].kind == "rest" then
        for _, to in ipairs(m.edges[id] or {}) do
          if m.nodes[to].kind == "rest" then
            fail(seed, "adjacent rests " .. id .. "→" .. to)
          end
        end
      end
    end
  end)
end)

test("map: seeds actually vary the maps (generator is not constant)", function()
  local distinct = {}
  local count = 0
  for _, seed in ipairs(seed_list()) do
    local s = serialize(gen(seed))
    if not distinct[s] then distinct[s] = true; count = count + 1 end
  end
  -- 200+ seeds must not collapse to a handful of layouts.
  if count < SEEDS / 2 then
    error("only " .. count .. " distinct maps across " .. SEEDS .. " seeds", 0)
  end
end)

test("map: determinism holds from mid-consumed streams too (same rng STATE)", function()
  -- The contract says same rng STATE ⇒ same map — not just fresh streams.
  for i = 1, 50 do
    local seed = i * 104729
    local r1 = RNG.new(seed, "map")
    local r2 = RNG.new(seed, "map")
    for _ = 1, i do r1:next_raw(); r2:next_raw() end -- advance both equally
    if serialize(Map.generate(r1)) ~= serialize(Map.generate(r2)) then
      fail(seed, "mid-stream generates differ")
    end
  end
end)

-- ---------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
