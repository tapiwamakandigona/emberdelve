// Tiny pooled-ish fx: dust puffs (landing / coin pops / rubble) drawn as
// fading circles, and the enemy-death flash animation.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

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
