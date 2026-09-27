// lib/ui/combat_pose.dart — the body language of a fight, as data.
//
// v0.183.0 "Bodies in the Fight". Until now a combatant attacked by having
// its idle sprite squashed and slid toward the target, every weapon on the
// same 90/230/300 ms clock, every die face read only as brightness. The
// combat-visual critique (docs/reviews/combat-visual-critique-2026-09-10.md)
// called that out: the game had a richer ruleset than its presentation.
//
// This file is the pure-Dart answer. Nothing here touches Flutter or the
// sim: it maps *what already happened* (weapon id, die face and size,
// remaining HP, whether the guard held) onto *how the body should carry it*
// — wind-up depth, lean, weapon arc, contact shape, slump, breathing,
// wounds. The stage reads these plans; damage, block and every roll stay
// exactly the simulation's result.
//
// Conventions: angles are radians around the grip, 0 = weapon straight up,
// positive rotates toward the enemy (screen-right for the hero). Lean is a
// body rotation about the feet in radians, positive tips the head toward the
// target. Fractions are of sprite height unless stated.
import 'dart:math' as math;

/// How a weapon *moves*: not its shape (that is WeaponDef) but the way the
/// body has to work to use it. Each family gets its own wind-up, travel and
/// contact anatomy so a maul and a fang never read as the same swing.
enum StrikeFamily {
  /// Planted sword cut: shoulder wind-up, blade crosses the target, recovery.
  cut,

  /// Braced weight shift into a downward blow; blunt shock, not a crescent.
  crush,

  /// Compact forward thrust; point contact and a quick recoiling guard.
  stab,

  /// Precise jab that stamps a mark; rune contact motif, controlled recovery.
  stamp,

  /// Curved pull: catches on the way back, rake-style contact.
  hook,

  /// Short chopping pick: chip sparks, stubby reach, close body.
  pick,
}

/// Which family a signature weapon belongs to. Unknown ids fall back to the
/// Kindler's cut so a future weapon never swings blind.
StrikeFamily familyForWeapon(String weaponId) => switch (weaponId) {
  'ward_maul' ||
  'pin_wrench' ||
  'stone_maul' ||
  'planishing_hammer' ||
  'grain_flail' ||
  'long_ladle' => StrikeFamily.crush,
  'lucky_fang' ||
  'brand_iron' ||
  'steeling_rod' ||
  'fire_iron' ||
  'stitching_awl' ||
  'glovers_needle' => StrikeFamily.stab,
  'rune_chisel' || 'agate_burnisher' => StrikeFamily.stamp,
  'coin_hook' ||
  'coal_rake' ||
  'hearth_hook' ||
  'lamp_pole' => StrikeFamily.hook,
  'knapping_pick' || 'shoeing_hammer' => StrikeFamily.pick,
  'ember_brand' || 'billhook' => StrikeFamily.cut,
  _ => StrikeFamily.cut,
};

/// Low / mid / high / natural maximum — read against the die's OWN size, so
/// a 4 on a d4 is a maximum, not a "third of a d12".
enum DieTier { low, mid, high, max }

DieTier tierFor(int face, int sides) {
  if (sides <= 1) return DieTier.max;
  if (face >= sides) return DieTier.max;
  final r = face / sides;
  if (r <= 0.34) return DieTier.low;
  if (r <= 0.67) return DieTier.mid;
  return DieTier.high;
}

/// Weapon heat 0.15..1.0 for the selected face, relative to its die size.
/// Replaces the old `face / 12` denominator that left a maximum d4 looking
/// permanently cold.
double heatFor(int face, int sides) {
  if (sides <= 0) return 0.15;
  final r = (face / sides).clamp(0.0, 1.0);
  return (0.15 + r * 0.85).clamp(0.15, 1.0);
}

