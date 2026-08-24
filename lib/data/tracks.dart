// lib/data/tracks.dart — the Gramophone catalog (v0.33.0).
//
// Display names + earn-hints for the six music tracks. Keys MUST match
// AudioService.musicPaths (asserted in test/gramophone_test.dart). Hints are
// honest descriptions of play — never purchases, never timers (spec §Ethics).
// Order below is display order in the Ledger's Gramophone section: the
// journey order a new delver meets them in.

class TrackDef {
  final String key; // AudioService.musicPaths key
  final String name;
  final String hint; // how a locked track is earned, plainly

  const TrackDef({required this.key, required this.name, required this.hint});
}

const List<TrackDef> gramophoneTracks = [
  TrackDef(
    key: 'title_menu',
    name: 'Hearthside',
    hint: 'Heard at the hearth.',
  ),
  TrackDef(
    key: 'map',
    name: 'Into the Delve',
    hint: 'Begin a delve.',
  ),
  TrackDef(
    key: 'combat',
    name: 'Steel and Ember',
    hint: 'Meet a foe below.',
  ),
  TrackDef(
    key: 'boss_combat',
    name: 'The Deep Crowned',
    hint: 'Stand before a crowned foe.',
  ),
  TrackDef(
    key: 'victory',
    name: 'The Climb Home',
    hint: 'Win a delve.',
  ),
  TrackDef(
    key: 'defeat',
    name: 'Ashes, Gently',
    hint: 'The fire keeps this one for when a delve ends early.',
  ),
];
