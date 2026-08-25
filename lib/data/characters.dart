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
  const CharacterDef(
    this.id,
    this.name,
    this.text, {
    required this.maxHp,
    required this.startDice,
    this.startRelic,
    this.unlockEmbers = 0,
  });
}

const String defaultCharacter = 'kindler';

const List<String> charactersOrder = [
  'kindler',
  'warden',
  'gambler',
  'ascetic',
  'peddler',
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
};

CharacterDef characterDef(String? id) =>
    characters[id] ?? characters[defaultCharacter]!;
