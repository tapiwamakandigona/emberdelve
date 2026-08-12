// data/themes.dart — Hearth colors (v0.3.3). CONTENT AS DATA, ZERO LOGIC.
//
// Ember-priced cosmetic tints for the title-screen hearth (ember drift +
// campfire glow). A macro-loop ember sink that fits the ethics charter:
// pure cosmetics, real prices shown up front, no gameplay effect, no
// timers/FOMO. Colors are raw ARGB ints so the meta layer stays UI-free.
//
// Schema:
//   HearthThemeDef { id, name, text, costEmbers, warmArgb, brightArgb }
// warmArgb  = the deep/charred end of the drift gradient
// brightArgb = the hot/bright end (also the campfire glow tint)

class HearthThemeDef {
  final String id;
  final String name;
  final String text;
  final int costEmbers;
  final int warmArgb;
  final int brightArgb;
  const HearthThemeDef(
    this.id,
    this.name,
    this.text, {
    required this.costEmbers,
    required this.warmArgb,
    required this.brightArgb,
  });
}

const String defaultTheme = 'emberglow';

const List<String> hearthThemesOrder = [
  'emberglow', 'frostfire', 'witchlight', 'goldvein',
  // v0.4.3 P1 ember sink — eight more colors, priced in a rising ladder so
  // the hearth stays a chase deep into the macro loop. Order = price order.
  'ashrose', 'verdigris', 'stormglass', 'moonpale',
  'duskwine', 'saltflame', 'sunflare', 'voidcoal',
];

const Map<String, HearthThemeDef> hearthThemes = {
  'emberglow': HearthThemeDef(
    'emberglow',
    'Emberglow',
    'The hearth as it has always burned.',
    costEmbers: 0,
    warmArgb: 0xFF7A3A16,
    brightArgb: 0xFFE8C24A,
  ),
  'frostfire': HearthThemeDef(
    'frostfire',
    'Frostfire',
    'A cold blue flame from the deep ice delves.',
    costEmbers: 60,
    warmArgb: 0xFF16407A,
    brightArgb: 0xFF7AC8E8,
  ),
  'witchlight': HearthThemeDef(
    'witchlight',
    'Witchlight',
    'Violet sparks that whisper of old magic.',
    costEmbers: 60,
    warmArgb: 0xFF4A1670,
    brightArgb: 0xFFC48AE8,
  ),
  'goldvein': HearthThemeDef(
    'goldvein',
    'Goldvein',
    'Molten gold, for delvers of proven fortune.',
    costEmbers: 100,
    warmArgb: 0xFF7A5A16,
    brightArgb: 0xFFF5E27A,
  ),
  'ashrose': HearthThemeDef(
    'ashrose',
    'Ashrose',
    'A soft rose flame, coaxed from petal-ash.',
    costEmbers: 120,
    warmArgb: 0xFF6E2438,
    brightArgb: 0xFFE89CB0,
  ),
  'verdigris': HearthThemeDef(
    'verdigris',
    'Verdigris',
    'Green copperfire from the drowned mines.',
    costEmbers: 140,
    warmArgb: 0xFF1E5A38,
    brightArgb: 0xFF7FE0A8,
  ),
  'stormglass': HearthThemeDef(
    'stormglass',
    'Stormglass',
    'The grey-teal light of a storm sealed in glass.',
    costEmbers: 160,
    warmArgb: 0xFF2E4A56,
    brightArgb: 0xFF9CCAD8,
  ),
  'moonpale': HearthThemeDef(
    'moonpale',
    'Moonpale',
    'Cold silver fire that burns without heat.',
    costEmbers: 200,
    warmArgb: 0xFF3C4458,
    brightArgb: 0xFFD8E0F0,
  ),
  'duskwine': HearthThemeDef(
    'duskwine',
    'Duskwine',
    'The deep red of a sun already gone.',
    costEmbers: 240,
    warmArgb: 0xFF581626,
    brightArgb: 0xFFC05068,
  ),
  'saltflame': HearthThemeDef(
    'saltflame',
    'Saltflame',
    'Blue-green fire fed on old sea salt.',
    costEmbers: 280,
    warmArgb: 0xFF0E5450,
    brightArgb: 0xFF6FE8DC,
  ),
  'sunflare': HearthThemeDef(
    'sunflare',
    'Sunflare',
    'White-gold noonfire, too bright to stare at.',
    costEmbers: 340,
    warmArgb: 0xFF8A5A10,
    brightArgb: 0xFFFFF2B0,
  ),
  'voidcoal': HearthThemeDef(
    'voidcoal',
    'Voidcoal',
    'A black flame that gives off dark instead of light.',
    costEmbers: 400,
    warmArgb: 0xFF16121E,
    brightArgb: 0xFF5A4A8A,
  ),
};

HearthThemeDef hearthThemeDef(String? id) =>
    hearthThemes[id] ?? hearthThemes[defaultTheme]!;
