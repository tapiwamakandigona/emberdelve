// data/characters.dart — Playable delvers (M3). CONTENT AS DATA, ZERO LOGIC.
//
// Schema:
//   CharacterDef { id, name, text, maxHp, startDice:[id...], startRelic:<id|null>,
//                  unlockEmbers }
// The first character is free; others unlock via the meta layer (embers).
// start_run injects a character id; run_layer applies maxHp/startDice/startRelic
// deterministically before map entry. Unknown/locked selection at the sim layer
// is treated as the default (the meta layer enforces unlock gating, not the sim).
//
// `charactersOrder` = deterministic authoring order.

class CharacterDef {
  final String id;
  final String name;
  final String text;
  final int maxHp;
  final List<String> startDice;
  final String? startRelic;
  final int unlockEmbers;

  /// v0.135.0 The Runesmith: marks worked before the first floor. Each
  /// entry is {die: 1-based index into startDice, face: natural face,
  /// rune: faceRunes id}, applied deterministically by run_layer at
  /// start_run. These are the SMITH'S marks, not the player's — they do
  /// not count toward tempers_used, runes_tempered, or the temper cap.
  final List<Map<String, Object>> startTempers;
  const CharacterDef(
    this.id,
    this.name,
    this.text, {
    required this.maxHp,
    required this.startDice,
    this.startRelic,
    this.unlockEmbers = 0,
    this.startTempers = const [],
  });
}

const String defaultCharacter = 'kindler';

const List<String> charactersOrder = [
  'kindler',
  'warden',
  'gambler',
  'ascetic',
  'peddler',
  'tinker',
  // v0.118.0 — append-LAST, same discipline as every roster bit.
  'flintwright',
  // v0.135.0 — append-LAST.
  'runesmith',
  // v0.145.0 — append-LAST.
  'bearer',
];

const Map<String, CharacterDef> characters = {
  'kindler': CharacterDef(
    'kindler',
    'The Kindler',
    'The balanced start: three plain Ember Dice, 30 HP.',
    maxHp: 30,
    startDice: ['d6', 'd6', 'd6'],
    unlockEmbers: 0,
  ),
  'warden': CharacterDef(
    'warden',
    'The Warden',
    'Tanky. Extra HP, an Iron Scale, and a Slate Chip guard die.',
    maxHp: 32,
    startDice: ['d6', 'd6', 'd4_guard'],
    startRelic: 'iron_scale',
    unlockEmbers: 120,
  ),
  'gambler': CharacterDef(
    'gambler',
    'The Gambler',
    'High variance. A d4 luck die and a reroll trinket.',
    maxHp: 27,
    startDice: ['d6', 'd6', 'd4_lucky'],
    startRelic: 'gamblers_eye',
    unlockEmbers: 200,
  ),
  'ascetic': CharacterDef(
    'ascetic',
    'The Ascetic',
    'Fragile but sharp: a Brand Iron and a Whetstone, low HP.',
    maxHp: 26,
    startDice: ['d6', 'd6', 'd6_brand'],
    startRelic: 'whetstone',
    unlockEmbers: 320,
  ),
  // v0.40.0 The Peddler: the economy archetype the roster lacked. A weaker
  // pouch than the Kindler (14 pips vs 18), traded for a Kiln Key — every won
  // fight pays +8 gold, so the shops do the delver's forging. Appended
  // LAST so charactersOrder indexes (delve-code bits 31..34, v0.37.0) stay
  // stable for every code already shared.
  'peddler': CharacterDef(
    'peddler',
    'The Peddler',
    'Mercantile. Lean dice and a Kiln Key — every won fight pays well.',
    maxHp: 31,
    startDice: ['d6', 'd6', 'd4'],
    startRelic: 'kiln_key',
    unlockEmbers: 450,
  ),
  // v0.50.0 The Tinker: the control archetype — the roster's variance runs
  // from the Gambler (widest) to nothing at the narrow end until now. A
  // Steady Ember (min 3) under Loaded Pips (min 2 on everything) gives the
  // best floors in the roster, traded for the smallest pip ceiling (16 vs
  // the Kindler's 18). 400-seed sweep: 85.25/58.25/31.0 — in band, normal
  // level with the other skill delvers. Reuses an existing relic on purpose: adding a NEW relic
  // resizes the shop offer pool and re-anchors every golden. Appended LAST
  // so charactersOrder indexes (delve-code bits 31..34) stay stable.
  'tinker': CharacterDef(
    'tinker',
    'The Tinker',
    'Consistent. Steady dice under Loaded Pips — never a dead roll.',
    maxHp: 30,
    startDice: ['d6_steady', 'd6', 'd4'],
    startRelic: 'loaded_pips',
    unlockEmbers: 600,
  ),
  // v0.118.0 The Flintwright: the SWARM archetype — the only delver who
  // starts with FOUR dice, and none of them grand. More rolls, smaller
  // promises, twice the forge futures. Pure data (existing dice only), so
  // seeded runs for every other delver are untouched — no re-anchor.
  // Balance swept before shipping; hp is the tuning knob (see release notes).
  'flintwright': CharacterDef(
    'flintwright',
    'The Flintwright',
    'The swarm: FOUR small dice, 24 HP — shards and chips, nothing grand.',
    maxHp: 24,
    startDice: ['d4', 'd4', 'd4_spark', 'd4_guard'],
    unlockEmbers: 750,
  ),
  // v0.135.0 The Runesmith — the eighth delver, the temper specialist:
  // arrives with one mark already worked (surge on the d8's own top face).
  // HP is the balance knob (sweeps in docs/improvements/v0.135.0): the
  // free mark is real tempo, so the runesmith runs lean.
  'runesmith': CharacterDef(
    'runesmith',
    'The Runesmith',
    'Arrives marked: a Deep Coal with Surge already worked into its 8. '
        'Lean, and the anvil answers them first.',
    maxHp: 26,
    startDice: ['d6', 'd6', 'd8'],
    startTempers: [
      {'die': 3, 'face': 8, 'rune': 'surge'},
    ],
    unlockEmbers: 900,
  ),
  // v0.145.0 The Bearer — the ninth delver, the GIANT: the flintwright's
  // exact opposite pole. TWO dice only, one of them the biggest starting
  // die in any kit (a d10 on floor one). Fewest rolls, grandest promises,
  // and every temper mark lands on half the pouch. Pure data (existing
  // dice only) — no re-anchor. HP is the tuning knob (sweeps in
  // docs/improvements/v0.145.0).
  'bearer': CharacterDef(
    'bearer',
    'The Bearer',
    'The giant: TWO dice, one a Molten Core — few rolls, grand promises.',
    maxHp: 36,
    startDice: ['d12', 'd8'],
    startRelic: 'iron_scale',
    startTempers: [
      {'die': 1, 'face': 12, 'rune': 'echo'},
    ],
    unlockEmbers: 1050,
  ),
};

CharacterDef characterDef(String? id) =>
    characters[id] ?? characters[defaultCharacter]!;
