// data/skins.dart — Dice skins (v0.4.3, P1 ember sink). CONTENT AS DATA,
// ZERO LOGIC.
//
// Ember-priced cosmetic recolors for every die in play. Same charter as
// hearth colors (docs/spec.md §Ethics): pure cosmetics, real prices shown up
// front, no gameplay effect, no timers/FOMO. A skin never changes a roll,
// a face layout, or a die's identity — only the paint.
//
// Schema:
//   DieSkinDef { id, name, text, costEmbers, bodyArgb, inkArgb }
// bodyArgb = multiply tint over the cream die art (0xFFFFFFFF = untouched)
// inkArgb  = pip / numeral ink drawn on the face
//
// The default 'bone' skin is deliberately the identity tint + the original
// ink (0xFF241407): a profile that never buys anything renders pixel-for-
// pixel as before this file existed.

class DieSkinDef {
  final String id;
  final String name;
  final String text;
  final int costEmbers;
  final int bodyArgb;
  final int inkArgb;
  const DieSkinDef(
    this.id,
    this.name,
    this.text, {
    required this.costEmbers,
    required this.bodyArgb,
    required this.inkArgb,
  });
}

const String defaultDieSkin = 'bone';

const List<String> dieSkinsOrder = [
  'bone',
  'embertide',
  'frostbound',
  'wychwood',
  'gilded',
  'bloodstone',
  'obsidian',
];

const Map<String, DieSkinDef> dieSkins = {
  'bone': DieSkinDef(
    'bone',
    'Bone',
    'Plain delver bone, worn smooth by a thousand throws.',
    costEmbers: 0,
    bodyArgb: 0xFFFFFFFF,
    inkArgb: 0xFF241407,
  ),
  'embertide': DieSkinDef(
    'embertide',
    'Embertide',
    'Dice warmed to a forge-glow that never quite fades.',
    costEmbers: 150,
    bodyArgb: 0xFFFFB878,
    inkArgb: 0xFF3A1404,
  ),
  'frostbound': DieSkinDef(
    'frostbound',
    'Frostbound',
    'Chipped from delve-ice that refuses to melt.',
    costEmbers: 150,
    bodyArgb: 0xFFA8C8F0,
    inkArgb: 0xFF102A4A,
  ),
  'wychwood': DieSkinDef(
    'wychwood',
    'Wychwood',
    'Carved from a tree that grew where no light reached.',
    costEmbers: 200,
    bodyArgb: 0xFFC8A8E8,
    inkArgb: 0xFF2E1048,
  ),
  'gilded': DieSkinDef(
    'gilded',
    'Gilded',
    'Every pip set in hammered gold leaf.',
    costEmbers: 300,
    bodyArgb: 0xFFF0D070,
    inkArgb: 0xFF4A3208,
  ),
  'bloodstone': DieSkinDef(
    'bloodstone',
    'Bloodstone',
    'Cut from the red stone that remembers every delver.',
    costEmbers: 300,
    bodyArgb: 0xFFE89090,
    inkArgb: 0xFF4A0E0E,
  ),
  'obsidian': DieSkinDef(
    'obsidian',
    'Obsidian',
    'Volcanic glass, black as the bottom of the delve.',
    costEmbers: 400,
    bodyArgb: 0xFF585868,
    inkArgb: 0xFFE8E0D0,
  ),
};

DieSkinDef dieSkinDef(String? id) => dieSkins[id] ?? dieSkins[defaultDieSkin]!;
