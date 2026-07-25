// Touch HUD: hold buttons (left/right), round jump/attack buttons, pause,
// plus readouts (procedural pixel hearts, coin/apple counters, chest x/y,
// feather icon, level timer). All live on the camera viewport, driving the
// game's shared TouchState.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';

import '../ember_game.dart';
import '../enemies/boss_core.dart';
import '../hold_button_core.dart';

/// A HUD button that reports press/release into a callback pair.
///
/// Mixes TapCallbacks AND DragCallbacks: a held thumb that drifts past the
/// platform touch slop gets its tap cancelled and promoted to a drag by the
/// gesture arena. Without drag handling the button would release mid-hold —
/// the alpha.1 "movement controls don't work" bug. HoldButtonCore keeps the
/// button pressed across that hand-off (see its header for the full story).
class HudHoldButton extends SpriteComponent
    with TapCallbacks, DragCallbacks, HasGameReference<EmberGame> {
  final String spritePath;
  final String? iconPath;
  final void Function() onPressed;
  final void Function() onReleased;
  SpriteComponent? _icon;
  late final HoldButtonCore _core;

  HudHoldButton({
    required this.spritePath,
    this.iconPath,
    required this.onPressed,
    required this.onReleased,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, priority: 10) {
    paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..color = const ui.Color(0xAAFFFFFF);
    _core = HoldButtonCore(
      onPressed: () {
        paint.color = const ui.Color(0xFFFFFFFF);
        onPressed();
      },
      onReleased: () {
        paint.color = const ui.Color(0xAAFFFFFF);
        onReleased();
      },
    );
  }

  @override
  Future<void> onLoad() async {
    sprite = Sprite(await game.images.load(spritePath));
    if (iconPath != null) {
      _icon = SpriteComponent(
        sprite: Sprite(await game.images.load(iconPath!)),
        size: size * 0.55,
        position: size / 2,
        anchor: Anchor.center,
        paint: ui.Paint()
          ..filterQuality = ui.FilterQuality.none
          ..color = const ui.Color(0xDDFFFFFF),
      );
      add(_icon!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _core.tick();
  }

  @override
  void onTapDown(TapDownEvent event) => _core.tapDown(event.pointerId);

  @override
  void onTapUp(TapUpEvent event) => _core.tapUp(event.pointerId);

  @override
  void onTapCancel(TapCancelEvent event) => _core.tapCancel(event.pointerId);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _core.dragStart(event.pointerId);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _core.dragEnd(event.pointerId);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _core.dragCancel(event.pointerId);
  }
}

/// Throw button: apple icon from items/apple.png (32x32 frame 0), only
/// visible & tappable while the player is actually carrying apples.
class HudThrowButton extends HudHoldButton {
  HudThrowButton({
    required super.onPressed,
    required super.position,
    required super.size,
  }) : super(
          spritePath: 'hud/btn_round.png',
          onReleased: _noop,
        );

  static void _noop() {}

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final apple = Sprite(await game.images.load('items/apple.png'),
        srcSize: Vector2(32, 32));
    add(SpriteComponent(
      sprite: apple,
      size: size * 0.62,
      position: size / 2,
      anchor: Anchor.center,
      paint: ui.Paint()..filterQuality = ui.FilterQuality.none,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final visible = game.session.applesHeld > 0;
    scale = visible ? Vector2.all(1) : Vector2.zero(); // hides + kills taps
  }
}

/// Readouts drawn procedurally each frame from session state.
class HudReadout extends PositionComponent with HasGameReference<EmberGame> {
  HudReadout() : super(priority: 10);

  late Sprite _coinSprite;
  late Sprite _appleSprite;
  late Sprite _featherSprite;
  late Sprite _chestSprite;

  static final _text = TextPaint(
    style: const TextStyle(
      fontSize: 8,
      color: ui.Color(0xFFF4EAD5),
      fontFamily: 'Inter',
    ),
  );
  final _heartFill = ui.Paint()..color = const ui.Color(0xFFD53C3C);
  final _bossBarBack = ui.Paint()..color = const ui.Color(0xCC201826);
  final _bossBarFill = ui.Paint()..color = const ui.Color(0xFF8FBF3F);
  final _bossBarTick = ui.Paint()..color = const ui.Color(0x88FFFFFF);
  final _heartEmpty = ui.Paint()..color = const ui.Color(0x66201826);
  final _spritePaint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  @override
  Future<void> onLoad() async {
    _coinSprite = Sprite(await game.images.load('items/coin.png'),
        srcSize: Vector2(16, 16));
    _appleSprite = Sprite(await game.images.load('items/apple.png'),
        srcSize: Vector2(32, 32));
    _featherSprite = Sprite(await game.images.load('items/feather.png'),
        srcSize: Vector2(15, 13));
    _chestSprite = Sprite(await game.images.load('items/chest.png'),
        srcSize: Vector2(48, 48));
  }

  /// 8x8 pixel heart: two bumps + point, drawn from a bitmask.
  static const _heartRows = [
    0x66, // .##..##.
    0xFF, // ########
    0xFF, // ########
    0xFF, // ########
    0x7E, // .######.
    0x3C, // ..####..
    0x18, // ...#....
    0x00,
  ];

  void _drawHeart(ui.Canvas canvas, double x, double y, ui.Paint paint) {
    for (var row = 0; row < 8; row++) {
      final bits = _heartRows[row];
      for (var col = 0; col < 8; col++) {
        if ((bits >> (7 - col)) & 1 == 1) {
          canvas.drawRect(ui.Rect.fromLTWH(x + col, y + row, 1, 1), paint);
        }
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final s = game.session;

    // Hearts (top-left).
    for (var i = 0; i < s.loadout.maxHearts; i++) {
      _drawHeart(canvas, 6.0 + i * 10, 6,
          i < s.player.hearts ? _heartFill : _heartEmpty);
    }

    // Coins.
    _coinSprite.render(canvas,
        position: Vector2(4, 16), size: Vector2(12, 12),
        overridePaint: _spritePaint);
    _text.render(canvas, '${s.coinsCollected}', Vector2(17, 18));

    // Apples.
    _appleSprite.render(canvas,
        position: Vector2(4, 28), size: Vector2(12, 12),
        overridePaint: _spritePaint);
    _text.render(canvas, '${s.applesHeld}', Vector2(17, 30));

    // Chests opened/total (only when the level has chests).
    if (s.chestTotal > 0) {
      _chestSprite.render(canvas,
          position: Vector2(4, 40), size: Vector2(12, 12),
          overridePaint: _spritePaint);
      _text.render(
          canvas, '${s.chestsOpened}/${s.chestTotal}', Vector2(17, 42));
    }

    // Feather icon when collected this run.
    if (s.feathersCollected > 0) {
      _featherSprite.render(canvas,
          position: Vector2(5, 52), size: Vector2(11, 10),
          overridePaint: _spritePaint);
      if (s.feathersCollected > 1) {
        _text.render(canvas, '${s.feathersCollected}', Vector2(17, 53));
      }
    }

    // Boss HP bar (top-center, under the timer) with phase threshold ticks.
    final boss = s.boss;
    if (boss != null) {
      const barW = 180.0, barH = 6.0;
      final left = (EmberGame.viewWidth - barW) / 2;
      const top = 18.0;
      canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(left - 1, top - 1, barW + 2, barH + 2),
              const ui.Radius.circular(2)),
          _bossBarBack);
      final frac = boss.hp / GroveGolemCore.maxHp;
      canvas.drawRect(
          ui.Rect.fromLTWH(left, top, barW * frac, barH), _bossBarFill);
      // Phase threshold ticks at 2/3 and 1/3.
      for (final t in const [2 / 3, 1 / 3]) {
        canvas.drawRect(
            ui.Rect.fromLTWH(left + barW * t, top, 1, barH), _bossBarTick);
      }
      _text.render(canvas, 'GROVE GOLEM', Vector2(EmberGame.viewWidth / 2, top - 10),
          anchor: Anchor.topCenter);
    }

    // Level timer (top-center).
    final t = s.time.floor();
    final mm = (t ~/ 60).toString().padLeft(1, '0');
    final ss = (t % 60).toString().padLeft(2, '0');
    _text.render(canvas, '$mm:$ss', Vector2(EmberGame.viewWidth / 2, 6),
        anchor: Anchor.topCenter);
  }
}
