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
  const WeaponDef(this.id, this.name,
      {required this.accent,
      this.reach = 0.52,
      this.idleAngle = 0.42,
      this.raiseAngle = -1.75,
      this.swingAngle = 1.85});
}

/// Character id -> signature weapon. Unknown ids fall back to the Kindler's
/// brand so a future character never renders empty-handed.
const Map<String, WeaponDef> _weapons = {
  // The balanced start: a short sword whose edge still glows from the forge.
  'kindler': WeaponDef('ember_brand', 'Ember Brand',
      accent: Color(0xFFF0A24C)),
  // Tanky: a squat iron maul — slower arc, heavier presence.
  'warden': WeaponDef('ward_maul', 'Ward Maul',
      accent: Color(0xFF9FB6D9),
      reach: 0.46,
      idleAngle: 0.55,
      raiseAngle: -2.0,
      swingAngle: 1.7),
  // High variance: a curved luck-fang, quick and showy.
  'gambler': WeaponDef('lucky_fang', 'Lucky Fang',
      accent: Color(0xFFE8C24A),
      reach: 0.44,
      idleAngle: 0.3,
      raiseAngle: -1.55,
      swingAngle: 2.0),
  // Fragile but sharp: the brand iron, tip still white-hot.
  'ascetic': WeaponDef('brand_iron', 'Brand Iron',
      accent: Color(0xFFFF7A3C), reach: 0.58, idleAngle: 0.36),
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
  const WeaponView(this.characterId,
      {super.key,
      required this.height,
      this.phase = WeaponPhase.idle,
      this.charge = 0.0});

  @override
  State<WeaponView> createState() => _WeaponViewState();
}