/// Parse a die id like `d6`, `d12_ember`, `D8` into its side count.
/// Anything unreadable is treated as a d6.
int sidesOfDieId(String id) {
  final m = RegExp(r'[dD](\d+)').firstMatch(id);
  if (m == null) return 6;
  final n = int.tryParse(m.group(1)!) ?? 6;
  return n <= 0 ? 6 : n;
}

/// The distinct shape the contact frame draws over the victim.
enum ContactShape { cut, crush, stab, stamp, hook, pick, claws }

/// One authored strike: timings and body/weapon amplitudes for a given
/// family and die tier. The whole wind-up + travel envelope is held at the
/// legacy 340 ms so every existing terminal-hold budget still fits — a heavy
/// blow spends longer coiling and less time travelling; a light one flicks.
class StrikePlan {
  final StrikeFamily family;
  final DieTier tier;

  /// Anticipation before the lunge (ms). Replaces the fixed 90 ms squash.
  final int windupMs;

  /// Lunge → contact (ms). Replaces the fixed 250 ms contact lead.
  final int travelMs;

  /// Weapon recovery to ready (ms).
  final int recoverMs;

  /// Body during wind-up: lean away from the target (rad), crouch (scaleY).
  final double windupLean;
  final double windupCrouch;

  /// Body at contact: lean into the target (rad), stretch (scaleY), how far
  /// the feet actually travel (fraction of the old 1.15 slide).
  final double strikeLean;
  final double strikeStretch;
  final double advance;

  /// Weapon angles for this strike (override the WeaponDef defaults).
  final double raiseAngle;
  final double swingAngle;

  /// Follow-through overshoot on recovery (0 = none). Weight lives here.
  final double followThrough;

  /// Smear trail intensity 0..1 (a stab barely smears; a max cut blazes).
  final double smear;

  final ContactShape contact;

  const StrikePlan({
    required this.family,
    required this.tier,
    required this.windupMs,
    required this.travelMs,
    required this.recoverMs,
    required this.windupLean,
    required this.windupCrouch,
    required this.strikeLean,
    required this.strikeStretch,
    required this.advance,
    required this.raiseAngle,
    required this.swingAngle,
    required this.followThrough,
    required this.smear,
    required this.contact,
  });

  /// The legacy body: 90 ms squash, 250 ms lunge, generic cut. Used when no
  /// die is known (e.g. a counter) so nothing ever renders plan-less.
  static const StrikePlan fallback = StrikePlan(
    family: StrikeFamily.cut,
    tier: DieTier.mid,
    windupMs: 90,
    travelMs: 250,
    recoverMs: 300,
    windupLean: -0.06,
    windupCrouch: 0.90,
    strikeLean: 0.10,
    strikeStretch: 1.04,
    advance: 1.0,
    raiseAngle: -1.75,
    swingAngle: 1.85,
    followThrough: 0.25,
    smear: 0.55,
    contact: ContactShape.cut,
  );

  int get totalLeadMs => windupMs + travelMs;
}

/// Tier weight 0..1 used to scale amplitudes: low 0.35, mid 0.6, high 0.85,
/// max 1.0. The steps are deliberately uneven — a max should feel like an
/// event, a low like a jab you barely commit to.
double tierWeight(DieTier t) => switch (t) {
  DieTier.low => 0.35,
  DieTier.mid => 0.6,
  DieTier.high => 0.85,
  DieTier.max => 1.0,
};

