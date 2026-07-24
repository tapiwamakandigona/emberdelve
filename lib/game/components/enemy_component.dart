// EnemyComponent: draws an EnemyCore (Thornling / Ashbat / Hopper) with hurt
// flash and facing flip; removes itself when the core dies (death fx + sfx
// are handled by the game's event loop).
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../ember_game.dart';
import '../enemies/enemy_core.dart';

class EnemyComponent extends PositionComponent
    with HasGameReference<EmberGame> {
  final EnemyCore core;
  EnemyComponent(this.core) : super(priority: 2);

  SpriteAnimationTicker? _ticker;
  SpriteAnimation? _main;
  SpriteAnimation? _alt; // hopper jump strip
  SpriteAnimation? _shown;

  static final _flashPaint = ui.Paint()
    ..colorFilter =
        const ui.ColorFilter.mode(ui.Color(0xFFFFFFFF), ui.BlendMode.srcATop);

  @override
  Future<void> onLoad() async {
    Future<SpriteAnimation> load(
        String path, int frames, Vector2 size, double stepTime) async {
      return SpriteAnimation.fromFrameData(
        await game.images.load(path),
        SpriteAnimationData.sequenced(
            amount: frames, stepTime: stepTime, textureSize: size),
      );
    }

    switch (core.kind) {
      case EnemyKind.thornling:
        _main =
            await load('enemies/thornling.png', 6, Vector2(36, 28), 0.11);
      case EnemyKind.ashbat:
        _main = await load('enemies/ashbat.png', 4, Vector2(40, 41), 0.10);
      case EnemyKind.hopper:
        _main =
            await load('enemies/hopper_idle.png', 4, Vector2(35, 32), 0.14);
        _alt = await load('enemies/hopper_jump.png', 2, Vector2(35, 32), 0.12);
    }
    _show(_main!);
  }

  void _show(SpriteAnimation anim) {
    if (identical(anim, _shown)) return;
    _shown = anim;
    _ticker = anim.createTicker();
  }

  @override
  void update(double dt) {
    if (!core.alive) {
      removeFromParent();
      return;
    }
    if (core is HopperCore && _alt != null) {
      _show((core as HopperCore).airborne ? _alt! : _main!);
    }
    if (!core.sleeping) _ticker?.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    final ticker = _ticker;
    if (ticker == null || core.sleeping) return;
    final sprite = ticker.getSprite();
    final w = sprite.srcSize.x, h = sprite.srcSize.y;
    final b = core.body;
    canvas.save();
    if (core.facing < 0) {
      canvas.translate(b.centerX * 2, 0);
      canvas.scale(-1, 1);
    }
    sprite.render(canvas,
        position: Vector2(b.centerX - w / 2, b.bottom - h),
        size: Vector2(w, h),
        overridePaint: core.hurtFlash > 0 ? _flashPaint : null);
    canvas.restore();
  }
}
