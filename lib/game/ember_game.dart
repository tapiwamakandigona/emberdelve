// game/ember_game.dart — the Flame shell around LevelSession. Owns the level
// lifecycle, fixed-resolution camera (352x198) with look-ahead + peek-down,
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
import 'package:flutter/widgets.dart' show EdgeInsets, KeyEventResult;

import '../audio/audio_service.dart';
import 'haptics.dart';
import '../core/rng.dart';
import '../meta/catalog.dart' show SpellEffect, WeaponSpecial;
import '../meta/daily.dart';
import '../ui/app_state.dart';
import 'components/apple_arc_preview.dart';
import 'components/decor_layer.dart';
import 'components/enemy_component.dart';
import 'components/fx.dart';
import 'components/hud.dart';
import 'components/items_component.dart';
import 'components/parallax_bg.dart';
import 'components/perf_overlay.dart';
import 'components/player_component.dart';
import 'components/tile_layer.dart';
import 'core_loadout.dart';
import 'difficulty.dart';
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
  // AKP-1a (docs/ak-parity-plan.md): 352x198 — owner-confirmed 2026-07-25:
  // exact Apple Knight character-size match. Same 16:9; the 24px player
  // reads 24/198 ≈ 12.1% of screen height (AK measured ≈12.5%). Was 384x216
  // (11.1%), originally 480x270. No sprite or physics constant changes.
  static const double viewWidth = 352;
  static const double viewHeight = 198;

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
  bool _touchThrowHeld = false; // AKP-4c: arc preview while held
  bool _touchSpellEdge = false;
  bool _keySpellEdge = false;
  bool _touchRollEdge = false;

  final Set<LogicalKeyboardKey> _keys = {};
  bool _keyJumpEdge = false;
  bool _keyAttackEdge = false;
  bool _keyThrowEdge = false;
  bool _keyRollEdge = false;

  late SpriteAnimation _deathAnim;
  double _camBump = 0;
  late PlayerComponent _playerComponent;
  double _stepClock = 0;
  bool _stepAlt = false;
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
    session = LevelSession(level, loadout,
        seed: seed,
        difficulty: AppState.isReady
            ? difficultyFromId(AppState.save.difficulty)
            : Difficulty.medium);

    camera.viewfinder.anchor = Anchor.center;
    _camSmoothX = session.player.body.centerX;
    _camSmoothY = session.player.body.centerY;
    camera.viewfinder.position = Vector2(_camSmoothX, _camSmoothY);
    camera.backdrop.add(ParallaxBackground());

    world.add(DecorLayerComponent());
    world.add(TileLayerComponent());
    world.add(ItemsComponent());
    world.add(_playerComponent = PlayerComponent());
    world.add(AppleArcPreview()); // AKP-4c
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

  // AKP-5 (docs/ak-parity-plan.md §5): AK-style control layout.
  // Bottom-left: left/right arrows + a down-chevron (peek/drop-through —
  // finally wires touchDown, AKP-2c). Bottom-right: 4-button diamond —
  // jump (biggest, bottom-right), sword (left of it), dash (top-left),
  // apple (top-right, auto-hides). Pause >= 44 logical px (AKP-5b).
  //
  // Alignment pass (owner-reported, 2026-07-25): the small diamond buttons
  // (dash, apple) are CENTERED on their column (sword / jump) instead of
  // edge-aligned, and the whole HUD respects device safe areas — display
  // cutouts (notch / punch-hole) and gesture- or 3-button-nav bars — pushed
  // in from the hosting widget via [setSafeArea]. Geometry lives in
  // [_layoutHud] so it can re-run on resize / inset changes.
  static const hudBtn = 52.0; // arrows + sword
  static const hudJumpBtn = 56.0; // jump reads biggest, AK-style
  static const hudSmallBtn = 44.0; // dash / apple / down / pause (>= 48dp)
  static const hudPad = 8.0;
  static const hudGap = 6.0;

  HudHoldButton? _btnLeft, _btnRight, _btnDown;
  HudHoldButton? _btnDash, _btnSword, _btnJump, _btnPause;
  HudThrowButton? _btnThrow;
  HudSpellButton? _btnSpell;
  HudReadout? _readout;

  // Screen-space (logical px) safe-area padding from the hosting widget;
  // converted to viewport units in [hudSafeInsets].
  EdgeInsets _safePadding = EdgeInsets.zero;
  Vector2 _canvas = Vector2(1280, 720);

  /// Called by the hosting widget (GameScreen) whenever MediaQuery padding
  /// changes: display cutout, status bar, gesture-nav / 3-button-nav bar.
  void setSafeArea(EdgeInsets padding) {
    if (padding == _safePadding) return;
    _safePadding = padding;
    _layoutHud();
  }

  /// Safe-area padding converted from screen logical px to viewport units.
  /// The fixed-resolution viewport is scaled uniformly and letterboxed; any
  /// part of an inset that falls inside the letterbox band costs nothing.
  EdgeInsets get hudSafeInsets {
    final scale =
        math.min(_canvas.x / viewWidth, _canvas.y / viewHeight);
    if (scale <= 0) return EdgeInsets.zero;
    final boxX = (_canvas.x - viewWidth * scale) / 2;
    final boxY = (_canvas.y - viewHeight * scale) / 2;
    double side(double inset, double box) =>
        math.max(0, (inset - box) / scale);
    return EdgeInsets.fromLTRB(
      side(_safePadding.left, boxX),
      side(_safePadding.top, boxY),
      side(_safePadding.right, boxX),
      side(_safePadding.bottom, boxY),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _canvas = size.clone();
    _layoutHud();
  }

  void _layoutHud() {
    if (_btnLeft == null) return; // HUD not built yet
    final ins = hudSafeInsets;
    final left = hudPad + ins.left;
    final right = viewWidth - hudPad - ins.right;
    final bottom = viewHeight - hudPad - ins.bottom;
    final top = hudPad + ins.top;

    // Left cluster: arrows bottom-aligned, down-chevron beside them.
    final bottomY = bottom - hudBtn;
    _btnLeft!.position.setValues(left, bottomY);
    _btnRight!.position.setValues(left + hudBtn + hudGap, bottomY);
    _btnDown!.position
        .setValues(left + (hudBtn + hudGap) * 2, bottom - hudSmallBtn);

    // Right diamond: jump biggest bottom-right, sword left of it; dash and
    // apple centered above their columns (not edge-aligned — the alignment
    // fix), so the diamond reads symmetric at any button-size mix.
    final jumpX = right - hudJumpBtn;
    final jumpY = bottom - hudJumpBtn;
    final swordX = jumpX - hudBtn - hudGap;
    final swordY = bottom - hudBtn;
    _btnJump!.position.setValues(jumpX, jumpY);
    _btnSword!.position.setValues(swordX, swordY);
    _btnDash!.position.setValues(
        swordX + (hudBtn - hudSmallBtn) / 2, swordY - hudSmallBtn - hudGap);
    _btnThrow!.position.setValues(jumpX + (hudJumpBtn - hudSmallBtn) / 2,
        jumpY - hudSmallBtn - hudGap);
    // Spell (AKP-4d): caps the dash column, auto-hides without a charge.
    _btnSpell!.position.setValues(swordX + (hudBtn - hudSmallBtn) / 2,
        swordY - (hudSmallBtn + hudGap) * 2);

    _btnPause!.position.setValues(right - hudSmallBtn, top);
    _readout!.position.setValues(ins.left, ins.top);
  }

  void _buildHud() {
    _btnLeft = HudHoldButton(
      spritePath: 'hud/btn_left.png',
      position: Vector2.zero(),
      size: Vector2.all(hudBtn),
      spawnFade: true,
      onPressed: () => touchLeft = true,
      onReleased: () => touchLeft = false,
    );
    _btnRight = HudHoldButton(
      spritePath: 'hud/btn_right.png',
      position: Vector2.zero(),
      size: Vector2.all(hudBtn),
      spawnFade: true,
      onPressed: () => touchRight = true,
      onReleased: () => touchRight = false,
    );
    // Down chevron (AKP-2c): camera peek-down + drop-through one-way
    // platforms — previously keyboard-only on the touch build.
    _btnDown = HudHoldButton(
      spritePath: 'hud/btn_down.png',
      position: Vector2.zero(),
      size: Vector2.all(hudSmallBtn),
      spawnFade: true,
      onPressed: () => touchDown = true,
      onReleased: () => touchDown = false,
    );
    // Throw (apple) button: diamond top-right, above jump; HudThrowButton
    // hides itself whenever the pouch is empty.
    _btnThrow = HudThrowButton(
      position: Vector2.zero(),
      size: Vector2.all(hudSmallBtn),
      onPressed: () {
        _touchThrowEdge = true;
        _touchThrowHeld = true; // AKP-4c: keep held -> arc preview
      },
      onReleased: () => _touchThrowHeld = false,
    );
    // Dash/roll (AKP-2a): diamond top-left, above the sword.
    // Spell cast (AKP-4d): one charge per run; hides itself otherwise.
    _btnSpell = HudSpellButton(
      position: Vector2.zero(),
      size: Vector2.all(hudSmallBtn),
      onPressed: () => _touchSpellEdge = true,
    );
    _btnDash = HudHoldButton(
      spritePath: 'hud/btn_round.png',
      iconPath: 'hud/icon_dash.png',
      position: Vector2.zero(),
      size: Vector2.all(hudSmallBtn),
      onPressed: () => _touchRollEdge = true,
      onReleased: () {},
    );
    _btnSword = HudHoldButton(
      spritePath: 'hud/btn_round.png',
      iconPath: 'hud/icon_sword.png',
      position: Vector2.zero(),
      size: Vector2.all(hudBtn),
      onPressed: () => _touchAttackEdge = true,
      onReleased: () {},
    );
    _btnJump = HudHoldButton(
      spritePath: 'hud/btn_round.png',
      iconPath: 'hud/icon_jump.png',
      position: Vector2.zero(),
      size: Vector2.all(hudJumpBtn),
      onPressed: () {
        _touchJumpEdge = true;
        _touchJumpHeld = true;
      },
      onReleased: () => _touchJumpHeld = false,
    );
    _btnPause = HudHoldButton(
      spritePath: 'hud/icon_pause.png',
      position: Vector2.zero(),
      size: Vector2.all(hudSmallBtn),
      onPressed: pauseGame,
      onReleased: () {},
    );
    _readout = HudReadout();
    _layoutHud();
    camera.viewport.addAll([
      _btnLeft!,
      _btnRight!,
      _btnDown!,
      _btnThrow!,
      _btnSpell!,
      _btnDash!,
      _btnSword!,
      _btnJump!,
      _btnPause!,
      _readout!,
      // Frame-time readout for device profiling; compiled out of normal
      // builds (--dart-define=PERF_OVERLAY=true to enable — docs/perf.md §2).
      if (const bool.fromEnvironment('PERF_OVERLAY'))
        PerfOverlay()..position = Vector2(4, viewHeight - 14),
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
      // AKP-4d: spell cast on Q or M (session-level verb, one per run).
      if (k == LogicalKeyboardKey.keyQ || k == LogicalKeyboardKey.keyM) {
        _keySpellEdge = true;
      }
      // AKP-2a: dash/roll on Shift (the DOWN+JUMP chord still works too).
      if (k == LogicalKeyboardKey.shiftLeft ||
          k == LogicalKeyboardKey.shiftRight ||
          k == LogicalKeyboardKey.keyL) {
        _keyRollEdge = true;
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
  bool get _keyThrowHeld =>
      _keys.contains(LogicalKeyboardKey.keyK) ||
      _keys.contains(LogicalKeyboardKey.keyC);

  /// AKP-4c: the arc preview draws only while the throw button is held with
  /// apples in the pouch and the player alive — an empty pouch has nothing
  /// to preview.
  bool get throwPreviewActive =>
      _intent.throwHeld && session.applesHeld > 0 && !session.player.isDead;

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
      ..throwPressed = _touchThrowEdge || _keyThrowEdge
      ..throwHeld = _touchThrowHeld || _keyThrowHeld
      ..rollPressed = _touchRollEdge || _keyRollEdge;
    _touchJumpEdge = _keyJumpEdge = false;
    _touchAttackEdge = _keyAttackEdge = false;
    _touchThrowEdge = _keyThrowEdge = false;
    _touchRollEdge = _keyRollEdge = false;
    // AKP-4d: the spell is a session verb (touch button + Q/M), not part of
    // InputIntent — it never competes with movement buffering.
    if (_touchSpellEdge || _keySpellEdge) session.castSpell();
    _touchSpellEdge = _keySpellEdge = false;

    session.cameraX = cameraPos.x;
    session.update(clamped, _intent);
    _handlePlayerEvents();
    _handleSessionEvents();
    _followCamera(clamped);

    // Footsteps: cadence-gated, only while genuinely running on ground.
    final p = session.player;
    if (p.state == PlayerState.run && p.body.vx.abs() > kRunSpeed * 0.5) {
      _stepClock -= clamped;
      if (_stepClock <= 0) {
        _stepClock = kFootstepInterval;
        _stepAlt = !_stepAlt;
        AudioService.instance
            ?.playSfx(_stepAlt ? 'step1' : 'step2', volume: 0.28);
      }
    } else {
      // Re-arm so the first step lands just after movement starts (not
      // instantly on a tap, which reads as a click).
      _stepClock = kFootstepInterval * 0.5;
    }

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
          _playerComponent.triggerSquash(); // AKP-3a
          world.add(PuffFx(
              Vector2(session.player.body.centerX, session.player.body.bottom)));
        case PlayerEvent.hurt:
          AudioService.instance?.playSfx('player_hit');
          Haptics.medium(); // taking a hit is the beat that must land
          _camBump = 3.0; // AKP-3e: getting hit shakes; normal hits never do
        case PlayerEvent.died:
          break; // handled via SessionEventKind.levelFailed
        case PlayerEvent.rolled:
          AudioService.instance?.playSfx('whoosh', volume: 0.5);
          world.add(PuffFx(
              Vector2(session.player.body.centerX, session.player.body.bottom),
              life: 0.22));
        case PlayerEvent.airDashed:
          // AKP-2b: slightly sharper whoosh, puff trails BEHIND the dash at
          // body height (there is no ground under an air dash).
          AudioService.instance?.playSfx('whoosh', volume: 0.65);
          world.add(PuffFx(
              Vector2(
                  session.player.body.centerX -
                      session.player.facing * 8,
                  session.player.body.centerY),
              life: 0.22));
        case PlayerEvent.attacked:
          // AKP-4b: Skypiercer's lunge leaves a dash streak behind the
          // burst, same read as the air-dash trail.
          if (session.loadout.weapon.special == WeaponSpecial.lunge) {
            world.add(PuffFx(
                Vector2(
                    session.player.body.centerX - session.player.facing * 7,
                    session.player.body.centerY + 4),
                color: const Color(0x99A9D1F7),
                radius: 4,
                life: 0.2));
          }
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
        case SessionEventKind.heartPickup:
          AudioService.instance?.playSfx('heal', volume: 0.8);
          world.add(SparkleFx(at, color: const Color(0xFFD53C3C), life: 0.4));
        case SessionEventKind.feather:
          AudioService.instance?.playSfx('feather');
        case SessionEventKind.chestOpen:
          AudioService.instance?.playSfx('chest_open');
          world.add(SparkleFx(at, life: 0.5));
        case SessionEventKind.spellCast:
          // AKP-4d: golden flash + chime; effect-specific feedback rides on
          // the events the effect itself emits (enemyHit / heal below).
          AudioService.instance?.playSfx('secret', volume: 0.9);
          Haptics.light();
          world.add(SparkleFx(at, life: 0.5));
          if (session.loadout.spell?.effect == SpellEffect.hearthLight) {
            AudioService.instance?.playSfx('heal');
          }
        case SessionEventKind.secretFound:
          AudioService.instance?.playSfx('secret');
        case SessionEventKind.enemyHit:
          AudioService.instance?.playSfx('enemy_hit');
          // AKP-3e: shake only on the beats that earn it — crits and the
          // combo finisher. Every normal hit shaking reads as noise (and
          // the plan calls it a motion-sickness risk).
          if (e.crit || session.player.comboIndex == 2) _camBump = 3.0;
          // AKP-3c: floating damage number (skipped silently at the cap).
          if (e.amount > 0 && DamageNumberFx.hasBudget) {
            world.add(DamageNumberFx(at.clone(), e.amount, crit: e.crit));
          }
          // AKP-4b: Ember Fang identity — hits shed embers (the ignite DoT
          // is session-side; this is its visual receipt).
          if (session.loadout.burnOnHit) {
            world.add(SparkleFx(at.clone(),
                color: const Color(0xFFF2A24B), life: 0.3));
          }
        case SessionEventKind.enemyDeath:
          AudioService.instance?.playSfx('enemy_death');
          Haptics.light(); // kill confirm
          world.add(DeathFx(at, _deathAnim.clone()));
        case SessionEventKind.wallHit:
          AudioService.instance?.playSfx('block', volume: 0.7);
        case SessionEventKind.wallBreak:
          AudioService.instance?.playSfx('block');
          // AKP-4b: the Woodsman's Axe one-chop break earns a heavier
          // rubble burst than chipping a wall down with a sword.
          world.add(PuffFx(at,
              color: const Color(0xCC8A7B66),
              radius: session.loadout.wallBreaker ? 10 : 7,
              life: session.loadout.wallBreaker ? 0.5 : 0.4));
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
          Haptics.heavy();
          _camBump = 4.0;
        case SessionEventKind.bossDefeated:
          AudioService.instance?.playSfx('boss_death');
          Haptics.heavy();
          _camBump = 5.0;
        case SessionEventKind.emberShotBroke:
          world.add(PuffFx(at,
              color: const Color(0xCCE86A17), radius: 4, life: 0.25));
        case SessionEventKind.checkpointLit:
          AudioService.instance?.playSfx('unlock', volume: 0.8);
          Haptics.light();
          world.add(SparkleFx(at, life: 0.6));
        case SessionEventKind.respawned:
          // A life spent, not a run lost: quick puff at the campfire and a
          // camera snap so the player never wonders where they went.
          AudioService.instance?.playSfx('heal', volume: 0.7);
          world.add(PuffFx(at, radius: 8, life: 0.35));
          _camSmoothX = at.x;
          _camSmoothY = at.y;
          _camBump = 2.0;
        case SessionEventKind.levelComplete:
          _persistResults();
          AudioService.instance?.playMusic('victory', loop: false);
          overlays.add(overlayResults);
        case SessionEventKind.levelFailed:
          AudioService.instance?.playMusic('defeat', loop: false);
          Haptics.heavy();
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

    // Frame-rate-independent exponential smoothing: the old `k * dt` linear
    // factor under-corrects at low fps and over-corrects at high fps, so
    // follow speed (and the apparent "weight" of the camera) changed with
    // frame rate. 1 - e^(-k*dt) converges identically at any fps.
    final k = 1 - math.exp(-kCameraSmooth * dt);
    _camBump = math.max(0, _camBump - 12 * dt);
    final bumpY = _camBump > 0 ? (_bumpRand.nextDouble() - 0.5) * _camBump * 2 : 0.0;
    _camSmoothX += (targetX - _camSmoothX) * k;
    _camSmoothY += (targetY - _camSmoothY) * k;
    // Pixel snap (movement-stutter fix): the 352x198 viewport is upscaled
    // ~5-6x with nearest-neighbor filtering. A camera at fractional world
    // coordinates makes every tile edge resample differently each frame —
    // full-screen shimmer/judder whenever the camera pans (i.e. whenever
    // the player moves). Smoothing runs on unrounded floats so no motion is
    // lost; only the rendered position is quantized to whole world pixels.
    camera.viewfinder.position = _camRender
      ..setValues(
        _camSmoothX.roundToDouble(),
        (_camSmoothY + bumpY).roundToDouble(),
      );
  }

  // Unrounded camera state (smoothing accumulator) + scratch render vector.
  double _camSmoothX = 0;
  double _camSmoothY = 0;
  final Vector2 _camRender = Vector2.zero();

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