/// Author the strike for [family] at [tier]. Pure function; the stage calls
/// it once per swing and freezes the result for the choreography.
StrikePlan planStrike(StrikeFamily family, DieTier tier) {
  final w = tierWeight(tier);
  // Wind-up grows with weight, travel shrinks, envelope stays 340 ms.
  final windup = (60 + 100 * w).round(); // 95 .. 160
  final travel = 340 - windup; // 245 .. 180
  switch (family) {
    case StrikeFamily.cut:
      return StrikePlan(
        family: family,
        tier: tier,
        windupMs: windup,
        travelMs: travel,
        recoverMs: 280,
        windupLean: -0.05 - 0.07 * w,
        windupCrouch: 0.94 - 0.06 * w,
        strikeLean: 0.10 + 0.10 * w,
        strikeStretch: 1.02 + 0.04 * w,
        advance: 0.85 + 0.25 * w,
        raiseAngle:
            -1.3 - 0.7 * w, // shoulder-high for a light cut, past it for a max
        swingAngle: 1.6 + 0.5 * w,
        followThrough: 0.15 + 0.35 * w,
        smear: 0.35 + 0.65 * w,
        contact: ContactShape.cut,
      );
    case StrikeFamily.crush:
      // The maul: crouch, coil, then the whole body drops into the blow.
      return StrikePlan(
        family: family,
        tier: tier,
        windupMs: windup + 15,
        travelMs: travel - 15,
        recoverMs: 340,
        windupLean: -0.10 - 0.10 * w,
        windupCrouch: 0.90 - 0.08 * w,
        strikeLean: 0.16 + 0.12 * w,
        strikeStretch: 0.96 - 0.04 * w, // lands compressed, not stretched
        advance: 0.7 + 0.2 * w,
        raiseAngle: -2.2 - 0.5 * w, // overhead
        swingAngle: 1.35 + 0.25 * w, // stops at the ground, never a full arc
        followThrough: 0.05, // a maul does not bounce back
        smear: 0.25 + 0.35 * w,
        contact: ContactShape.crush,
      );
    case StrikeFamily.stab:
      // Compact: almost no wind-up lean, the body drives forward, weapon
      // barely rotates (the reach is the animation), snappy recoil guard.
      return StrikePlan(
        family: family,
        tier: tier,
        windupMs: (windup * 0.8).round(),
        travelMs: 340 - (windup * 0.8).round(),
        recoverMs: 220,
        windupLean: -0.03 - 0.04 * w,
        windupCrouch: 0.96 - 0.03 * w,
        strikeLean: 0.14 + 0.10 * w,
        strikeStretch: 1.04 + 0.03 * w,
        advance: 1.0 + 0.3 * w, // the stab travels furthest
        raiseAngle: 0.55, // point already toward the enemy
        swingAngle: 1.45 + 0.1 * w, // near-horizontal thrust
        followThrough: 0.45 + 0.2 * w, // whips back to guard
        smear: 0.15 + 0.25 * w,
        contact: ContactShape.stab,
      );
    case StrikeFamily.stamp:
      // The chisel: measured, almost ceremonial. Small motion, exact contact.
      return StrikePlan(
        family: family,
        tier: tier,
        windupMs: windup,
        travelMs: travel,
        recoverMs: 300,
        windupLean: -0.04 - 0.04 * w,
        windupCrouch: 0.97 - 0.03 * w,
        strikeLean: 0.08 + 0.08 * w,
        strikeStretch: 1.0,
        advance: 0.8 + 0.2 * w,
        raiseAngle: -0.6 - 0.5 * w,
        swingAngle: 1.2 + 0.2 * w,
        followThrough: 0.10,
        smear: 0.20 + 0.30 * w,
        contact: ContactShape.stamp,
      );
    case StrikeFamily.hook:
      // Wide side pull: winds far back, comes across low, catches.
      return StrikePlan(
        family: family,
        tier: tier,
        windupMs: windup,
        travelMs: travel,
        recoverMs: 320,
        windupLean: -0.08 - 0.08 * w,
        windupCrouch: 0.94 - 0.04 * w,
        strikeLean: 0.12 + 0.10 * w,
        strikeStretch: 1.02,
        advance: 0.9 + 0.2 * w,
        raiseAngle: -1.9 - 0.4 * w,
        swingAngle: 2.1 + 0.3 * w, // sweeps past horizontal and hooks
        followThrough: 0.35 + 0.2 * w,
        smear: 0.30 + 0.5 * w,
        contact: ContactShape.hook,
      );
    case StrikeFamily.pick:
      // Short chop from close in: quick, repeated-looking, chips fly.
      return StrikePlan(
        family: family,
        tier: tier,
        windupMs: (windup * 0.85).round(),
        travelMs: 340 - (windup * 0.85).round(),
        recoverMs: 240,
        windupLean: -0.06 - 0.05 * w,
        windupCrouch: 0.93 - 0.05 * w,
        strikeLean: 0.14 + 0.08 * w,
        strikeStretch: 0.98,
        advance: 0.95 + 0.15 * w,
        raiseAngle: -1.6 - 0.4 * w,
        swingAngle: 1.5 + 0.2 * w,
        followThrough: 0.20 + 0.15 * w,
        smear: 0.25 + 0.4 * w,
        contact: ContactShape.pick,
      );
  }
}

