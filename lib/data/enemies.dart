// data/enemies.dart — Emberdelve enemy roster. CONTENT AS DATA, ZERO LOGIC.
//
// Schema (docs/m2-contract.md §7):
//   EnemyDef { id, name, hp, boss, elite, pattern }
// Intent = pattern entries cycled IN ORDER (index advances each enemy turn;
// deterministic, no RNG). Enemy block absorbs player damage the turn after it
// is gained and resets at enemy turn start.
//
// `enemiesOrder` lists every id in deterministic authoring order. Consumers
// iterate via enemiesOrder, never unordered map iteration.
//
// Balance (M1 pass, measured with the greedy autoplayer): regular/elite/boss
// amounts carry the x2.75 scaling from the recorded balance decision.

class Intent {
  final String kind; // attack | block | attack_block
  final int amount;
  final int block; // only for attack_block
  const Intent(this.kind, this.amount, [this.block = 0]);

  Map<String, Object> toMap() => {
        'kind': kind,
        'amount': amount,
        if (kind == 'attack_block') 'block': block,
      };
}

class EnemyDef {
  final String id;
  final String name;
  final int hp;
  final bool boss;
  final bool elite;
  final List<Intent> pattern;
  const EnemyDef(this.id, this.name, this.hp,
      {this.boss = false, this.elite = false, required this.pattern});
}

const List<String> enemiesOrder = [
  'cinder_wisp', 'ash_rat', 'soot_shade', 'ember_beetle',
  'pyre_howler', 'kiln_golem',
  'ember_tyrant',
];

const Map<String, EnemyDef> enemies = {
  // regulars -------------------------------------------------------------------
  'cinder_wisp': EnemyDef('cinder_wisp', 'Cinder Wisp', 12, pattern: [
    Intent('attack', 11),
    Intent('attack', 14),
    Intent('attack', 8),
  ]),
  'ash_rat': EnemyDef('ash_rat', 'Ash Rat', 10, pattern: [
    Intent('attack', 8),
    Intent('attack', 8),
    Intent('attack_block', 11, 8),
  ]),
  'soot_shade': EnemyDef('soot_shade', 'Soot Shade', 13, pattern: [
    Intent('attack_block', 8, 8),
    Intent('attack', 14),
  ]),
  'ember_beetle': EnemyDef('ember_beetle', 'Ember Beetle', 15, pattern: [
    Intent('block', 14),
    Intent('attack', 16),
  ]),

  // elites ---------------------------------------------------------------------
  'pyre_howler': EnemyDef('pyre_howler', 'Pyre Howler', 20, elite: true, pattern: [
    Intent('attack', 16),
    Intent('attack_block', 14, 11),
    Intent('attack', 19),
  ]),
  'kiln_golem': EnemyDef('kiln_golem', 'Kiln Golem', 24, elite: true, pattern: [
    Intent('block', 16),
    Intent('attack', 19),
    Intent('attack_block', 14, 14),
  ]),

  // boss (exactly one in act 1) --------------------------------------------------
  'ember_tyrant': EnemyDef('ember_tyrant', 'Ember Tyrant', 42, boss: true, pattern: [
    Intent('attack', 16),
    Intent('block', 22),
    Intent('attack_block', 19, 14),
    Intent('attack', 25),
  ]),
};

EnemyDef enemyDef(String id) {
  final def = enemies[id];
  if (def == null) throw ArgumentError('unknown enemy id: $id');
  return def;
}
