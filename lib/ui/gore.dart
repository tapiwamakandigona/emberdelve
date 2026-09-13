// lib/ui/gore.dart — blood and ichor. v0.183.0 "Bodies in the Fight".
//
// A landed hit sprays droplets away from the attacker; some of them fall to
// the stage floor and STAY there for the rest of the encounter, so a long
// fight looks fought. Delvers bleed red; the delve's creatures bleed what
// they are made of (embers, soot, ichor — see [ichorFor]).
//
// Restraint is the design rule: the burst is short (~520 ms), droplets are
// 1–4 px, the floor stains are dark and low-alpha. This is a wound cue, not
// a splatter show. Everything is deterministic (seeded by hit index) so
// frames never flicker and tests can pin it. No saveLayer, no blur.
//
// Content rating note: this is the only place blood is drawn. The Play
// rating questionnaire must declare it (docs/release.md).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'combat_pose.dart';
import 'motion.dart';

/// Colours for each ichor family: (droplet, floor stain).
(Color, Color) ichorPalette(Ichor ichor) => switch (ichor) {
  Ichor.blood => (const Color(0xFFB81E1E), const Color(0xFF4E0B0B)),
  Ichor.ember => (const Color(0xFFFF9A3C), const Color(0xFF7A3410)),
  Ichor.soot => (const Color(0xFF4A3F55), const Color(0xFF16101E)),
  Ichor.ichor => (const Color(0xFF9CC23A), const Color(0xFF3D5216)),
};

/// One-shot burst of droplets from a hit. Sized to the victim's box (the
/// stage hands it the same 1.35× box the contact FX use); the wound point
/// sits mid-torso on the attacker's side.
class BloodBurst extends StatefulWidget {
  /// damage / victim max HP, 0..1 — drives droplet count and reach.
  final double severity;

  /// +1: the attacker stood screen-left (droplets fly right). -1: reverse.
  final int facing;
  final Ichor ichor;
  final int seed;
  final Duration duration;
  final VoidCallback onDone;

  /// Called once, at the burst's end, with the floor landing spots
  /// (fractions of the widget width from its left edge, and stain radius in
  /// px) so the stage can keep them.
  final void Function(List<FloorStain> stains)? onStains;
  const BloodBurst({
    super.key,
    required this.severity,
    required this.onDone,
    this.facing = 1,
    this.ichor = Ichor.blood,
    this.seed = 0,
    this.duration = const Duration(milliseconds: 520),
    this.onStains,
  });

  @override
  State<BloodBurst> createState() => _BloodBurstState();
}

