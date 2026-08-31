// Touch HUD: hold buttons (left/right), round jump/attack buttons, pause,
// plus readouts (procedural pixel hearts, coin/apple counters, chest x/y,
// feather icon, level timer). All live on the camera viewport, driving the
// game's shared TouchState.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show TextPainter;

import '../ember_game.dart';
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
  // AKP-5c: idle buttons sit at ~0.55 opacity (AK-style) so they stop
  // visually blocking pickups; a pressed button snaps to full opacity.
  static const _idleColor = ui.Color(0x8CFFFFFF);
  static const _pressedColor = ui.Color(0xFFFFFFFF);
  // AKP-5c: movement buttons additionally fade for the first second after
  // spawn so the player is never hidden behind them on levels that spawn
  // near the screen's left edge.
  static const _spawnFadeColor = ui.Color(0x40FFFFFF);
  static const _spawnFadeSeconds = 1.0;

  final String spritePath;
  final String? iconPath;
  final bool spawnFade;
  final void Function() onPressed;
  final void Function() onReleased;
  SpriteComponent? _icon;
  late final HoldButtonCore _core;

  HudHoldButton({
    required this.spritePath,
    this.iconPath,
    this.spawnFade = false,
    required this.onPressed,
    required this.onReleased,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, priority: 10) {
    paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..color = _idleColor;
    _core = HoldButtonCore(
      onPressed: () {
        paint.color = _pressedColor;
        onPressed();
      },
      onReleased: () {
        paint.color = _idleColor;
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
    if (spawnFade && !_core.pressed) {
      paint.color = game.session.time < _spawnFadeSeconds
          ? _spawnFadeColor
          : _idleColor;
    }
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
    // AKP-4c: release ends the arc preview; the throw itself stays on the
    // press edge (tap-to-throw latency is untouched).
    super.onReleased = _noop,
    required super.position,
    required super.size,
  }) : super(spritePath: 'hud/btn_round.png');

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

  /// A zero-scaled component does NOT "kill taps": Flame inverts the
  /// (singular) transform, every canvas point collapses to local (0,0), and
  /// (0,0) is inside the button — so the hidden throw button swallowed every
  /// tap on screen before the movement arrows could see it (checked earlier
  /// in reversed child order; jump/attack/pause are checked before it and
  /// kept working, which is why only left/right looked broken). Gate hit
  /// testing on visibility explicitly.
  @override
  bool containsLocalPoint(Vector2 point) =>
      game.session.applesHeld > 0 && super.containsLocalPoint(point);

  @override
  void update(double dt) {
    super.update(dt);
    final visible = game.session.applesHeld > 0;
    scale = visible ? Vector2.all(1) : Vector2.zero(); // hides the sprite
  }
}

/// Spell button (AKP-4d): only visible & tappable while a spell is equipped
/// and its one-per-run charge is unspent. Same zero-scale hide + explicit
/// hit-test gate as HudThrowButton (see its containsLocalPoint note).
class HudSpellButton extends HudHoldButton {
  HudSpellButton({
    required super.onPressed,
    required super.position,
    required super.size,
  }) : super(
          spritePath: 'hud/btn_round.png',
          iconPath: 'hud/icon_spell.png',
          onReleased: _noop,
        );

  static void _noop() {}

  @override
  bool containsLocalPoint(Vector2 point) =>
      game.session.spellReady && super.containsLocalPoint(point);

  @override
  void update(double dt) {
    super.update(dt);
    final visible = game.session.spellReady;
    scale = visible ? Vector2.all(1) : Vector2.zero(); // hides the sprite
  }
}

/// Readouts drawn procedurally each frame from session state.
class HudReadout extends PositionComponent with HasGameReference<EmberGame> {
  HudReadout() : super(priority: 10);

  late Sprite _coinSprite;
  late Sprite _appleSprite;
  late Sprite _featherSprite;
  late Sprite _chestSprite;

  /// Ink outline behind every in-world HUD glyph. World 1's sunburst sky is
  /// almost the same value as the ivory text — counters/timer/lore were
  /// unreadable over it (2026-08-31 look pass). Four 1px cardinal shadows
  /// give a crisp pixel outline; they bake into each slot's cached
  /// TextPainter, so steady-state frames pay nothing extra.
  static const hudTextStyle = TextStyle(
    fontSize: 8,
    color: ui.Color(0xFFF4EAD5),
    fontFamily: 'Inter',
    shadows: [
      ui.Shadow(offset: ui.Offset(1, 0), color: ui.Color(0xFF201826)),
      ui.Shadow(offset: ui.Offset(-1, 0), color: ui.Color(0xFF201826)),
      ui.Shadow(offset: ui.Offset(0, 1), color: ui.Color(0xFF201826)),
      ui.Shadow(offset: ui.Offset(0, -1), color: ui.Color(0xFF201826)),
    ],
  );
  static final _text = TextPaint(style: hudTextStyle);
  final _heartFill = ui.Paint()..color = const ui.Color(0xFFD53C3C);
  final _bossBarBack = ui.Paint()..color = const ui.Color(0xCC201826);
  final _bossBarFill = ui.Paint()..color = const ui.Color(0xFF8FBF3F);
  final _bossBarTick = ui.Paint()..color = const ui.Color(0x88FFFFFF);
  final _heartEmpty = ui.Paint()..color = const ui.Color(0x66201826);
  final _spritePaint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  // Per-slot text caches: TextPaint's internal painter cache is a 10-entry
  // LRU shared across every string — five readouts churning values would
  // constantly evict each other and re-run text layout. Each slot below
  // re-layouts only when ITS value actually changes (perf.md §render).
  final _coinText = _HudText(_text, 17, 18);
  final _appleText = _HudText(_text, 17, 30);
  final _chestText = _HudText(_text, 17, 42);
  final _featherText = _HudText(_text, 17, 53);
  final _timerText = _HudText(_text, EmberGame.viewWidth / 2, 6, centerX: true);
  // Lives ("x2") sit right of the heart row — AK shows the same thing as a
  // small counter, and a player has to be able to see what a death costs.
  final _livesText = _HudText(_text, 0, 4);
  // Stage 2 lore intro: level name + one-line blurb, shown for the first
  // few seconds of a run (meta: lore=... in the level file).
  static const _loreSeconds = 4.5;
  final _loreTitle =
      _HudText(_text, EmberGame.viewWidth / 2, 26, centerX: true);
  final _loreLine =
      _HudText(_text, EmberGame.viewWidth / 2, 38, centerX: true);
  // AKP-5d: boss name sits BELOW the bar — at _barTop - 10 it overlapped
  // the level timer (both top-centre).
  final _bossName =
      _HudText(_text, EmberGame.viewWidth / 2, _barTop + _barH + 3, centerX: true);

  // Fixed geometry, allocated once (icon positions/sizes never change).
  static final _coinPos = Vector2(4, 16);
  static final _applePos = Vector2(4, 28);
  static final _chestPos = Vector2(4, 40);
  static final _featherPos = Vector2(5, 52);
  static final _icon12 = Vector2(12, 12);
  static final _featherSize = Vector2(11, 10);

  // Boss bar geometry (constant), precomputed once.
  // Bar top at 20: the timer text (y=6, 8px font) ends ~y16 — bar + name
  // stack cleanly under it (AKP-5d).
  static const _barW = 180.0, _barH = 6.0, _barTop = 20.0;
  static const _barLeft = (EmberGame.viewWidth - _barW) / 2;
  static final _bossBackRRect = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(_barLeft - 1, _barTop - 1, _barW + 2, _barH + 2),
      const ui.Radius.circular(2));
  static const _tick1 =
      ui.Rect.fromLTWH(_barLeft + _barW * 2 / 3, _barTop, 1, _barH);
  static const _tick2 =
      ui.Rect.fromLTWH(_barLeft + _barW * 1 / 3, _barTop, 1, _barH);

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

    // Hearts (top-left) + remaining lives.
    final maxHearts = s.loadout.maxHearts;
    for (var i = 0; i < maxHearts; i++) {
      _drawHeart(canvas, 6.0 + i * 10, 6,
          i < s.player.hearts ? _heartFill : _heartEmpty);
    }
    _drawHeart(canvas, 6.0 + maxHearts * 10 + 2, 6, _heartFill);
    _livesText.moveTo(6.0 + maxHearts * 10 + 12);
    if (_livesText.dirty(s.lives)) _livesText.text = 'x${s.lives}';
    _livesText.paint(canvas);

    // Coins.
    _coinSprite.render(canvas,
        position: _coinPos, size: _icon12, overridePaint: _spritePaint);
    if (_coinText.dirty(s.coinsCollected)) {
      _coinText.text = '${s.coinsCollected}';
    }
    _coinText.paint(canvas);

    // Apples.
    _appleSprite.render(canvas,
        position: _applePos, size: _icon12, overridePaint: _spritePaint);
    if (_appleText.dirty(s.applesHeld)) {
      _appleText.text = '${s.applesHeld}';
    }
    _appleText.paint(canvas);

    // Chests opened/total (only when the level has chests).
    if (s.chestTotal > 0) {
      _chestSprite.render(canvas,
          position: _chestPos, size: _icon12, overridePaint: _spritePaint);
      if (_chestText.dirty(s.chestsOpened * 1000 + s.chestTotal)) {
        _chestText.text = '${s.chestsOpened}/${s.chestTotal}';
      }
      _chestText.paint(canvas);
    }

    // Feather icon when collected this run.
    if (s.feathersCollected > 0) {
      _featherSprite.render(canvas,
          position: _featherPos, size: _featherSize,
          overridePaint: _spritePaint);
      if (s.feathersCollected > 1) {
        if (_featherText.dirty(s.feathersCollected)) {
          _featherText.text = '${s.feathersCollected}';
        }
        _featherText.paint(canvas);
      }
    }

    // Boss HP bar (top-center, under the timer) with phase threshold ticks.
    final boss = s.boss;
    if (boss != null) {
      canvas.drawRRect(_bossBackRRect, _bossBarBack);
      final frac = boss.hp / boss.maxHpTotal;
      canvas.drawRect(
          ui.Rect.fromLTWH(_barLeft, _barTop, _barW * frac, _barH),
          _bossBarFill);
      // Phase threshold ticks at 2/3 and 1/3.
      canvas.drawRect(_tick1, _bossBarTick);
      canvas.drawRect(_tick2, _bossBarTick);
      if (_bossName.dirty(0)) {
        _bossName.text = game.session.level.name.toUpperCase();
      }
      _bossName.paint(canvas);
    }

    // Lore intro (Stage 2): name + blurb for the first seconds, then gone.
    // Suppressed during a boss fight intro (the bar owns that space).
    final lore = s.level.meta['lore'];
    if (boss == null && s.time < _loreSeconds && lore != null &&
        lore.isNotEmpty) {
      if (_loreTitle.dirty(0)) {
        _loreTitle.text = s.level.name.toUpperCase();
      }
      _loreTitle.paint(canvas);
      if (_loreLine.dirty(0)) _loreLine.text = lore;
      _loreLine.paint(canvas);
    }

    // Level timer (top-center): re-layout only when the second ticks over.
    final t = s.time.floor();
    if (_timerText.dirty(t)) {
      final mm = t ~/ 60;
      final ss = (t % 60).toString().padLeft(2, '0');
      _timerText.text = '$mm:$ss';
    }
    _timerText.paint(canvas);
  }
}

