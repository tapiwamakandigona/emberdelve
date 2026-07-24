// Tiny pooled-ish fx: dust puffs (landing / coin pops / rubble) drawn as
// fading circles, and the enemy-death flash animation.
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
