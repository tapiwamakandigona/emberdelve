// Tiny pooled-ish fx: dust puffs (landing / coin pops / rubble) drawn as
// fading circles, the enemy-death flash animation, and the AKP-3 combat juice
// (swing arcs + floating damage numbers).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show
        FontWeight,
        TextDirection,
        TextPainter,
        TextScaler,
        TextSpan,
        TextStyle;

import '../tuning.dart';

/// A short-lived burst of fading circles. Cheap: no particle system, no
/// per-frame allocations after construction.
class PuffFx extends PositionComponent {
  final ui.Color color;
  final double life;
  final double radius;
  double _t = 0;
  final _paint = ui.Paint();

  PuffFx(Vector2 at,
      {this.color = const ui.Color(0xAAC9BFA8),
      this.life = 0.28,
      this.radius = 5})
      : super(position: at, priority: 4);

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final k = (1 - _t / life).clamp(0.0, 1.0);
    _paint.color = color.withValues(alpha: color.a * k);
    final r = radius * (0.5 + 0.5 * (1 - k));
    canvas.drawCircle(ui.Offset(-radius, 0), r * 0.8, _paint);
    canvas.drawCircle(ui.Offset.zero, r, _paint);
    canvas.drawCircle(ui.Offset(radius, 0), r * 0.8, _paint);
  }
}

/// Enemy death: fx/enemy_death.png, 6 frames of 40x41, play once and vanish.
class DeathFx extends SpriteAnimationComponent {
  DeathFx(Vector2 at, SpriteAnimation animation)
      : super(
          animation: animation,
          position: at,
          size: Vector2(40, 41),
          anchor: Anchor.center,
          priority: 4,
          removeOnFinish: true,
        );
}

/// Coin/loot sparkle: a few gold star-points that fly up and out, fading.
/// Offsets pre-baked at construction — zero per-frame allocations.
class SparkleFx extends PositionComponent {
  static const _count = 5;
  final double life;
  final ui.Color color;
  double _t = 0;
  final _paint = ui.Paint();
  final List<ui.Offset> _dirs;

  SparkleFx(Vector2 at,
      {this.color = const ui.Color(0xFFF2C14E), this.life = 0.35, int seed = 0})
      : _dirs = List.generate(_count, (i) {
          // Deterministic fan spread: -60°..+60° around straight up.
          final a = -2.1 + (i / (_count - 1)) * 2.1 * 2 - 1.5708;
          return ui.Offset(18 * math.cos(a), 18 * math.sin(a) - 10);
        }, growable: false),
        super(position: at, priority: 4);

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final k = (_t / life).clamp(0.0, 1.0);
    final fade = 1 - k;
    _paint.color = color.withValues(alpha: fade);
    for (final d in _dirs) {
      final x = d.dx * k, y = d.dy * k + 6 * k * k; // slight gravity
      // 4-point pixel star: center + cardinal points.
      final s = 1.0 + fade;
      canvas.drawRect(ui.Rect.fromLTWH(x - s / 2, y - s / 2, s, s), _paint);
      canvas.drawRect(ui.Rect.fromLTWH(x - s * 1.5, y - 0.5, s, 1), _paint);
      canvas.drawRect(ui.Rect.fromLTWH(x + s * 0.5, y - 0.5, s, 1), _paint);
      canvas.drawRect(ui.Rect.fromLTWH(x - 0.5, y - s * 1.5, 1, s), _paint);
      canvas.drawRect(ui.Rect.fromLTWH(x - 0.5, y + s * 0.5, 1, s), _paint);
    }
  }
}

/// AKP-3b: the melee swing arc — the single biggest "reads like Apple Knight"
/// win in combat. A tapered crescent that sweeps through the swing direction
/// and fades out over [kSwingArcLife]. Procedural on purpose: no new art
/// asset (nothing to license, nothing to atlas) and it can be tinted per
/// weapon (AKP-4b) by passing [color].
class SwingArcFx extends PositionComponent {
  final int facing; // +1 right, -1 left
  final double life;
  final ui.Color color;
  final double reach; // outer radius px
  final double sweep; // radians covered by the crescent
  double _t = 0;
  final ui.Path _path;
  final _paint = ui.Paint()..style = ui.PaintingStyle.fill;

