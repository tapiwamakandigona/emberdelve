// data/vistas.dart — Delve vistas (v0.35.0, The Vistas). CONTENT AS DATA,
// ZERO LOGIC beyond one pure unlock resolver.
//
// The second half of the first outside player ask ("change backgrounds in
// the update" — reviews, 2026-08-23; customisation shipped as dyes in
// v0.27.0). A vista is a named color-grade laid over the painted
// backgrounds, reusing the hue/sat/val matrix machinery the Shifting Strata
// (v0.28.0) proved in production — no new PNGs, so the APK does not grow.
//
// Charter (docs/spec.md §Ethics, same as dyes/themes/skins): pure cosmetic,
// no gameplay effect, no timers, no FOMO. Vistas are MILESTONE unlocks, not
// purchases — the unlock line states the real milestone, never a price.
//
// The default 'emberlight' is the identity (0°, 1.0, 1.0, transparent wash):
// a fresh profile renders pixel-for-pixel as before this file existed, and
// the strata depth grade composes on top exactly as it always has.

import 'dart:ui' show Color;

import 'tales.dart' show hearthgoldTales;

class VistaDef {
  final String id;
  final String name;
  final String text; // campfire-voiced description
  final String unlockLine; // honest milestone, shown while locked
  final double hueDeg; // hue rotation, degrees
  final double satMul; // saturation multiplier
  final double valMul; // brightness multiplier
  final Color wash; // translucent breath over the graded art
  const VistaDef(
    this.id,
    this.name,
    this.text, {
    required this.unlockLine,
    this.hueDeg = 0,
    this.satMul = 1,
    this.valMul = 1,
    this.wash = const Color(0x00000000),
  });
}

const String defaultVista = 'emberlight';

const List<String> vistasOrder = [
  'emberlight',
  'moonveil',
  'verdigris',
  'bloodstone',
  'duskquartz', // v0.55.0 — append-LAST, same discipline as roster bits
  'deepshale', // v0.64.0 — append-LAST
  'hearthgold', // v0.98.0 — append-LAST
  'frostvein', // v0.112.0 — append-LAST
];

const Map<String, VistaDef> vistas = {
  'emberlight': VistaDef(
    'emberlight',
    'Emberlight',
    'The delve as the first delvers found it — kiln-brown rock and warm coals.',
    unlockLine: 'Yours from the start.',
  ),
  'moonveil': VistaDef(
    'moonveil',
    'Moonveil',
    'Moonlight finds its way down here somehow. Cold, blue, and quiet.',
    unlockLine: 'Win a delve.',
    hueDeg: -140,
    satMul: 1.2,
    valMul: 0.97,
    wash: Color(0x33203050),
  ),
  'verdigris': VistaDef(
    'verdigris',
    'Verdigris',
    'Glowworm moss has taken the walls. The dark breathes green.',
    unlockLine: 'Fell 15 different foes.',
    hueDeg: 85,
    satMul: 1.55,
    valMul: 0.97,
    wash: Color(0x3D1E4A32),
  ),
  'bloodstone': VistaDef(
    'bloodstone',
    'Bloodstone',
    'Deep-vein rock, red as the forge. Only the hard roads lead here.',
    unlockLine: 'Win a delve on Hard.',
    hueDeg: -28,
    satMul: 1.8,
    valMul: 0.93,
    wash: Color(0x45521A1E),
  ),
  // v0.55.0 The Duskquartz — the first vista the Provings feed. Violet-gold
  // dusk grade; unlock derives from meta.provingsCleared like every other
  // vista counter, so the two systems finally touch.
  'duskquartz': VistaDef(
    'duskquartz',
    'Duskquartz',
    'Quartz veins catch the last light. The delve keeps its own dusk.',
    unlockLine: 'Clear 3 provings.',
    hueDeg: -95,
    satMul: 1.35,
    valMul: 0.96,
    wash: Color(0x3D2E1E4E),
  ),
  // v0.64.0 The Deepshale — the first vista the depth record feeds, closing
  // the arc The Deepest Mark (v0.61.0) opened: the summary names the record,
  // this is what standing on the true floor leaves you. Also the first
  // DESATURATING grade — every earlier vista raises color; the deep drains it.
  'deepshale': VistaDef(
    'deepshale',
    'Deepshale',
    'Slate from the true floor. Down here the rock forgets its color, '
        'and what the fire touches is all there is.',
    unlockLine: 'Stand on the ninth floor.',
    hueDeg: -10,
    satMul: 0.72,
    valMul: 0.9,
    wash: Color(0x40232830),
  ),
  // v0.98.0 The Hearthgold — the first vista the hearth-tale arc feeds
  // (hearthTalesHeard, v0.96.0), and the first BRIGHTENING grade: every
  // earlier vista tints or drains; the fire's color gilds. Earned by
  // sitting with the fire through its whole cycle of tales — the delve
  // rewards listening the same way it rewards depth.
  'hearthgold': VistaDef(
    'hearthgold',
    'Hearthgold',
    'The fire\'s own color, carried into the stone. Walls that have '
        'heard every tale hold the light a little longer.',
    unlockLine: 'Hear the fire\'s first ten tales.',
    hueDeg: 6,
    satMul: 1.12,
    valMul: 1.08,
    wash: Color(0x2EB07B2A),
  ),
  // v0.112.0 The Frostvein — the first vista the Weekly feeds, earned on
  // the rotation's hardest sit (the doubled week, v0.111.0). The first PALE
  // grade: frost drains color the way the deep does, but it brightens —
  // ice-blue veins in white-lit rock, nothing like moonveil's saturated
  // night or deepshale's warm dark.
  'frostvein': VistaDef(
    'frostvein',
    'Frostvein',
    'Rock that has wintered. The cold got into the stone the week the '
        'shops closed and the camps went dark, and it never quite left.',
    unlockLine: 'Claim the Ember on a doubled week.',
    hueDeg: -150,
    satMul: 0.62,
    valMul: 1.08,
    wash: Color(0x478FB6C9),
  ),
};

/// Pure unlock resolver: true when [id] is available given the profile's
/// real, uncapped counters (MetaState.runsWon / enemyFelled distinct keys /
/// hardWins / provingsCleared size / bestFloor). Derived at read time — nothing new is
/// persisted, so there is nothing to migrate or merge and the unlock can
/// never lie (§Ethics).
bool vistaUnlockedFor(
  String id, {
  required int runsWon,
  required int distinctFelled,
  required int hardWins,
  required int provingsCleared,
  required int bestFloor,
  required int talesHeard,
  required int doubledWins,
}) {
  switch (id) {
    case 'emberlight':
      return true;
    case 'moonveil':
      return runsWon >= 1;
    case 'verdigris':
      return distinctFelled >= 15;
    case 'bloodstone':
      return hardWins >= 1;
    case 'duskquartz':
      return provingsCleared >= 3;
    // v0.64.0: bestFloor counts the deepest 1-based layer STOOD ON, won or
    // lost — a loss on the ninth floor earns the deep's colors too.
    case 'deepshale':
      return bestFloor >= 9;
    // v0.98.0, corrected v0.100.0: the FIRST cycle of hearth tales. The
    // gate briefly followed hearthTales.length, but a derived unlock that
    // tracks a growing list re-locks earned vistas — milestones freeze.
    case 'hearthgold':
      return talesHeard >= hearthgoldTales;
    // v0.112.0: fed by the monotonic doubled-week win counter — a shared
    // challenge won under the paired rule, never derivable, never re-locks.
    case 'frostvein':
      return doubledWins >= 1;
    default:
      return false;
  }
}
