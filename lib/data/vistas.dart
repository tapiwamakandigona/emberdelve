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
};

/// Pure unlock resolver: true when [id] is available given the profile's
/// real, uncapped counters (MetaState.runsWon / enemyFelled distinct keys /
/// hardWins). Derived at read time — nothing new is persisted, so there is
/// nothing to migrate or merge and the unlock can never lie (§Ethics).
bool vistaUnlockedFor(
  String id, {
  required int runsWon,
  required int distinctFelled,
  required int hardWins,
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
    default:
      return false;
  }
}
