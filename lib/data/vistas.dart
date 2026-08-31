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
  'forgelight', // v0.126.0 — append-LAST
  'runemark', // v0.134.0
  'tenthfire', // v0.152.0
  'amethyst', // v0.164.0 — append-LAST
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
  // v0.126.0 The Forgelight — the temper arc's vista (fed by the same
  // monotonic tempersSet the Tempered Hand honors read). The first HOT
  // grade: not hearthgold's amber comfort but working-forge heat — redder,
  // richer, the stone lit from below.
  'forgelight': VistaDef(
    'forgelight',
    'Forgelight',
    'Stone that remembers the anvil. Ten marks on ten faces, and the '
        'walls started holding the glow the way a smithy does.',
    unlockLine: 'Temper ten die faces.',
    // Grade strengthened after plate critique (first pass -18/1.3/1.04/0x3B
    // was near-invisible against the identity control — the frostvein
    // 'too timid' lesson repeats): the delve must clearly burn.
    hueDeg: -25,
    satMul: 1.5,
    valMul: 1.12,
    wash: Color(0x66E8571F),
  ),
  // v0.134.0 The Runemark — the Six Marks summit (every rune worked at
  // least once, v0.133.0), and the first VIOLET grade: runeglass light,
  // cool and arcane where forgelight burns. Opened BOLD per the grade
  // doctrine (frostvein/forgelight both shipped 'too timid' first passes).
  'runemark': VistaDef(
    'runemark',
    'Runemark',
    'Six runes, each worked into stone at least once. The walls keep '
        'the marks the way glass keeps light \u2014 cold, violet, and '
        'patient.',
    unlockLine: 'Temper every rune the anvil offers.',
    hueDeg: 155,
    satMul: 1.35,
    valMul: 1.06,
    wash: Color(0x5C7B4FC0),
  ),
  // v0.152.0 The Tenth Chair: the full company's vista — every chair at
  // the fire filled. Warm and bright: ten delvers' worth of hearthlight.
  'tenthfire': VistaDef(
    'tenthfire',
    'Tenthfire',
    'Ten chairs, ten shadows on the same wall. The delve is not '
        'smaller for it \u2014 but it is warmer.',
    unlockLine: 'Unlock every delver.',
    hueDeg: 24,
    satMul: 1.25,
    valMul: 1.10,
    wash: Color(0x40E8A050),
  ),
  // v0.164.0 The Amethyst Vein: the won company's vista — not just every
  // chair filled, but every delver carried out of the deep with a win.
  'amethyst': VistaDef(
    'amethyst',
    'Amethyst',
    'Vein-purple crystal in the dark. Twelve roads down, twelve roads '
        'back — the rock remembers each one.',
    unlockLine: 'Win a delve with twelve different delvers.',
    hueDeg: -48,
    satMul: 1.8,
    valMul: 1.04,
    wash: Color(0x46603090),
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
  required int tempersSet,
  required int runesMarked,
  required int charsUnlocked,
  required int delversCleared,
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
    // v0.126.0: fed by the monotonic lifetime temper counter (v0.125.0) —
    // banked win or lose, never derivable, never re-locks.
    case 'forgelight':
      return tempersSet >= 10;
    // v0.134.0: the distinct-rune count (junk-proofed at the reader,
    // v0.133.0). FROZEN at six — a gate that tracked the live rune set
    // would re-lock earned vistas if the anvil ever grows (v0.100 lesson).
    case 'runemark':
      return runesMarked >= 6;
    // v0.152.0: FROZEN at ten — a gate that tracked the live roster would
    // re-lock this vista the day an eleventh delver joins (v0.100 lesson;
    // milestones freeze, exactly like full_roster's plain 'four').
    case 'tenthfire':
      return charsUnlocked >= 10;
    // v0.164.0: fed by the junk-proofed distinct-winners count
    // (delvers_cleared — only real roster ids with a banked win). FROZEN
    // at twelve — a gate that tracked the live roster would re-lock this
    // vista the day a thirteenth delver joins (v0.100 lesson).
    case 'amethyst':
      return delversCleared >= 12;
    default:
      return false;
  }
}
