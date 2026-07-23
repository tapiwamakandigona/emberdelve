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
// Balance: v0.3.0 gameplay-depth rebalance (measured, not guessed): the v0.2.0
// roster was rescaled hp x2.4, attack +7, block +5 to absorb the player-power
// gains from combos, the risky reroll, starting boons, overkill splash, and
// the smarter greedy bot. 200-seed autoplay win rate: 53.5% (was 53.5% before
// the v0.3.0 features; it had drifted to 100% pre-rebalance). Late-band
// regulars threaten ~19-28/turn, elites ~21-31, boss ~23-32 with a block cycle.

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
  'cinder_wisp': EnemyDef('cinder_wisp', 'Cinder Wisp', 29, pattern: [
    Intent('attack', 18),
    Intent('attack', 21),
    Intent('attack', 15),
  ]),
  'ash_rat': EnemyDef('ash_rat', 'Ash Rat', 24, pattern: [
    Intent('attack', 15),
    Intent('attack', 15),
    Intent('attack_block', 18, 14),
  ]),
  'soot_shade': EnemyDef('soot_shade', 'Soot Shade', 31, pattern: [
    Intent('attack_block', 15, 14),
    Intent('attack', 21),
  ]),
  'ember_beetle': EnemyDef('ember_beetle', 'Ember Beetle', 36, pattern: [
    Intent('block', 20),
    Intent('attack', 23),
  ]),

  // ---- regulars, late band (layer 5+) ----------------------------------------
  'soot_hound': EnemyDef('soot_hound', 'Soot Hound', 43, fromLayer: 5, pattern: [
    Intent('attack', 20),
    Intent('attack', 20),
    Intent('attack_block', 17, 16),
  ]),
  'ash_wraith': EnemyDef('ash_wraith', 'Ash Wraith', 38, fromLayer: 5, pattern: [
    Intent('block', 22),
    Intent('attack', 25),
    Intent('attack', 19),
  ]),
  'cinder_crawler':
      EnemyDef('cinder_crawler', 'Cinder Crawler', 48, fromLayer: 5, pattern: [
    Intent('attack_block', 18, 17),
    Intent('attack_block', 18, 17),
    Intent('attack', 24),
  ]),
  'ember_moth': EnemyDef('ember_moth', 'Ember Moth', 34, fromLayer: 5, pattern: [
    Intent('attack', 23),
    Intent('block', 18),
    Intent('attack', 25),
  ]),
  'slag_brute': EnemyDef('slag_brute', 'Slag Brute', 58, fromLayer: 6, pattern: [
    Intent('block', 24),
    Intent('attack', 28),
  ]),

  // ---- elites ------------------------------------------------------------------
  'pyre_howler':
      EnemyDef('pyre_howler', 'Pyre Howler', 48, elite: true, pattern: [
    Intent('attack', 23),
    Intent('attack_block', 21, 17),
    Intent('attack', 26),
  ]),
  'kiln_golem': EnemyDef('kiln_golem', 'Kiln Golem', 58, elite: true, pattern: [
    Intent('block', 22),
    Intent('attack', 26),
    Intent('attack_block', 21, 20),
  ]),
  'ash_reaper':
      EnemyDef('ash_reaper', 'Ash Reaper', 62, elite: true, fromLayer: 5, pattern: [
    Intent('attack', 27),
    Intent('attack', 21),
    Intent('attack_block', 24, 19),
  ]),
  'forge_warden': EnemyDef('forge_warden', 'Forge Warden', 72,
      elite: true, fromLayer: 5, pattern: [
    Intent('block', 26),
    Intent('attack_block', 22, 21),
    Intent('attack', 29),
  ]),
  'molten_maw':
      EnemyDef('molten_maw', 'Molten Maw', 67, elite: true, fromLayer: 6, pattern: [
    Intent('attack', 31),
    Intent('block', 24),
    Intent('attack', 25),
  ]),

  // ---- boss (exactly one in act 1) -----------------------------------------------
  'ember_tyrant':
      EnemyDef('ember_tyrant', 'Ember Tyrant', 101, boss: true, pattern: [
    Intent('attack', 23),
    Intent('block', 28),
    Intent('attack_block', 26, 20),
    Intent('attack', 32),
  ]),
};

EnemyDef enemyDef(String id) {
  final def = enemies[id];
  if (def == null) throw ArgumentError('unknown enemy id: $id');
  return def;
}
