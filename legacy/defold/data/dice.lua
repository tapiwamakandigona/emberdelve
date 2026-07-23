-- data/dice.lua — Emberdelve die roster (M1). CONTENT AS DATA, ZERO LOGIC.
--
-- Schema (docs/m1-contract.md §7):
--   { [id] = { id, name, size, mods = {...} } }
-- Mod vocabulary (exact, resolved by sim/combat.lua — nothing else is legal):
--   attack_bonus=N   +N when assigned to attack
--   block_bonus=N    +N when assigned to block
--   min_value=N      rolls below N become N
--   on_max_bonus=N   +N to the action when the die rolled its max face
--   attack_only=true / block_only=true
--
-- `_order` lists every id in deterministic authoring order (roughly the
-- power curve, starter first). Consumers iterate via `_order`, never pairs().
--
-- Design curve: the run starts on {"d6","d6","d6"} (plain Ember Dice).
-- Early rewards trade variance (steady/keen/stout d6s, spark chip d4),
-- mid-run rewards trade size (d8s, committed blade/aegis), late rewards
-- are jackpot dice (surge d10, ember heart d12).

return {
  _order = {
    "d4", "d4_spark",
    "d6", "d6_keen", "d6_stout", "d6_steady",
    "d8", "d8_blade", "d8_aegis",
    "d10", "d10_surge",
    "d12_heart",
  },

  -- filler / utility tier -------------------------------------------------
  d4 = { -- cheap filler: low ceiling, safe floor for topping off block
    id = "d4", name = "Flint Shard", size = 4, mods = {},
  },
  d4_spark = { -- reliable chip damage: never rolls a dead 1, but can't block
    id = "d4_spark", name = "Spark Chip", size = 4,
    mods = { attack_only = true, min_value = 2 },
  },

  -- starter tier -----------------------------------------------------------
  d6 = { -- THE starter die; run begins with three of these
    id = "d6", name = "Ember Die", size = 6, mods = {},
  },
  d6_keen = { -- first offense upgrade: same swing, +1 edge on attack
    id = "d6_keen", name = "Keen Ember", size = 6,
    mods = { attack_bonus = 1 },
  },
  d6_stout = { -- first defense upgrade: mirror of keen, +1 on block
    id = "d6_stout", name = "Stout Ember", size = 6,
    mods = { block_bonus = 1 },
  },
  d6_steady = { -- variance killer: floor of 3, average 4.0 vs plain 3.5
    id = "d6_steady", name = "Steady Ember", size = 6,
    mods = { min_value = 3 },
  },

  -- mid tier ---------------------------------------------------------------
  d8 = { -- pure size upgrade over the starter
    id = "d8", name = "Deep Coal", size = 8, mods = {},
  },
  d8_blade = { -- committed offense: big hits, useless when you must turtle
    id = "d8_blade", name = "Cinder Blade", size = 8,
    mods = { attack_only = true, attack_bonus = 2 },
  },
  d8_aegis = { -- committed defense: mirror of the blade
    id = "d8_aegis", name = "Ash Aegis", size = 8,
    mods = { block_only = true, block_bonus = 2 },
  },

  -- late tier --------------------------------------------------------------
  d10 = { -- big honest swing die
    id = "d10", name = "Forge Core", size = 10, mods = {},
  },
  d10_surge = { -- jackpot die: a natural 10 surges to 14
    id = "d10_surge", name = "Surge Core", size = 10,
    mods = { on_max_bonus = 4 },
  },
  d12_heart = { -- endgame chase die: floor 2, natural 12 becomes 15
    id = "d12_heart", name = "Ember Heart", size = 12,
    mods = { min_value = 2, on_max_bonus = 3 },
  },
}
