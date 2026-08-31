// ItemsComponent: single world component drawing every non-enemy entity from
// the session — coins (incl. chest-burst coins), apples/feathers, chests,
// apple projectiles, the exit door, signs and the active sign bubble. One
// component, no per-item children (perf budget: no per-frame allocations).
import 'dart:math' as math;
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

  /// Per-chest open-animation clocks (few chests per level; grows once per
  /// opened chest, never per frame).
  final Map<Object, double> _chestOpenClock = {};
  double _doorPulse = 0;

  /// Coin frames drawn per-coin (indexed by [coinFrame]) so each coin spins
  /// on its own phase; a single shared ticker made every coin in the level
  /// hit the edge-on frame simultaneously.
  late List<Sprite> _coinFrames;
  double _coinClock = 0;
  static const _coinStep = 0.12; // s per frame, matches items/coin.png
  late SpriteAnimationTicker _feather;

  /// Frame index for a coin with [spinPhase] (cycles) at animation [clock].
  /// Pure so tests can pin the phase math.
  static int coinFrame(double clock, double spinPhase, int frameCount) =>
      ((clock / _coinStep) + spinPhase * frameCount).floor() % frameCount;
  late ui.Image _apple;
  late ui.Image _chest;
  late ui.Image _door;
  late ui.Image _doorOpen;
  late ui.Image _sign;
  late ui.Image _fireOut;
  late ui.Image _fireLit;

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
  final _doorGlow = ui.Paint()
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
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

    final coinAnim = SpriteAnimation.fromFrameData(
      await game.images.load('items/coin.png'),
      SpriteAnimationData.sequenced(
          amount: 4, stepTime: _coinStep, textureSize: Vector2(16, 16)),
    );
    _coinFrames = [for (final f in coinAnim.frames) f.sprite];
    _feather = await anim('items/feather.png', 5, Vector2(15, 13), 0.14);
    _apple = await game.images.load('items/apple.png');
    _chest = await game.images.load('items/chest.png');
    _door = await game.images.load('props/door.png');
    _doorOpen = await game.images.load('props/door_open.png');
    _sign = await game.images.load('props/sign.png');
    _fireOut = await game.images.load('props/campfire_out.png');
    _fireLit = await game.images.load('props/campfire_lit.png');
  }

  @override
  void update(double dt) {
    _coinClock += dt;
    _feather.update(dt);
    _doorPulse += dt;
    for (final ch in game.session.chests) {
      if (ch.opened) {
        _chestOpenClock.update(ch, (t) => t + dt, ifAbsent: () => 0.0);
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final s = game.session;

    // Exit door (bottom-center anchored on the exit tile). In boss arenas
    // the door swings open the moment the boss dies; an open door breathes
    // a soft golden glow so the goal reads from across the screen.
    final doorOpen = s.completed || (s.bossPresent && !s.exitLocked);
    if (doorOpen) {
      final pulse = 0.5 + 0.5 * math.sin(_doorPulse * 4);
      _doorGlow.color = ui.Color.fromARGB((40 + 50 * pulse).round(),
          0xF2, 0xC1, 0x4E);
      canvas.drawCircle(
          ui.Offset(s.exitX, s.exitY - 16), 20 + 4 * pulse, _doorGlow);
    }
    canvas.drawImageRect(
      doorOpen ? _doorOpen : _door,
      const ui.Rect.fromLTWH(0, 0, 22, 33),
      ui.Rect.fromLTWH(s.exitX - 11, s.exitY - 33, 22, 33),
      _paint,
    );

    // Checkpoints: a cold campfire until you touch it, then a lit one with a
    // soft breathing glow so a rescued run is visible from a screen away.
    for (final cp in s.checkpoints) {
      if (cp.lit) {
        final pulse = 0.5 + 0.5 * math.sin(_doorPulse * 5);
        _doorGlow.color =
            ui.Color.fromARGB((50 + 45 * pulse).round(), 0xE8, 0x6A, 0x17);
        canvas.drawCircle(
            ui.Offset(cp.x, cp.y - 4), 14 + 3 * pulse, _doorGlow);
      }
      canvas.drawImageRect(
        cp.lit ? _fireLit : _fireOut,
        const ui.Rect.fromLTWH(0, 0, 16, 16),
        ui.Rect.fromLTWH(cp.x - 8, cp.y - 8, 16, 16),
        _paint,
      );
    }

    // Signs.
    for (final sign in s.signs) {
      canvas.drawImageRect(
        _sign,
        const ui.Rect.fromLTWH(0, 0, 18, 20),
        ui.Rect.fromLTWH(sign.x - 9, sign.y + kTileSize / 2 - 20, 18, 20),
        _paint,
      );
    }

    // Chests (48x48 frames: closed / opening / open). Opening plays the
    // middle frame for a beat instead of snapping closed->open.
    for (final ch in s.chests) {
      var frame = 0;
      if (ch.opened) {
        final t = _chestOpenClock[ch] ?? 0.0;
        frame = t < 0.12 ? 1 : 2;
      }
      canvas.drawImageRect(
        _chest,
        ui.Rect.fromLTWH(frame * 48.0, 0, 48, 48),
        ui.Rect.fromLTWH(ch.x - 12, ch.y + kTileSize / 2 - 24, 24, 24),
        _paint,
      );
    }

    // Coins — each on its own spin phase (see CoinEntity.spinPhase).
    final nFrames = _coinFrames.length;
    for (final c in s.coins) {
      if (c.collected) continue;
      _drawPos.setValues(c.x - 8, c.y - 8);
      _coinFrames[coinFrame(_coinClock, c.spinPhase, nFrames)]
          .render(canvas, position: _drawPos, size: _coinSize);
    }

    // Apple + feather + heart pickups.
    final featherSprite = _feather.getSprite();
    for (final p in s.pickups) {
      if (p.collected) continue;
      if (p.kind == SpawnKind.apple) {
        _drawApple(canvas, p.x, p.y);
      } else if (p.kind == SpawnKind.heart) {
        _drawHeartPickup(canvas, p.x, p.y);
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

  /// 8x8 pixel heart, same bitmask as the HUD hearts so the pickup reads as
  /// "this refills one of THOSE". Procedural (original-assets pillar), 1.5x
  /// scale with a slow bob; darker outline row first for pop against grass.
  static const _heartRows = [
    0x66, // .##..##.
    0xFF, // ########
    0xFF, // ########
    0xFF, // ########
    0x7E, // .######.
    0x3C, // ..####..
    0x18, // ...##...
    0x00,
  ];
  final _heartFill = ui.Paint()..color = const ui.Color(0xFFD53C3C);
  final _heartShine = ui.Paint()..color = const ui.Color(0xFFF2917F);
  final _heartShadow = ui.Paint()..color = const ui.Color(0x66201826);

  void _drawHeartPickup(ui.Canvas canvas, double x, double y) {
    const scale = 1.5;
    final bob = math.sin(_coinClock * 2.4) * 1.5;
    final left = x - 4 * scale, top = y - 4 * scale + bob;
    for (var row = 0; row < 8; row++) {
      final bits = _heartRows[row];
      for (var col = 0; col < 8; col++) {
        if ((bits >> (7 - col)) & 1 == 1) {
          canvas.drawRect(
              ui.Rect.fromLTWH(left + col * scale + 1, top + row * scale + 1,
                  scale, scale),
              _heartShadow);
          canvas.drawRect(
              ui.Rect.fromLTWH(
                  left + col * scale, top + row * scale, scale, scale),
              _heartFill);
        }
      }
    }
    // Single shine pixel top-left lobe.
    canvas.drawRect(
        ui.Rect.fromLTWH(left + 1 * scale, top + 1 * scale, scale, scale),
        _heartShine);
  }
}
