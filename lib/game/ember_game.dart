// game/ember_game.dart — the Flame shell around LevelSession. Owns the level
// lifecycle, fixed-resolution camera (480x270) with look-ahead + peek-down,
// parallax backdrop, touch HUD + keyboard input (one shared InputIntent),
// sfx/fx event mapping, and results/fail persistence. ALL gameplay logic
// lives in the headless session/cores — nothing here mutates game state
// except through InputIntent.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/gestures.dart'
    show
        Drag,
        DragEndDetails,
        DragStartDetails,
        DragUpdateDetails,
        ImmediateMultiDragGestureRecognizer,
        TapDownDetails,
        TapUpDetails;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../audio/audio_service.dart';
import '../core/rng.dart';
import '../meta/daily.dart';
import '../ui/app_state.dart';
import 'components/decor_layer.dart';
import 'components/enemy_component.dart';
import 'components/fx.dart';
import 'components/hud.dart';
import 'components/items_component.dart';
import 'components/parallax_bg.dart';
import 'components/player_component.dart';
import 'components/tile_layer.dart';
import 'core_loadout.dart';
import 'input_intent.dart';
import 'level/level_data.dart';
import 'player/player_core.dart';
import 'session.dart';
import 'tuning.dart';

// NOTE ON THE MIXINS (v1.0.0-alpha.3 touch-input fix, the REAL alpha.1 bug):
// Flame's TapCallbacks/DragCallbacks components normally get their gesture
// recognizers attached lazily — MultiTap/MultiDragDispatcher are only created
// when the first such component MOUNTS, which for our HUD is after onLoad,
// i.e. after the GameWidget has already built once. The widget-refresh that
// is supposed to re-wrap the game in a RawGestureDetector after that never
// lands in release builds (verified empirically in headless Chromium against
// the compiled web build: pointer events reached Flutter's Listener but no
// recognizer ever fired, so no HUD button ever received a tap — on device
// the whole touch HUD was dead while keyboard input worked fine).
//
// The fix: EmberGame itself implements MultiTouchTapDetector +
// MultiTouchDragDetector. Their `mount()` overrides register the gesture
// recognizers via `initializeGestures`/`gestureDetectors` BEFORE the first
// GameWidget build, so the RawGestureDetector is present from frame one. The
// game-level handlers then forward every tap/drag into the stock Flame
// dispatchers, preserving the normal component routing (componentsAtPoint →
// HudHoldButton TapCallbacks/DragCallbacks) that all existing tests cover.
class EmberGame extends FlameGame
    with KeyboardEvents, MultiTouchTapDetector, MultiTouchDragDetector {
  static const double viewWidth = 480;
  static const double viewHeight = 270;

  static const overlayPause = 'pause';
  static const overlayResults = 'results';
  static const overlayFail = 'fail';

  final String levelId;
  final int? seedOverride; // tests + Daily Delve (deterministic daily seed)
  final bool daily; // Daily Delve run: wallet + daily best only, no records

  EmberGame({required this.levelId, this.seedOverride, this.daily = false})
      : super(
          camera: CameraComponent.withFixedResolution(
              width: viewWidth, height: viewHeight),
        ) {
    // Pre-register the component-event dispatchers. If we left this to
    // TapCallbacks/DragCallbacks (which add them when the first HUD button
    // mounts), their gesture recognizers would be registered after the
    // GameWidget's first build and never attach in release builds — the
    // whole touch HUD stays deaf (see class note above).
    // registerKey is what TapCallbacks/DragCallbacks.onMount would call for
    // their lazily-created dispatchers; using it here keeps them from ever
    // creating duplicates.
    // ignore: invalid_use_of_internal_member
    registerKey(const MultiTapDispatcherKey(), _tapDispatcher);
    add(_tapDispatcher);
    // ignore: invalid_use_of_internal_member
    registerKey(const MultiDragDispatcherKey(), _dragDispatcher);
    add(_dragDispatcher);
    // Touching gestureDetectors here runs initializeGestures(this), wiring
    // the tap recognizer to our MultiTapListener API before the first build.
    // The drag recognizer has no game-level branch there, so add it directly.
    gestureDetectors.add<ImmediateMultiDragGestureRecognizer>(
      ImmediateMultiDragGestureRecognizer.new,
      (ImmediateMultiDragGestureRecognizer instance) {
        instance.onStart = (Offset point) => _GameDragAdapter(this, point);
      },
    );
  }

  final MultiTapDispatcher _tapDispatcher = MultiTapDispatcher();
  final MultiDragDispatcher _dragDispatcher = MultiDragDispatcher();

  // -- game-level gesture API → component dispatchers -------------------------
  // Forward every tap/drag into the stock Flame dispatchers, preserving the
  // normal componentsAtPoint routing to TapCallbacks/DragCallbacks components.
  @override
  void handleTapDown(int pointerId, TapDownDetails details) =>
      _tapDispatcher.onTapDown(TapDownEvent(pointerId, this, details));

  @override
  void handleTapUp(int pointerId, TapUpDetails details) =>
      _tapDispatcher.onTapUp(TapUpEvent(pointerId, this, details));

  @override
  void handleTapCancel(int pointerId) =>
      _tapDispatcher.onTapCancel(TapCancelEvent(pointerId));

  @override
  void handleLongTapDown(int pointerId, TapDownDetails details) =>
      _tapDispatcher.onLongTapDown(TapDownEvent(pointerId, this, details));

  @override
  void handleDragStart(int pointerId, DragStartDetails details) =>
      _dragDispatcher.onDragStart(DragStartEvent(pointerId, this, details));

  @override
  void handleDragUpdate(int pointerId, DragUpdateDetails details) =>
      _dragDispatcher.onDragUpdate(DragUpdateEvent(pointerId, this, details));

  @override
  void handleDragEnd(int pointerId, DragEndDetails details) =>
      _dragDispatcher.onDragEnd(DragEndEvent(pointerId, details));

  @override
  void handleDragCancel(int pointerId) =>
      _dragDispatcher.onDragCancel(DragCancelEvent(pointerId));

  late LevelSession session;
  final InputIntent _intent = InputIntent();

  // Touch state (buttons set these; merged with keyboard each frame).
  bool touchLeft = false;
  bool touchRight = false;
  bool touchDown = false;
  bool _touchJumpHeld = false;
  bool _touchJumpEdge = false;
  bool _touchAttackEdge = false;
  bool _touchThrowEdge = false;

  final Set<LogicalKeyboardKey> _keys = {};
  bool _keyJumpEdge = false;
  bool _keyAttackEdge = false;
  bool _keyThrowEdge = false;

  late SpriteAnimation _deathAnim;
  double _camBump = 0;
  final math.Random _bumpRand = math.Random();
  bool _resultsPersisted = false;

  Vector2 get cameraPos => camera.viewfinder.position;

  @override
  Future<void> onLoad() async {
    final source = await Flame.bundle.loadString('assets/levels/$levelId.txt');
    final level = LevelData.parse(source);
    final loadout = AppState.isReady
        ? Loadout.fromSave(AppState.save)
        : Loadout.starter();
    final seed = seedOverride ??
        DateTime.now().millisecondsSinceEpoch % rngMod;
    session = LevelSession(level, loadout, seed: seed);

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position =
        Vector2(session.player.body.centerX, session.player.body.centerY);
    camera.backdrop.add(ParallaxBackground());

    world.add(DecorLayerComponent());
    world.add(TileLayerComponent());
    world.add(ItemsComponent());
    world.add(PlayerComponent());
    for (final core in session.enemies) {
      world.add(EnemyComponent(core));
    }

    _deathAnim = SpriteAnimation.fromFrameData(
      await images.load('fx/enemy_death.png'),
      SpriteAnimationData.sequenced(
          amount: 6, stepTime: 0.07, textureSize: Vector2(40, 41), loop: false),
    );

    _buildHud();
    AudioService.instance?.playMusic(session.level.music);
  }

  void _buildHud() {
    const btn = 52.0;
    const pad = 8.0;
    final bottomY = viewHeight - btn - pad;
    camera.viewport.addAll([
      HudHoldButton(
        spritePath: 'hud/btn_left.png',
        position: Vector2(pad, bottomY),
        size: Vector2.all(btn),
        onPressed: () => touchLeft = true,
        onReleased: () => touchLeft = false,
      ),
      HudHoldButton(
        spritePath: 'hud/btn_right.png',
        position: Vector2(pad + btn + 6, bottomY),
        size: Vector2.all(btn),
        onPressed: () => touchRight = true,
        onReleased: () => touchRight = false,
      ),
      // Throw (apple) button sits above the sword button; HudThrowButton
      // hides itself whenever the pouch is empty.
      HudThrowButton(
        position: Vector2(viewWidth - pad - btn * 2 - 6, bottomY - btn * 0.8 - 6),
        size: Vector2.all(btn * 0.8),
        onPressed: () => _touchThrowEdge = true,
      ),
      HudHoldButton(
        spritePath: 'hud/btn_round.png',
        iconPath: 'hud/icon_sword.png',
        position: Vector2(viewWidth - pad - btn * 2 - 6, bottomY),
        size: Vector2.all(btn),
        onPressed: () => _touchAttackEdge = true,
        onReleased: () {},
      ),
      HudHoldButton(
        spritePath: 'hud/btn_round.png',
        iconPath: 'hud/icon_jump.png',
        position: Vector2(viewWidth - pad - btn, bottomY),
        size: Vector2.all(btn),
        onPressed: () {
          _touchJumpEdge = true;
          _touchJumpHeld = true;
        },
        onReleased: () => _touchJumpHeld = false,
      ),
      HudHoldButton(
        spritePath: 'hud/icon_pause.png',
        position: Vector2(viewWidth - 26, 6),
        size: Vector2.all(20),
        onPressed: pauseGame,
        onReleased: () {},
      ),
      HudReadout(),
    ]);
  }

  // -- input ------------------------------------------------------------------

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keys
      ..clear()
      ..addAll(keysPressed);
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space ||
          k == LogicalKeyboardKey.keyW ||
          k == LogicalKeyboardKey.arrowUp) {
        _keyJumpEdge = true;
      }
      if (k == LogicalKeyboardKey.keyJ || k == LogicalKeyboardKey.keyX) {
        _keyAttackEdge = true;
      }
      if (k == LogicalKeyboardKey.keyK || k == LogicalKeyboardKey.keyC) {
        _keyThrowEdge = true;
      }
      if (k == LogicalKeyboardKey.escape) pauseGame();
    }
    return KeyEventResult.handled;
  }

  bool get _keyLeft =>
      _keys.contains(LogicalKeyboardKey.arrowLeft) ||
      _keys.contains(LogicalKeyboardKey.keyA);
  bool get _keyRight =>
      _keys.contains(LogicalKeyboardKey.arrowRight) ||
      _keys.contains(LogicalKeyboardKey.keyD);
  bool get _keyDown =>
      _keys.contains(LogicalKeyboardKey.arrowDown) ||
      _keys.contains(LogicalKeyboardKey.keyS);
  bool get _keyJumpHeld =>
      _keys.contains(LogicalKeyboardKey.space) ||
      _keys.contains(LogicalKeyboardKey.keyW) ||
      _keys.contains(LogicalKeyboardKey.arrowUp);

  // -- frame ------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;
    final clamped = math.min(dt, 1 / 30); // avoid tunnel-y catch-up steps

    _intent
      ..dirX = (touchRight || _keyRight ? 1.0 : 0.0) -
          (touchLeft || _keyLeft ? 1.0 : 0.0)
      ..down = touchDown || _keyDown
      ..jumpHeld = _touchJumpHeld || _keyJumpHeld
      ..jumpPressed = _touchJumpEdge || _keyJumpEdge
      ..attackPressed = _touchAttackEdge || _keyAttackEdge
      ..throwPressed = _touchThrowEdge || _keyThrowEdge;
    _touchJumpEdge = _keyJumpEdge = false;
    _touchAttackEdge = _keyAttackEdge = false;
    _touchThrowEdge = _keyThrowEdge = false;

    session.cameraX = cameraPos.x;
    session.update(clamped, _intent);
    _handlePlayerEvents();
    _handleSessionEvents();
    _followCamera(clamped);

    // Low-HP heartbeat bed under the combat music (dedupes internally).
    AudioService.instance?.setDanger(
        session.player.hearts <= 1 && !session.player.isDead && !session.over);
  }

  @override
  void onRemove() {
    AudioService.instance?.setDanger(false);
    super.onRemove();
  }

  void _handlePlayerEvents() {
    for (final e in session.takePlayerEvents()) {
      switch (e) {
        case PlayerEvent.jumped:
          AudioService.instance?.playSfx('jump', volume: 0.55);
        case PlayerEvent.airJumped:
          AudioService.instance?.playSfx('double_jump', volume: 0.55);
        case PlayerEvent.landed:
          AudioService.instance?.playSfx('land', volume: 0.5);
          world.add(PuffFx(
              Vector2(session.player.body.centerX, session.player.body.bottom)));
        case PlayerEvent.hurt:
          AudioService.instance?.playSfx('player_hit');
        case PlayerEvent.died:
          break; // handled via SessionEventKind.levelFailed
        case PlayerEvent.attacked:
          // 3-hit combo reads as a phrase: neutral / up / down+heavy.
          AudioService.instance?.playSfx(
              'swing${session.player.comboIndex.clamp(0, 2) + 1}',
              volume: 0.7);
        case PlayerEvent.droppedThrough:
          break;
      }
    }
  }

  void _handleSessionEvents() {
    for (final e in session.takeEvents()) {
      final at = Vector2(e.x, e.y);
      switch (e.kind) {
        case SessionEventKind.coin:
          AudioService.instance?.playSfx('coin', volume: 0.5);
          world.add(SparkleFx(at));
        case SessionEventKind.applePickup:
          AudioService.instance?.playSfx('heal', volume: 0.6);
        case SessionEventKind.feather:
          AudioService.instance?.playSfx('feather');
        case SessionEventKind.chestOpen:
          AudioService.instance?.playSfx('chest_open');
          world.add(SparkleFx(at, life: 0.5));
        case SessionEventKind.secretFound:
          AudioService.instance?.playSfx('secret');
        case SessionEventKind.enemyHit:
          AudioService.instance?.playSfx('enemy_hit');
          _camBump = e.crit ? 3.0 : 1.5;
        case SessionEventKind.enemyDeath:
          AudioService.instance?.playSfx('enemy_death');
          world.add(DeathFx(at, _deathAnim.clone()));
        case SessionEventKind.wallHit:
          AudioService.instance?.playSfx('block', volume: 0.7);
        case SessionEventKind.wallBreak:
          AudioService.instance?.playSfx('block');
          world.add(PuffFx(at,
              color: const Color(0xCC8A7B66), radius: 7, life: 0.4));
        case SessionEventKind.appleThrown:
          AudioService.instance?.playSfx('whoosh', volume: 0.5);
        case SessionEventKind.appleBroke:
          world.add(PuffFx(at,
              color: const Color(0xAAB6D53C), radius: 3, life: 0.2));
        case SessionEventKind.attackBlocked:
          AudioService.instance?.playSfx('block');
          world.add(PuffFx(at,
              color: const Color(0xCCB8C0C8), radius: 4, life: 0.22));
        case SessionEventKind.emberShot:
          AudioService.instance?.playSfx('whoosh', volume: 0.45);
        case SessionEventKind.bossPhase:
          AudioService.instance?.playSfx('enemy_hit', volume: 0.9);
          _camBump = 4.0;
        case SessionEventKind.bossDefeated:
          AudioService.instance?.playSfx('boss_death');
          _camBump = 5.0;
        case SessionEventKind.emberShotBroke:
          world.add(PuffFx(at,
              color: const Color(0xCCE86A17), radius: 4, life: 0.25));
        case SessionEventKind.levelComplete:
          _persistResults();
          AudioService.instance?.playMusic('victory', loop: false);
          overlays.add(overlayResults);
        case SessionEventKind.levelFailed:
          AudioService.instance?.playMusic('defeat', loop: false);
          overlays.add(overlayFail);
      }
    }
  }

  void _followCamera(double dt) {
    final p = session.player;
    var targetX = p.body.centerX + kCameraLookAhead * p.facing;
    var targetY = p.body.centerY - 12;
    final peeking = _intent.down &&
        p.body.onGround &&
        (p.state == PlayerState.idle || p.state == PlayerState.run);
    if (peeking) targetY += kCameraPeekDown;

    // Clamp to level bounds (center the axis when the level is smaller).
    final levelW = session.level.width * kTileSize;
    final levelH = session.level.height * kTileSize;
    targetX = levelW <= viewWidth
        ? levelW / 2
        : targetX.clamp(viewWidth / 2, levelW - viewWidth / 2);
    targetY = levelH <= viewHeight
        ? levelH / 2
        : targetY.clamp(viewHeight / 2, levelH - viewHeight / 2);

    final k = (kCameraSmooth * dt).clamp(0.0, 1.0);
    final pos = camera.viewfinder.position;
    _camBump = math.max(0, _camBump - 12 * dt);
    final bumpY = _camBump > 0 ? (_bumpRand.nextDouble() - 0.5) * _camBump * 2 : 0.0;
    camera.viewfinder.position = Vector2(
      pos.x + (targetX - pos.x) * k,
      pos.y + (targetY - pos.y) * k + bumpY,
    );
  }

  // -- flow -------------------------------------------------------------------

  void pauseGame() {
    if (overlays.isActive(overlayPause) || session.over) return;
    overlays.add(overlayPause);
    pauseEngine();
  }

  void resumeGame() {
    overlays.remove(overlayPause);
    resumeEngine();
  }

  /// Results persistence — spec: recordFor(levelId) + wallet earn + kill
  /// counting to the equipped skin, saved exactly once at level end.
  void _persistResults() {
    if (_resultsPersisted || !AppState.isReady) return;
    _resultsPersisted = true;
    final r = session.results!;
    final save = AppState.save;
    if (daily) {
      // Daily Delve is a remix: it pays out normally but never touches
      // campaign level records (would skew unlock progression). Best time
      // is kept for today only — yesterday's record simply ages out.
      final key = dailyKey(DateTime.now());
      if (save.dailyBestDate != key || r.timeMs < save.dailyBestTimeMs) {
        save.dailyBestDate = key;
        save.dailyBestTimeMs = r.timeMs;
      }
      save.coins += r.totalCoins;
      save.feathers += session.feathersCollected;
      save.skinKills[save.equippedSkin] =
          (save.skinKills[save.equippedSkin] ?? 0) + session.kills;
      AppState.persist();
      return;
    }
    final rec = save.recordFor(levelId);
    rec.finished = rec.finished || r.finished;
    rec.allChests = rec.allChests || r.allChests;
    rec.lowDamage = rec.lowDamage || r.lowDamage;
    if (r.chestsOpened > rec.chestsOpened) rec.chestsOpened = r.chestsOpened;
    if (r.secretsFound > rec.secretsFound) rec.secretsFound = r.secretsFound;
    if (rec.bestTimeMs == 0 || r.timeMs < rec.bestTimeMs) {
      rec.bestTimeMs = r.timeMs;
    }
    save.coins += r.totalCoins; // run coins + perfect-clear bonus
    save.feathers += session.feathersCollected;
    save.skinKills[save.equippedSkin] =
        (save.skinKills[save.equippedSkin] ?? 0) + session.kills;
    if (levelId == 'w1_l1') save.tutorialSeen = true;
    AppState.persist();
  }
}

/// Adapts Flutter's [Drag] interface (fed by the
/// [ImmediateMultiDragGestureRecognizer] registered in the [EmberGame]
/// constructor) to the game-level MultiDragListener API. Mirrors Flame's
/// internal FlameDragAdapter, which is not exported.
class _GameDragAdapter implements Drag {
  _GameDragAdapter(this._game, Offset startPoint) {
    _id = _dragIdCounter++;
    _game.handleDragStart(
      _id,
      DragStartDetails(
        sourceTimeStamp: Duration.zero,
        globalPosition: startPoint,
        localPosition: _game.renderBox.globalToLocal(startPoint),
      ),
    );
  }

  static int _dragIdCounter = 0;
  final EmberGame _game;
  late final int _id;

  @override
  void update(DragUpdateDetails details) =>
      _game.handleDragUpdate(_id, details);

  @override
  void end(DragEndDetails details) => _game.handleDragEnd(_id, details);

  @override
  void cancel() => _game.handleDragCancel(_id);
}