/// How an enemy body attacks. Enemies carry no weapon painter, so the family
/// lives entirely in the body: a rat hops and bites, a golem drops its whole
/// mass, a wisp darts.
enum EnemyStrikeStyle { bite, slam, dart, swipe }

EnemyStrikeStyle enemyStyleFor(
  String enemyId, {
  bool boss = false,
  bool elite = false,
}) {
  if (boss) return EnemyStrikeStyle.slam;
  const darters = {'wisp', 'shade', 'spark', 'moth', 'ghost', 'flame'};
  const biters = {'rat', 'beetle', 'slug', 'crawler', 'bat', 'spider', 'worm'};
  for (final d in darters) {
    if (enemyId.contains(d)) return EnemyStrikeStyle.dart;
  }
  for (final b in biters) {
    if (enemyId.contains(b)) return EnemyStrikeStyle.bite;
  }
  // Experimental loop C0-01: heavy brutes hop in and drop their whole mass.
  const hoppers = {'brute', 'ogre', 'hulk'};
  for (final h in hoppers) {
    if (enemyId.contains(h)) return EnemyStrikeStyle.slam;
  }
  if (elite) return EnemyStrikeStyle.slam;
  return EnemyStrikeStyle.swipe;
}

/// How a body idles on the combat stage (2026-09-24 living foes). The
/// sheets' idle rows are a few sub-pixel frames, so without this every foe
/// breathed with the same 2px bob. [breathe] IS that original bob, and it is
/// the default everywhere, so every non-combat call site is pixel-identical.
enum IdleStyle {
  /// The original LFP-4 breathing bob only.
  breathe,

  /// Floats clear of its shadow: a slow rise and fall, a lazy figure-eight
  /// drift and a gentle tilt (wisps, moths, shades, wraiths).
  hover,

  /// A heavy body: one deep, slow breath that lifts the chest about the
  /// feet each loop (brutes, golems, ogres, every boss and elite).
  heave,

  /// A small crawler: quick twitchy side-steps between held beats, low to
  /// the ground (rats, beetles, crawlers, ticks, serpents).
  scuttle,
}

/// The body's idle personality, from the same id vocabulary the strike
/// styles use (whole `_`-separated words, never substrings).
IdleStyle enemyIdleFor(
  String enemyId, {
  bool boss = false,
  bool elite = false,
}) {
  const hover = {
    'wisp',
    'moth',
    'mote',
    'sprite',
    'shade',
    'wraith',
    'widow',
    'hag',
  };
  const scuttle = {
    'rat',
    'beetle',
    'crawler',
    'tick',
    'snail',
    'urchin',
    'serpent',
    'wyrm',
  };
  const heavy = {
    'brute',
    'golem',
    'ogre',
    'hulk',
    'colossus',
    'tyrant',
    'maw',
    'shell',
    'sentinel',
    'bellows',
    'ram',
    'king',
    'regent',
    'twins',
    'matriarch',
    'hierophant',
  };
  final words = enemyId.split('_').toSet();
  if (words.any(hover.contains)) return IdleStyle.hover;
  if (words.any(scuttle.contains)) return IdleStyle.scuttle;
  if (boss || elite || words.any(heavy.contains)) return IdleStyle.heave;
  return IdleStyle.breathe;
}

