// lib/ui/weapons.dart — programmatic combat weapons + contact FX.
//
// The delver finally HOLDS their weapon on the combat stage: each character
// gets a hand-drawn (CustomPainter) signature weapon that idles with a slow
// sway, pulls back in anticipation, and swings through a smear arc on the
// attack — the classic anticipation → strike → recovery arc (GDKeys "Anatomy
// of an Attack"; GDQuest "Juicing up your game attacks": anticipation, smear,
// easing). Zero image assets, matching the visual-overhaul precedent and
// PROJECT.md decision #7 (no AI-generated animated sprites — this is drawn
// geometry, like fx.dart / logo.dart).
//
// Also here: ImpactSlash (weapon smear / claw rake shown on the victim at the
// contact frame — enemy sheets have no attack frames, so the claw overlay is
// what sells the enemy's strike) and GuardFlash (a shield-arc flourish for
// block, which previously had ZERO visual feedback).
//
// Everything is allocation-light and sits behind RepaintBoundary; painters
// reuse Paint objects and derive per-particle randomness from index hashes
// (same trick as fx.dart) so nothing allocates per frame.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'build_identity.dart';
import 'theme.dart';

/// Choreography phase for the held weapon. Drive it straight from the combat
/// screen's existing squash/lunge flags — the weapon needs no timers of its
/// own beyond its transition tween.
enum WeaponPhase { idle, raise, swing }

/// One signature weapon. Angles are radians around the grip; 0 = blade up,
/// positive rotates toward the enemy (screen-right for the hero).
class WeaponDef {
  final String id;
  final String name;

  /// Accent used for the smear trail + impact slash.
  final Color accent;

  /// Blade length as a fraction of the widget height.
  final double reach;
  final double idleAngle;
  final double raiseAngle;
  final double swingAngle;
  const WeaponDef(
    this.id,
    this.name, {
    required this.accent,
    this.reach = 0.52,
    this.idleAngle = 0.42,
    this.raiseAngle = -1.75,
    this.swingAngle = 1.85,
  });
}

