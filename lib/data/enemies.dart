// data/enemies.dart — Emberdelve enemy roster (v0.5.0: 30 enemies).
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
  const EnemyDef(
    this.id,
    this.name,
    this.hp, {
    this.boss = false,
    this.elite = false,
    this.fromLayer = 2,
    required this.pattern,
  });
}

const List<String> enemiesOrder = [
  // regulars — early band
  'cinder_wisp', 'ash_rat', 'soot_shade', 'ember_beetle',
  // regulars — early band, v0.5.0 additions
  'scoria_tick', 'char_sprite', 'flue_crawler', 'cinder_pup',
  // regulars — late band (layer 5+)
  'soot_hound', 'ash_wraith', 'cinder_crawler', 'ember_moth', 'slag_brute',
  // regulars — late band, v0.5.0 additions
  'clinker_ogre', 'smoke_stalker', 'basalt_shell', 'wick_widow',
  // elites
  'pyre_howler', 'kiln_golem', 'ash_reaper', 'forge_warden', 'molten_maw',
  // elites — v0.5.0 additions
  'bellows_knight', 'quench_hag',
  // bosses (exactly one per run, chosen deterministically from the run seed
  // in run_layer.dart — see bossForSeed). Ordering is deliberate: the golden
  // anchor seed (20260723 % 3 == 1) must keep mapping to the Ember Tyrant so
  // the long-lived v6 golden replay stays valid. Append new bosses at the
  // END; never reorder.
  'ashen_colossus', 'ember_tyrant', 'pyre_matriarch',
  // v0.5.0 bosses, appended. Verified before adding: bossForSeed indexes
  // _bossIds by `seed % length`, and the golden anchor seed 20260723 is
  // congruent to 1 both mod 3 and mod 6, so index 1 (ember_tyrant) still wins
  // for that seed and the v6 golden replay stays valid. Going from 6 to any
  // other count must be re-checked the same way BEFORE it is committed.
  'cinder_hierophant', 'the_bellows', 'ashfall_twins',
];

