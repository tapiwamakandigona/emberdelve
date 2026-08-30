// data/attire.dart — Delver dyes (v0.27.0, The Delver's Wardrobe). CONTENT AS
// DATA, ZERO LOGIC.
//
// Ember-priced recolors for the player character sprite, answering the first
// outside player ask ("add character customisation"). Same charter as hearth
// colors and dice skins (docs/spec.md §Ethics): pure cosmetics, real prices
// shown up front, no gameplay effect, no timers/FOMO. A dye never changes
// stats, dice, or hit-boxes — only the paint on the delver.
//
// Schema:
//   DelverDyeDef { id, name, text, costEmbers, hueDeg, satMul, valMul }
// hueDeg = hue rotation in degrees applied to the sprite (the UI layer builds
// the ColorFilter matrix — see Art.dyeFilter). satMul/valMul scale saturation
// and brightness. A plain multiply tint was tried first and REJECTED by
// visual critique: multiplying can only darken, so a red-cloaked delver never
// visibly changed (all eight dyes read identical on the plate). Hue rotation
// actually turns the cloak blue/green/violet.
//
// The default 'undyed' is the identity (0°, 1.0, 1.0): a profile that never
// buys anything renders pixel-for-pixel as before this file existed.

class DelverDyeDef {
  final String id;
  final String name;
  final String text;
  final int costEmbers;
  final double hueDeg;
  final double satMul;
  final double valMul;
  const DelverDyeDef(
    this.id,
    this.name,
    this.text, {
    required this.costEmbers,
    this.hueDeg = 0,
    this.satMul = 1,
    this.valMul = 1,
  });
}

const String defaultDye = 'undyed';

const List<String> delverDyesOrder = [
  'undyed',
  'emberwash',
  'goldthread',
  'mosscloak',
  'frostveil',
  'duskrose',
  'palewisp',
  'wyrmshade',
  'emberheart', // v0.94.0 The Deep Wardrobe
  'glowmere', // v0.94.0 The Deep Wardrobe
  'forgesoot', // v0.128.0 The Smith's Shelf
];

const Map<String, DelverDyeDef> delverDyes = {
  'undyed': DelverDyeDef(
    'undyed',
    'Undyed',
    'Travel cloth as the tailor cut it, ash and all.',
    costEmbers: 0,
  ),
  'emberwash': DelverDyeDef(
    'emberwash',
    'Emberwash',
    'Cloth rinsed in forge-water; it burns a shade brighter.',
    costEmbers: 80,
    hueDeg: 18,
    satMul: 1.15,
    valMul: 1.06,
  ),
  'goldthread': DelverDyeDef(
    'goldthread',
    'Goldthread',
    'Fine wire of kiln-gold worked through every seam.',
    costEmbers: 120,
    hueDeg: 42,
    satMul: 1.05,
    valMul: 1.1,
  ),
  'mosscloak': DelverDyeDef(
    'mosscloak',
    'Mosscloak',
    'Steeped in glowworm moss until the weave took the green.',
    costEmbers: 160,
    hueDeg: 105,
    satMul: 0.9,
  ),
  'frostveil': DelverDyeDef(
    'frostveil',
    'Frostveil',
    'A cold rinse from the ice delves, pale and clean.',
    costEmbers: 200,
    hueDeg: 210,
    satMul: 0.85,
    valMul: 1.05,
  ),
  'duskrose': DelverDyeDef(
    'duskrose',
    'Duskrose',
    'The last pink of the sky, carried down into the dark.',
    costEmbers: 260,
    hueDeg: -35,
    satMul: 0.8,
    valMul: 1.08,
  ),
  'palewisp': DelverDyeDef(
    'palewisp',
    'Palewisp',
    'Bleached by wisp-light to a ghostly, moon-fed grey.',
    costEmbers: 320,
    satMul: 0.22,
    valMul: 1.12,
  ),
  'wyrmshade': DelverDyeDef(
    'wyrmshade',
    'Wyrmshade',
    'Violet from crushed wyrmscale; the deep delvers swear by it.',
    costEmbers: 400,
    hueDeg: 265,
    satMul: 0.95,
  ),
  // v0.94.0 The Deep Wardrobe: two hue gaps closed after the plate audit —
  // no red on the shelf (duskrose reads pink) and no teal at all.
  'emberheart': DelverDyeDef(
    'emberheart',
    'Emberheart',
    'Twice through the forge-water; the red of the coal\'s own heart.',
    costEmbers: 480,
    hueDeg: -18,
    satMul: 1.25,
    valMul: 0.97,
  ),
  'glowmere': DelverDyeDef(
    'glowmere',
    'Glowmere',
    'Drawn from the still pools where the delve-light gathers.',
    costEmbers: 560,
    hueDeg: 160,
    satMul: 0.9,
    valMul: 1.05,
  ),
  // v0.128.0 The Smith's Shelf: the plate audit's remaining gap — nothing
  // DARK on the shelf (every dye brightens or recolors; none smolders).
  'forgesoot': DelverDyeDef(
    'forgesoot',
    'Forgesoot',
    'Cloth that worked the bellows. The soot never washes out; the '
        'warmth never quite leaves.',
    costEmbers: 640,
    hueDeg: 8,
    satMul: 0.7,
    valMul: 0.8,
  ),
};