/// Character id -> signature weapon. Unknown ids fall back to the Kindler's
/// brand so a future character never renders empty-handed.
const Map<String, WeaponDef> _weapons = {
  // The balanced start: a short sword whose edge still glows from the forge.
  'kindler': WeaponDef('ember_brand', 'Ember Brand', accent: Color(0xFFF0A24C)),
  // Tanky: a squat iron maul — slower arc, heavier presence.
  'warden': WeaponDef(
    'ward_maul',
    'Ward Maul',
    accent: Color(0xFF9FB6D9),
    reach: 0.46,
    idleAngle: 0.55,
    raiseAngle: -2.0,
    swingAngle: 1.7,
  ),
  // High variance: a curved luck-fang, quick and showy.
  'gambler': WeaponDef(
    'lucky_fang',
    'Lucky Fang',
    accent: Color(0xFFE8C24A),
    reach: 0.44,
    idleAngle: 0.3,
    raiseAngle: -1.55,
    swingAngle: 2.0,
  ),
  // Fragile but sharp: the brand iron, tip still white-hot.
  'ascetic': WeaponDef(
    'brand_iron',
    'Brand Iron',
    accent: Color(0xFFFF7A3C),
    reach: 0.58,
    idleAngle: 0.36,
  ),
  // Mercantile (v0.40.0): a brass cargo hook with a coin-weighted pommel —
  // the tool of someone who hauls goods first and fights second.
  'peddler': WeaponDef(
    'coin_hook',
    'Coin Hook',
    accent: Color(0xFFDCB65A),
    reach: 0.50,
    idleAngle: 0.38,
    raiseAngle: -1.65,
    swingAngle: 1.9,
  ),
  // Control (v0.50.0): a long-handled pin wrench with a burnished steel
  // head — the tool of someone who fixes the delve rather than fights it.
  'tinker': WeaponDef(
    'pin_wrench',
    'Pin Wrench',
    accent: Color(0xFF8FB4C9),
    reach: 0.54,
    idleAngle: 0.32,
    raiseAngle: -1.55,
    swingAngle: 1.8,
  ),
  // Marked (v0.135.0): a rune chisel — the tool that works the marks.
  // Short, precise reach; runeglass-violet accent to match the sheet.
  'runesmith': WeaponDef(
    'rune_chisel',
    'Rune Chisel',
    accent: Color(0xFFB9A6D9),
    reach: 0.46,
    idleAngle: 0.34,
    raiseAngle: -1.60,
    swingAngle: 1.85,
  ),
  // Giant (v0.145.0): a stone maul — two hands, one promise. The longest
  // reach in the roster (the bearer swings wide and slow, like their
  // dice: few and grand), cold granite accent to match the sheet.
  'bearer': WeaponDef(
    'stone_maul',
    'Stone Maul',
    accent: Color(0xFF9AA3B0),
    reach: 0.62,
    idleAngle: 0.28,
    raiseAngle: -1.45,
    swingAngle: 1.95,
  ),
  // Ward (v0.158.0): a planishing hammer — the tool that raises a shield
  // from flat steel. Mid reach, deliberate swing (shieldwrights strike
  // twice in the shop and once in the field), deep-steel-blue accent to
  // match the sheet's remap.
  'shieldwright': WeaponDef(
    'planishing_hammer',
    'Planishing Hammer',
    accent: Color(0xFF7FA3D9),
    reach: 0.50,
    idleAngle: 0.30,
    raiseAngle: -1.50,
    swingAngle: 1.80,
  ),
  // Goldsmith (v0.162.0): an agate burnisher — the tool that rubs gold
  // leaf to a shine. Short reach (gilders work at the bench, close and
  // exact), burnished-gold accent to match the sheet's remap.
  'gilder': WeaponDef(
    'agate_burnisher',
    'Agate Burnisher',
    accent: Color(0xFFD9B84A),
    reach: 0.44,
    idleAngle: 0.28,
    raiseAngle: -1.40,
    swingAngle: 1.75,
  ),
  // Knife-maker (v0.168.0): a steeling rod — the tool that trues an edge
  // between grinds. Short reach (cutlers work at the bench, wrist and
  // whetstone), pale-steel accent to match the sheet's remap.
  'cutler': WeaponDef(
    'steeling_rod',
    'Steeling Rod',
    accent: Color(0xFF9CB4CC),
    reach: 0.46,
    idleAngle: 0.26,
    raiseAngle: -1.42,
    swingAngle: 1.78,
  ),
  // Charcoal-burner (v0.171.0): a coal rake — the long tool that tends
  // the clamp without opening it. Longer reach (colliers work the pile
  // at arm's length, in the heat), sooty-ember accent to match the
  // sheet's remap.
  'collier': WeaponDef(
    'coal_rake',
    'Coal Rake',
    accent: Color(0xFF8A6A52),
    reach: 0.56,
    idleAngle: 0.24,
    raiseAngle: -1.38,
    swingAngle: 1.72,
  ),
  // Furnace-feeder (v0.175.0): a fire iron — the bar that shoves the
  // big coals home. Long reach (stokers work at the mouth of the heat,
  // not in it), hot-iron accent to match the sheet's remap.
  'stoker': WeaponDef(
    'fire_iron',
    'Fire Iron',
    accent: Color(0xFFC97B3F),
    reach: 0.58,
    idleAngle: 0.22,
    raiseAngle: -1.40,
    swingAngle: 1.74,
  ),
  // Healer (v0.150.0): a stitching awl — the tool that closes what the
  // delve opens. Short reach (menders work close, where the wound is),
  // sage-green accent to match the sheet's remap.
  'mender': WeaponDef(
    'stitching_awl',
    'Stitching Awl',
    accent: Color(0xFF8FBF9A),
    reach: 0.40,
    idleAngle: 0.22,
    raiseAngle: -1.15,
    swingAngle: 1.55,
  ),
  // Swarm (v0.118.0): a short knapping pick — the tool that makes shards.
  // Stubby reach (the flintwright fights close, like their dice: small and
  // many), flint-tan accent to match the sheet's palette.
  'flintwright': WeaponDef(
    'knapping_pick',
    'Knapping Pick',
    accent: Color(0xFFC9B98F),
    reach: 0.42,
    idleAngle: 0.40,
    raiseAngle: -1.70,
    swingAngle: 1.95,
  ),
};

WeaponDef weaponFor(String characterId) =>
    _weapons[characterId] ?? _weapons['kindler']!;

/// The held weapon. Anchor it over the hero sprite (grip roughly at the
/// sprite's hand); it sways on idle, snaps back on [WeaponPhase.raise] and
/// whips through the arc with a smear trail on [WeaponPhase.swing].
class WeaponView extends StatefulWidget {
  final String characterId;
  final double height;
  final WeaponPhase phase;

  /// 0..1 — how "charged" the weapon is (die pips ready to strike). The
  /// accent edge brightens, a heat halo grows, and sparks rise off the
  /// blade, making the die -> weapon causality visible before the swing.
  final double charge;

