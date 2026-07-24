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
  const HearthThemeDef(this.id, this.name, this.text,
      {required this.costEmbers,
      required this.warmArgb,
      required this.brightArgb});
}

const String defaultTheme = 'emberglow';

const List<String> hearthThemesOrder = [
  'emberglow', 'frostfire', 'witchlight', 'goldvein',
];

const Map<String, HearthThemeDef> hearthThemes = {
  'emberglow': HearthThemeDef('emberglow', 'Emberglow',
      'The hearth as it has always burned.',
      costEmbers: 0, warmArgb: 0xFF7A3A16, brightArgb: 0xFFE8C24A),
  'frostfire': HearthThemeDef('frostfire', 'Frostfire',
      'A cold blue flame from the deep ice delves.',
      costEmbers: 60, warmArgb: 0xFF16407A, brightArgb: 0xFF7AC8E8),
  'witchlight': HearthThemeDef('witchlight', 'Witchlight',
      'Violet sparks that whisper of old magic.',
      costEmbers: 60, warmArgb: 0xFF4A1670, brightArgb: 0xFFC48AE8),
  'goldvein': HearthThemeDef('goldvein', 'Goldvein',
      'Molten gold, for delvers of proven fortune.',
      costEmbers: 100, warmArgb: 0xFF7A5A16, brightArgb: 0xFFF5E27A),
};

HearthThemeDef hearthThemeDef(String? id) =>
    hearthThemes[id] ?? hearthThemes[defaultTheme]!;