const Map<String, EnemyDef> enemies = {
  // ---- regulars, early band (layer 2+) ---------------------------------------
  'cinder_wisp': EnemyDef(
    'cinder_wisp',
    'Cinder Wisp',
    29,
    pattern: [Intent('attack', 18), Intent('attack', 21), Intent('attack', 15)],
  ),
  'ash_rat': EnemyDef(
    'ash_rat',
    'Ash Rat',
    24,
    pattern: [
      Intent('attack', 15),
      Intent('attack', 15),
      Intent('attack_block', 18, 14),
    ],
  ),
  'soot_shade': EnemyDef(
    'soot_shade',
    'Soot Shade',
    31,
    pattern: [Intent('attack_block', 15, 14), Intent('attack', 21)],
  ),
  'ember_beetle': EnemyDef(
    'ember_beetle',
    'Ember Beetle',
    36,
    pattern: [Intent('block', 20), Intent('attack', 23)],
  ),
  // v0.5.0 early additions. Same band as the four above (hp 24-36, swings
  // 15-23) so the opening layers are more varied without getting harder.
  // Each one has a different RHYTHM, which is the point: a new sprite with an
  // old pattern is not new content.
  'scoria_tick': EnemyDef(
    'scoria_tick',
    'Scoria Tick',
    26,
    pattern: [
      // Two small bites then a real one — punishes blocking on the wrong beat.
      Intent('attack', 14),
      Intent('attack', 14),
      Intent('attack', 22),
    ],
  ),
  'char_sprite': EnemyDef(
    'char_sprite',
    'Char Sprite',
    30,
    pattern: [
      // Guards every other beat: the shortest possible block cycle to read.
      Intent('block', 18),
      Intent('attack', 20),
      Intent('block', 18),
      Intent('attack', 16),
    ],
  ),
  'flue_crawler': EnemyDef(
    'flue_crawler',
    'Flue Crawler',
    33,
    pattern: [Intent('attack_block', 16, 12), Intent('attack', 19)],
  ),
  'cinder_pup': EnemyDef(
    'cinder_pup',
    'Cinder Pup',
    24,
    pattern: [
      // Front-loaded: hits hardest on the beat you meet it, then tires.
      Intent('attack', 21),
      Intent('attack', 15),
      Intent('attack', 15),
    ],
  ),

  // ---- regulars, late band (layer 5+) ----------------------------------------
  'soot_hound': EnemyDef(
    'soot_hound',
    'Soot Hound',
    43,
    fromLayer: 5,
    pattern: [
      Intent('attack', 20),
      Intent('attack', 20),
      Intent('attack_block', 17, 16),
    ],
  ),
  'ash_wraith': EnemyDef(
    'ash_wraith',
    'Ash Wraith',
    38,
    fromLayer: 5,
    pattern: [Intent('block', 22), Intent('attack', 25), Intent('attack', 19)],
  ),
  'cinder_crawler': EnemyDef(
    'cinder_crawler',
    'Cinder Crawler',
    48,
    fromLayer: 5,
    pattern: [
      Intent('attack_block', 18, 17),
      Intent('attack_block', 18, 17),
      Intent('attack', 24),
    ],
  ),
  'ember_moth': EnemyDef(
    'ember_moth',
    'Ember Moth',
    34,
    fromLayer: 5,
    pattern: [Intent('attack', 23), Intent('block', 18), Intent('attack', 25)],
  ),
  'slag_brute': EnemyDef(
    'slag_brute',
    'Slag Brute',
    58,
    fromLayer: 6,
    pattern: [Intent('block', 24), Intent('attack', 28)],
  ),
  // v0.5.0 late additions — inside the measured late band (hp 34-58, swings
  // 19-28) so the 200-seed autoplay win rate stays in the 20-80% gate.
  'clinker_ogre': EnemyDef(
    'clinker_ogre',
    'Clinker Ogre',
    55,
    fromLayer: 5,
    pattern: [Intent('attack', 26), Intent('block', 21), Intent('attack', 22)],
  ),
  'smoke_stalker': EnemyDef(
    'smoke_stalker',
    'Smoke Stalker',
    40,
    fromLayer: 5,
    pattern: [
      // Never guards: a pure race, the late-band answer to the Pyre Matriarch.
      Intent('attack', 21),
      Intent('attack', 24),
      Intent('attack', 27),
    ],
  ),
  'basalt_shell': EnemyDef(
    'basalt_shell',
    'Basalt Shell',
    52,
    fromLayer: 5,
    pattern: [
      // Two guarded beats in three: the one to burst through, not chip at.
      Intent('block', 23),
      Intent('attack_block', 19, 18),
      Intent('attack', 25),
    ],
  ),
  'wick_widow': EnemyDef(
    'wick_widow',
    'Wick Widow',
    37,
    fromLayer: 6,
    pattern: [Intent('attack_block', 20, 15), Intent('attack', 28)],
  ),

  // ---- elites ------------------------------------------------------------------
  'pyre_howler': EnemyDef(
    'pyre_howler',
    'Pyre Howler',
    48,
    elite: true,
    pattern: [
      Intent('attack', 23),
      Intent('attack_block', 21, 17),
      Intent('attack', 26),
    ],
  ),
  'kiln_golem': EnemyDef(
    'kiln_golem',
    'Kiln Golem',
    58,
    elite: true,
    pattern: [
      Intent('block', 22),
      Intent('attack', 26),
      Intent('attack_block', 21, 20),
    ],
  ),
  'ash_reaper': EnemyDef(
    'ash_reaper',
    'Ash Reaper',
    62,
    elite: true,
    fromLayer: 5,
    pattern: [
      Intent('attack', 27),
      Intent('attack', 21),
      Intent('attack_block', 24, 19),
    ],
  ),
  'forge_warden': EnemyDef(
    'forge_warden',
    'Forge Warden',
    72,
    elite: true,
    fromLayer: 5,
    pattern: [
      Intent('block', 26),
      Intent('attack_block', 22, 21),
      Intent('attack', 29),
    ],
  ),
  'molten_maw': EnemyDef(
    'molten_maw',
    'Molten Maw',
    67,
    elite: true,
    fromLayer: 6,
    pattern: [Intent('attack', 31), Intent('block', 24), Intent('attack', 25)],
  ),
  // v0.5.0 elite additions — elite band (hp 48-72, swings 21-31).
  'bellows_knight': EnemyDef(
    'bellows_knight',
    'Bellows Knight',
    70,
    elite: true,
    fromLayer: 5,
    pattern: [
      // Alternating wall: guard, swing, guard, bigger swing. Rewards saving a
      // big die for the open beat instead of spending every turn.
      Intent('block', 25),
      Intent('attack', 24),
      Intent('block', 22),
      Intent('attack', 30),
    ],
  ),
  'quench_hag': EnemyDef(
    'quench_hag',
    'Quench Hag',
    51,
    elite: true,
    pattern: [
      // Squishiest elite, hits like the hardest: an early-layer gamble.
      Intent('attack', 29),
      Intent('attack_block', 23, 16),
      Intent('attack', 26),
    ],
  ),

  // ---- bosses (exactly one per run, seed-picked) ----------------------------------
  // v0.4 boss variety: three bosses with deliberately different rhythms, all
  // built from the same honest Intent vocabulary (no new mechanics):
  //   ember_tyrant   — the balanced 4-beat teacher (unchanged since v0.1).
  //   ashen_colossus — the siege wall: guards two beats in three, then one
  //                    giant swing; open beat is the player turn right after
  //                    the swing. Tankiest, slowest.
  //   pyre_matriarch — the race: never guards, escalating 3-beat burn; every
  //                    player turn lands full but so does hers. Least HP.
  'ember_tyrant': EnemyDef(
    'ember_tyrant',
    'Ember Tyrant',
    101,
    boss: true,
    pattern: [
      Intent('attack', 23),
      Intent('block', 28),
      Intent('attack_block', 26, 20),
      Intent('attack', 32),
    ],
  ),
  'ashen_colossus': EnemyDef(
    'ashen_colossus',
    'Ashen Colossus',
    112,
    boss: true,
    pattern: [
      Intent('block', 26),
      Intent('attack_block', 23, 22),
      Intent('attack', 36),
    ],
  ),
  'pyre_matriarch': EnemyDef(
    'pyre_matriarch',
    'Pyre Matriarch',
    94,
    boss: true,
    pattern: [Intent('attack', 21), Intent('attack', 25), Intent('attack', 29)],
  ),
  // v0.5.0 bosses. Same Intent vocabulary, three more rhythms, boss band
  // (hp 94-112, swings 21-36):
  //   cinder_hierophant — the long teacher: a 5-beat cycle, the longest in the
  //                       game, with two open beats. Learnable, punishing to
  //                       anyone who does not count.
  //   the_bellows       — the pressure plate: guards and swings on the SAME
  //                       beat every beat, so there is never a free hit; you
  //                       out-scale it or you lose.
  //   ashfall_twins     — the double tap: two medium hits back to back, then a
  //                       guard. Kills anyone hoarding block for one big swing.
  'cinder_hierophant': EnemyDef(
    'cinder_hierophant',
    'Cinder Hierophant',
    106,
    boss: true,
    pattern: [
      Intent('attack', 24),
      Intent('block', 27),
      Intent('attack', 22),
      Intent('attack_block', 25, 21),
      Intent('attack', 31),
    ],
  ),
  'the_bellows': EnemyDef(
    'the_bellows',
    'The Bellows',
    98,
    boss: true,
    pattern: [
      Intent('attack_block', 24, 22),
      Intent('attack_block', 27, 19),
      Intent('attack_block', 22, 25),
    ],
  ),
  'ashfall_twins': EnemyDef(
    'ashfall_twins',
    'Ashfall Twins',
    104,
    boss: true,
    pattern: [
      Intent('attack', 26),
      Intent('attack', 26),
      Intent('block', 24),
      Intent('attack', 33),
    ],
  ),
};

EnemyDef enemyDef(String id) {
  final def = enemies[id];
  if (def == null) throw ArgumentError('unknown enemy id: $id');
  return def;
}