  /// The current pool's dominant build language. Pure presentation: this is
  /// derived from die IDs and never enters the simulation or save.
  final RunBuildIdentity? identity;
  const WeaponView(
    this.characterId, {
    super.key,
    required this.height,
    this.phase = WeaponPhase.idle,
    this.charge = 0.0,
    this.identity,
  });

  @override
  State<WeaponView> createState() => _WeaponViewState();
}

class _WeaponViewState extends State<WeaponView> with TickerProviderStateMixin {
  // Slow idle sway — bounded pumps in tests, same convention as EmberDrift.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  // Phase transition tween (retargeted on phase change).
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late double _from;
  late double _to;
  Curve _curve = Curves.easeOutCubic;
  bool _smearing = false;

  WeaponDef get _def => weaponFor(widget.characterId);

  /// PERF: the idle sway + swing tween feed the painter directly through
  /// [CustomPainter.repaint]. They used to drive an AnimatedBuilder, i.e. a
  /// setState 60x/s for as long as the weapon was on screen. The combat
  /// screen's stage sits inside a LayoutBuilder, so that setState scheduled
  /// a layout callback every frame and forced a full relayout + repaint of
  /// the whole screen — permanently, even with nothing happening. Cached so
  /// rebuilds don't hand the painter a fresh merge object each time.
  late final Listenable _paintClock = Listenable.merge([_sway, _move]);

  @override
  void initState() {
    super.initState();
    _from = _to = _def.idleAngle;
  }

  void _retarget(
    double target, {
    required Duration duration,
    required Curve curve,
    bool smear = false,
  }) {
    _from = _angle();
    _to = target;
    _curve = curve;
    _smearing = smear;
    _move
      ..duration = duration
      ..forward(from: 0);
  }

  /// Current tweened angle (before sway). Swings accelerate into contact
  /// (easeIn communicates weight); raises/recoveries ease out.
  double _angle() => _from + (_to - _from) * _curve.transform(_move.value);