  SwingArcFx(
    Vector2 at, {
    required this.facing,
    this.color = const ui.Color(0xFFFFFFFF),
    this.life = 0.16,
    this.reach = 26,
    this.sweep = 1.9,
  })  : _path = _buildCrescent(reach, sweep),
        super(position: at, priority: 5);

  /// Local-space crescent centred on the +X axis: outer edge at [reach],
  /// inner edge at 55 % of it. Built once per swing, never per frame.
  static ui.Path _buildCrescent(double reach, double sweep) {
    final inner = reach * 0.55;
    final rect = ui.Rect.fromCircle(center: ui.Offset.zero, radius: reach);
    final innerRect = ui.Rect.fromCircle(center: ui.Offset.zero, radius: inner);
    return ui.Path()
      ..arcTo(rect, -sweep / 2, sweep, true)
      ..arcTo(innerRect, sweep / 2, -sweep, false)
      ..close();
  }

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final k = (_t / life).clamp(0.0, 1.0);
    // Bright at the start, gone at the end; the crescent also rotates through
    // the swing (top-down) so the eye reads a sweep, not a static shape.
    _paint.color = color.withValues(alpha: (1 - k) * 0.85);
    canvas.save();
    if (facing < 0) canvas.scale(-1, 1);
    canvas.rotate(-0.5 + k * 1.1);
    canvas.scale(0.9 + 0.2 * k);
    canvas.drawPath(_path, _paint);
    canvas.restore();
  }
}

/// AKP-3c: floating damage numbers. Rises, fades, and crits read bigger and
/// weapon-tinted. Text layout is cached per (value, crit, colour) for the
/// whole run, so the steady state is one `TextPainter.paint` per number and
/// no text layout in a combat frame.
class DamageNumberFx extends PositionComponent {
  final int amount;
  final bool crit;
  final double life;
  double _t = 0;
  final TextPainter _painter;
  final _fade = ui.Paint();

  DamageNumberFx(
    Vector2 at, {
    required this.amount,
    this.crit = false,
    ui.Color color = const ui.Color(0xFFF4EAD5),
    this.life = kDamageNumberLife,
  })  : _painter = _painterFor(amount, crit, color),
        super(position: at, priority: 6);

  static final Map<int, TextPainter> _cache = {};

  static TextPainter _painterFor(int amount, bool crit, ui.Color color) {
    final key = Object.hash(amount.clamp(0, 999), crit, color.toARGB32()) &
        0x7fffffff;
    final hit = _cache[key];
    if (hit != null) return hit;
    final tp = TextPainter(
      text: TextSpan(
        text: crit ? '$amount!' : '$amount',
        style: TextStyle(
          fontSize: crit ? 11 : 8,
          height: 1,
          fontFamily: 'Inter',
          fontWeight: crit ? FontWeight.w700 : FontWeight.w600,
          color: color,
          shadows: const [
            ui.Shadow(color: ui.Color(0xFF201826), offset: ui.Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    // Bounded by construction: damage values are small integers and there are
    // a handful of weapon tints, so this is a few dozen entries at most.
    if (_cache.length < 64) _cache[key] = tp;
    return tp;
  }

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final k = (_t / life).clamp(0.0, 1.0);
    // Ease-out rise; the number holds full opacity for the first 60 % of its
    // life so it stays readable, then fades.
    final rise = -kDamageNumberRise * (1 - (1 - k) * (1 - k));
    final alpha = k < 0.6 ? 1.0 : (1 - (k - 0.6) / 0.4).clamp(0.0, 1.0);
    final w = _painter.width, h = _painter.height;
    canvas.save();
    canvas.translate(-w / 2, rise);
    if (alpha < 1) {
      // Tight bounds keep this layer cheap (numbers are ~12x11 logical px).
      _fade.color = ui.Color.fromARGB((alpha * 255).round(), 255, 255, 255);
      canvas.saveLayer(ui.Rect.fromLTWH(-1, -1, w + 2, h + 2), _fade);
      _painter.paint(canvas, ui.Offset.zero);
      canvas.restore();
    } else {
      _painter.paint(canvas, ui.Offset.zero);
    }
    canvas.restore();
  }
}
