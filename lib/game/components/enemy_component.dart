// EnemyComponent: draws an EnemyCore (Thornling / Ashbat / Hopper) with hurt
// flash and facing flip; removes itself when the core dies (death fx + sfx
// are handled by the game's event loop).
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../ember_game.dart';
import '../enemies/boss_core.dart';
import '../enemies/enemy_core.dart';

class EnemyComponent extends PositionComponent
    with HasGameReference<EmberGame> {
  final EnemyCore core;
  EnemyComponent(this.core) : super(priority: 2);

  SpriteAnimationTicker? _ticker;
  SpriteAnimation? _main;
  SpriteAnimation? _alt; // hopper jump strip
  SpriteAnimation? _shown;

  // Scratch vectors reused every frame (Sprite.render copies, never stores).
  static final _drawPos = Vector2.zero();
  static final _drawSize = Vector2.zero();

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
      case EnemyKind.emberTotem:
        // Composite: stone base (props/rock, CC0 Sunny Land) + the shared
        // fire animation burning on top. No new art assets needed.
        _rock = await game.images.load('props/rock.png');
        _main = await load('fx/fire.png', 3, Vector2(16, 32), 0.09);
      case EnemyKind.rotshield:
        // Thornling strip tinted rot-green; the shield plate is drawn
        // procedurally on the facing side.
        _main =
            await load('enemies/thornling.png', 6, Vector2(36, 28), 0.16);
        _tint = ui.Paint()
          ..filterQuality = ui.FilterQuality.none
          ..colorFilter = const ui.ColorFilter.mode(
              ui.Color(0xFF7FA05A), ui.BlendMode.modulate);
      case EnemyKind.sootCreeper:
        _main = await load('enemies/soot_creeper.png', 6, Vector2(36, 28), 0.14);
      case EnemyKind.cinderDiver:
        _main = await load('enemies/cinder_diver.png', 5, Vector2(32, 41), 0.1);
      case EnemyKind.pyreWisp:
        // Stage 2: bright pyre-gold recolor of the ashbat strip
        // (tool/build_new_enemies.py, CC0 Sunny Land base).
        _main = await load('enemies/pyre_wisp.png', 4, Vector2(40, 41), 0.09);
      case EnemyKind.slagHound:
        // Stage 2: molten recolor of the hopper strips; the jump strip is
        // the crouch/charge pose (telegraph + charge read instantly).
        _main =
            await load('enemies/slag_hound.png', 4, Vector2(35, 32), 0.14);
        _alt = await load(
            'enemies/slag_hound_charge.png', 2, Vector2(35, 32), 0.10);
      case EnemyKind.groveGolem:
        // Boss: 2x-scaled, moss-tinted thornling composite (CC0 Sunny Land)
        // + rock.png for its lobbed rocks. No unverified art added.
        _main = await load('enemies/thornling.png', 6, Vector2(36, 28), 0.18);
        _rock = await game.images.load('props/rock.png');
        _tint = ui.Paint()
          ..filterQuality = ui.FilterQuality.none
          ..colorFilter = const ui.ColorFilter.mode(
              ui.Color(0xFF87A96B), ui.BlendMode.modulate);
      case EnemyKind.kilnGolem:
        // Boss: same 2x thornling base fired kiln-terracotta. Its fire
        // hazards (embers / patches / vent pillars) are drawn procedurally
        // in _renderBoss — no new art assets.
        _main = await load('enemies/thornling.png', 6, Vector2(36, 28), 0.18);
        _tint = ui.Paint()
          ..filterQuality = ui.FilterQuality.none
          ..colorFilter = const ui.ColorFilter.mode(
              ui.Color(0xFFC9704A), ui.BlendMode.modulate);
    }
    _show(_main!);
  }

  ui.Image? _rock;
  ui.Paint? _tint;
  static final _shieldPaint = ui.Paint()..color = const ui.Color(0xFF4A5C3A);
  static final _shieldRim = ui.Paint()..color = const ui.Color(0xFF9BB07C);
  static final _rockPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none;

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
    if (core is SlagHoundCore && _alt != null) {
      final h = core as SlagHoundCore;
      _show(h.telegraphing || h.charging ? _alt! : _main!);
    }
    if (!core.sleeping) _ticker?.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    final ticker = _ticker;
    if (ticker == null || core.sleeping) return;
    final b = core.body;
    if (core.kind == EnemyKind.emberTotem) {
      _renderTotem(canvas, ticker);
      return;
    }
    if (core.kind == EnemyKind.groveGolem ||
        core.kind == EnemyKind.kilnGolem) {
      _renderBoss(canvas, ticker);
      return;
    }
    final sprite = ticker.getSprite();
    final w = sprite.srcSize.x, h = sprite.srcSize.y;
    canvas.save();
    // ALL enemy strips in this art set face LEFT in the source frames
    // (Sunny Land-derived bases + their recolors), while the player strips
    // face RIGHT. So enemies mirror when facing RIGHT (facing > 0) — the
    // opposite of the player. Getting this backwards makes every enemy
    // moonwalk (owner-reported "enemies moving in reverse", 2026-07-25).
    if (core.facing > 0) {
      canvas.translate(b.centerX * 2, 0);
      canvas.scale(-1, 1);
    }
    _drawPos.setValues(b.centerX - w / 2, b.bottom - h);
    _drawSize.setValues(w, h);
    sprite.render(canvas,
        position: _drawPos,
        size: _drawSize,
        overridePaint: core.hurtFlash > 0 ? _flashPaint : _tint);
    canvas.restore();
    if (core.kind == EnemyKind.rotshield) {
      // Shield plate on the facing side. Drawn OUTSIDE the mirror transform
      // with an explicit facing offset, so it stays glued to the shield arm
      // regardless of which way the body strip is mirrored.
      final left = core.facing > 0 ? b.centerX + 8 : b.centerX - 13;
      final rect = ui.Rect.fromLTWH(left, b.top - 2, 5, b.h + 2);
      canvas.drawRRect(
          ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(2)),
          _shieldPaint);
      canvas.drawRect(
          ui.Rect.fromLTWH(rect.left + 1, rect.top + 2, 1, rect.height - 4),
          _shieldRim);
    }
  }

  /// Stone base + fire crown; the fire dims while the totem recharges.
  void _renderTotem(ui.Canvas canvas, SpriteAnimationTicker ticker) {
    final b = core.body;
    final rock = _rock;
    if (rock != null) {
      // Stack two rock slices for a stone pillar body.
      canvas.drawImageRect(
          rock,
          const ui.Rect.fromLTWH(0, 0, 28, 15),
          ui.Rect.fromLTWH(b.left - 2, b.bottom - 12, b.w + 4, 12),
          core.hurtFlash > 0 ? _flashPaint : _rockPaint);
      canvas.drawImageRect(
          rock,
          const ui.Rect.fromLTWH(2, 0, 24, 15),
          ui.Rect.fromLTWH(b.left, b.bottom - 22, b.w, 11),
          core.hurtFlash > 0 ? _flashPaint : _rockPaint);
    }
    final fire = ticker.getSprite();
    final charging = (core as EmberTotemCore).cooldownLeft;
    _firePaint.color = charging > 0.4
        ? const ui.Color(0x99FFFFFF)
        : const ui.Color(0xFFFFFFFF);
    _drawPos.setValues(b.centerX - 8, b.bottom - 22 - 26);
    _drawSize.setValues(16, 32);
    fire.render(canvas,
        position: _drawPos,
        size: _drawSize,
        overridePaint: core.hurtFlash > 0 ? _flashPaint : _firePaint);
  }

  static final _firePaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none;

  /// Bosses: 2x-scaled tinted thornling body; telegraph = red pulse tint.
  /// Hazards (grove: shockwaves / root spikes / rocks — kiln: ember bombs /
  /// fire patches / vent pillars) are drawn here too since the core owns
  /// them. Kiln fire is procedural paint work: no art assets needed.
  void _renderBoss(ui.Canvas canvas, SpriteAnimationTicker ticker) {
    final golem = core as BossCore;
    final b = core.body;
    final sprite = ticker.getSprite();
    const w = 72.0, h = 56.0;
    canvas.save();
    // Thornling-derived strip: source art faces LEFT, mirror when facing
    // right (see the orientation note in render()).
    if (core.facing > 0) {
      canvas.translate(b.centerX * 2, 0);
      canvas.scale(-1, 1);
    }
    ui.Paint? paint = _tint;
    if (core.hurtFlash > 0) {
      paint = _flashPaint;
    } else if (golem.telegraphPulse > 0.5) {
      paint = _telegraphPaint;
    }
    _drawPos.setValues(b.centerX - w / 2, b.bottom - h);
    _drawSize.setValues(w, h);
    sprite.render(canvas,
        position: _drawPos, size: _drawSize, overridePaint: paint);
    canvas.restore();

    for (final hz in golem.hazards) {
      final r = hz.rect;
      switch (hz.kind) {
        case BossHazardKind.shockwave:
          canvas.drawOval(
              ui.Rect.fromLTWH(r.x, r.y + 2, r.w, r.h - 2), _shockPaint);
          canvas.drawOval(
              ui.Rect.fromLTWH(r.x + 3, r.y + 5, r.w - 6, r.h - 6),
              _shockCore);
        case BossHazardKind.rootSpike:
          if (!hz.harmful) {
            // Warning mark on the ground.
            canvas.drawRect(
                ui.Rect.fromLTWH(hz.x - 6, hz.y - 2, 12, 2), _warnPaint);
          } else {
            final path = ui.Path()
              ..moveTo(r.x, hz.y)
              ..lineTo(hz.x, r.y)
              ..lineTo(r.x + r.w, hz.y)
              ..close();
            canvas.drawPath(path, _spikePaint);
          }
        case BossHazardKind.rock:
          final rock = _rock;
          if (rock != null) {
            canvas.drawImageRect(
                rock,
                const ui.Rect.fromLTWH(0, 0, 28, 15),
                ui.Rect.fromLTWH(r.x, r.y, r.w, r.h),
                _rockPaint);
          } else {
            canvas.drawOval(
                ui.Rect.fromLTWH(r.x, r.y, r.w, r.h), _spikePaint);
          }
        case BossHazardKind.emberBomb:
          // Glowing mortar ember: hot core + halo.
          canvas.drawOval(
              ui.Rect.fromLTWH(r.x - 2, r.y - 2, r.w + 4, r.h + 4),
              _emberHalo);
          canvas.drawOval(ui.Rect.fromLTWH(r.x, r.y, r.w, r.h), _emberCore);
        case BossHazardKind.firePatch:
          // Burning ground: ember bed + flame lobes that gutter out as the
          // patch expires (hz.life runs down from KilnGolemCore.patchLife).
          final k = (hz.life / KilnGolemCore.patchLife).clamp(0.0, 1.0);
          canvas.drawOval(
              ui.Rect.fromLTWH(hz.x - 10, hz.y - 4, 20, 5), _emberHalo);
          final flameH = 4 + 6 * k;
          for (final off in const [-6.0, 0.0, 6.0]) {
            canvas.drawOval(
                ui.Rect.fromLTWH(
                    hz.x + off - 2.5, hz.y - 2 - flameH, 5, flameH),
                off == 0 ? _flameInner : _flameOuter);
          }
        case BossHazardKind.flamePillar:
          if (!hz.harmful) {
            // Vent warning: a glowing crack on the floor.
            canvas.drawRect(
                ui.Rect.fromLTWH(hz.x - 6, hz.y - 2, 12, 2), _emberCore);
          } else {
            // Erupting column: outer flame + hot inner tongue.
            canvas.drawRRect(
                ui.RRect.fromRectAndRadius(
                    ui.Rect.fromLTWH(r.x, r.y, r.w, r.h),
                    const ui.Radius.circular(4)),
                _flameOuter);
            canvas.drawRRect(
                ui.RRect.fromRectAndRadius(
                    ui.Rect.fromLTWH(r.x + 3, r.y + 4, r.w - 6, r.h - 6),
                    const ui.Radius.circular(3)),
                _flameInner);
          }
      }
    }
  }

  static final _emberHalo = ui.Paint()..color = const ui.Color(0x88E8623D);
  static final _emberCore = ui.Paint()..color = const ui.Color(0xFFF2C14B);
  static final _flameOuter = ui.Paint()..color = const ui.Color(0xCCE8623D);
  static final _flameInner = ui.Paint()..color = const ui.Color(0xEEF2C14B);

  static final _telegraphPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..colorFilter =
        const ui.ColorFilter.mode(ui.Color(0xFFE86A4A), ui.BlendMode.modulate);
  static final _shockPaint = ui.Paint()..color = const ui.Color(0xAA9C6A2F);
  static final _shockCore = ui.Paint()..color = const ui.Color(0xCCE8A33D);
  static final _warnPaint = ui.Paint()..color = const ui.Color(0xCCD53C3C);
  static final _spikePaint = ui.Paint()..color = const ui.Color(0xFF6B4A2B);
}
