// data/ranks.dart — The Delver's Rank tier table (v0.13.0). CONTENT AS DATA.
//
// A rank is a NAME for how much a profile has already banked — it is never
// a currency, never a gate, and never a comparison to anyone else. The rank
// is computed at read time as a pure function of MetaState (meta/rank.dart);
// nothing here persists, expires, or resets (§Ethics).
//
// Tier names deliberately avoid the four character names (Kindler, Warden,
// Gambler, Ascetic) so "You delve as a …" can never read as a class change.
//
// Threshold tuning (meta/rank.dart documents the marks formula): a brand-new
// player's first evening — two or three runs, a handful of foes met and
// felled, maybe one win — lands 2–3 rank-ups (quick early wins), while the
// top tier is a long, honest climb over hundreds of banked marks.

class RankTier {
  final String id;
  final String name;

  /// Marks required to hold this tier (see meta/rank.dart for the formula).
  final int marks;

  /// One quiet line of world voice shown under the rank on the Ledger.
  final String flavor;

  const RankTier(this.id, this.name, this.marks, this.flavor);

  /// 'an Ashfoot' / 'a Tinderhand' — copy helper so "You delve as …" lines
  /// stay grammatical for every tier name.
  String get withArticle =>
      "${'aeiou'.contains(name[0].toLowerCase()) ? 'an' : 'a'} $name";
}

/// Ascending by [marks]; first entry MUST be 0 so every profile holds a rank.
const List<RankTier> rankTiers = [
  RankTier('ashfoot', 'Ashfoot', 0, 'Every delver starts in the ash.'),
  RankTier('tinderhand', 'Tinderhand', 8, 'The first sparks answer you.'),
  RankTier('sparktender', 'Sparktender', 24, 'You keep small fires alive.'),
  RankTier('emberwright', 'Emberwright', 60, 'You shape embers into intent.'),
  RankTier('flamebearer', 'Flamebearer', 120, 'The delve knows your light.'),
  RankTier('pyrewalker', 'Pyrewalker', 240, 'You walk where pyres burned.'),
  RankTier(
    'hearthkeeper',
    'Hearthkeeper',
    420,
    'Delvers rest easier in your glow.',
  ),
  RankTier('cinderlord', 'Cinderlord', 700, 'Even the deep layers dim first.'),
  RankTier(
    'deepfire_sovereign',
    'Deepfire Sovereign',
    1100,
    'The mountain remembers your name.',
  ),
  // v0.149.0 The Tenth Fire: the ladder grew — veterans who long ago
  // banked 1100 marks climb again. Threshold gap keeps the curve's shape
  // (diffs 280, 400, now 600).
  RankTier(
    'mountainheart',
    'Mountainheart',
    1700,
    'What the mountain remembers, it keeps.',
  ),
  // v0.161.0 The Eleventh Fire: the ladder grew again — veterans who long
  // ago banked 1700 marks climb again. Threshold gap keeps the curve's
  // shape (diffs 280, 400, 600, now 850).
  RankTier(
    'firstflame',
    'Firstflame',
    2550,
    'Every fire below began with yours.',
  ),
  // v0.166.0 The Everburn: a twelfth fire above Firstflame — veterans who
  // long ago banked 2550 marks climb again. Threshold gap keeps the curve's
  // shape (diffs 280, 400, 600, 850, now 1200).
  RankTier(
    'everburn',
    'Everburn',
    3750,
    'Fires gutter and fall. Yours has not.',
  ),
  // v0.173.0 The Worldflame: a thirteenth fire above the Everburn — veterans
  // who long ago banked 3750 marks climb again. Threshold gap keeps the
  // curve's shape (diffs 280, 400, 600, 850, 1200, now 1700).
  RankTier(
    'worldflame',
    'Worldflame',
    5450,
    'Far above, the world steers by your light.',
  ),
];