/// One HUD text slot: caches its laid-out TextPainter and rebuilds it only
/// when [key] changes. Rendering a slot is then a pure `TextPainter.paint`
/// — no string interpolation, no TextSpan/TextPainter construction, and no
/// text layout in the steady-state frame. (TextPaint.toTextPainter has its
/// own cache, but it is a 10-entry LRU shared across all strings — mixed
/// HUD readouts + timer churn would evict each other every frame.)
class _HudText {
  _HudText(this._style, this._x, this._y, {this.centerX = false});

  final TextPaint _style;
  double _x;
  final double _y;
  final bool centerX;
  int _key = -0x7fffffff; // sentinel: first dirty() is always true
  ui.Offset _offset = ui.Offset.zero;
  TextPainter? _tp;

  /// True when [key] differs from the cached one; caller must then set
  /// [text]. Marks the new key as current either way.
  bool dirty(int key) {
    if (key == _key) return false;
    _key = key;
    return true;
  }

  /// Move the slot (used by the lives counter, whose x depends on how many
  /// heart pips the loadout draws). Re-lays out only if text already exists.
  void moveTo(double x) {
    if (x == _x) return;
    _x = x;
    final tp = _tp;
    if (tp != null) {
      _offset = ui.Offset(centerX ? _x - tp.width / 2 : _x, _y);
    }
  }

  set text(String value) {
    final tp = _style.toTextPainter(value);
    _tp = tp;
    _offset = ui.Offset(centerX ? _x - tp.width / 2 : _x, _y);
  }

  void paint(ui.Canvas canvas) => _tp?.paint(canvas, _offset);
}
