// data/dice.dart — Emberdelve die roster (M3 content). CONTENT AS DATA, ZERO LOGIC.
//
// Schema (docs/m3-contract.md §7):
//   DieDef { id, name, size, tier, mods, forgeTo }
// Mod vocabulary (exact — resolved by sim/combat.dart, nothing else is legal):
//   attack_bonus=N   +N when assigned to attack
//   block_bonus=N    +N when assigned to block
//   min_value=N      rolls below N become N
//   on_max_bonus=N   +N to the action when the die rolled its max face
//   attack_only=true / block_only=true
//
// Tier rule: size<=6 -> 1, size==8 -> 2, size>=10 -> 3. Tiers gate reward and
// shop pools by map layer (early layers never offer jackpot dice).
// forgeTo lists what a die can become at a forge (rest node alternative).
//
// `diceOrder` lists every id in deterministic authoring order. Consumers that
// consume randomness iterate via diceOrder, never map iteration order.

class DieDef {
  final String id;
  final String name;
  final int size;
  final int tier;
  final Map<String, Object> mods;
  final List<String> forgeTo;
  const DieDef(this.id, this.name, this.size,
      {required this.tier, this.mods = const {}, this.forgeTo = const []});
}

const List<String> diceOrder = [
  // tier 1 — d4 utility
  'd4', 'd4_spark', 'd4_guard', 'd4_lucky',
  // tier 1 — d6 core
  'd6', 'd6_keen', 'd6_stout', 'd6_steady', 'd6_brand', 'd6_ward',
  'd6_ember', 'd6_forged',
  // tier 2 — d8
  'd8', 'd8_keen', 'd8_stout', 'd8_steady', 'd8_blade', 'd8_aegis', 'd8_surge',
  // tier 3 — d10
  'd10', 'd10_keen', 'd10_steady', 'd10_blade', 'd10_aegis', 'd10_surge',
  // tier 3 — d12
  'd12', 'd12_heart', 'd12_titan', 'd12_fury', 'd12_bulwark',
];

const Map<String, DieDef> dice = {
  // ---- tier 1: d4 utility ---------------------------------------------------
  'd4': DieDef('d4', 'Flint Shard', 4, tier: 1, forgeTo: ['d6']),
  'd4_spark': DieDef('d4_spark', 'Spark Chip', 4,
      tier: 1,
      mods: {'attack_only': true, 'min_value': 2},
      forgeTo: ['d6_brand']),
  'd4_guard': DieDef('d4_guard', 'Slate Chip', 4,
      tier: 1,
      mods: {'block_only': true, 'min_value': 2},
      forgeTo: ['d6_ward']),
  'd4_lucky': DieDef('d4_lucky', 'Charm Bone', 4,
      tier: 1, mods: {'on_max_bonus': 3}, forgeTo: ['d6_ember']),

  // ---- tier 1: d6 core --------------------------------------------------------
  'd6': DieDef('d6', 'Ember Die', 6, tier: 1, forgeTo: ['d8', 'd6_forged']),
  'd6_keen': DieDef('d6_keen', 'Keen Ember', 6,
      tier: 1, mods: {'attack_bonus': 1}, forgeTo: ['d8_keen']),
  'd6_stout': DieDef('d6_stout', 'Stout Ember', 6,
      tier: 1, mods: {'block_bonus': 1}, forgeTo: ['d8_stout']),
  'd6_steady': DieDef('d6_steady', 'Steady Ember', 6,
      tier: 1, mods: {'min_value': 3}, forgeTo: ['d8_steady']),
  'd6_brand': DieDef('d6_brand', 'Brand Iron', 6,
      tier: 1,
      mods: {'attack_only': true, 'attack_bonus': 2},
      forgeTo: ['d8_blade']),
  'd6_ward': DieDef('d6_ward', 'Ward Iron', 6,
      tier: 1,
      mods: {'block_only': true, 'block_bonus': 2},
      forgeTo: ['d8_aegis']),
  'd6_ember': DieDef('d6_ember', 'Glowing Ember', 6,
      tier: 1, mods: {'on_max_bonus': 2}, forgeTo: ['d8_surge']),
  'd6_forged': DieDef('d6_forged', 'Forged Ember', 6,
      tier: 1,
      mods: {'attack_bonus': 1, 'block_bonus': 1},
      forgeTo: ['d8']),

  // ---- tier 2: d8 -------------------------------------------------------------
  'd8': DieDef('d8', 'Deep Coal', 8, tier: 2, forgeTo: ['d10']),
  'd8_keen': DieDef('d8_keen', 'Keen Coal', 8,
      tier: 2, mods: {'attack_bonus': 1}, forgeTo: ['d10_keen']),
  'd8_stout': DieDef('d8_stout', 'Stout Coal', 8,
      tier: 2, mods: {'block_bonus': 1}, forgeTo: ['d10_aegis']),
  'd8_steady': DieDef('d8_steady', 'Steady Coal', 8,
      tier: 2, mods: {'min_value': 3}, forgeTo: ['d10_steady']),
  'd8_blade': DieDef('d8_blade', 'Cinder Blade', 8,
      tier: 2,
      mods: {'attack_only': true, 'attack_bonus': 2},
      forgeTo: ['d10_blade']),
  'd8_aegis': DieDef('d8_aegis', 'Ash Aegis', 8,
      tier: 2,
      mods: {'block_only': true, 'block_bonus': 2},
      forgeTo: ['d10_aegis']),
  'd8_surge': DieDef('d8_surge', 'Surge Coal', 8,
      tier: 2, mods: {'on_max_bonus': 3}, forgeTo: ['d10_surge']),

  // ---- tier 3: d10 ------------------------------------------------------------
  'd10': DieDef('d10', 'Forge Core', 10, tier: 3, forgeTo: ['d12']),
  'd10_keen': DieDef('d10_keen', 'Keen Core', 10,
      tier: 3, mods: {'attack_bonus': 2}, forgeTo: ['d12_fury']),
  'd10_steady': DieDef('d10_steady', 'Steady Core', 10,
      tier: 3, mods: {'min_value': 4}, forgeTo: ['d12_titan']),
  'd10_blade': DieDef('d10_blade', 'Molten Blade', 10,
      tier: 3,
      mods: {'attack_only': true, 'attack_bonus': 3},
      forgeTo: ['d12_fury']),
  'd10_aegis': DieDef('d10_aegis', 'Molten Aegis', 10,
      tier: 3,
      mods: {'block_only': true, 'block_bonus': 3},
      forgeTo: ['d12_bulwark']),
  'd10_surge': DieDef('d10_surge', 'Surge Core', 10,
      tier: 3, mods: {'on_max_bonus': 4}, forgeTo: ['d12_heart']),

  // ---- tier 3: d12 ------------------------------------------------------------
  'd12': DieDef('d12', 'Molten Core', 12, tier: 3),
  'd12_heart': DieDef('d12_heart', 'Ember Heart', 12,
      tier: 3, mods: {'min_value': 2, 'on_max_bonus': 3}),
  'd12_titan': DieDef('d12_titan', 'Titan Core', 12,
      tier: 3, mods: {'min_value': 3, 'block_bonus': 1}),
  'd12_fury': DieDef('d12_fury', 'Fury Core', 12,
      tier: 3, mods: {'attack_only': true, 'attack_bonus': 3}),
  'd12_bulwark': DieDef('d12_bulwark', 'Bulwark Core', 12,
      tier: 3, mods: {'block_only': true, 'block_bonus': 4}),
};

DieDef dieDef(String id) {
  final def = dice[id];
  if (def == null) throw ArgumentError('unknown die id: $id');
  return def;
}