/// Near-square wave in -1..1: a quick step, then a held beat. tanh keeps
/// the step smooth (a fractional power would cusp at every zero crossing).
double _twitch(double x) => _tanh(4.0 * math.sin(x)) / _tanh(4.0);

double _tanh(double x) {
  final e = math.exp(2.0 * x);
  return (e - 1.0) / (e + 1.0);
}

/// Idle-life offsets for [style] at loop phase [t] (radians; one loop is
/// 2pi). Logical pixels / radians / scale about the feet, layered on the
/// breathing bob. Pure, and periodic in [t], so the loop never seams.
({double dx, double dy, double rot, double scaleY}) idleLife(
  IdleStyle style,
  double t,
) => switch (style) {
  IdleStyle.breathe => (dx: 0.0, dy: 0.0, rot: 0.0, scaleY: 1.0),
  // Always 1..7px off the floor: the ground shadow stays put, so the gap
  // reads as flight.
  IdleStyle.hover => (
    dx: math.sin(2 * t + 1.3) * 1.6,
    dy: -4.0 + math.sin(t) * 3.0,
    rot: math.sin(t + 0.8) * 0.03,
    scaleY: 1.0,
  ),
  IdleStyle.heave => (
    dx: 0.0,
    dy: 0.0,
    rot: 0.0,
    scaleY: 1.0 + (0.5 - 0.5 * math.cos(t)) * 0.03,
  ),
  IdleStyle.scuttle => (
    dx: _twitch(3 * t) * 1.5,
    dy: -math.sin(6 * t).abs() * 0.6,
    rot: 0.0,
    scaleY: 1.0,
  ),
};

/// Enemy body choreography per style. The wind-up is always the player's
/// last read of the incoming hit, so it never gets shorter than the legacy
/// 190 ms telegraph.
///
/// Experimental loop C0-01 (2026-09-25): [travelMs] is a 120-160 ms dash
/// that the combat stage aims at a strike mark beside the delver (it
/// measures the gap), so a foe crosses the floor to land its blow instead
/// of swinging at air from where it stood. The wind-up grew by what the
/// dash gave back, so wind-up + dash stays the 440 ms envelope that contact
/// timing is pinned to (test/combat_contact_timeline_test.dart): a longer,
/// easier-to-read telegraph, then a snap. [advance] only scales the legacy
/// fallback when no strike distance is given.
class EnemyStrikePlan {
  final EnemyStrikeStyle style;
  final int windupMs;
  final int travelMs;
  final double windupLean; // negative = tips away from the player
  final double windupCrouch;
  final double strikeLean;
  final double strikeStretch;
  final double advance;
  final double hop; // fraction of height lifted mid-travel (0 = none)
  final ContactShape contact;
  const EnemyStrikePlan({
    required this.style,
    required this.windupMs,
    required this.travelMs,
    required this.windupLean,
    required this.windupCrouch,
    required this.strikeLean,
    required this.strikeStretch,
    required this.advance,
    required this.hop,
    required this.contact,
  });
}

