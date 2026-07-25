// ItemsComponent: single world component drawing every non-enemy entity from
// the session — coins (incl. chest-burst coins), apples/feathers, chests,
// apple projectiles, the exit door, signs and the active sign bubble. One
// component, no per-item children (perf budget: no per-frame allocations).
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextPainter;

import '../ember_game.dart';
import '../level/level_data.dart';
import '../tuning.dart';

class ItemsComponent extends PositionComponent
    with HasGameReference<EmberGame> {
  ItemsComponent() : super(priority: 1);

  late SpriteAnimationTicker _coin;
  late SpriteAnimationTicker _feather;
  late ui.Image _apple;
  late ui.Image _chest;
  late ui.Image _door;
  late ui.Image _doorOpen;
  late ui.Image _sign;

  static final _bubbleText = TextPaint(
    style: const TextStyle(
      fontSize: 6,
      color: ui.Color(0xFF2B2B3A),
      fontFamily: 'Inter',
    ),
  );
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  final _bubblePaint = ui.Paint()..color = const ui.Color(0xEEF4EAD5);

  // Scratch vectors reused every frame (Sprite.render copies, never stores).
  static final _drawPos = Vector2.zero();
  static final _coinSize = Vector2(16, 16);
  static final _featherSize = Vector2(15, 13);

  // Sign-bubble cache: text layout runs only when the active sign changes,
  // not on every frame the bubble is visible.
  String _bubbleFor = '';
  TextPainter? _bubbleTp;
  final _emberGlow = ui.Paint()..color = const ui.Color(0x88E86A17);
  final _emberCore = ui.Paint()..color = const ui.Color(0xFFF2C14E);

  @override
  Future<void> onLoad() async {
    Future<SpriteAnimationTicker> anim(
        String path, int frames, Vector2 size, double stepTime) async {
      return SpriteAnimation.fromFrameData(
        await game.images.load(path),
        SpriteAnimationData.sequenced(
            amount: frames, stepTime: stepTime, textureSize: size),
      ).createTicker();
    }

    _coin = await anim('items/coin.png', 4, Vector2(16, 16), 0.12);
    _feather = await anim('items/feather.png', 5, Vector2(15, 13), 0.14);
    _apple = await game.images.load('items/apple.png');
    _chest = await game.images.load('items/chest.png');
    _door = await game.images.load('props/door.png');
    _doorOpen = await game.images.load('props/door_open.png');
    _sign = await game.images.load('props/sign.png');
  }

  @override
  void update(double dt) {
    _coin.update(dt);
    _feather.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    final s = game.session;

    // Exit door (bottom-center anchored on the exit tile). In boss arenas
    // the door swings open the moment the boss dies.
    final door = s.completed || (s.bossPresent && !s.exitLocked)
        ? _doorOpen
        : _door;
    canvas.drawImageRect(
      door,
      const ui.Rect.fromLTWH(0, 0, 22, 33),
      ui.Rect.fromLTWH(s.exitX - 11, s.exitY - 33, 22, 33),
      _paint,
    );

    // Signs.
    for (final sign in s.signs) {
      canvas.drawImageRect(
        _sign,
        const ui.Rect.fromLTWH(0, 0, 18, 20),
        ui.Rect.fromLTWH(sign.x - 9, sign.y + kTileSize / 2 - 20, 18, 20),
        _paint,
      );
    }

    // Chests (48x48 frames; frame 0 closed, frame 2 open) drawn tile-sized.
    for (final ch in s.chests) {
      final frame = ch.opened ? 2 : 0;
      canvas.drawImageRect(
        _chest,
        ui.Rect.fromLTWH(frame * 48.0, 0, 48, 48),
        ui.Rect.fromLTWH(ch.x - 12, ch.y + kTileSize / 2 - 24, 24, 24),
        _paint,
      );
    }

    // Coins.
    final coinSprite = _coin.getSprite();
    for (final c in s.coins) {
      if (c.collected) continue;
      _drawPos.setValues(c.x - 8, c.y - 8);
      coinSprite.render(canvas, position: _drawPos, size: _coinSize);
    }

    // Apple + feather pickups.
    final featherSprite = _feather.getSprite();
    for (final p in s.pickups) {
      if (p.collected) continue;
      if (p.kind == SpawnKind.apple) {
        _drawApple(canvas, p.x, p.y);
      } else {
        _drawPos.setValues(p.x - 7.5, p.y - 6.5);
        featherSprite.render(canvas, position: _drawPos, size: _featherSize);
      }
    }

    // Apple projectiles.
    for (final a in s.appleProjectiles) {
      if (a.active) _drawApple(canvas, a.x, a.y);
    }

    // Ember shots (totem spit): glowing two-tone orbs, no sprite needed.
    for (final sh in s.emberShots) {
      if (!sh.active) continue;
      canvas.drawCircle(ui.Offset(sh.x, sh.y), 3.5, _emberGlow);
      canvas.drawCircle(ui.Offset(sh.x, sh.y), 2, _emberCore);
    }

    // Active sign bubble.
    final active = s.activeSign;
    if (active != null && active.text.isNotEmpty) {
      if (!identical(active.text, _bubbleFor)) {
        _bubbleFor = active.text;
        _bubbleTp = _bubbleText.toTextPainter(active.text);
      }
      final tp = _bubbleTp!;
      final w = tp.width + 6, h = tp.height + 4;
      final left = active.x - w / 2;
      final top = active.y - 34 - h;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(left, top, w, h), const ui.Radius.circular(2)),
        _bubblePaint,
      );
      tp.paint(canvas, ui.Offset(left + 3, top + 2));
    }
  }

  void _drawApple(ui.Canvas canvas, double x, double y) {
    // items/apple.png is a 32x32-frame strip; frame 0 only (single frame).
    canvas.drawImageRect(
      _apple,
      const ui.Rect.fromLTWH(0, 0, 32, 32),
      ui.Rect.fromLTWH(x - 8, y - 8, 16, 16),
      _paint,
    );
  }
}
