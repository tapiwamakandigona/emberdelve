// data/enemies.dart — Emberdelve enemy roster (M3 content: 15 enemies).
// CONTENT AS DATA, ZERO LOGIC.
//
// Schema (docs/m3-contract.md §7):
//   EnemyDef { id, name, hp, boss, elite, fromLayer, pattern }
// Intent = pattern entries cycled IN ORDER (deterministic, no RNG). Enemy
// block absorbs player damage the turn after it is gained; resets at enemy
// turn start. fromLayer gates spawns: an enemy is eligible at fight/elite
// nodes on layer >= fromLayer (keeps the early curve gentle and deepens the
// bestiary later in the run).
//
// `enemiesOrder` lists every id in deterministic authoring order. Consumers
// iterate via enemiesOrder, never unordered map iteration.
//
// Balance: the roster carries the measured x2.75 M1 scaling; late-band regulars
// threaten ~13-18/turn, elites ~16-22, boss ~16-25 with a block cycle.

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
  final int fromLayer;
  final List<Intent> pattern;
  const EnemyDef(this.id, this.name, this.hp,
      {this.boss = false,
      this.elite = false,
      this.fromLayer = 2,
      required this.pattern});
}

const List<String> enemiesOrder = [
  // regulars — early band
  'cinder_wisp', 'ash_rat', 'soot_shade', 'ember_beetle',
  // regulars — late band (layer 5+)
  'soot_hound', 'ash_wraith', 'cinder_crawler', 'ember_moth', 'slag_brute',
  // elites
  'pyre_howler', 'kiln_golem', 'ash_reaper', 'forge_warden', 'molten_maw',
  // boss
  'ember_tyrant',
];

const Map<String, EnemyDef> enemies = {
  // ---- regulars, early band (layer 2+) ---------------------------------------
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

  // ---- regulars, late band (layer 5+) ----------------------------------------
  'soot_hound': EnemyDef('soot_hound', 'Soot Hound', 18, fromLayer: 5, pattern: [
    Intent('attack', 13),
    Intent('attack', 13),
    Intent('attack_block', 10, 10),
  ]),
  'ash_wraith': EnemyDef('ash_wraith', 'Ash Wraith', 16, fromLayer: 5, pattern: [
    Intent('block', 16),
    Intent('attack', 18),
    Intent('attack', 12),
  ]),
  'cinder_crawler':
      EnemyDef('cinder_crawler', 'Cinder Crawler', 20, fromLayer: 5, pattern: [
    Intent('attack_block', 11, 11),
    Intent('attack_block', 11, 11),
    Intent('attack', 17),
  ]),
  'ember_moth': EnemyDef('ember_moth', 'Ember Moth', 14, fromLayer: 5, pattern: [
    Intent('attack', 16),
    Intent('block', 12),
    Intent('attack', 18),
  ]),
  'slag_brute': EnemyDef('slag_brute', 'Slag Brute', 24, fromLayer: 6, pattern: [
    Intent('block', 18),
    Intent('attack', 21),
  ]),

  // ---- elites ------------------------------------------------------------------
  'pyre_howler':
      EnemyDef('pyre_howler', 'Pyre Howler', 20, elite: true, pattern: [
    Intent('attack', 16),
    Intent('attack_block', 14, 11),
    Intent('attack', 19),
  ]),
  'kiln_golem': EnemyDef('kiln_golem', 'Kiln Golem', 24, elite: true, pattern: [
    Intent('block', 16),
    Intent('attack', 19),
    Intent('attack_block', 14, 14),
  ]),
  'ash_reaper':
      EnemyDef('ash_reaper', 'Ash Reaper', 26, elite: true, fromLayer: 5, pattern: [
    Intent('attack', 20),
    Intent('attack', 14),
    Intent('attack_block', 17, 13),
  ]),
  'forge_warden': EnemyDef('forge_warden', 'Forge Warden', 30,
      elite: true, fromLayer: 5, pattern: [
    Intent('block', 20),
    Intent('attack_block', 15, 15),
    Intent('attack', 22),
  ]),
  'molten_maw':
      EnemyDef('molten_maw', 'Molten Maw', 28, elite: true, fromLayer: 6, pattern: [
    Intent('attack', 24),
    Intent('block', 18),
    Intent('attack', 18),
  ]),

  // ---- boss (exactly one in act 1) -----------------------------------------------
  'ember_tyrant':
      EnemyDef('ember_tyrant', 'Ember Tyrant', 42, boss: true, pattern: [
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