EnemyStrikePlan planEnemyStrike(EnemyStrikeStyle style) => switch (style) {
  // A crawler coils low and pounces: a short hop that lands on the delver.
  EnemyStrikeStyle.bite => const EnemyStrikePlan(
    style: EnemyStrikeStyle.bite,
    windupMs: 290,
    travelMs: 150,
    windupLean: -0.06,
    windupCrouch: 0.84, // coils low
    strikeLean: 0.18,
    strikeStretch: 1.10, // springs long
    advance: 1.15,
    hop: 0.18,
    contact: ContactShape.claws,
  ),
  // Bosses, elites and brutes hop in and drop their whole mass.
  EnemyStrikeStyle.slam => const EnemyStrikePlan(
    style: EnemyStrikeStyle.slam,
    windupMs: 280,
    travelMs: 160,
    windupLean: -0.12,
    windupCrouch: 0.86,
    strikeLean: 0.22,
    strikeStretch: 0.94, // lands compressed
    advance: 0.85,
    hop: 0.22,
    contact: ContactShape.crush,
  ),
  // A wisp darts flat and fast, straight through the guard.
  EnemyStrikeStyle.dart => const EnemyStrikePlan(
    style: EnemyStrikeStyle.dart,
    windupMs: 320,
    travelMs: 120,
    windupLean: -0.04,
    windupCrouch: 0.96,
    strikeLean: 0.10,
    strikeStretch: 1.08,
    advance: 1.3,
    hop: 0.0,
    contact: ContactShape.claws,
  ),
  // Everything else (maws, golems) lunges low along the floor.
  EnemyStrikeStyle.swipe => const EnemyStrikePlan(
    style: EnemyStrikeStyle.swipe,
    windupMs: 300,
    travelMs: 140,
    windupLean: -0.08,
    windupCrouch: 0.86,
    strikeLean: 0.16,
    strikeStretch: 1.06,
    advance: 1.0,
    hop: 0.0,
    contact: ContactShape.claws,
  ),
};

/// How the body carries its remaining health. Cosmetic only — nothing here
/// feeds back into the simulation — but read in the body, not the HP bar:
/// a delver at a quarter health stands slumped, breathes hard and trembles.
class Condition {
  /// 1.0 = untouched, 0.0 = dead.
  final double vitality;
  const Condition(this.vitality);

  static Condition of(int hp, int maxHp) {
    if (maxHp <= 0) return const Condition(1.0);
    return Condition((hp / maxHp).clamp(0.0, 1.0));
  }

  static const Condition fresh = Condition(1.0);

  /// 0..1 how hurt: the complement of vitality, eased so the first scratch
  /// barely shows and the last quarter reads loudly.
  double get hurt {
    final h = (1.0 - vitality).clamp(0.0, 1.0);
    return h * h * (3 - 2 * h); // smoothstep
  }

  /// Forward slump about the feet (rad). Up to ~0.09 rad (5°) at death's door.
  double get slump => hurt * 0.09;

  /// Body compression from exhaustion (scaleY). 1.0 → 0.955.
  double get sag => 1.0 - hurt * 0.045;

  /// Breathing rate multiplier: calm 1.0 → laboured 2.2.
  double get breathRate => 1.0 + hurt * 1.2;

  /// Breathing amplitude multiplier (shoulders heave when spent): 1 → 2.4.
  double get breathAmp => 1.0 + hurt * 1.4;

  /// Colour drain 0..1 (pallor): skin and cloth lose saturation as blood
  /// leaves them. Capped so the character stays recognisable.
  double get pallor => (hurt * 0.55).clamp(0.0, 0.55);

  /// Number of visible wound marks 0..4, stepping in at 85/65/45/25 %.
  int get wounds {
    if (vitality > 0.85) return 0;
    if (vitality > 0.65) return 1;
    if (vitality > 0.45) return 2;
    if (vitality > 0.25) return 3;
    return 4;
  }

  /// Tremor amplitude in logical px — only once below a quarter health.
  double get tremor => vitality < 0.25 ? (0.25 - vitality) * 4.0 : 0.0;

  bool get isFresh => vitality >= 0.999;
}