  @override
  void didUpdateWidget(WeaponView old) {
    super.didUpdateWidget(old);
    if (old.characterId != widget.characterId) {
      _from = _to = _def.idleAngle;
      _move.value = 1;
    }
    if (old.phase != widget.phase) {
      switch (widget.phase) {
        case WeaponPhase.raise:
          // Anticipation: quick pull back past the shoulder.
          _retarget(
            _def.raiseAngle,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
          );
          break;
        case WeaponPhase.swing:
          // Strike: whip through the full arc, smear trailing the edge.
          _retarget(
            _def.swingAngle,
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeInCubic,
            smear: true,
          );
          break;
        case WeaponPhase.idle:
          // Recovery: settle back to the ready pose with a little
          // follow-through overshoot (weight lives in the deceleration).
          _retarget(
            _def.idleAngle,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
          );
          break;
      }
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.height, widget.height);
    return IgnorePointer(
      child: RepaintBoundary(
        // TweenAnimationBuilder eases charge changes (die picked/unpicked)
        // so the heat swells instead of popping.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.charge.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, charge, _) => CustomPaint(
            size: size,
            painter: _WeaponPainter(
              _def,
              swayAmp: widget.phase == WeaponPhase.idle ? 0.05 : 0.0,
              angleOf: _angle,
              sway: _sway,
              move: _move,
              smearing: () => _smearing && _move.isAnimating,
              smearFromOf: () => _from,
              charge: charge,
              identity: widget.identity,
              repaint: _paintClock,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeaponPainter extends CustomPainter {
  final WeaponDef def;
  final double swayAmp;
  final double Function() angleOf;
  final Animation<double> sway;
  final Animation<double> move;
  final bool Function() smearing;
  final double Function() smearFromOf;
  final double charge; // 0..1 heat from the selected die's pips
  final RunBuildIdentity? identity;

  /// Live values, read at paint time (see [_paintClock]).
  double get angle => angleOf() + math.sin(sway.value * math.pi * 2) * swayAmp;
  double? get smearFrom => smearing() ? smearFromOf() : null;
  double get sparkTime => sway.value; // sway clock reused for spark motion
  final Paint _p = Paint();
  final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xCC120C08);
  _WeaponPainter(
    this.def, {
    required this.swayAmp,
    required this.angleOf,
    required this.sway,
    required this.move,
    required this.smearing,
    required this.smearFromOf,
    this.charge = 0.0,
    this.identity,
    required super.repaint,
  });

  double _h(int i, int salt) {
    final v = math.sin(i * 113.9 + salt * 271.3) * 43758.5453;
    return v - v.floorToDouble();
  }

  Color get _accent => identity?.color ?? def.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final grip = Offset(size.width * 0.5, size.height * 0.66);
    final tier = identity?.dominantTier ?? 1;
    final reach = size.height * def.reach * (1.0 + (tier - 1) * 0.035);
    final accent = _accent;

    // Smear trail: a fading arc sector swept behind the blade (GDQuest's
    // "smear" — makes the attack read faster than it is).
    final from = smearFrom;
    if (from != null && (angle - from).abs() > 0.12) {
      final rect = Rect.fromCircle(center: grip, radius: reach * 0.98);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = reach * 0.30
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0,
          endAngle: math.pi * 2,
          transform: GradientRotation(from - math.pi / 2),
          colors: [
            accent.withValues(alpha: 0.0),
            accent.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawArc(
        rect.deflate(reach * 0.15),
        from - math.pi / 2,
        angle - from,
        false,
        _p,
      );
      _p.shader = null;
      // White-hot core streak on the trailing half of the smear — the glint
      // that sells speed (brighter when the swing was charged).
      final coreSweep = (angle - from) * 0.45;
      _p
        ..strokeWidth = reach * 0.09
        ..color = Colors.white.withValues(alpha: 0.35 + 0.45 * charge);
      canvas.drawArc(
        rect.deflate(reach * 0.15),
        angle - math.pi / 2 - coreSweep,
        coreSweep,
        false,
        _p,
      );
      _p.style = PaintingStyle.fill;
    }

    canvas.save();
    canvas.translate(grip.dx, grip.dy);
    canvas.rotate(angle);
    // Charge heat: a soft halo around the business end that swells with the
    // selected die's pips, plus embers rising off the edge.
    if (charge > 0.02) {
      final tip = Offset(0, -reach * 0.75);
      // Layered radial falloff (blur scaled to reach) so the heat reads as
      // a soft aura, not a solid disc.
      _p
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          reach * (0.16 + 0.10 * charge),
        );
      _p.color = accent.withValues(alpha: 0.05 + 0.11 * charge);
      canvas.drawCircle(tip, reach * (0.16 + 0.18 * charge), _p);
      _p.color = accent.withValues(alpha: 0.05 + 0.10 * charge);
      canvas.drawCircle(tip, reach * (0.08 + 0.10 * charge), _p);
      _p.maskFilter = null;
      final sparkCount = (2 + charge * 5).round();
      for (var i = 0; i < sparkCount; i++) {
        final f = (sparkTime * (0.7 + _h(i, 1) * 0.8) + _h(i, 2)) % 1.0;
        final x = (_h(i, 3) - 0.5) * reach * 0.30;
        final y = -reach * (0.45 + _h(i, 4) * 0.5) - f * reach * 0.22;
        _p.color = Color.lerp(
          accent,
          Colors.white,
          _h(i, 5) * 0.5,
        )!.withValues(alpha: (1.0 - f) * (0.35 + 0.5 * charge));
        canvas.drawCircle(Offset(x, y), 0.8 + _h(i, 6) * 1.4, _p);
      }
    }
    // All weapons draw in grip space: +y down the hand, -y out to the tip.
    switch (def.id) {
      case 'ward_maul':
        _maul(canvas, reach);
        break;
      case 'lucky_fang':
        _fang(canvas, reach);
        break;
      case 'brand_iron':
        _brandIron(canvas, reach);
        break;
      case 'coin_hook':
        _coinHook(canvas, reach);
        break;
      case 'pin_wrench':
        _pinWrench(canvas, reach);
        break;
      default:
        _sword(canvas, reach);
    }
    _buildMark(canvas, reach, accent);
    canvas.restore();
  }

  /// One extra silhouette/detail per pool path. This is intentionally small:
  /// the signature weapon remains recognisable while the run's build becomes
  /// visible at a glance.
  void _buildMark(Canvas canvas, double reach, Color accent) {
    final path = identity?.path ?? BuildPath.ember;
    final tier = identity?.dominantTier ?? 1;
    _p
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = reach * (0.022 + tier * 0.006)
      ..color = accent.withValues(alpha: 0.74 + tier * 0.07);
    switch (path) {
      case BuildPath.ember:
        // Forked lick of flame along the upper third.
        final flame = Path()
          ..moveTo(0, -reach * 0.52)
          ..quadraticBezierTo(reach * 0.10, -reach * 0.66, 0, -reach * 0.80)
          ..quadraticBezierTo(
            -reach * 0.08,
            -reach * 0.70,
            -reach * 0.03,
            -reach * 0.61,
          );
        canvas.drawPath(flame, _p);
        break;
      case BuildPath.blade:
        // A hooked second edge makes the profile visibly more aggressive.
        final hook = Path()
          ..moveTo(0, -reach * 0.46)
          ..lineTo(reach * 0.18, -reach * 0.68)
          ..lineTo(reach * 0.07, -reach * 0.88);
        canvas.drawPath(hook, _p);
        break;
      case BuildPath.aegis:
        // Compact guard plate around the grip.
        _p.style = PaintingStyle.fill;
        final plate = Path()
          ..moveTo(-reach * 0.17, -reach * 0.08)
          ..lineTo(0, -reach * 0.18)
          ..lineTo(reach * 0.17, -reach * 0.08)
          ..lineTo(reach * 0.11, reach * 0.06)
          ..lineTo(0, reach * 0.12)
          ..lineTo(-reach * 0.11, reach * 0.06)
          ..close();
        _p.color = accent.withValues(alpha: 0.58);
        canvas.drawPath(plate, _p);
        break;
      case BuildPath.heart:
        // Three steady forge-runes along the spine.
        _p.style = PaintingStyle.fill;
        for (final y in [0.38, 0.56, 0.74]) {
          canvas.drawCircle(
            Offset(0, -reach * y),
            reach * (0.018 + tier * 0.003),
            _p,
          );
        }
        break;
    }
    _p.style = PaintingStyle.fill;
  }

  void _sword(Canvas canvas, double reach) {
    final w = reach * 0.13; // half blade width
    // Hilt wrap + pommel.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4A3626);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, reach * 0.10),
          width: w * 1.1,
          height: reach * 0.22,
        ),
        Radius.circular(w * 0.5),
      ),
      _p,
    );
    _p.color = const Color(0xFF8A6A3A);
    canvas.drawCircle(Offset(0, reach * 0.22), w * 0.72, _p);
    // Crossguard.
    _p.color = const Color(0xFF6E5A3A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 4.4, height: w * 0.95),
        Radius.circular(w * 0.4),
      ),
      _p,
    );
    // Blade: warm steel, ember-lit edge.
    final blade = Path()
      ..moveTo(-w, -w * 0.6)
      ..lineTo(-w * 0.72, -reach * 0.92)
      ..lineTo(0, -reach) // tip
      ..lineTo(w * 0.72, -reach * 0.92)
      ..lineTo(w, -w * 0.6)
      ..close();
    _p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFB9A992), Color(0xFFDACCB2)],
    ).createShader(Rect.fromLTWH(-w, -reach, w * 2, reach));
    canvas.drawPath(blade, _p);
    _p.shader = null;
    _outline.strokeWidth = w * 0.18;
    canvas.drawPath(blade, _outline); // crisp silhouette against any bg
    // Forge-hot edge line up the leading side (white-hot when charged).
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.34
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        _accent,
        Colors.white,
        charge * 0.6,
      )!.withValues(alpha: 0.85 + 0.15 * charge);
    canvas.drawLine(Offset(w * 0.62, -w * 1.2), Offset(0, -reach * 0.97), _p);
    // Fuller groove.
    _p
      ..strokeWidth = w * 0.22
      ..color = const Color(0xFF8F8171).withValues(alpha: 0.8);
    canvas.drawLine(Offset(0, -w * 1.4), Offset(0, -reach * 0.8), _p);
    _p.style = PaintingStyle.fill;
  }

  void _maul(Canvas canvas, double reach) {
    final w = reach * 0.14;
    // Haft.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4A3626);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -reach * 0.36),
          width: w * 0.9,
          height: reach * 1.22,
        ),
        Radius.circular(w * 0.4),
      ),
      _p,
    );
    // Grip wrap.
    _p.color = const Color(0xFF6E5A3A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, reach * 0.06),
          width: w * 1.05,
          height: reach * 0.2,
        ),
        Radius.circular(w * 0.4),
      ),
      _p,
    );
    // Head: squat iron block with a gold band + rivet, warden-blue sheen.
    final head = Rect.fromCenter(
      center: Offset(0, -reach * 0.82),
      width: w * 4.6,
      height: reach * 0.34,
    );
    _p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFF3C4354), Color(0xFF5C6880)],
    ).createShader(head);
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, Radius.circular(w * 0.5)),
      _p,
    );
    _p.shader = null;
    _outline.strokeWidth = w * 0.16;
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, Radius.circular(w * 0.5)),
      _outline,
    );
    _p.color = const Color(0xFFE8C24A);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -reach * 0.82),
        width: w * 0.5,
        height: reach * 0.34,
      ),
      _p,
    );
    _p.color = _accent.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(-w * 1.6, -reach * 0.82), w * 0.3, _p);
    canvas.drawCircle(Offset(w * 1.6, -reach * 0.82), w * 0.3, _p);
  }

  void _fang(Canvas canvas, double reach) {
    final w = reach * 0.12;
    // Pommel with the gambler's gem.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4A3626);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, reach * 0.08),
          width: w,
          height: reach * 0.2,
        ),
        Radius.circular(w * 0.5),
      ),
      _p,
    );
    _p.color = const Color(0xFFC24040);
    canvas.drawCircle(Offset(0, reach * 0.2), w * 0.55, _p);
    // Short guard.
    _p.color = const Color(0xFF8A6A3A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 3.0, height: w * 0.8),
        Radius.circular(w * 0.4),
      ),
      _p,
    );
    // Curved blade: crescent fang leaning into the swing direction.
    final blade = Path()
      ..moveTo(-w * 0.7, -w * 0.4)
      ..quadraticBezierTo(
        w * 1.6,
        -reach * 0.5,
        w * 0.35,
        -reach,
      ) // outer edge (leading)
      ..quadraticBezierTo(w * 0.3, -reach * 0.5, -w * 0.7, -w * 0.4)
      ..close();
    _p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFB9A992), Color(0xFFE6DCC4)],
    ).createShader(Rect.fromLTWH(-w, -reach, w * 2.6, reach));
    canvas.drawPath(blade, _p);
    _p.shader = null;
    _outline.strokeWidth = w * 0.16;
    canvas.drawPath(blade, _outline);
    // Gold glint on the leading edge.
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.3
      ..strokeCap = StrokeCap.round
      ..color = _accent.withValues(alpha: 0.9);
    final glint = Path()
      ..moveTo(w * 0.05, -w * 1.2)
      ..quadraticBezierTo(w * 1.35, -reach * 0.5, w * 0.32, -reach * 0.94);
    canvas.drawPath(glint, _p);
    _p.style = PaintingStyle.fill;
  }

  void _coinHook(Canvas canvas, double reach) {
    final w = reach * 0.12;
    // Coin-weighted pommel: a brass disc with a stamped inner ring.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB98F3E);
    canvas.drawCircle(Offset(0, reach * 0.14), w * 0.85, _p);
    _p.color = const Color(0xFFE6C878);
    canvas.drawCircle(Offset(0, reach * 0.14), w * 0.6, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..color = const Color(0xFF8A6A3A);
    canvas.drawCircle(Offset(0, reach * 0.14), w * 0.38, _p);
    // Wrapped grip + slim hardwood shaft up to the hook's throat.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4A3626);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -reach * 0.28),
          width: w * 0.7,
          height: reach * 0.78,
        ),
        Radius.circular(w * 0.35),
      ),
      _p,
    );
    // Brass ferrule where the hook is socketed onto the shaft.
    _p.color = const Color(0xFF8A6A3A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -reach * 0.62),
          width: w * 1.1,
          height: w * 0.7,
        ),
        Radius.circular(w * 0.3),
      ),
      _p,
    );
    // The cargo hook: a thick brass crescent opening into the swing.
    final hook = Path()
      ..moveTo(-w * 0.35, -reach * 0.64)
      ..quadraticBezierTo(-w * 0.5, -reach * 1.02, w * 0.9, -reach * 0.98)
      ..quadraticBezierTo(w * 1.9, -reach * 0.94, w * 1.6, -reach * 0.72)
      ..quadraticBezierTo(w * 1.75, -reach * 0.9, w * 0.95, -reach * 0.86)
      ..quadraticBezierTo(w * 0.2, -reach * 0.88, w * 0.35, -reach * 0.64)
      ..close();
    _p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFB98F3E), Color(0xFFE6C878)],
    ).createShader(Rect.fromLTWH(-w, -reach, w * 3.0, reach * 0.5));
    canvas.drawPath(hook, _p);
    _p.shader = null;
  }

  void _pinWrench(Canvas canvas, double reach) {
    final w = reach * 0.12;
    // Cross-pin through the pommel: the tool's namesake.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6E7B85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, reach * 0.14),
          width: w * 1.7,
          height: w * 0.42,
        ),
        Radius.circular(w * 0.2),
      ),
      _p,
    );
    // Wrapped grip: dark leather over the lower shaft.
    _p.color = const Color(0xFF3A3F45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -reach * 0.04),
          width: w * 0.78,
          height: reach * 0.34,
        ),
        Radius.circular(w * 0.35),
      ),
      _p,
    );
    // Long burnished steel shaft up to the head.
    _p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFF7C8B96), Color(0xFFB9CBD6)],
    ).createShader(Rect.fromLTWH(-w, -reach, w * 2.0, reach));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -reach * 0.44),
          width: w * 0.6,
          height: reach * 0.52,
        ),
        Radius.circular(w * 0.3),
      ),
      _p,
    );
    _p.shader = null;
    // The spanner head: a C-jaw opening into the swing, drawn as a thick
    // crescent with a squared bite so it reads as a tool, not a blade.
    final jaw = Path()
      ..moveTo(-w * 0.9, -reach * 0.70)
      ..quadraticBezierTo(-w * 1.5, -reach * 0.94, -w * 0.4, -reach * 1.02)
      ..lineTo(w * 1.0, -reach * 1.06)
      ..lineTo(w * 1.0, -reach * 0.92)
      ..lineTo(w * 0.15, -reach * 0.90)
      ..quadraticBezierTo(-w * 0.5, -reach * 0.86, -w * 0.25, -reach * 0.70)
      ..close();
    _p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFF8FA5B2), Color(0xFFD3E2EA)],
    ).createShader(Rect.fromLTWH(-w * 1.5, -reach * 1.1, w * 3.0, reach * 0.4));
    canvas.drawPath(jaw, _p);
    _p.shader = null;
    // Adjustment pin socket on the head.
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.2
      ..color = const Color(0xFF4C5B66);
    canvas.drawCircle(Offset(w * 0.55, -reach * 0.99), w * 0.28, _p);
    _p.style = PaintingStyle.fill;
  }

  void _brandIron(Canvas canvas, double reach) {
    final w = reach * 0.09;
    // Long dark iron rod.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF3A3148);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -reach * 0.38),
          width: w,
          height: reach * 1.28,
        ),
        Radius.circular(w * 0.5),
      ),
      _p,
    );
    // Leather grip.
    _p.color = const Color(0xFF4A3626);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, reach * 0.05),
          width: w * 1.4,
          height: reach * 0.24,
        ),
        Radius.circular(w * 0.6),
      ),
      _p,
    );
    // White-hot brand head: glowing ring + core.
    final tip = Offset(0, -reach * 0.94);
    _p.color = _accent.withValues(alpha: 0.35 + 0.3 * charge);
    canvas.drawCircle(tip, w * 3.1, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.9
      ..color = _accent;
    canvas.drawCircle(tip, w * 1.9, _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFE2B8);
    canvas.drawCircle(tip, w * 0.85, _p);
  }

  @override
  bool shouldRepaint(covariant _WeaponPainter old) =>
      // Animation-driven values arrive via [repaint]; only rebuild-time
      // inputs are compared here.
      old.def != def ||
      old.charge != charge ||
      old.identity?.path != identity?.path ||
      old.identity?.dominantTier != identity?.dominantTier ||
      old._accent != _accent ||
      old.swayAmp != swayAmp ||
      old.sway != sway ||
      old.move != move;
}