class _WeaponViewState extends State<WeaponView>
    with TickerProviderStateMixin {
  // Slow idle sway — bounded pumps in tests, same convention as EmberDrift.
  late final AnimationController _sway = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  // Phase transition tween (retargeted on phase change).
  late final AnimationController _move = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  late double _from;
  late double _to;
  Curve _curve = Curves.easeOutCubic;
  bool _smearing = false;

  WeaponDef get _def => weaponFor(widget.characterId);

  @override
  void initState() {
    super.initState();
    _from = _to = _def.idleAngle;
  }

  void _retarget(double target,
      {required Duration duration, required Curve curve, bool smear = false}) {
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
  double _angle() =>
      _from + (_to - _from) * _curve.transform(_move.value);

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
          _retarget(_def.raiseAngle,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut);
          break;
        case WeaponPhase.swing:
          // Strike: whip through the full arc, smear trailing the edge.
          _retarget(_def.swingAngle,
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeInCubic,
              smear: true);
          break;
        case WeaponPhase.idle:
          // Recovery: settle back to the ready pose with a little
          // follow-through overshoot (weight lives in the deceleration).
          _retarget(_def.idleAngle,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack);
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
          builder: (context, charge, _) => AnimatedBuilder(
            animation: Listenable.merge([_sway, _move]),
            builder: (context, _) {
              final swayAmp = widget.phase == WeaponPhase.idle ? 0.05 : 0.0;
              final angle = _angle() +
                  math.sin(_sway.value * math.pi * 2) * swayAmp;
              final smearFrom =
                  _smearing && _move.isAnimating ? _from : null;
              return CustomPaint(
                size: size,
                painter: _WeaponPainter(_def, angle,
                    smearFrom: smearFrom,
                    charge: charge,
                    sparkTime: _sway.value),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WeaponPainter extends CustomPainter {
  final WeaponDef def;
  final double angle;
  final double? smearFrom; // when set, draw the smear arc from here to angle
  final double charge; // 0..1 heat from the selected die's pips
  final double sparkTime; // sway clock reused for charge-spark motion
  final Paint _p = Paint();
  final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xCC120C08);
  _WeaponPainter(this.def, this.angle,
      {this.smearFrom, this.charge = 0.0, this.sparkTime = 0.0});

  double _h(int i, int salt) {
    final v = math.sin(i * 113.9 + salt * 271.3) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grip = Offset(size.width * 0.5, size.height * 0.66);
    final reach = size.height * def.reach;

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
            def.accent.withValues(alpha: 0.0),
            def.accent.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawArc(rect.deflate(reach * 0.15), from - math.pi / 2,
          angle - from, false, _p);
      _p.shader = null;
      // White-hot core streak on the trailing half of the smear — the glint
      // that sells speed (brighter when the swing was charged).
      final coreSweep = (angle - from) * 0.45;
      _p
        ..strokeWidth = reach * 0.09
        ..color = Colors.white.withValues(alpha: 0.35 + 0.45 * charge);
      canvas.drawArc(rect.deflate(reach * 0.15),
          angle - math.pi / 2 - coreSweep, coreSweep, false, _p);
      _p.style = PaintingStyle.fill;
    }

    canvas.save();
    canvas.translate(grip.dx, grip.dy);
    canvas.rotate(angle);
    // Charge heat: a soft halo around the business end that swells with the
    // selected die's pips, plus embers rising off the edge.
    if (charge > 0.02) {
      final tip = Offset(0, -reach * 0.75);
      _p
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = def.accent.withValues(alpha: 0.10 + 0.28 * charge);
      canvas.drawCircle(tip, reach * (0.18 + 0.22 * charge), _p);
      _p.maskFilter = null;
      final sparkCount = (2 + charge * 5).round();
      for (var i = 0; i < sparkCount; i++) {
        final f = (sparkTime * (0.7 + _h(i, 1) * 0.8) + _h(i, 2)) % 1.0;
        final x = (_h(i, 3) - 0.5) * reach * 0.30;
        final y = -reach * (0.45 + _h(i, 4) * 0.5) - f * reach * 0.22;
        _p.color = Color.lerp(def.accent, Colors.white, _h(i, 5) * 0.5)!
            .withValues(alpha: (1.0 - f) * (0.35 + 0.5 * charge));
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
      default:
        _sword(canvas, reach);
    }
    canvas.restore();
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
                height: reach * 0.22),
            Radius.circular(w * 0.5)),
        _p);
    _p.color = const Color(0xFF8A6A3A);
    canvas.drawCircle(Offset(0, reach * 0.22), w * 0.72, _p);
    // Crossguard.
    _p.color = const Color(0xFF6E5A3A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: w * 4.4, height: w * 0.95),
            Radius.circular(w * 0.4)),
        _p);
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
      ..color = Color.lerp(def.accent, Colors.white, charge * 0.6)!
          .withValues(alpha: 0.85 + 0.15 * charge);
    canvas.drawLine(
        Offset(w * 0.62, -w * 1.2), Offset(0, -reach * 0.97), _p);
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
                height: reach * 1.22),
            Radius.circular(w * 0.4)),
        _p);
    // Grip wrap.
    _p.color = const Color(0xFF6E5A3A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, reach * 0.06),
                width: w * 1.05,
                height: reach * 0.2),
            Radius.circular(w * 0.4)),
        _p);
    // Head: squat iron block with a gold band + rivet, warden-blue sheen.
    final head = Rect.fromCenter(
        center: Offset(0, -reach * 0.82), width: w * 4.6, height: reach * 0.34);
    _p.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFF3C4354), Color(0xFF5C6880)],
    ).createShader(head);
    canvas.drawRRect(
        RRect.fromRectAndRadius(head, Radius.circular(w * 0.5)), _p);
    _p.shader = null;
    _outline.strokeWidth = w * 0.16;
    canvas.drawRRect(
        RRect.fromRectAndRadius(head, Radius.circular(w * 0.5)), _outline);
    _p.color = const Color(0xFFE8C24A);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(0, -reach * 0.82), width: w * 0.5, height: reach * 0.34),
        _p);
    _p.color = def.accent.withValues(alpha: 0.9);
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
                height: reach * 0.2),
            Radius.circular(w * 0.5)),
        _p);
    _p.color = const Color(0xFFC24040);
    canvas.drawCircle(Offset(0, reach * 0.2), w * 0.55, _p);
    // Short guard.
    _p.color = const Color(0xFF8A6A3A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: w * 3.0, height: w * 0.8),
            Radius.circular(w * 0.4)),
        _p);
    // Curved blade: crescent fang leaning into the swing direction.
    final blade = Path()
      ..moveTo(-w * 0.7, -w * 0.4)
      ..quadraticBezierTo(
          w * 1.6, -reach * 0.5, w * 0.35, -reach) // outer edge (leading)
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
      ..color = def.accent.withValues(alpha: 0.9);
    final glint = Path()
      ..moveTo(w * 0.05, -w * 1.2)
      ..quadraticBezierTo(w * 1.35, -reach * 0.5, w * 0.32, -reach * 0.94);
    canvas.drawPath(glint, _p);
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
                height: reach * 1.28),
            Radius.circular(w * 0.5)),
        _p);
    // Leather grip.
    _p.color = const Color(0xFF4A3626);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, reach * 0.05),
                width: w * 1.4,
                height: reach * 0.24),
            Radius.circular(w * 0.6)),
        _p);
    // White-hot brand head: glowing ring + core.
    final tip = Offset(0, -reach * 0.94);
    _p.color = def.accent.withValues(alpha: 0.35 + 0.3 * charge);
    canvas.drawCircle(tip, w * 3.1, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.9
      ..color = def.accent;
    canvas.drawCircle(tip, w * 1.9, _p);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFE2B8);
    canvas.drawCircle(tip, w * 0.85, _p);
  }

  @override
  bool shouldRepaint(covariant _WeaponPainter old) =>
      old.angle != angle ||
      old.smearFrom != smearFrom ||
      old.def != def ||
      old.charge != charge ||
      (charge > 0.02 && old.sparkTime != sparkTime);
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
  const ImpactSlash(
      {super.key,
      required this.onDone,
      this.claws = false,
      this.color = EmberColors.gold,
      this.duration = const Duration(milliseconds: 340)});

  @override
  State<ImpactSlash> createState() => _ImpactSlashState();
}