/// A 4x5 colour matrix that drains saturation and cools the image by
/// [amount] 0..1 (0 = identity). Used for pallor; kept as pure math so it
/// can be unit-tested and reused by any renderer.
List<double> pallorMatrix(double amount) {
  final a = amount.clamp(0.0, 1.0);
  // Luma weights (Rec. 601) for the grey target.
  const lr = 0.299, lg = 0.587, lb = 0.114;
  final s = 1.0 - a; // remaining saturation
  // Slight cool cast: drop red a touch, lift blue a touch, proportional to a.
  final rGain = 1.0 - 0.10 * a;
  final bGain = 1.0 + 0.08 * a;
  return [
    (lr + (1 - lr) * s) * rGain,
    lg * (1 - s) * rGain,
    lb * (1 - s) * rGain,
    0,
    0,
    lr * (1 - s),
    lg + (1 - lg) * s,
    lb * (1 - s),
    0,
    0,
    lr * (1 - s) * bGain,
    lg * (1 - s) * bGain,
    (lb + (1 - lb) * s) * bGain,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// Blood colour family for a combatant. Delvers bleed red; the delve's
/// creatures bleed what they are made of — embers, soot, ichor. Kept in
/// data so the content-rating declaration can name exactly what is drawn.
enum Ichor { blood, ember, soot, ichor }

Ichor ichorFor(String combatantId, {bool player = false}) {
  if (player) return Ichor.blood;
  const ember = {
    'wisp',
    'cinder',
    'spark',
    'flame',
    'kiln',
    'forge',
    'ash',
    'ember',
  };
  const soot = {'shade', 'soot', 'smoke', 'ghost', 'wraith', 'shadow'};
  const bug = {'beetle', 'slug', 'worm', 'spider', 'moth', 'larva', 'grub'};
  for (final k in ember) {
    if (combatantId.contains(k)) return Ichor.ember;
  }
  for (final k in soot) {
    if (combatantId.contains(k)) return Ichor.soot;
  }
  for (final k in bug) {
    if (combatantId.contains(k)) return Ichor.ichor;
  }
  return Ichor.blood;
}

/// Where a wound mark sits on the body, in sprite-fraction space, and how
/// large. Deterministic per index so the same wound stays put across frames;
/// spread over torso/shoulders/upper legs, never the face row.
class WoundSpot {
  final double x, y, r;
  const WoundSpot(this.x, this.y, this.r);
}

const List<WoundSpot> woundSpots = [
  WoundSpot(0.56, 0.42, 0.055), // upper chest, weapon side
  WoundSpot(0.40, 0.55, 0.048), // ribs
  WoundSpot(0.62, 0.66, 0.042), // hip
  WoundSpot(0.46, 0.34, 0.038), // shoulder
];

/// Blood/ichor droplets for one landed hit: deterministic spray so tests
/// can pin it and frames never flicker. [severity] 0..1 (damage / max HP)
/// drives count and reach; [facing] +1 sprays screen-right (attacker on the
/// left), -1 the reverse.
class Droplet {
  final double angle; // rad, direction of travel
  final double speed; // fraction of victim height per second
  final double size; // px at scale 1
  final double lifeFrac; // portion of the burst life this drop survives
  final bool stains; // lands on the floor and stays
  const Droplet(this.angle, this.speed, this.size, this.lifeFrac, this.stains);
}

List<Droplet> spray(double severity, {int facing = 1, int seed = 0}) {
  final s = severity.clamp(0.0, 1.0);
  final count = (6 + (s * 12).round()).clamp(6, 18);
  final out = <Droplet>[];
  for (var i = 0; i < count; i++) {
    final h1 = _hash(i, seed + 1);
    final h2 = _hash(i, seed + 2);
    final h3 = _hash(i, seed + 3);
    // Fan of ±55° around "away from the attacker and slightly up".
    final base = facing > 0 ? -0.35 : math.pi + 0.35;
    final angle = base + (h1 - 0.5) * 1.9;
    final speed = 0.9 + h2 * (1.1 + s * 1.4);
    final size = 1.2 + h3 * (1.4 + s * 1.6);
    out.add(Droplet(angle, speed, size, 0.55 + h2 * 0.45, h3 > 0.45));
  }
  return out;
}

double _hash(int i, int salt) {
  final v = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
  return v - v.floorToDouble();
}
