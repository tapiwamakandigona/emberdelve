// data/dice.dart — Emberdelve die roster. CONTENT AS DATA, ZERO LOGIC.
//
// Schema (docs/m2-contract.md §7):
//   DieDef { id, name, size, tier, mods, forgeTo }
// Mod vocabulary (exact — resolved by sim/combat.dart, nothing else is legal):
//   attack_bonus=N   +N when assigned to attack
//   block_bonus=N    +N when assigned to block
//   min_value=N      rolls below N become N
//   on_max_bonus=N   +N to the action when the die rolled its max face
//   attack_only=true / block_only=true
//
// `diceOrder` lists every id in deterministic authoring order (power curve,
// starter first). Consumers iterate via diceOrder, never map iteration order
// that consumes randomness.

class DieDef {
  final String id;
  final String name;
  final int size;
  final int tier; // 1 early / 2 mid / 3 late — gates reward & shop pools
  final Map<String, Object> mods;
  final List<String> forgeTo; // die ids this die can be forged into
  const DieDef(this.id, this.name, this.size,
      {this.tier = 1, this.mods = const {}, this.forgeTo = const []});
}

const List<String> diceOrder = [
  'd4', 'd4_spark',
  'd6', 'd6_keen', 'd6_stout', 'd6_steady',
  'd8', 'd8_blade', 'd8_aegis',
  'd10', 'd10_surge',
  'd12_heart',
];

const Map<String, DieDef> dice = {
  // filler / utility tier ----------------------------------------------------
  'd4': DieDef('d4', 'Flint Shard', 4, tier: 1),
  'd4_spark': DieDef('d4_spark', 'Spark Chip', 4,
      tier: 1, mods: {'attack_only': true, 'min_value': 2}),

  // starter tier ---------------------------------------------------------------
  'd6': DieDef('d6', 'Ember Die', 6, tier: 1),
  'd6_keen': DieDef('d6_keen', 'Keen Ember', 6,
      tier: 1, mods: {'attack_bonus': 1}),
  'd6_stout': DieDef('d6_stout', 'Stout Ember', 6,
      tier: 1, mods: {'block_bonus': 1}),
  'd6_steady': DieDef('d6_steady', 'Steady Ember', 6,
      tier: 1, mods: {'min_value': 3}),

  // mid tier -------------------------------------------------------------------
  'd8': DieDef('d8', 'Deep Coal', 8, tier: 2),
  'd8_blade': DieDef('d8_blade', 'Cinder Blade', 8,
      tier: 2, mods: {'attack_only': true, 'attack_bonus': 2}),
  'd8_aegis': DieDef('d8_aegis', 'Ash Aegis', 8,
      tier: 2, mods: {'block_only': true, 'block_bonus': 2}),

  // late tier ------------------------------------------------------------------
  'd10': DieDef('d10', 'Forge Core', 10, tier: 3),
  'd10_surge': DieDef('d10_surge', 'Surge Core', 10,
      tier: 3, mods: {'on_max_bonus': 4}),
  'd12_heart': DieDef('d12_heart', 'Ember Heart', 12,
      tier: 3, mods: {'min_value': 2, 'on_max_bonus': 3}),
};

DieDef dieDef(String id) {
  final def = dice[id];
  if (def == null) throw ArgumentError('unknown die id: $id');
  return def;
}