// ---------------------------------------------------------------------------
// ImpactSlash — one-shot contact overlay on the victim: a weapon smear
// crescent (player attacks) or a three-line claw rake (enemy attacks, whose
// sheets have no attack frames), with a spark burst on the impact frame.
// ---------------------------------------------------------------------------
class ImpactSlash extends StatefulWidget {
  final bool claws;
  final Color color;
  final Duration duration;
  final VoidCallback onDone;
  const ImpactSlash({
    super.key,
    required this.onDone,
    this.claws = false,
    this.color = EmberColors.gold,
    this.duration = const Duration(milliseconds: 340),
  });

  @override
  State<ImpactSlash> createState() => _ImpactSlashState();
}

class _ImpactSlashState extends State<ImpactSlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ImpactSlashPainter(
            _t,
            claws: widget.claws,
            color: widget.color,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ImpactSlashPainter extends CustomPainter {
  final Animation<double> t;
  final bool claws;
  final Color color;
  final Paint _p = Paint();
  _ImpactSlashPainter(this.t, {required this.claws, required this.color})
    : super(repaint: t);

  double _h(int i, int salt) {
    final v = math.sin(i * 157.3 + salt * 269.1) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = t.value;
    if (f >= 1.0) return;
    final c = Offset(size.width / 2, size.height * 0.5);
    final r = size.shortestSide * 0.42;
    // The slash draws on in the first 40%, fades over the rest — impact
    // frame short and violent, decay soft (2D impact-animation anatomy).
    final grow = Curves.easeOutCubic.transform((f / 0.4).clamp(0.0, 1.0));
    final fade = f < 0.35 ? 1.0 : 1.0 - (f - 0.35) / 0.65;

    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (claws) {
      // Three raked lines, upper-left to lower-right across the victim.
      for (var i = 0; i < 3; i++) {
        final off = (i - 1) * r * 0.34;
        final a = Offset(c.dx - r * 0.75 + off, c.dy - r * 0.9);
        final b = Offset(c.dx + r * 0.55 + off, c.dy + r * 0.8);
        final end = Offset.lerp(a, b, grow)!;
        _p
          ..strokeWidth = r * (0.09 - i * 0.015)
          ..color = color.withValues(alpha: (0.9 - i * 0.18) * fade);
        canvas.drawLine(a, end, _p);
      }
    } else {
      // One clean crescent smear sweeping through the victim.
      final rect = Rect.fromCircle(center: c, radius: r);
      const start = -2.4; // upper-left
      final sweep = 2.1 * grow;
      _p
        ..strokeWidth = r * 0.16
        ..color = color.withValues(alpha: 0.85 * fade);
      canvas.drawArc(rect, start, sweep, false, _p);
      _p
        ..strokeWidth = r * 0.07
        ..color = Colors.white.withValues(alpha: 0.8 * fade);
      canvas.drawArc(
        rect.deflate(r * 0.02),
        start + 0.15,
        sweep * 0.85,
        false,
        _p,
      );
    }
    // Impact sparks: fly out from the center, cooling.
    _p.style = PaintingStyle.fill;
    for (var i = 0; i < 9; i++) {
      final ang = _h(i, 1) * math.pi * 2;
      final dist = (r * 0.2 + _h(i, 2) * r * 0.9) * Curves.easeOut.transform(f);
      final p = Offset(
        c.dx + math.cos(ang) * dist,
        c.dy + math.sin(ang) * dist - f * f * 14,
      );
      _p.color = Color.lerp(
        Colors.white,
        color,
        (f * 1.6).clamp(0.0, 1.0),
      )!.withValues(alpha: fade * (0.5 + _h(i, 3) * 0.5));
      canvas.drawCircle(p, (1.0 - f * 0.5) * (1.4 + _h(i, 4) * 2.0), _p);
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactSlashPainter old) => false;
}

// ---------------------------------------------------------------------------
// GuardFlash — one-shot shield-arc flourish. Pops in front of the defender
// with overshoot, shimmers block-blue, fades. Block finally LOOKS like
// something happened.
// ---------------------------------------------------------------------------
class GuardFlash extends StatefulWidget {
  /// +1: shield faces right (the player guarding); -1: faces left (enemy).
  final int facing;
  final VoidCallback onDone;
  final Duration duration;
  const GuardFlash({
    super.key,
    required this.onDone,
    this.facing = 1,
    this.duration = const Duration(milliseconds: 480),
  });

  @override
  State<GuardFlash> createState() => _GuardFlashState();
}

class _GuardFlashState extends State<GuardFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GuardFlashPainter(_t, widget.facing),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GuardFlashPainter extends CustomPainter {
  final Animation<double> t;
  final int facing;
  final Paint _p = Paint();
  _GuardFlashPainter(this.t, this.facing) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final f = t.value;
    if (f >= 1.0) return;
    // Pop with overshoot, then fade.
    final scale = f < 0.25 ? 0.6 + (f / 0.25) * 0.5 : 1.1 - (f - 0.25) * 0.13;
    final fade = f < 0.45 ? 1.0 : 1.0 - (f - 0.45) / 0.55;
    final c = Offset(
      size.width / 2 + facing * size.width * 0.16,
      size.height * 0.52,
    );
    final r = size.shortestSide * 0.30 * scale;
    // Shield arc: a vertical crescent facing the attacker.
    final rect = Rect.fromCircle(center: c, radius: r);
    final start = facing > 0 ? -math.pi / 2 + 0.25 : math.pi / 2 + 0.25;
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.22
      ..color = EmberColors.block.withValues(alpha: 0.85 * fade);
    canvas.drawArc(rect, start, math.pi - 0.5, false, _p);
    _p
      ..strokeWidth = r * 0.08
      ..color = Colors.white.withValues(alpha: 0.7 * fade);
    canvas.drawArc(
      rect.deflate(r * 0.14),
      start + 0.12,
      math.pi - 0.74,
      false,
      _p,
    );
    // Rune dot at the boss of the shield.
    _p
      ..style = PaintingStyle.fill
      ..color = EmberColors.block.withValues(alpha: fade);
    canvas.drawCircle(c, r * 0.1, _p);
  }

  @override
  bool shouldRepaint(covariant _GuardFlashPainter old) => false;
}