class _ImpactSlashState extends State<ImpactSlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: widget.duration)
        ..forward().whenComplete(widget.onDone);

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
          painter: _ImpactSlashPainter(_t, claws: widget.claws,
              color: widget.color),
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
      canvas.drawArc(rect.deflate(r * 0.02), start + 0.15,
          sweep * 0.85, false, _p);
    }
    // Impact sparks: fly out from the center, cooling.
    _p.style = PaintingStyle.fill;
    for (var i = 0; i < 9; i++) {
      final ang = _h(i, 1) * math.pi * 2;
      final dist = (r * 0.2 + _h(i, 2) * r * 0.9) * Curves.easeOut.transform(f);
      final p = Offset(c.dx + math.cos(ang) * dist,
          c.dy + math.sin(ang) * dist - f * f * 14);
      _p.color = Color.lerp(Colors.white, color, (f * 1.6).clamp(0.0, 1.0))!
          .withValues(alpha: fade * (0.5 + _h(i, 3) * 0.5));
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
  const GuardFlash(
      {super.key,
      required this.onDone,
      this.facing = 1,
      this.duration = const Duration(milliseconds: 480)});

  @override
  State<GuardFlash> createState() => _GuardFlashState();
}

class _GuardFlashState extends State<GuardFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: widget.duration)
        ..forward().whenComplete(widget.onDone);

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
        size.width / 2 + facing * size.width * 0.16, size.height * 0.52);
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
    canvas.drawArc(rect.deflate(r * 0.14), start + 0.12, math.pi - 0.74,
        false, _p);
    // Rune dot at the boss of the shield.
    _p
      ..style = PaintingStyle.fill
      ..color = EmberColors.block.withValues(alpha: fade);
    canvas.drawCircle(c, r * 0.1, _p);
  }

  @override
  bool shouldRepaint(covariant _GuardFlashPainter old) => false;
}