class _BloodBurstState extends State<BloodBurst>
    with SingleTickerProviderStateMixin {
  late final List<Droplet> _drops = spray(
    widget.severity,
    facing: widget.facing,
    seed: widget.seed,
  );
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    // Reduce motion: no flying droplets. The stains still land (they are
    // the informative part) and the burst reports done next frame.
    if (Motion.instance.reduced) {
      _t.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _t.forward().whenComplete(_finish);
    }
  }

  void _finish() {
    if (_reported) return;
    _reported = true;
    if (!mounted) return;
    final box = context.size;
    if (widget.onStains != null && box != null) {
      widget.onStains!(_landings(box));
    }
    widget.onDone();
  }

  /// Where the staining droplets end up on the floor line (y = 0.86 h).
  List<FloorStain> _landings(Size size) {
    final h = size.height;
    final out = <FloorStain>[];
    final origin = _origin(size);
    for (var i = 0; i < _drops.length; i++) {
      final d = _drops[i];
      if (!d.stains) continue;
      // Solve the same ballistic path the painter draws, at the floor.
      final vx = math.cos(d.angle) * d.speed * h;
      final vy = math.sin(d.angle) * d.speed * h;
      final floorY = h * 0.86;
      // y(t) = oy + vy t + 0.5 g t²  → land when y == floorY.
      const g = 900.0;
      final a = 0.5 * g, b = vy, c = origin.dy - floorY;
      final disc = b * b - 4 * a * c;
      if (disc < 0) continue;
      final t = (-b + math.sqrt(disc)) / (2 * a);
      if (t <= 0 || t > 1.4) continue;
      final x = origin.dx + vx * t;
      if (x < -size.width * 0.2 || x > size.width * 1.2) continue;
      out.add(FloorStain(x / size.width, d.size * 1.6, widget.ichor));
    }
    return out;
  }

  Offset _origin(Size size) => Offset(
    size.width * (widget.facing > 0 ? 0.42 : 0.58),
    size.height * 0.46,
  );

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
          painter: _BloodPainter(_t, _drops, widget.ichor, _origin),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BloodPainter extends CustomPainter {
  final Animation<double> t;
  final List<Droplet> drops;
  final Ichor ichor;
  final Offset Function(Size) origin;
  final Paint _p = Paint()..style = PaintingStyle.fill;
  _BloodPainter(this.t, this.drops, this.ichor, this.origin)
    : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final f = t.value;
    if (f >= 1.0) return;
    final (drop, _) = ichorPalette(ichor);
    final h = size.height;
    final o = origin(size);
    const life = 0.52; // seconds, matches the default duration
    final time = f * life;
    const g = 900.0;
    for (final d in drops) {
      final tt = time;
      if (f > d.lifeFrac) continue;
      final vx = math.cos(d.angle) * d.speed * h;
      final vy = math.sin(d.angle) * d.speed * h;
      final x = o.dx + vx * tt;
      final y = o.dy + vy * tt + 0.5 * g * tt * tt;
      if (y > h * 0.88) continue; // on the floor: the stain layer owns it
      final alpha = (1.0 - f / d.lifeFrac).clamp(0.0, 1.0);
      _p.color = drop.withValues(alpha: 0.55 + 0.45 * alpha);
      // Stretch along the velocity so fast drops read as streaks.
      final speed = math.sqrt(vx * vx + (vy + g * tt) * (vy + g * tt));
      final stretch = (1.0 + speed / (h * 6)).clamp(1.0, 2.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.atan2(vy + g * tt, vx));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: d.size * 2 * stretch,
          height: d.size * 2,
        ),
        _p,
      );
      canvas.restore();
    }
    // A brief dark spurt at the wound itself, first 30% only.
    if (f < 0.3) {
      final k = 1.0 - f / 0.3;
      _p.color = drop.withValues(alpha: 0.7 * k);
      canvas.drawCircle(o, h * 0.035 * (1.2 - k * 0.4), _p);
    }
  }

  @override
  bool shouldRepaint(covariant _BloodPainter old) => false;
}

/// A dried mark on the stage floor. [x] is a fraction of the stage width
/// (the stage owns the coordinate space); [r] is the radius in px.
class FloorStain {
  final double x;
  final double r;
  final Ichor ichor;
  const FloorStain(this.x, this.r, this.ichor);
}

/// Paints every stain the encounter has produced along the floor line.
/// Static — repaints only when the list changes.
class FloorStainsPainter extends CustomPainter {
  final List<FloorStain> stains;
  final double floorY; // fraction of height
  final Paint _p = Paint()..style = PaintingStyle.fill;
  FloorStainsPainter(this.stains, {this.floorY = 0.93});

  @override
  void paint(Canvas canvas, Size size) {
    if (stains.isEmpty) return;
    final y = size.height * floorY;
    for (var i = 0; i < stains.length; i++) {
      final s = stains[i];
      final (_, stain) = ichorPalette(s.ichor);
      final c = Offset(s.x * size.width, y + (i % 3) * 1.5);
      _p.color = stain.withValues(alpha: 0.62);
      // Flattened puddle: wide, low.
      canvas.drawOval(
        Rect.fromCenter(center: c, width: s.r * 3.2, height: s.r * 1.1),
        _p,
      );
      _p.color = stain.withValues(alpha: 0.38);
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(s.r * 1.2, -s.r * 0.2),
          width: s.r * 1.6,
          height: s.r * 0.7,
        ),
        _p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FloorStainsPainter old) =>
      old.stains.length != stains.length || old.floorY != floorY;
}
